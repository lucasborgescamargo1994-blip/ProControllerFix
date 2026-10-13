PRO CONTROLLER GENERICO (CLONE DE SWITCH) NO WINDOWS 10 VIA BLUETOOTH
======================================================================

ENGLISH TL;DR
-------------
Some generic "Switch Pro Controller" clones (Bluetooth name "Pro Controller", SDP provider string
"mypow Tech.") pair with Windows 10 but drop the connection ~4 seconds later and never reconnect,
while working fine on a phone. Cause: the controller firmware answers SDP with malformed data, so
Windows never creates the HID device. This script pairs the controller and, while the link is still
up, writes a corrected HID/PnP record into the Windows Bluetooth cache for that device and enables the
HID service. Run Parear-ProController.bat (it asks for admin) and follow the prompts.
Tested on ONE unit, Windows 10 22H2 (build 19045), generic CSR USB dongle (0A12:0001) with the stock
Microsoft driver. Only buttons and sticks were verified. Use at your own risk.


1. SINTOMAS (E O SEU CASO?)
---------------------------
- Voce emparelha o controle no Windows (Configuracoes > Bluetooth) e ele desliga sozinho em poucos
  segundos. Ao ligar de novo com o botao Home, ele pisca e nao conecta.
- O mesmo controle funciona normalmente no celular.
- Em joy.cpl (Controladores de jogo) nao aparece nada.
- No Gerenciador de Dispositivos, "Pro Controller" aparece em "Bluetooth", mas NAO existe nenhum
  "Dispositivo HID Bluetooth" nem "Controlador de jogo compativel com HID" para ele.

Se os sintomas forem diferentes, este script provavelmente nao e a solucao para o seu controle.


2. O QUE A SOLUCAO FAZ
----------------------
O firmware desse controle responde ao Windows com dados invalidos na hora do pareamento. O Windows
descarta a resposta, nunca cria o dispositivo HID e derruba a conexao. O script:

  1) remove o pareamento antigo do controle (so dele; outros dispositivos nao sao tocados);
  2) espera voce parear de novo pelo Windows;
  3) logo depois do pareamento, com a conexao ainda ativa, grava no cache do Windows (so para esse
     controle) um registro HID/PnP corrigido e habilita o servico HID.

Depois disso o Windows reconhece o controle como gamepad e ele reconecta sozinho com o botao Home.


3. REQUISITOS
-------------
- Windows 10 (testado no 22H2, build 19045). Windows 11: nao testado.
- Um adaptador Bluetooth funcionando (testado com dongle USB generico CSR 0A12:0001).
- Permissao de administrador (o script grava no registro do Bluetooth).
- O controle em maos, com bateria.


4. PASSO A PASSO
----------------
1) Baixe a pasta inteira (os arquivos .bat e .ps1 precisam ficar juntos).
2) (Se o controle tambem estiver pareado no celular) esqueca o controle no celular ou desligue o
   Bluetooth do celular. Senao o controle pode tentar conectar nele e nao no PC.
3) De dois cliques em  Parear-ProController.bat  e aceite o pedido de administrador (UAC).
   Opcional: antes, rode "Parear-ProController.bat -DryRun" num terminal para so validar os dados.
4) O script lista os pareamentos antigos do controle e pergunta se pode remover. Responda S.
5) Quando aparecer "AGORA:", faca nesta ordem (o controle fica em modo de pareamento so por pouco
   tempo e desliga sozinho se nada conectar, entao deixe o Windows pronto ANTES):
     a) no Windows: Configuracoes > Bluetooth e dispositivos > Adicionar dispositivo > Bluetooth
        (deixe a lista procurando);
     b) SEGURE o botao SYNC do controle (o pequeno, no topo) ate as luzes ficarem "correndo";
     c) assim que "Pro Controller" aparecer na lista, clique nele.
6) Depois que o Windows disser que emparelhou, NAO mexa em nada. O script detecta o controle sozinho,
   grava o cache e termina com "PRONTO".
7) Teste: abra joy.cpl (Win+R > joy.cpl) > Propriedades e mexa nos botoes e analogicos.


5. USO DIARIO
-------------
Depois de configurado: desligue o controle e ligue so com o botao HOME (nao use o SYNC). Ele
reconecta sozinho. Voce so precisa rodar o script de novo se remover o controle do Windows,
reinstalar o Windows ou trocar o adaptador Bluetooth.


6. SE DER ERRADO
----------------
- "NAO concluiu": rode de novo e segure o SYNC ate as luzes correrem ANTES de adicionar o dispositivo
  no Windows. Nao toque em nada depois de parear.
- O controle nao entra no modo de pareamento: pressione e segure o SYNC por uns 3 segundos.
- O controle desliga logo depois do SYNC e as luzes ficam piscando: o modo de pareamento expirou sem o
  Windows conectar. Deixe a janela "Adicionar dispositivo" ja aberta e procurando, e so entao segure o
  SYNC de novo.
- Windows nao encontra o controle na lista: desligue o Bluetooth do celular e tente de novo.
- O gamepad aparece, mas botoes nao respondem ou estao trocados: pode ser outra versao de firmware
  (formato de relatorio diferente). Abra uma issue com o log (veja abaixo).
- Apareceu dispositivo duplicado: reinicie o Windows.
- O log fica em Parear-ProController.log (mesma pasta). ATENCAO: ele contem o endereco Bluetooth do
  controle e o nome do seu usuario/computador. Apague essas linhas antes de postar em uma issue.


7. COMO FUNCIONA (TECNICO)
--------------------------
Medido com captura ETW do driver Bluetooth do Windows (BTHPORT/BTHUSB) e leitura direta do HID:
- A resposta SDP do controle tem um registro PnP Information que declara 143 bytes, mas so 119
  chegam: o registro e cortado no meio do VendorID. O Windows descarta a resposta toda
  (por isso o erro 1060, "servico nao existe", ao tentar habilitar o HID) e, sem nenhum canal L2CAP
  aberto, desconecta o link ocioso cerca de 3 s depois.
- O descritor HID do controle e invalido: a terceira colecao (Consumer Control) nao declara Report ID
  e herda o ID 2 do mouse, e os botoes declaram 15 usos para Report Count 16.
- Pelo que observamos, o controle so guarda o pareamento se o HID chegar a abrir na primeira sessao
  (sem isso, o botao Home nao reconectava). Por isso gravar o cache depois nao basta: ele precisa
  existir durante o primeiro pareamento. O script faz isso ~1,2 s depois do pareamento, antes de o
  Windows desconectar o link.
- O formato real dos relatorios, lido do controle, e o "simple HID report" 0x3F do Pro Controller:
  3F | botoes(2) | hat(1) | LX LY RX RY (16 bits cada) = 12 bytes. O descritor embutido no script
  descreve exatamente isso.
- O script grava em  HKLM\SYSTEM\CurrentControlSet\Services\BTHPORT\Parameters\Devices\<mac> :
  VID, PID, VIDType, Version e a subchave DynamicCachedServices (00010001 = HID, 00010002 = PnP),
  e chama BluetoothSetServiceState para habilitar o servico HID (UUID 0x1124).


8. LIMITACOES
-------------
- Testado em UMA unidade, Windows 10 22H2, dongle CSR generico com driver padrao da Microsoft.
- Somente botoes e analogicos foram verificados. Giroscopio, vibracao e LEDs de jogador NAO foram
  testados (e o relatorio 0x3F nao os inclui).
- ZL e ZR chegam como BOTOES (9 e 10 no Windows), nao como eixos: neste modo o controle envia os
  gatilhos como liga/desliga, sem valor de pressao (medido: o byte so alterna 00 / 01 / 02).
  Dosagem analogica de acelerador/freio nao e possivel por este caminho.
- O VID/PID gravado (057E / 2009, Nintendo Pro Controller) e um palpite: o VendorID real do clone
  chegou cortado em "05..". Jogos e softwares podem identificar o controle como Pro Controller original.
- Nao ha garantia para outras marcas/firmwares de clones.


9. DESFAZER
-----------
Remova o controle em Configuracoes > Bluetooth e dispositivos > "Remover dispositivo". Isso apaga as
chaves de registro desse controle, inclusive o cache gravado pelo script. Nada mais e alterado.


10. AVISO
---------
Este script altera chaves de registro do Bluetooth relativas a UM dispositivo. Ele nao mexe em
drivers nem em outros dispositivos pareados. Mesmo assim, use por sua conta e risco.
