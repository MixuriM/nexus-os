# Teste da RC2 no VirtualBox (rodada 2): passo a passo completo

Este documento explica, do zero, como testar a ISO da RC2 do Nexus OS no VirtualBox e como registrar o resultado. Foi escrito para quem **nunca viu o projeto**: cada passo diz **o que fazer**, **quando fazer**, **por que fazer** e **como fazer**, com o que deve aparecer e o que fazer se não aparecer. Leia o documento inteiro uma vez antes de começar.

Não há tarefas separadas por pessoa aqui: o roteiro é um só, do início ao fim. Se mais de uma pessoa executar, cada uma segue o roteiro inteiro e preenche a própria ficha (seção 12).

## Sumário

1. [O que é este teste e por que ele existe](#1-o-que-é-este-teste-e-por-que-ele-existe)
2. [Regras que valem o tempo todo](#2-regras-que-valem-o-tempo-todo)
3. [O que você precisa ter antes](#3-o-que-você-precisa-ter-antes)
4. [Preparar o computador (Windows)](#4-preparar-o-computador-windows)
5. [Conferir a ISO (SHA256)](#5-conferir-a-iso-sha256)
6. [Criar a máquina virtual no VirtualBox](#6-criar-a-máquina-virtual-no-virtualbox)
7. [Ligar a VM e esperar o desktop](#7-ligar-a-vm-e-esperar-o-desktop)
8. [Como usar a janela da VM (mouse, teclado, capturas de tela)](#8-como-usar-a-janela-da-vm-mouse-teclado-capturas-de-tela)
9. [Parte 1: roteiro do desktop (H2 a H6)](#9-parte-1-roteiro-do-desktop-h2-a-h6)
10. [Parte 2: conferência das melhorias (N1 a N20)](#10-parte-2-conferência-das-melhorias-n1-a-n20)
11. [Parte 3 (opcional): o teste `nexus-smoke all` sem rede](#11-parte-3-opcional-o-teste-nexus-smoke-all-sem-rede)
12. [Ficha do teste e o que devolver](#12-ficha-do-teste-e-o-que-devolver)
13. [Como relatar uma falha](#13-como-relatar-uma-falha)
14. [Desligar e apagar a VM](#14-desligar-e-apagar-a-vm)
15. [Problemas conhecidos (não são falha sua)](#15-problemas-conhecidos-não-são-falha-sua)
16. [Perguntas frequentes](#16-perguntas-frequentes)

## 1. O que é este teste e por que ele existe

O **Nexus OS** é uma distribuição Linux (baseada no Debian 13) para virtualização de redes. Ela vem numa **ISO** que roda "ao vivo" (live): o sistema inicia direto da ISO, na memória RAM da máquina virtual, sem instalar nada em disco. Ao desligar, tudo o que foi feito na sessão some.

A versão que está em teste se chama **RC2** (*release candidate 2*, a segunda candidata a versão final). Ela já foi testada pelo próprio projeto no QEMU (com KVM) e no Hyper-V Geração 2. O que **ainda não foi feito** é rodar no **VirtualBox**, que é o programa de máquinas virtuais que a maior parte das pessoas usa em casa. Este é o objetivo desta rodada.

**Por que testar no VirtualBox?** Cada programa de máquina virtual simula o computador de um jeito (vídeo, rede, teclado). Algo que funciona no QEMU pode falhar no VirtualBox, por exemplo a resolução da tela, o mouse ou o desempenho. Só rodando de fato se descobre. Quem for usar o Nexus OS no VirtualBox precisa saber se funciona e quais são os limites.

**O que este teste confere, em resumo:**

- a ISO inicia no VirtualBox e chega ao desktop sozinha (Parte 1, H2);
- o desktop, a identidade visual, os atalhos e os programas funcionam (Parte 1, H3 a H5b);
- as melhorias feitas na RC2 (barra, menu, relógio, ícones, aplicativos novos) aparecem e funcionam (Parte 2, N1 a N20);
- a máquina desliga (H6).

**Resultado esperado de uma execução bem-sucedida:** uma ficha preenchida (seção 12) com "passou" ou "falhou" em cada item, mais algumas capturas de tela. Falhar em um item **não** é problema: o objetivo é descobrir e registrar. O que não pode acontecer é marcar "passou" sem ter conferido.

## 2. Regras que valem o tempo todo

1. **Faça só o que está escrito aqui.** Se precisar de algo que não está escrito (um pacote, um comando, um clique, uma explicação), isso é uma **falha da documentação**: anote e relate (seção 13). Não conserte em silêncio e não improvise.
2. **Um passo de cada vez, na ordem.** Os passos dependem uns dos outros. Pular um passo costuma causar uma falha que não é real.
3. **Confira o resultado de cada passo antes de seguir.** Cada passo diz "o que deve aparecer". Se não apareceu, pare e veja o "se não apareceu" do mesmo passo.
4. **Se um item falhar, siga para o próximo** e registre o que apareceu (texto exato de mensagens, captura de tela). Só pare tudo se a VM não ligar.
5. **O repositório é público.** Nunca cole em issue, ficha ou captura: senha pessoal, chave, token, e-mail, nome de usuário do seu computador, caminho com o seu nome de usuário do Windows. A conta `user` com senha `live` da ISO é pública e pode aparecer.
6. **Anote horários e números** quando o roteiro pedir (tempo até a barra, versão do VirtualBox, resolução). Eles entram no relatório do projeto.
7. **Não instale nada na VM** além do que está escrito. A ISO é live: o que se instala some ao desligar, então não serve de teste.

## 3. O que você precisa ter antes

| # | Item | Por que | Como conseguir |
| --- | --- | --- | --- |
| 1 | Um computador com **Windows 10 ou 11** (64 bits), com pelo menos **8 GB de RAM** e **10 GB livres** em disco | A VM usa 2,5 GB de RAM; o Windows e o VirtualBox precisam do resto. O disco guarda a ISO (cerca de 1,9 GB) e a VM | Verifique em Configurações, Sistema, Sobre |
| 2 | **VirtualBox 7.2** instalado | É o programa que está sendo testado. O roteiro foi escrito para a 7.2; versão diferente pode ter comandos diferentes | Baixe em https://www.virtualbox.org/wiki/Downloads (pacote "Windows hosts") e instale com as opções padrão |
| 3 | A **ISO** `nexus-os-rc2-amd64.iso` | É o que se testa | Peça o arquivo a quem gerou a ISO (o responsável pelo build do projeto). Não gere a ISO você mesmo: o build só roda em Linux e leva mais de 20 minutos |
| 4 | O **SHA256 correto da ISO** | Prova que o arquivo não está corrompido nem é outra versão | Está em `docs/rc2.md`, tabela "Identificação", linha "SHA256". Na data deste documento: `5f47083bfd5a009a7c11b093e98edfd3bdf21ac593f80f4d549bfe3310c10dbe` (RC2 final, tamanho 1990639616 bytes; a RC2 da rodada 5 era `bb6d89c68970...3e58`). Se o arquivo de `docs/rc2.md` no GitHub mostrar outro valor, **vale o do GitHub** |
| 5 | Este roteiro aberto num **segundo lugar** (celular, segundo monitor ou impresso) | Dentro da VM você não consegue ler o roteiro na mesma tela | Abra `docs/teste-virtualbox.md` no GitHub, branch `main` ou a branch indicada por quem passou a ISO |
| 6 | Um **editor de texto** (Bloco de Notas) e uma pasta para as capturas | Para anotar resultados e guardar imagens | Crie uma pasta, por exemplo `Documentos\teste-nexus` |
| 7 | **Tempo livre sem interrupção:** cerca de 20 min para preparar e de 2 h a 3 h para o roteiro | O VirtualBox roda sem KVM e é mais lento que o QEMU e o Hyper-V; o roteiro tem muitos itens | Reserve a tarde |

**Nível técnico necessário:** saber abrir o PowerShell e copiar e colar comandos. Todo comando está escrito pronto para copiar. Nenhum conhecimento de Linux é exigido: onde há comando de Linux, ele está escrito exatamente.

## 4. Preparar o computador (Windows)

### 4.1 O problema do Hyper-V (leia, é a causa mais comum de lentidão)

O Windows 10 e 11 podem ter o **Hyper-V** (ou recursos que o ligam: "Plataforma de Máquina Virtual", WSL2, Isolamento de Núcleo / Integridade de Memória) ativo. Quando o Hyper-V está ligado, o VirtualBox roda **sobre** ele, e fica bem mais lento. Isso é normal e **não invalida o teste**, mas o desempenho medido deve ser anotado com essa informação.

**O que fazer:** só **anote** (na ficha, campo "Hyper-V ligado no Windows") se o Hyper-V estava ligado. Não desligue nada se você não sabe como: mexer nisso exige reiniciar o computador e pode afetar outros programas. Para saber: no PowerShell como administrador, rode:

```powershell
Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All | Select-Object FeatureName, State
```

- `State : Enabled` significa ligado. `Disabled` significa desligado.
- Se o comando der erro de "recurso desconhecido", anote "não foi possível verificar".

### 4.2 Fechar o que pesa

- Feche navegadores com muitas abas, jogos e outras máquinas virtuais (Hyper-V, WSL2 aberto, outro VirtualBox). **Por quê:** a VM usa 2,5 GB de RAM e 2 núcleos; se o Windows ficar sem memória, a VM trava e o teste falha por motivo que não é do Nexus OS.
- Conecte o notebook na tomada, se for notebook. **Por quê:** o modo de economia de energia reduz a velocidade e distorce o tempo medido.

### 4.3 Escolher a pasta da ISO

Copie a ISO para uma pasta **sem acentos e sem espaços** no caminho, por exemplo `C:\HyperV\nexus-os-rc2-amd64.iso` (o caminho usado nos comandos abaixo; se usar outro, troque nos comandos). **Por quê:** acentos e espaços em caminhos costumam quebrar comandos copiados.

## 5. Conferir a ISO (SHA256)

**O que fazer:** abra o **PowerShell** (menu Iniciar, digite PowerShell). Não precisa ser administrador. Rode:

```powershell
Get-FileHash C:\HyperV\nexus-os-rc2-amd64.iso -Algorithm SHA256
```

**Por quê:** se o download ou a cópia falhou, a ISO pode estar corrompida; o teste inteiro seria inútil.

**Deve aparecer:** uma tabela com `Algorithm`, `Hash` e `Path`. O `Hash` (em letras maiúsculas) tem de ser **igual** ao SHA256 do item 4 da seção 3. A comparação ignora maiúsculas e minúsculas.

**Se não for igual:** pare. Peça a ISO de novo a quem gerou. Não continue com um arquivo diferente.

## 6. Criar a máquina virtual no VirtualBox

Há dois jeitos. O **jeito dos comandos** é o recomendado porque reproduz exatamente a configuração testada pelo projeto. Use o jeito da interface (6.3) só se o PowerShell não funcionar.

### 6.1 O que cada configuração significa (para entender, não para decorar)

| Configuração | Valor | Por que esse valor |
| --- | --- | --- |
| Memória | 2560 MiB | É a RAM recomendada para o desktop, medida pelo projeto (`docs/requisitos.md`). Com menos, o desktop pode ficar lento ou falhar |
| Processadores | 2 | O projeto mediu com 2 núcleos |
| Memória de vídeo | 128 MiB | O desktop gráfico (XFCE) precisa de vídeo para a janela; 128 MiB é o máximo do VirtualBox |
| Controlador gráfico | VMSVGA | O controlador de vídeo que o Linux reconhece melhor no VirtualBox |
| Firmware | BIOS | A ISO inicia por BIOS e por UEFI; a BIOS é o caminho mais simples e o que o projeto testou primeiro |
| Virtualização aninhada | desligada | Em processadores AMD, ligar a virtualização aninhada derruba a VM (problema conhecido, issue 25). Por isso a VM **não** tem aceleração KVM e roda mais lenta |
| Boot | só pelo DVD | A ISO está num "DVD virtual"; a VM não tem disco |
| Rede | NAT | A VM acessa a internet pela conexão do Windows, sem configurar nada |
| Disco | nenhum | O sistema roda da ISO |

### 6.2 Criar pelos comandos (recomendado)

**Onde:** PowerShell (não precisa ser administrador).

**Como:** copie e cole **um bloco inteiro de uma vez**, aperte Enter e leia a saída antes de seguir.

Bloco 1: define as variáveis e confere a versão.

```powershell
$vb = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
$vm = "nexus-rc2-vbox"
& $vb --version
```

**Deve aparecer:** um número começando com `7.2` (por exemplo `7.2.20r...`). Anote **a versão completa** na ficha.

**Se der erro "não é reconhecido" ou "caminho não encontrado":** o VirtualBox não está em `C:\Program Files\Oracle\VirtualBox`. Abra esse local no Explorador de Arquivos e veja onde está o `VBoxManage.exe`; ajuste a primeira linha com o caminho certo. Se não existir, o VirtualBox não foi instalado (volte à seção 3).

**Se a versão for diferente de 7.2.x:** o roteiro pode ter opções incompatíveis. Anote a versão e continue; se um comando acusar "opção inválida", veja a seção 13.

Bloco 2: cria e registra a VM.

```powershell
& $vb createvm --name $vm --platform-architecture=x86 --ostype Debian_64 --register
```

**Deve aparecer:** `Virtual machine 'nexus-rc2-vbox' is created and registered.` e uma linha com `UUID:` e outra com `Settings file:`.

**Se aparecer "already exists" (já existe):** há uma VM com esse nome de uma tentativa anterior. Apague-a primeiro (seção 14, passo 3) e repita.

Bloco 3: configura o hardware da VM.

```powershell
& $vb modifyvm $vm --memory 2560 --cpus 2 --vram 128 --graphicscontroller vmsvga --firmware bios --nested-hw-virt off
& $vb modifyvm $vm --boot1 dvd --boot2 none --boot3 none --boot4 none --nic1 nat
```

**Deve aparecer:** nada (o VirtualBox não imprime nada quando dá certo).

**Se imprimir erro de opção** (por exemplo `Invalid parameter` ou `unknown option`): copie a mensagem completa e a saída de `& $vb modifyvm --help`, e relate (seção 13). Não tente adivinhar outra opção.

Bloco 4: cria o leitor de DVD e coloca a ISO nele.

```powershell
& $vb storagectl $vm --name IDE --add ide
& $vb storageattach $vm --storagectl IDE --port 0 --device 0 --type dvddrive --medium "C:\HyperV\nexus-os-rc2-amd64.iso"
```

**Deve aparecer:** nada. Se aparecer `VBOX_E_FILE_ERROR` ou "não foi possível abrir a mídia", o caminho da ISO está errado: confira o nome do arquivo e a pasta.

Bloco 5: confere o que foi configurado antes de ligar.

```powershell
& $vb showvminfo $vm --machinereadable | Select-String -Pattern 'memory=|cpus=|vram=|firmware=|nestedhwvirt=|boot1=|"IDE-0-0-0"'
```

**Deve aparecer** (a ordem pode variar): `memory=2560`, `cpus=2`, `vram=128`, `firmware="BIOS"`, `nestedhwvirt="off"`, `boot1="dvd"` e uma linha `"IDE-0-0-0"="C:\HyperV\nexus-os-rc2-amd64.iso"`.

**Por que conferir:** é a única forma de ter certeza de que a VM está do jeito testado antes de gastar 2 horas.

### 6.3 Criar pela interface gráfica (só se o PowerShell não funcionar)

1. Abra o **VirtualBox Manager**. Clique em **Novo**.
2. Nome: `nexus-rc2-vbox`. Tipo: **Linux**. Versão: **Debian (64-bit)**.
3. Em **Imagem ISO**, escolha a ISO. Marque **Ignorar instalação desacompanhada** (se existir; a ISO é live, não instala).
4. Memória: **2560 MB**. Processadores: **2**. **Não** crie disco (marque "Não adicionar um disco rígido virtual").
5. Concluir. Depois selecione a VM e clique em **Configurações**:
   - **Sistema, Placa-mãe:** ordem de boot com **Óptico** primeiro e os outros desmarcados; **Habilitar EFI** **desmarcado**.
   - **Sistema, Processador:** 2 CPUs.
   - **Sistema, Aceleração:** desmarque a virtualização aninhada ("Habilitar VT-x/AMD-V aninhado") se a opção aparecer.
   - **Vídeo, Tela:** memória de vídeo **128 MB**; controlador gráfico **VMSVGA**.
   - **Rede, Adaptador 1:** **NAT**.
   - **Armazenamento:** o controlador IDE com a ISO no leitor óptico.
6. Anote na ficha que usou a interface e qualquer opção que não encontrou.

## 7. Ligar a VM e esperar o desktop

**Quando:** só depois de conferir o bloco 5 (ou os itens da interface).

**O que fazer (PowerShell):**

```powershell
& $vb startvm $vm --type gui
```

**Deve aparecer no PowerShell:** `Waiting for VM "nexus-rc2-vbox" to power on...` e depois `VM "nexus-rc2-vbox" has been successfully started.`

**Deve aparecer na tela:** uma janela do VirtualBox com a VM. Primeiro, o **menu de boot** do Nexus OS: fundo azul-escuro com a logo do Nexus OS e as entradas **Iniciar o Nexus OS** e **Nexus OS (modo de compatibilidade)**.

**O que fazer agora (H2.1 e H2.5):**

1. **Cronômetro:** no instante em que o menu de boot aparecer, comece a contar (celular).
2. Clique **dentro da janela da VM** (ela captura o mouse; veja a seção 8) e aperte **Enter**, ou espere a contagem de 5 segundos terminar.
3. Não digite nada. Espere as mensagens de boot e depois a tela azul-escura com a logo no centro (o papel de parede).
4. Pare o cronômetro quando a **barra de baixo** aparecer completa. Esse número é o **tempo até a barra** (anote na ficha, em segundos). Sem KVM pode levar de alguns minutos até cerca de 10 minutos; o projeto **não mediu** o VirtualBox, então o seu número é uma informação nova e valiosa.

**Por que o menu mostra "modo de compatibilidade":** é uma segunda entrada de boot, para máquinas com problema de vídeo. Se a entrada normal não chegar ao desktop, **não** troque de entrada por conta própria: relate a falha. A troca só entra como segundo teste depois de registrar a primeira.

**Se a VM não ligar** (janela some, erro "VERR_..." ou "Failed to open a session"): copie o texto exato do erro, anote a versão do VirtualBox e se o Hyper-V estava ligado, e relate (seção 13). É uma falha importante: não siga o roteiro.

**Se ficar horas na tela preta:** espere até 15 minutos. Se continuar, relate com a captura da tela.

## 8. Como usar a janela da VM (mouse, teclado, capturas de tela)

O VirtualBox **sem as "Adições de Convidado"** (programa extra que não vem na ISO) funciona assim:

| Situação | O que fazer | Por quê |
| --- | --- | --- |
| O mouse "some" quando entra na janela | É normal: a VM **capturou** o mouse. Clique dentro da janela da VM para capturar | Sem as Adições, o mouse da VM não acompanha o do Windows |
| Para **soltar** o mouse para o Windows | Aperte a **Tecla Host**, que no padrão é o **Ctrl direito**. A tecla aparece escrita no canto inferior direito da janela | É a única forma de sair da janela da VM |
| A janela da VM não muda de tamanho sozinha | Normal. Use a resolução que aparecer e **anote** (seção 12) | Sem as Adições a resolução não acompanha a janela |
| Capturar o teclado | Clique dentro da janela. Enquanto o teclado estiver capturado, quase todas as teclas vão para a VM, inclusive a tecla Windows | Necessário para testar a tecla Windows (item N12) |
| Tirar **captura de tela** da VM | Use o menu da janela da VM: **Visualizar** (ou **View**), **Tirar captura de tela** (ou **Take Screenshot**). Escolha a pasta de capturas (seção 3, item 6) | Mostra exatamente o que a VM exibe, sem o resto do Windows |
| Alternativa para a captura | Abra a **Ferramenta de Captura** do Windows **antes** de clicar dentro da VM e use o botão dela; não use atalhos de teclado do Windows com o teclado capturado | O atalho de teclado do Windows não chega ao Windows quando a VM captura o teclado |

**Como nomear as capturas:** `H2-2-barra.png`, `N7-janelas.png` e assim por diante: número do item e uma palavra. **Por quê:** facilita relacionar a imagem com a linha da ficha.

**Quando tirar captura:** sempre que um item **falhar** (para mostrar o problema) e nos itens que pedem captura. Em itens que passam, uma captura é opcional.

## 9. Parte 1: roteiro do desktop (H2 a H6)

Estas tabelas são a parte H do [checklist](checklist-teste-documentacao.md) em forma resumida. Preencha na sua ficha (seção 12) **passou**, **falhou** ou **passou com ressalvas** e anote o que apareceu.

**Antes:** a VM está ligada e o desktop apareceu (seção 7).

### 9.1 H2: esperar o desktop

| # | O que fazer | O que deve aparecer | Por quê |
| --- | --- | --- | --- |
| H2.1 | No menu de boot aperte **Enter** ou espere 5 s. O menu **não** deve mostrar o texto "Debian GNU/Linux" nem o capacete do live-build | Mensagens de boot e depois a tela azul-escura com losangos finos e a logo do Nexus OS no centro | Confere a identidade visual do boot |
| H2.2 | Sem digitar nada, espere a barra aparecer na **parte de baixo** | Barra escura de ponta a ponta: no centro o botão do menu (só o ícone da marca) e os ícones dos aplicativos fixados (terminal, arquivos, Firefox, máquinas virtuais, configurações); à direita o som e o relógio (hora em cima, data embaixo). Nada de barra em cima. **Não** pede usuário nem senha | O login automático e a barra são o que o usuário vê primeiro |
| H2.3 | Só se aparecer tela de login: usuário `user`, senha `live` | O desktop abre. Marque **falhou** em H2.2 (o login devia ser automático) | Registra o desvio |
| H2.4 | Olhe a área de trabalho | Dez ícones de atalho com nomes, sem aviso de "atalho não confiável" e sem ponto de exclamação, mais **Pasta pessoal**, **Lixeira** e o disco da ISO, no mesmo estilo (quadrado azul-escuro com contorno colorido). **Não** deve haver "Disco Disquete" | O ícone de disquete era um defeito já corrigido; confere que não voltou |
| H2.5 | Cronômetro | O tempo até a barra em segundos (seção 7) | Dado de desempenho no VirtualBox |

### 9.2 H3: itens da definição do desktop

Para abrir o **terminal**: duplo clique no ícone **Terminal do Nexus OS** na área de trabalho. Comandos: digite exatamente e aperte Enter.

| # | O que fazer | O que deve aparecer | Por quê |
| --- | --- | --- | --- |
| H3.1 | Já visto em H2.2 | Nenhuma tela de login | Login automático |
| H3.2 | No terminal: `loginctl list-sessions`. Depois: `loginctl show-session $(loginctl list-sessions --no-legend \| awk '$3=="user"{print $1;exit}') -p Type -p State` | Uma linha com `user` e `seat0`; depois `Type=x11` e `State=active` | Confere que a sessão gráfica está ativa |
| H3.3 | Clique no botão da logo (canto inferior, esquerda do grupo de ícones) | Menu em português com categorias (**Escritório**, **Internet**, **Multimídia**, **Acessórios**, **Sistema**) e **Nexus OS** (passando o mouse ou clicando, aparecem os atalhos). Abra o terminal e outro aplicativo: cada janela aparece como ícone na barra | Menu e lista de janelas |
| H3.4 | Abra o terminal, arraste a barra de título, minimize, reabra pela barra, maximize | A janela se move, some, volta e ocupa a tela | Gerenciador de janelas |
| H3.5 | No menu, abra o gerenciador de arquivos (ícone da pasta na barra) | Janela do Thunar com as pastas do `user` | Gerenciador de arquivos |
| H3.6 | No terminal: `echo ok` | `ok` | Terminal funciona |
| H3.7 | Clique no ícone do Firefox | Firefox em português com a documentação do Nexus OS. Com rede (NAT), abra `https://www.debian.org`; sem rede, o erro de conexão é esperado | Navegador |
| H3.8 | No terminal: `nm-connection-editor`. Depois, no menu, **Configurações** e **Tela** (ou **Display**) | O editor de conexões abre (feche); a tela de vídeo mostra a **resolução**. Anote a resolução na ficha | Rede e vídeo; a resolução no VirtualBox é informação nova |
| H3.9 | No terminal: `journalctl -b -u lightdm -p err --no-pager` | Nenhuma linha de erro (termina em `-- No entries --` ou fica vazio) | Sem erro de login |

### 9.3 H4: identidade visual

| # | O que fazer | O que deve aparecer | Por quê |
| --- | --- | --- | --- |
| H4.1 | Olhe o papel de parede | Fundo azul-escuro com reflexos azul e magenta, losangos finos e a logo original (losango com o N e "NEXUS OS") no centro, sem faixas visíveis nos degradês | Identidade visual |
| H4.2 | Olhe o botão do menu na barra | Só o **ícone da marca** (losango com o N, sem fundo). **Não** deve ter texto ao lado | A melhoria M3 tirou o texto |
| H4.3 | Olhe as janelas | Tema escuro azul-marinho: barra de título, menus e janelas na cor da logo, com ícones do tema Nexus | Tema |
| H4.4 | No terminal: `head -n 3 /etc/os-release` | `PRETTY_NAME` e `NAME` com **Debian** (o sistema continua Debian; só a identidade visual é do Nexus OS) | A base é Debian |
| H4.5 | No terminal: `hostname`, `date` e `locale \| head -n 1`. Digite `ç` e `~a` | `nexus-os`; data e hora de Brasília (UTC-3); `LANG=pt_BR.UTF-8`; `ç` e `~a` saem certos (teclado ABNT2) | Idioma, fuso e teclado |
| H4.6 | Deixe a tela parada por **15 minutos** (olhe o relógio) | A tela não apaga e não pede senha | Sem bloqueio de tela |

### 9.4 H5: abrir cada atalho

Na área de trabalho, **duplo clique** em cada ícone, na ordem. Nos atalhos de terminal a janela mostra a saída, `Código de saída: 0` e `Pressione Enter para fechar...`: aperte Enter para fechar.

| # | Atalho | O que deve aparecer |
| --- | --- | --- |
| H5.1 | Terminal do Nexus OS | Janela de terminal |
| H5.2 | Documentação do Nexus OS | Firefox com a página escura "Documentação do Nexus OS" e a lista dos documentos; clique em **Manual v2 do Nexus OS** e confira que abre. Funciona sem internet |
| H5.3 | Gerenciador de máquinas virtuais | A janela **Gerenciador de máquinas virtuais** abre (até 15 s) e lista uma conexão **QEMU/KVM**. **Não** crie VM. Feche. Dentro do VirtualBox não há KVM; anote se a janela mostrar aviso sobre isso |
| H5.4 | Laboratório Open vSwitch | Terminal com `== Nexus OS: sudo nexus-sdn up ==` e `Código de saída: 0`. **Depois**, no terminal, rode `sudo nexus-sdn down` (o atalho só cria o laboratório) |
| H5.5 | VNF FRR: instanciar | `OK:` e `Código de saída: 0` |
| H5.6 | VNF FRR: estado | `OK: VNF vnf1 rodando` e `Código de saída: 0` |
| H5.7 | VNF FRR: remover | `OK:` e `Código de saída: 0` |
| H5.8 | Topologia Containerlab: criar | Tabela com `clab-frr-duo-r1` e `clab-frr-duo-r2` em `running` e `Código de saída: 0` (leva até 1 min; sem KVM pode levar mais: anote o tempo) |
| H5.9 | Topologia Containerlab: remover | `Código de saída: 0`. Depois, no terminal, `sudo docker ps -a` não lista nenhum contêiner |
| H5.10 | Configurações | Abre a janela de configurações do Xfce (rede, aparência, teclado, vídeo). Feche |

**Por que os atalhos de rede estão no teste do desktop:** eles são a "demonstração" do projeto (Open vSwitch para SDN, FRRouting para NFV, Containerlab para a topologia). Se o desktop abrir mas esses atalhos falharem, o sistema não cumpre o objetivo.

### 9.5 H5b: programas e teclas

| # | O que fazer | O que deve aparecer |
| --- | --- | --- |
| H5b.1 | No terminal: `echo "# teste" > ~/teste.md`. No gerenciador de arquivos (pasta pessoal), duplo clique em `teste.md` | O **Mousepad** abre o arquivo |
| H5b.2 | Aperte **Print Screen** (no VirtualBox o teclado precisa estar capturado) | A janela do **Captura de tela** abre, sem erro. Se o Windows capturar a tecla em vez da VM, anote |
| H5b.3 | No menu, abra o **LibreOffice Writer**, escreva uma linha e feche sem salvar | O Writer abre em português |
| H5b.4 | Abra o **Wireshark**, escolha a interface `any` ou `eth0` e inicie a captura, sem `sudo` | A captura começa sem aviso de permissão. Feche |
| H5b.5 | Abra, um por vez, o **VLC**, o **GIMP**, o **Inkscape** e o **KeePassXC** | Cada um abre em janela própria. Feche-os. Não crie arquivos |

### 9.6 H6: desligar

Só faça o H6 **depois** da Parte 2 (seção 10), porque a Parte 2 precisa da VM ligada. O desligamento está na seção 14.

## 10. Parte 2: conferência das melhorias (N1 a N20)

**Por que existe:** depois do teste manual anterior (no Hyper-V Geração 2), o projeto fez melhorias na barra, no menu, nos ícones e nos aplicativos. A Parte 2 confere cada melhoria **no VirtualBox**. Cada linha tem um número (N1 a N20) e deve ser marcada **passou** ou **falhou**.

**Quando:** com a VM ligada no desktop, depois (ou antes) da Parte 1; a ordem entre as partes não importa, mas dentro da parte siga a ordem das linhas.

**Como:** faça a coluna "O que fazer", compare com "O que deve aparecer" e marque. Tire **captura da barra inteira** e **do menu aberto** (obrigatórias, seção 12).

| # | O que fazer | O que deve aparecer | Por quê |
| --- | --- | --- | --- |
| N1 | Olhe o canto direito da barra | **Sem** botão azul de "mostrar a área de trabalho" | O botão foi removido (pedido M1) |
| N2 | Olhe o relógio e a esquerda da barra | **Nenhum** texto "Nexus OS" na barra | O texto foi removido (M2 e M3) |
| N3 | Olhe a logo na barra | Só o losango com o "N", sem quadrado de fundo, e maior do que na versão anterior | Logo maior e transparente (M4) |
| N4 | Passe o mouse sobre a logo (sem clicar) e espere 1 s; depois clique | Ao passar: fundo azul translúcido arredondado e a dica "Menu do Nexus OS (tecla Windows)". Ao clicar: fundo mais forte e o menu abre | Deixar claro que a logo é clicável (M5) |
| N5 | Compare o ícone do volume com a logo | O volume é **menor** que a logo | Ícone do volume menor (M6) |
| N6 | Olhe a posição do menu e dos ícones. No terminal: `nexus-barra esquerda`, espere uns 20 s, olhe; depois `nexus-barra centro`, espere e olhe | Estão no centro (um pouco à esquerda do centro exato é conhecido). Com `esquerda`, vão para o canto esquerdo; com `centro`, voltam. Se aparecer "comando não encontrado", confira se digitou `nexus-barra` (com `s`) | Barra centralizada com opção de ir para a esquerda (M7) |
| N7 | Abra o **Terminal**, o **gerenciador de arquivos** e o **Firefox** pelos **ícones da barra** (um clique em cada) | Cada janela fica sob **o próprio ícone fixado**, com uma linha de estado embaixo dele (azul na janela em foco, verde nas outras). **Não** deve aparecer um ícone novo depois dos fixados, nem ícone genérico. Janelas só com ícone, sem texto | Janelas agrupadas só com ícone (M8 e M9). Já falhou uma vez por falta de uma configuração, depois corrigida |
| N8 | Clique com o **botão direito** num ícone da barra | Menu com "Fixo no Dock". Abra o **GIMP** pelo menu do Nexus OS (aparece um ícone novo na barra), clique com o botão direito nele e marque "Fixo no Dock", feche o GIMP: o ícone **fica**. Clique direito de novo e desmarque: o ícone **some** ao fechar | Fixar e desafixar qualquer aplicativo (M9) |
| N9 | Procure a bateria na barra | Em **VM sem bateria: nenhum ícone de bateria**. Se o seu notebook repassar a bateria para a VM, o ícone com a porcentagem pode aparecer, e isso também é correto; **anote** o que viu | Bateria só quando existe (M10) |
| N10 | Olhe o relógio | **Hora em cima** e **data embaixo**, no formato `03/11/2026` (dia/mês/ano) | Relógio em duas linhas (M11) |
| N11 | Olhe os ícones do gerenciador de arquivos (barra e menu) e abra o gerenciador de arquivos: olhe a pasta **Desktop** na barra lateral | Estilo do Nexus OS (quadrado azul-escuro com contorno colorido). O **Firefox continua com o ícone oficial** (a marca da Mozilla não é redesenhada). O item **user** da barra lateral pode estar com ícone simples: é problema **conhecido**, anote | Ícones novos (M12 e M13) |
| N12 | Clique dentro da VM (para capturar o teclado) e aperte a **tecla Windows**. Depois aperte de novo, ou **Esc** | O **menu do Nexus OS** abre; a mesma tecla ou Esc fecha. **Se abrir o menu Iniciar do Windows em vez do menu da VM**, marque falhou, anote, e tente `Alt+F1` (também abre o menu da VM): anote o resultado | Tecla Windows abre o menu (M14) |
| N13 | Abra o menu e escreva `gimp` na busca | Aparece escrito só **GIMP** (não o nome longo "Programa de manipulação de imagem do GNU") | Nome curto do GIMP (M15) |
| N14 | No menu, olhe o grupo **Nexus OS** (na lista de categorias) | Com a **logo do Nexus OS**, não com a engrenagem | Ícone do grupo (M16) |
| N15 | Olhe o menu como um todo | Grade de ícones grandes, categorias na lateral, busca na parte de baixo e três botões coloridos de **reiniciar**, **desligar** e **sair** na base. **Anote sua opinião** (por exemplo, se lembra o macOS, o Windows 7 ou outro) | Menu mais bonito (M17). A opinião é só informação |
| N16 | No menu, clique em **desligar** (ou **reiniciar**, ou **sair**). Aparece uma confirmação; escolha **Cancelar** em dois deles e **confirme só um** | Cada botão mostra uma janela de confirmação com contagem. Ao confirmar: a sessão encerra, reinicia ou a VM desliga. **Só confirme o desligamento no final do roteiro**, porque ele encerra a VM | Botões de sessão (M17) |
| N17 | No terminal, rode `sleep 100` e aperte **Ctrl+C**. Depois escreva um texto, selecione com o mouse, aperte **Ctrl+Shift+C**, e cole em outro terminal com **Ctrl+Shift+V** | O `sleep` é **interrompido** (aparece `^C`). A cópia e a colagem com Ctrl+Shift funcionam. O Ctrl+C **não** copia, de propósito | Copiar e colar no terminal (M19) |
| N18 | Abra, pelo menu, os aplicativos novos: **Thunderbird**, **Geany**, **GParted**, **Audacity**, **FileZilla**, **Meld**, **Discos**, **Analisador de uso de disco** e o **Gerenciador de tarefas**. Se quiser, veja a lista completa em `docs/gui.md`, seção "Programas incluídos" | Todos abrem sem erro. O GParted pede senha de administrador: o `user` não precisa de senha para o `sudo`; se pedir, anote | Aplicativos novos |
| N19 | No menu, grupo **Nexus OS**, abra **Ícones dos aplicativos**. Role a lista, marque **Gerenciador de arquivos** (ou "File Manager"), clique **OK**. Espere uns 20 s. No terminal: `nexus-icone xfce4-file-manager.desktop nexus` e espere | A janela abre com uma lista e a coluna "Ícone original". Depois do **OK**, o ícone do gerenciador de arquivos na barra muda para o ícone original (mais colorido); depois do comando com `nexus`, volta ao ícone do Nexus OS | Opção de ícone padrão |
| N20 | Abra vários programas e olhe a lista de janelas da barra | **Nenhum** botão cinza sem ícone escrito "Monitor". Se aparecer, no terminal: `xwininfo -root -tree \| grep -i -B2 -A2 monitor` e depois `xprop -id <id> WM_CLASS _NET_WM_PID` (troque `<id>` pelo número que o primeiro comando mostrou) e **cole as duas saídas** na ficha | Um botão "Monitor" foi visto uma vez e não reproduziu; só confirma que não existe |

**Antes de marcar "falhou" num item da Parte 2,** confira: (a) você esperou os 20 s depois de comandos que reiniciam a barra? (b) digitou o comando exatamente? (c) a VM capturou o teclado? Se sim para tudo, marque falhou e relate.

## 11. Parte 3 (opcional): o teste `nexus-smoke all` sem rede

**O que é:** o `nexus-smoke` é um conjunto de testes automáticos dentro da ISO que confere o Open vSwitch, o libvirt, o Docker, o FRRouting, o Containerlab e o desktop. Em QEMU com KVM leva cerca de 4 minutos. **Sem KVM leva muito mais.** O projeto quer saber **quanto** no VirtualBox.

**Por que é opcional:** leva tempo e o desktop só passa **sem rota padrão** (sem internet). Faça se sobrar tempo.

**Passos:**

1. **PowerShell (no Windows):** desconecte o "cabo" da rede da VM:

   ```powershell
   & $vb controlvm $vm setlinkstate1 off
   ```

   **Por quê:** o teste do desktop exige que a máquina não tenha rota para a internet.

2. **No terminal da VM:** rode e anote o horário de início:

   ```bash
   date; sudo nexus-smoke all; date
   ```

   **Deve aparecer:** blocos `NEXUS-SMOKE-BEGIN` e `NEXUS-SMOKE-END <nome> 0` para cada teste e, no fim, `NEXUS-SMOKE-DONE 8 0` (8 testes, 0 falhas). Anote o tempo total (a diferença entre os dois `date`).

3. **PowerShell:** reconecte o cabo:

   ```powershell
   & $vb controlvm $vm setlinkstate1 on
   ```

4. **Se algum teste falhar:** anote qual (`NEXUS-SMOKE-END <nome> 1`) e as últimas 15 linhas da saída (sem dado pessoal) e relate (seção 13).

## 12. Ficha do teste e o que devolver

Copie a ficha para um arquivo de texto e preencha **durante** o teste, não depois (a memória falha).

### 12.1 Ficha do ambiente

| Campo | Valor |
| --- | --- |
| Data do teste (DD/MM/AAAA) | |
| Versão completa do VirtualBox (`& $vb --version`) | |
| Versão do Windows e RAM do computador | |
| Hyper-V ligado no Windows (sim, não ou não verificado, seção 4.1) | |
| VM criada por comandos ou pela interface | |
| RAM e CPUs da VM | 2560 MiB e 2 (se mudou, escreva) |
| SHA256 da ISO conferido (sim ou não) e a versão do `docs/rc2.md` usada | |
| Tempo até a barra em segundos (H2.5) | |
| Resolução da tela da VM (H3.8) | |
| Tempo do `nexus-smoke all`, se feito (seção 11) | |
| Resultado final: **passou**, **passou com ressalvas** ou **falhou** | |

### 12.2 Resultado por item

Para **cada** linha de H2, H3, H4, H5, H5b e N1 a N20, anote: o número, **passou** ou **falhou** e o que aconteceu (em falha, o texto exato). Exemplo:

```text
H2.2: passou
H3.8: passou. Resolução 1024x768.
N7: falhou. O terminal abriu como ícone novo depois dos fixados. Captura N7-janelas.png
N12: passou com ressalva. A tecla Windows abriu o menu do Windows; o Alt+F1 abriu o menu da VM
```

### 12.3 O que devolver

1. A ficha 12.1 preenchida.
2. A lista 12.2 completa (todas as linhas, não só as falhas).
3. As **capturas obrigatórias:** barra inteira e menu aberto; mais uma captura de cada item que falhou.
4. A saída do N20 (`xwininfo` e `xprop`), se o botão "Monitor" aparecer.
5. Os números das issues abertas (seção 13).
6. O resultado final.

**Para quem devolver:** a quem gerou a ISO (o responsável pelo build do projeto). A forma recomendada é um **comentário nas issues 54 e 55** do repositório no GitHub, com a ficha colada em texto e as capturas anexadas (arraste a imagem para a caixa de comentário). **Antes de enviar,** releia tudo procurando dado pessoal (seção 2, regra 5).

**O que acontece depois:** o responsável pelo build registra o resultado em `docs/rc2.md`, em `docs/gui.md`, no checklist e no cofre de planejamento, e só fecha as issues 54 e 55 quando as rodadas manuais estiverem aprovadas.

## 13. Como relatar uma falha

**Quando:** para cada falha que se repete, para qualquer erro de comando deste roteiro e para tudo que o roteiro não explicou (falha de documentação).

**Onde:** uma **issue** no repositório do projeto no GitHub, ou um comentário nas issues 54 e 55 se for algo pequeno.

**Título:** `F3.18: <item>: <resumo curto>`. Exemplos: `F3.18: N12: tecla Windows abre o menu do Windows no VirtualBox` ou `F3.18: modifyvm: opção --platform-architecture inválida`.

**Corpo, com quatro blocos:**

- **Passos:** o que você fez, na ordem, com os comandos exatos.
- **Saída:** o texto exato que apareceu (copie e cole, não resuma). Se for tela, anexe a captura.
- **Esperado:** o que o roteiro dizia que deveria aparecer.
- **Ambiente:** versão do VirtualBox, Windows, Hyper-V ligado ou não, RAM e CPUs da VM, SHA256 da ISO, e se usou comandos ou a interface.

**Regras:** uma issue por falha; falha intermitente também vira issue (diga em quantas tentativas ocorreu); sem dado pessoal (seção 2, regra 5).

## 14. Desligar e apagar a VM

**Quando:** só ao terminar **todo** o roteiro e ter salvo as capturas e a ficha. Depois de apagar a VM não dá para repetir a conferência sem recriá-la.

1. **Dentro da VM:** desligue pelo menu (botão vermelho de **desligar**, e confirme) ou no terminal:

   ```bash
   sudo poweroff
   ```

   **Deve acontecer:** a janela da VM fecha ou a VM desliga. Se a tela ficar parada pedindo **ENTER**, aperte Enter (comportamento conhecido da live, issue 34). Esse é o item **H6**: marque passou se a VM desligou.

2. **PowerShell:** se a VM ainda estiver ligada, force o desligamento:

   ```powershell
   & $vb controlvm $vm poweroff
   ```

   Se responder que a VM não está rodando, tudo certo.

3. **PowerShell:** apague a VM e os arquivos dela:

   ```powershell
   & $vb unregistervm $vm --delete
   ```

   **Por quê:** libera o disco e evita o erro "already exists" na próxima vez. A ISO **não** é apagada.

4. Reinicie o Hyper-V ou os programas que você fechou na seção 4.2, se for o caso.

## 15. Problemas conhecidos (não são falha sua)

Estes itens já foram vistos pelo projeto. **Anote se aparecerem**, mas não precisa abrir issue só por isso (a menos que o comportamento seja diferente do descrito).

| Problema | O que se vê | Detalhe |
| --- | --- | --- |
| A barra fica um pouco à esquerda do centro | O grupo de ícones fica cerca de 80 px à esquerda do centro da tela (em tela de 1280 px) | A barra centraliza entre a borda esquerda e o bloco do som e do relógio |
| Ícone do item "user" no gerenciador de arquivos | O item da pasta pessoal na barra lateral tem ícone simples, fora do estilo | Ainda sem correção |
| O desligamento pede ENTER | A tela parada pedindo ENTER ao desligar | Comportamento da live (issue 34) |
| O menu não tem botão de bloquear | Só reiniciar, desligar e sair | Não há bloqueio de tela na ISO, de propósito |
| O Gerenciador de máquinas virtuais não tem KVM | Dentro do VirtualBox a aninhada fica desligada | Esperado: a VM roda sem aceleração |
| Resolução fixa | A janela não acompanha o tamanho da tela | Sem as Adições de Convidado |
| Lentidão | O boot e os testes são bem mais lentos que no QEMU | Sem KVM, com ou sem Hyper-V ligado |
| Programas instalados somem | `sudo apt install` na sessão não persiste | A ISO é live; não há loja de aplicativos (decisão do grupo) |

## 16. Perguntas frequentes

**Posso usar outra versão do VirtualBox?** Pode, mas anote a versão. A 7.2 é a do roteiro; versões diferentes podem ter opções diferentes e gerar erros que não são do Nexus OS.

**Posso dar mais RAM à VM?** Pode (por exemplo 4096 MiB) se o computador aguentar. Anote na ficha. Com menos de 1792 MiB o desktop falha.

**A VM ficou muito lenta, o que faço?** Confira o item 4.2 (feche programas), a energia do notebook e se o Hyper-V está ligado. Anote o que observou; lentidão no VirtualBox é um resultado, não um erro seu.

**O teclado da VM está com teclas trocadas.** O sistema usa o teclado **ABNT2** (Brasil). Se o seu teclado for outro (por exemplo ANSI/US), algumas teclas (`ç`, `/`, `?`, `~`) mudam de lugar. Anote o modelo do teclado.

**Posso pausar e continuar outro dia?** Pode salvar o estado da VM (menu **Máquina**, **Fechar**, **Salvar o estado da máquina**), mas como a ISO é live o estado salvo mantém a sessão. Se preferir, termine tudo no mesmo dia.

**Não tenho certeza se um item passou.** Marque **passou com ressalvas** e descreva exatamente o que viu. É melhor do que adivinhar.

**Posso refazer um item que falhou?** Pode: anote as duas tentativas (por exemplo "falhou na 1ª, passou na 2ª") e o que mudou entre elas.

**Onde está o resto da documentação?** [Índice dos documentos](README.md), [manual do Nexus OS](manual.md), [especificação do desktop](gui.md), [requisitos de hardware](requisitos.md), [RC2](rc2.md) e o [checklist completo](checklist-teste-documentacao.md), parte H.
