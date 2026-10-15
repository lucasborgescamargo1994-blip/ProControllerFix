PRO CONTROLLER FIX
Corrige o pareamento Bluetooth e os analógicos (no DS4Windows) de controles "Pro Controller" genéricos
(clones do controle do Switch) no Windows 10.
=====================================================================================================

ENGLISH TL;DR
-------------
Some generic "Switch Pro Controller" clones (Bluetooth name "Pro Controller", SDP provider "mypow Tech.")
pair with Windows 10 but disconnect ~4 seconds later and never reconnect, while working fine on a phone.
The firmware answers Windows with malformed SDP/HID data. ProControllerFix.exe re-pairs the controller and,
while the link is still up, writes a corrected HID/PnP record into the Windows Bluetooth cache for that
device. A second tab patches DS4Windows 3.9.9 so the sticks are calibrated correctly (the clone only answers
the console-style calibration read). Tested on ONE unit, Windows 10 22H2, generic CSR USB dongle, DS4Windows
3.9.9. Source code included. Use at your own risk.


1. SINTOMAS (É O SEU CASO?)
---------------------------
- Você pareia o controle no Windows e ele desliga sozinho em poucos segundos; ao ligar com o Home, ele
  pisca e não conecta. No celular funciona normalmente.
- Em joy.cpl (Controladores de jogo) não aparece nada.
- Depois que parece funcionar: no DS4Windows os analógicos ficam tortos (repouso fora do centro).
- No Steam o controle aparece como Switch Pro mas o log mostra "Couldn't load stick calibration".

Se os seus sintomas forem outros, este programa provavelmente não resolve.


2. USO RÁPIDO
-------------
1) Baixe o ZIP da release, extraia e dê dois cliques em ProControllerFix.exe (pede administrador).
   O Windows pode mostrar um aviso do SmartScreen porque o programa não é assinado digitalmente:
   "Mais informações" > "Executar assim mesmo". O código-fonte está incluído (veja o item 8).
2) ETAPA 1 - Parear o controle:
   a) Escolha "Uso simples" (jogos/emuladores com controle genérico) ou "Com DS4Windows" (gyro e Xbox
      360 virtual). Se você usa o DS4Windows, escolha a segunda.
   b) Clique em "Primeiro de tudo, clique aqui". Se houver DS4Windows aberto, ele pede para fechar.
   c) Siga o que estiver piscando: "Abrir Bluetooth do Windows" > Adicionar dispositivo > Bluetooth;
      segure o botão SYNC do controle (o pequeno, no topo) até as luzes correrem; escolha "Pro Controller".
   d) Não mexa em mais nada: o programa termina sozinho com "Controle corrigido".
3) ETAPA 2 - Corrigir o DS4Windows (só se você usa o DS4Windows):
   a) Baixe o DS4Windows 3.9.9 pelo botão "Abrir página de download" e extraia o ZIP numa pasta.
   b) Indique a pasta (ou use "Detectar") e clique em "Aplicar correção".
   c) O controle precisa ter sido pareado na Etapa 1 com a opção "Com DS4Windows". O programa mostra
      um selo "Controle: modo DS4Windows" e oferece "Refazer no modo DS4Windows" se estiver no modo errado.
4) Dia a dia: desligue o controle e ligue só com o botão HOME (sem SYNC). Ele reconecta sozinho.


3. PROBLEMAS COMUNS
-------------------
- O controle desliga logo depois do SYNC e as luzes ficam piscando: o modo de pareamento dura pouco.
  Deixe a janela "Adicionar dispositivo" aberta e procurando antes de segurar o SYNC.
- Log "Habilitar o serviço HID -> código 87": algum programa está usando o controle (DS4Windows,
  BetterJoy, Steam...). Feche e tente de novo. O programa tenta fechar DS4Windows/BetterJoy/JoyShockMapper
  sozinho, com a sua permissão.
- No DS4Windows aparece o Xbox virtual, mas ele não se mexe e o "Wireless Gamepad" ainda responde: o
  controle foi pareado no modo simples. Use "Refazer no modo DS4Windows" (Etapa 2).
- Analógicos tortos no DS4Windows: aplique a Etapa 2. Se atualizar o DS4Windows, reaplique.
- Steam: este firmware não funciona com o Steam Input/SDL (veja o item 6). Desligue "Switch Pro" nas
  configurações de controle do Steam, senão ele fica tentando e piscando as luzes. O Xbox virtual do
  DS4Windows continua funcionando nos jogos do Steam.
- Se o celular estiver por perto, esqueça o controle nele ou desligue o Bluetooth do celular.
- "Não concluiu": repita; segure o SYNC até as luzes correrem ANTES de escolher o dispositivo.


4. O QUE O PROGRAMA ALTERA (E COMO DESFAZER)
---------------------------------------------
ETAPA 1
- Remove o pareamento atual de dispositivos chamados "Pro Controller" / "Wireless Gamepad" (com
  confirmação; outros dispositivos Bluetooth não são tocados).
- Grava no registro, só para esse controle (HKLM\SYSTEM\CurrentControlSet\Services\BTHPORT\Parameters\
  Devices\<endereço>): VID, PID, VIDType, Version e DynamicCachedServices\00010001 (HID) e \00010002
  (PnP); depois chama BluetoothSetServiceState para habilitar o serviço HID.
- Desfazer: Configurações > Bluetooth > remover o dispositivo (apaga o cache gravado).
ETAPA 2
- Faz backup de DS4Windows.dll como DS4Windows.dll.orig-<versão> (na pasta do DS4Windows), ajusta o DLL
  e confere o resultado. Se marcado, liga "Switch Pro" no Profiles.xml (backup: Profiles.xml.bak-ProControllerFix).
- Desfazer: botão "Desfazer ajuste" (restaura o backup).


5. COMO FUNCIONA (TÉCNICO)
--------------------------
Medido com captura ETW do driver Bluetooth (BTHPORT/BTHUSB) e leitura direta do HID:
- A resposta SDP do firmware tem um registro PnP Information cortado no meio do VendorID (declara 143 bytes,
  entrega 119) e um descritor HID inválido (a coleção Consumer Control herda o Report ID do mouse). O
  Windows descarta tudo, não cria o dispositivo HID e derruba o link ocioso ~3 s depois. O controle também
  não guarda o pareamento se o HID não abrir na primeira sessão.
- O programa grava no cache, ~1,2 s depois do pareamento (com o link ainda ativo), registros HID/PnP
  corrigidos. Dois formatos: "simples" (relatório 0x3F: 3F | botões(2) | hat | LX LY RX RY, 12 bytes) e
  "Nintendo" (descritor completo do Pro Controller: entradas 0x21/0x30, saídas 0x01/0x10), necessário
  para o DS4Windows enviar comandos.
- O clone só responde à leitura da memória de calibração do jeito que o console faz (bloco 0x8010 de 24
  bytes; 0x603D de 25 bytes) e ignora o tamanho pedido. O DS4Windows lê em 0x8012/0x801D (sem resposta) e
  calcula a calibração com bytes errados. O ajuste troca os dois pedidos por 0x8010 (22 bytes) e insere
  Array.Copy para alinhar os dados (esquerdo: bytes 22-30; direito: 33-41). Funciona também em controles
  originais. É feito com Mono.Cecil, em memória, e verificado antes de gravar.
- Steam/SDL exigem que o tamanho devolvido nas leituras de calibração seja igual ao pedido; o clone devolve
  tamanhos fixos, então eles falham com "Couldn't load stick calibration". Gravações na memória do clone
  são aceitas (ack) mas ignoradas.


6. LIMITAÇÕES E O QUE FOI TESTADO
---------------------------------
- Testado em UMA unidade (SDP: "Wireless Gamepad" / "mypow Tech."), Windows 10 22H2 (build 19045), dongle USB
  CSR genérico (0A12:0001) com o driver padrão da Microsoft, DS4Windows 3.9.9. Windows 11 não testado.
- Verificados: botões, ZL/ZR, analógicos, gyro (via DS4Windows) e Xbox 360 virtual (ViGEmBus).
- ZL e ZR chegam como botões (liga/desliga); o controle não envia a pressão analógica em nenhum modo.
- O VID/PID gravado (057E / 2009, Nintendo Pro Controller) é um palpite: o VendorID real do clone chegou
  cortado em "05..". Softwares podem identificá-lo como Pro Controller original.
- Outras marcas/firmwares de clones podem se comportar de outro jeito.
- O DS4Windows não é distribuído aqui; só é ajustado a cópia que você mesmo baixou. A versão testada é a 3.9.9.


7. OPÇÕES DE LINHA DE COMANDO (AVANÇADO)
-----------------------------------------
ProControllerFix.exe --selftest --out resultado.txt
ProControllerFix.exe --ds4-status "C:\DS4Windows" --out resultado.txt
ProControllerFix.exe --ds4-apply "C:\DS4Windows" --enable-switch --out resultado.txt
ProControllerFix.exe --ds4-restore "C:\DS4Windows" --out resultado.txt
ProControllerFix.exe --auto-pair simple|nintendo --out log.txt     (remove o pareamento antigo sem perguntar)


8. COMPILAR A PARTIR DO CÓDIGO-FONTE
------------------------------------
Só precisa do .NET Framework 4.x que já vem no Windows 10 (não precisa de Visual Studio nem SDK):
    powershell -ExecutionPolicy Bypass -File .\build.ps1
Isso gera ProControllerFix.exe a partir de src\ usando o csc.exe do Windows. O Mono.Cecil (MIT) fica em lib\ e
é embutido no .exe. A pasta scripts\ traz as versões em PowerShell (pareamento e ajuste do DS4Windows) para quem
prefere ler ou rodar sem o .exe. O arquivo SHA256SUMS.txt traz o hash do .exe da release.


9. PRIVACIDADE, AVISOS E LICENÇAS
---------------------------------
- Nada é enviado pela internet. O único acesso externo é o botão que abre a página de download do DS4Windows
  no navegador.
- O programa grava ProControllerFix.log (ao lado do .exe, ou em %TEMP%). Ele contém o endereço Bluetooth
  do controle: apague essas linhas antes de colar em uma issue.
- Ele altera chaves de registro do Bluetooth de UM dispositivo e um arquivo do DS4Windows (com backup). Use
  por sua conta e risco.
- Este projeto não é afiliado à Nintendo nem aos autores do DS4Windows. "Nintendo", "Switch" e "Pro
  Controller" são marcas dos seus donos.
- Mono.Cecil: licença MIT (veja THIRD-PARTY-NOTICES.txt). O restante do código não tem licença definida
  ainda: o autor do repositório escolhe a licença antes de publicar.
