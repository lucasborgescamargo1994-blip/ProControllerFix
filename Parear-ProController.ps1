<#
  Pareia um Pro Controller generico (clone de Switch, ex.: "mypow Tech.") no Windows 10 via Bluetooth.

  Problema: o firmware do controle manda um SDP quebrado (registro PnP cortado) e um descritor HID
  invalido. O Windows descarta tudo, nunca cria o dispositivo HID e derruba a conexao ~4 s depois.
  Solucao: logo depois do pareamento (com o link ainda ativo), gravar no cache do Windows um registro
  HID/PnP corrigido (relatorio 0x3F do Pro Controller, medido no proprio controle) e habilitar o servico HID.

  Uso: de preferencia pelo Parear-ProController.bat (pede administrador sozinho). Direto:
      powershell -ExecutionPolicy Bypass -File .\Parear-ProController.ps1
  Parametros:
      -DryRun   so valida os dados embutidos; nao altera nada
      -Yes      nao pergunta nada (remove pareamentos antigos do controle automaticamente)
      -Mac      endereco Bluetooth (12 hex, sem :) de um pareamento antigo a remover; opcional
  Um log fica em Parear-ProController.log, na mesma pasta.
  Desfazer: remover o dispositivo em Configuracoes > Bluetooth (isso apaga o cache gravado).
#>
param(
  [string]$Mac = '',
  [int]$Seconds = 240,
  [int]$DelayAfterBondMs = 1200,
  [switch]$Yes,
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$logDir = if ($PSScriptRoot) { $PSScriptRoot } else { $env:TEMP }
try { Start-Transcript -Path (Join-Path $logDir 'Parear-ProController.log') -Force | Out-Null } catch { }

# Registro HID (305 bytes): descritor com o relatorio 0x3F + atributos que o Windows exige.
$hidHex = '36012E0900000A000100010900013503191124090004350D350619010009001135031900110900053503191002090006350909656E09006A0901000900093508350619112409010109000D350F350D350619010009001335031900110901002510576972656C6573732047616D65706164090101250747616D65706164090102250B6D79706F7720546563682E0902000901000902010901110902020808090203082109020428000902052801090206354D354B0822254705010905A101853F05091901291015002501750195108102050109391500250775049501814205097504950181010501093009310933093416000027FFFF0000751095048102C0090207350835060904090901000902082800090209280109020A280109020B09010009020C090C8009020D280009020E2800'
# Registro PnP (85 bytes): VID 057E / PID 2009 (o clone imita o Pro Controller da Nintendo).
$pnpHex = '3600520900000A000100020900013503191200090004350D350619010009000135031900010900093508350619120009010309020009010309020109057E0902020920090902030901000902042801090205090002'
$Vid = 0x057E
$Pid_ = 0x2009

function Log($m) { "{0:HH:mm:ss}  {1}" -f (Get-Date), $m }
function To-Bytes([string]$h) { [byte[]]$b = for ($i = 0; $i -lt $h.Length; $i += 2) { [Convert]::ToByte($h.Substring($i, 2), 16) }; $b }

try {
  $hid = To-Bytes $hidHex
  $pnp = To-Bytes $pnpHex
  if ($hid.Count -ne 305 -or $pnp.Count -ne 85) { throw "dados embutidos corrompidos (HID=$($hid.Count), PnP=$($pnp.Count))" }
  if ((($hid[1] * 256) + $hid[2] + 3) -ne $hid.Count) { throw 'comprimento do registro HID nao confere' }
  if ((($pnp[1] * 256) + $pnp[2] + 3) -ne $pnp.Count) { throw 'comprimento do registro PnP nao confere' }
  Log ("dados embutidos ok: HID={0} bytes, PnP={1} bytes, VID=0x{2:X4} PID=0x{3:X4}" -f $hid.Count, $pnp.Count, $Vid, $Pid_)

  if ($DryRun) { Log 'DryRun: nada foi alterado.'; return }

  if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'execute como ADMINISTRADOR (use o Parear-ProController.bat).'
  }

  Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class BtFix {
  [StructLayout(LayoutKind.Sequential)] public struct ST { public ushort a,b,c,d,e,f,g,h; }
  [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
  public struct DEVINFO {
    public uint dwSize; public ulong Address; public uint ulClassofDevice;
    public int fConnected; public int fRemembered; public int fAuthenticated;
    public ST stLastSeen; public ST stLastUsed;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 248)] public string szName;
  }
  [DllImport("bthprops.cpl", SetLastError = true)] public static extern uint BluetoothGetDeviceInfo(IntPtr r, ref DEVINFO i);
  [DllImport("bthprops.cpl", SetLastError = true)] public static extern uint BluetoothSetServiceState(IntPtr r, ref DEVINFO i, ref Guid g, uint f);
  [DllImport("bthprops.cpl", SetLastError = true)] public static extern uint BluetoothRemoveDevice(ref ulong a);
  public static DEVINFO Make(ulong a) { DEVINFO d = new DEVINFO(); d.dwSize = (uint)Marshal.SizeOf(typeof(DEVINFO)); d.Address = a; return d; }
}
'@

  $devRoot = 'HKLM:\SYSTEM\CurrentControlSet\Services\BTHPORT\Parameters\Devices'
  $nameRx  = '^(Pro Controller|Wireless Gamepad)$'
  $hidGuid = [Guid]'00001124-0000-1000-8000-00805f9b34fb'

  function Get-BtKeys {
    Get-ChildItem $devRoot -ErrorAction SilentlyContinue | ForEach-Object {
      $n = ''
      $p = Get-ItemProperty -Path $_.PSPath -Name Name -ErrorAction SilentlyContinue
      if ($p -and ($p.Name -is [byte[]])) { $n = [Text.Encoding]::UTF8.GetString($p.Name).Trim([char]0) }
      [pscustomobject]@{ Mac = $_.PSChildName.ToUpper(); Name = $n }
    }
  }

  # 1. Pareamentos antigos deste tipo de controle (so "Pro Controller" / "Wireless Gamepad"; outros dispositivos nao sao tocados).
  if ($Mac) { $targets = @([pscustomobject]@{ Mac = ($Mac -replace '[:\-]', '').ToUpper(); Name = '(informado)' }) }
  else { $targets = @(Get-BtKeys | Where-Object { $_.Name -match $nameRx }) }
  if ($targets.Count -gt 0) {
    Log 'Pareamentos atuais deste tipo de controle:'
    $targets | ForEach-Object { "      $($_.Name)  [$($_.Mac)]" }
    if (-not $Yes) {
      $ans = Read-Host 'Remover esses pareamentos agora para parear do zero? (S/N)'
      if ($ans -notmatch '^[sSyY]') { throw 'cancelado pelo usuario.' }
    }
    foreach ($t in $targets) {
      $a = [Convert]::ToUInt64($t.Mac, 16)
      Log ("pareamento {0} removido -> codigo {1} (0 = ok)" -f $t.Mac, [BtFix]::BluetoothRemoveDevice([ref]$a))
    }
    Start-Sleep -Milliseconds 800
  } else {
    Log 'Nenhum pareamento antigo deste controle encontrado.'
  }
  $before = @(Get-BtKeys | ForEach-Object { $_.Mac })

  Log ''
  Log 'AGORA: 1) segure o botao SYNC do controle (o pequeno, no topo) ate as luzes correrem;'
  Log '       2) no Windows: Configuracoes > Bluetooth > Adicionar dispositivo > Bluetooth > Pro Controller.'
  Log '       Depois de parear, NAO mexa em nada. O script termina sozinho.'

  # 2. Espera o controle aparecer, o pareamento fechar e aplica o cache corrigido enquanto o link ainda esta ativo.
  $t0 = Get-Date; $target = $null; $firstSeen = @{}; $bondAt = $null; $applied = $false; $done = $false
  $nextScan = Get-Date; $nextHint = (Get-Date).AddSeconds(25)
  while (-not $done -and ((Get-Date) - $t0).TotalSeconds -lt $Seconds) {

    if (-not $target -and (Get-Date) -ge $nextScan) {
      $nextScan = (Get-Date).AddMilliseconds(150)
      # Chaves de pareamentos removidos continuam no registro, entao o criterio e "esta conectado agora".
      foreach ($k in @(Get-BtKeys)) {
        $isNew = ($before -notcontains $k.Mac)
        if ($k.Name -and $k.Name -notmatch $nameRx) { continue }
        if (-not $k.Name -and -not $isNew) { continue }
        $dc = [BtFix]::Make([Convert]::ToUInt64($k.Mac, 16))
        [void][BtFix]::BluetoothGetDeviceInfo([IntPtr]::Zero, [ref]$dc)
        if ($dc.fConnected -ne 0) {
          $target = $k.Mac
          $shown = if ($k.Name) { $k.Name } else { '(sem nome)' }
          Log "controle detectado: $shown [$target]"
          break
        }
      }
    }
    if ($target) {
      $addr = [Convert]::ToUInt64($target, 16)
      $key  = "$devRoot\$($target.ToLower())"
      $d = [BtFix]::Make($addr)
      [void][BtFix]::BluetoothGetDeviceInfo([IntPtr]::Zero, [ref]$d)

      if (-not $bondAt -and $d.fRemembered -ne 0 -and $d.fConnected -ne 0) { $bondAt = Get-Date; Log 'pareamento fechado; gravando o cache corrigido...' }

      if ($bondAt -and -not $applied -and ((Get-Date) - $bondAt).TotalMilliseconds -ge $DelayAfterBondMs -and (Test-Path $key)) {
        New-ItemProperty -Path $key -Name VID     -PropertyType DWord -Value $Vid  -Force | Out-Null
        New-ItemProperty -Path $key -Name PID     -PropertyType DWord -Value $Pid_ -Force | Out-Null
        New-ItemProperty -Path $key -Name VIDType -PropertyType DWord -Value 2     -Force | Out-Null
        New-ItemProperty -Path $key -Name Version -PropertyType DWord -Value 0     -Force | Out-Null
        $sub = "$key\DynamicCachedServices"
        if (-not (Test-Path $sub)) { New-Item -Path $sub | Out-Null }
        New-ItemProperty -Path $sub -Name '00010001' -PropertyType Binary -Value $hid -Force | Out-Null
        New-ItemProperty -Path $sub -Name '00010002' -PropertyType Binary -Value $pnp -Force | Out-Null
        $applied = $true
        Log 'cache gravado.'
      }

      if ($applied) {
        $di = [BtFix]::Make($addr); [void][BtFix]::BluetoothGetDeviceInfo([IntPtr]::Zero, [ref]$di)
        $g = $hidGuid
        $r = [BtFix]::BluetoothSetServiceState([IntPtr]::Zero, [ref]$di, [ref]$g, 1)
        Log "habilitar servico HID -> $r (0 = ok)"
        if ($r -eq 0) { $done = $true }
      }
    }

    if ((Get-Date) -ge $nextHint -and -not $bondAt) {
      $nextHint = (Get-Date).AddSeconds(25)
      Log 'ainda esperando: segure o SYNC ate as luzes correrem e adicione o dispositivo no Windows.'
    }
    Start-Sleep -Milliseconds 40
  }

  # 3. Resultado
  if ($done) {
    $seen = $false
    for ($i = 0; $i -lt 20 -and -not $seen; $i++) {
      $c = Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object { $_.InstanceId -like 'HID\{00001124-*VID&0002057E_PID&2009*' -and $_.Status -eq 'OK' }
      if ($c) { $seen = $true } else { Start-Sleep -Milliseconds 500 }
    }
    Log ''
    if ($seen) { Log 'PRONTO: o Windows reconheceu o controle como gamepad. Teste em joy.cpl (Controladores de jogo).' }
    else       { Log 'Habilitado, mas o Windows ainda nao mostrou o gamepad. Espere uns segundos e abra joy.cpl.' }
    Log 'Para usar depois: desligue o controle e ligue so com o botao HOME (sem sync).'
  } else {
    Log ''
    Log 'NAO concluiu. Rode de novo: segure o SYNC ate as luzes correrem ANTES de adicionar o dispositivo no Windows.'
    Log 'Se o celular estiver por perto, esqueca o controle nele ou desligue o Bluetooth do celular.'
  }
}
catch {
  Log "ERRO: $($_.Exception.Message)"
}
finally {
  try { Stop-Transcript | Out-Null } catch { }
}
