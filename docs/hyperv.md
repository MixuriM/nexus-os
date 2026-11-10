# VM de build no Hyper-V (com KVM): passo a passo completo

Este documento explica, do zero, como criar no Hyper-V do Windows 11 Pro uma VM Debian 13 com virtualização aninhada, para gerar e testar a ISO do Nexus OS com `/dev/kvm`. Foi escrito para quem **nunca viu o projeto**: cada passo diz **onde fazer**, **o que fazer**, **por que fazer**, **o que deve aparecer** e **o que fazer se não aparecer**. Leia a seção do passo inteira antes de executá-lo. A visão geral do ambiente está em [ambiente-de-build.md](ambiente-de-build.md).

## Sumário

1. [O que é esta VM e por que ela existe](#1-o-que-é-esta-vm-e-por-que-ela-existe)
2. [Regras que valem o tempo todo](#2-regras-que-valem-o-tempo-todo)
3. [O que você precisa ter antes](#3-o-que-você-precisa-ter-antes)
4. [Preparar o Windows](#4-preparar-o-windows)
5. [Baixar o Debian](#5-baixar-o-debian)
6. [Criar a VM](#6-criar-a-vm)
7. [Instalar o Debian](#7-instalar-o-debian)
8. [Conferir o KVM](#8-conferir-o-kvm)
9. [Acessar por SSH](#9-acessar-por-ssh)
10. [Preparar o build e validar](#10-preparar-o-build-e-validar)
11. [Desligar e apagar a VM](#11-desligar-e-apagar-a-vm)
12. [Problemas conhecidos](#12-problemas-conhecidos)
13. [Como relatar uma falha](#13-como-relatar-uma-falha)
14. [Perguntas frequentes](#14-perguntas-frequentes)

## 1. O que é esta VM e por que ela existe

O build da ISO do Nexus OS e os testes que iniciam a ISO precisam de uma máquina **Linux** (Debian 13). Para os testes ficarem rápidos, essa máquina precisa de **KVM**, a aceleração de virtualização do Linux (`/dev/kvm`). Como o KVM roda dentro de uma VM, a VM precisa de **virtualização aninhada** (nested): o Hyper-V do Windows expõe os recursos de virtualização do processador (`svm` em AMD, `vmx` em Intel) à VM.

**Por que não o VirtualBox:** o VirtualBox 7.2.20 em processador AMD aborta a VM quando o QEMU interno usa KVM (`Guru Meditation -4060 (VERR_SVM_UNKNOWN_EXIT)`, issue 25). Por isso a VM de build principal é do Hyper-V.

**Resultado esperado de uma execução bem-sucedida:** uma VM Debian 13 com `/dev/kvm`, na qual o build da ISO leva de 19 a 23 minutos e o `tests/iso.sh` chega ao `login:` em cerca de 40 s. Medido em 23/10/2026 numa VM de Geração 2 com 4 vCPU e 8 GB estáticos: `tests/iso.sh` com `OK` em 21 s, build da ISO em 348 s (ISO da prova de conceito, sem desktop) e smokes com `OK` em 24 s. A Microsoft documenta o aninhado em AMD (Ryzen e EPYC) para host Windows 11 e VM de configuração versão 9.3 ou mais nova: https://learn.microsoft.com/windows-server/virtualization/hyper-v/enable-nested-virtualization

**Tempo estimado:** 1 hora, quase toda no download e na instalação.

## 2. Regras que valem o tempo todo

1. **Faça só o que está escrito aqui.** Se precisar de algo que não está escrito (um pacote, um comando, um clique), isso é uma falha da documentação: anote e relate (seção 13). Não improvise.
2. **Um passo de cada vez, na ordem.** Os passos dependem uns dos outros.
3. **Confira o resultado de cada passo antes de seguir.** Cada passo diz "Deve aparecer". Se não apareceu, veja o "Se não aparecer" do mesmo passo.
4. **O repositório é público.** Nunca cole em issue ou captura: senha, chave, token, e-mail, nome de usuário do Windows, caminho com o seu nome de usuário.
5. **Comandos longos:** o console da VM no Hyper-V não aceita colar texto. Depois do passo 9, conecte por SSH e cole no terminal do Git Bash.

## 3. O que você precisa ter antes

| # | Item | Por quê | Como conseguir |
| --- | --- | --- | --- |
| 1 | **Windows 11 Pro ou Enterprise** | O Hyper-V não existe no Windows Home | Confira em Configurações, Sistema, Sobre |
| 2 | **Virtualização ligada no firmware** (VT-x ou AMD-V) | Sem ela o Hyper-V não inicia | Opção do BIOS/UEFI do computador (nome varia: "SVM Mode", "Intel Virtualization Technology") |
| 3 | **20 GB livres** no disco e **16 GB de RAM** no Windows (a VM usa 8 GB) | O disco da VM tem 80 GB dinâmicos e a RAM da VM é fixa | Confira em Configurações, Sistema, Armazenamento e Sobre |
| 4 | **Internet** | A instalação do Debian baixa pacotes e o build baixa pacotes e uma imagem de contêiner | Conexão normal |
| 5 | O **PowerShell como administrador** | Os comandos de Hyper-V pedem administrador | Menu Iniciar, digite `PowerShell`, botão direito, **Executar como administrador** |
| 6 | O **Git Bash** (vem com o Git para Windows) | Os comandos `ssh` e `scp` rodam nele | https://git-scm.com/download/win |

Os comandos `PowerShell` rodam como administrador; os comandos `bash` rodam no terminal da VM ou no Git Bash do Windows, conforme o rótulo de cada bloco.

## 4. Preparar o Windows

### Passo 4.1: conferir se o Hyper-V está habilitado

**Onde:** PowerShell como administrador.

**O que fazer:**

```powershell
dism /online /get-featureinfo /featurename:Microsoft-Hyper-V-All
```

**Por quê:** o recurso do Windows chamado Hyper-V precisa estar ligado para existir a máquina virtual.

**Deve aparecer:** `Estado : Habilitado` (ou `State : Enabled`).

**Se aparecer `Desabilitado`:** habilite e reinicie o Windows:

```powershell
dism /online /enable-feature /all /featurename:Microsoft-Hyper-V
```

No PowerShell 7, `Get-WindowsOptionalFeature` falha com "Classe não registrada"; use o `dism`, como acima.

### Passo 4.2: garantir que o hypervisor inicia com o Windows

**Onde:** PowerShell como administrador.

**O que fazer:**

```powershell
bcdedit /set hypervisorlaunchtype auto
bcdedit /enum | Select-String hypervisorlaunchtype
```

**Por quê:** o hypervisor é o componente que roda as VMs; ele precisa iniciar junto com o Windows.

**Deve aparecer:** `hypervisorlaunchtype    Auto`.

**Se não aparecer:** rode o primeiro comando de novo; se continuar, relate a saída de `bcdedit /enum`.

### Passo 4.3: reiniciar e confirmar

**O que fazer:** reinicie o Windows pelo menu Iniciar, **Reiniciar** (não "Desligar", por causa da inicialização rápida), e confirme no PowerShell:

```powershell
(Get-CimInstance Win32_ComputerSystem).HypervisorPresent
Get-VMHost | Select-Object Name
```

**Deve aparecer:** `True` e o nome do computador.

**Se o `Get-VMHost` der "classe não registrada":** rode o mesmo comando no Windows PowerShell (o azul, antigo).

Com o hypervisor ligado, WSL2 e Docker Desktop continuam funcionando. O VirtualBox passa a rodar sobre o Hyper-V e **não** oferece KVM: use o Hyper-V para os testes com KVM.

## 5. Baixar o Debian

**Onde:** navegador.

**O que fazer:** baixe a ISO **netinst amd64** do Debian 13 em https://www.debian.org/distrib/netinst (seção "CDs pequenos ou pendrives USB", link `amd64`). Salve em `C:\HyperV` (crie a pasta se não existir) e **anote o nome exato do arquivo** (algo como `debian-13.x.x-amd64-netinst.iso`).

**Por quê:** é o instalador que vai criar o sistema da VM. Use uma pasta sem acentos e sem espaços: acentos e espaços em caminhos costumam quebrar comandos copiados.

**Como conferir:** o SHA256 publicado fica em https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/SHA256SUMS. No PowerShell:

```powershell
Get-FileHash C:\HyperV\NOME-DA-ISO.iso -Algorithm SHA256
```

O `Hash` deve ser igual ao da linha do arquivo no `SHA256SUMS` (maiúsculas e minúsculas não importam). Se for diferente, baixe de novo.

## 6. Criar a VM

### 6.1 O que cada configuração significa (para entender, não para decorar)

| Configuração | Valor | Por que esse valor |
| --- | --- | --- |
| Geração | 2 (UEFI) | É a geração que expõe o aninhado e que o projeto usou |
| Memória | 8 GB **estáticos** | O build precisa de RAM. Com a Memória Dinâmica ligada a VM enxergou só cerca de 528 MB (`MemTotal`) e o build não tem RAM |
| Processadores | 4, com `ExposeVirtualizationExtensions` | Expõe `svm`/`vmx` à VM: é o que permite o KVM. Só funciona com a VM desligada |
| Secure Boot | desligada | O instalador do Debian não inicia com a Secure Boot padrão do Hyper-V |
| Disco | 80 GB dinâmicos | Guarda o sistema, o clone e o build (cerca de 14 GiB do clone) |
| Rede | `Default Switch` | NAT do Windows, com DHCP e internet |

### 6.2 Criar pelos comandos

**Onde:** PowerShell como administrador. **Como:** troque `NOME-DA-ISO.iso` pelo arquivo do passo 5, escolha o nome da VM no lugar de `<nome-da-vm>` e rode **um comando por vez**, lendo a saída antes do seguinte.

**O que fazer:**

```powershell
New-Item -ItemType Directory -Force C:\HyperV
$vm = "<nome-da-vm>"
New-VM -Name $vm -Generation 2 -MemoryStartupBytes 8GB -NewVHDPath "C:\HyperV\$vm.vhdx" -NewVHDSizeBytes 80GB -SwitchName "Default Switch"
Set-VMProcessor -VMName $vm -Count 4 -ExposeVirtualizationExtensions $true
Set-VMMemory -VMName $vm -DynamicMemoryEnabled $false -StartupBytes 8GB
Set-VMFirmware -VMName $vm -EnableSecureBoot Off
Add-VMDvdDrive -VMName $vm -Path "C:\HyperV\NOME-DA-ISO.iso"
Set-VMFirmware -VMName $vm -FirstBootDevice (Get-VMDvdDrive -VMName $vm)
```

**Por quê (comando por comando):** `New-VM` cria a VM de Geração 2 com disco dinâmico de 80 GB e a rede `Default Switch`; `Set-VMProcessor ... -ExposeVirtualizationExtensions $true` dá 4 processadores e expõe o aninhado; `Set-VMMemory ... -DynamicMemoryEnabled $false` **fixa os 8 GB**; `Set-VMFirmware ... -EnableSecureBoot Off` desliga a Secure Boot; `Add-VMDvdDrive` e `-FirstBootDevice` colocam a ISO e a fazem iniciar primeiro.

**Deve aparecer:** o `New-VM` imprime uma linha com o nome da VM, `State Off`, `Version` (9.3 ou maior). Os demais comandos não imprimem nada quando dão certo.

**Se não aparecer:** o `New-VM` com erro de caminho indica que `C:\HyperV` não existe (o primeiro comando a cria); erro de memória indica pouca RAM livre no Windows: troque `8GB` por `6GB` nos dois comandos que usam 8 GB.

Para uma VM que só **testa a ISO do Nexus OS** (sem disco, como no [manual](manual.md)), a rede não vem pronta: o `New-VM` sem `-SwitchName` deixa a VM sem rede, e o Firefox da ISO acusa `NS_ERROR_OFFLINE`. Para dar internet a ela: `Connect-VMNetworkAdapter -VMName <nome-da-vm> -SwitchName "Default Switch"`.

### 6.3 Conferir a configuração antes de ligar

**O que fazer:**

```powershell
Get-VMProcessor -VMName $vm | Select-Object Count, ExposeVirtualizationExtensions
Get-VMMemory -VMName $vm | Select-Object DynamicMemoryEnabled, Startup
(Get-VM $vm).Version
```

**Por quê:** é a única forma de ter certeza de que o aninhado e a memória fixa estão aplicados antes de instalar o sistema.

**Deve aparecer:** `4` e `True`; `False` e `8589934592`; versão `9.3` ou maior.

**Se não aparecer:** se a versão for menor, com a VM desligada: `Update-VMVersion $vm`. Se `ExposeVirtualizationExtensions` for `False`, desligue a VM e repita o `Set-VMProcessor`.

## 7. Instalar o Debian

### Passo 7.1: ligar a VM e abrir o console

**Onde:** PowerShell como administrador.

**O que fazer:**

```powershell
Start-VM -Name $vm
vmconnect.exe localhost $vm
```

**Deve aparecer:** uma janela com o menu do instalador do Debian. Clique **dentro da janela** e escolha **Install** (modo texto) com Enter.

### Passo 7.2: responder o instalador

| # | Tela | O que fazer | Por quê |
| --- | --- | --- | --- |
| 1 | Idioma, país e teclado | O que preferir (no Brasil, teclado ABNT2) | Só afeta o instalador e o teclado da VM |
| 2 | Nome da máquina e domínio | Nome o que preferir; domínio **vazio** | O domínio vazio evita configuração extra de rede |
| 3 | Senha do root | **Deixe em branco** | Assim o usuário comum entra no grupo `sudo` |
| 4 | Usuário comum e senha | Crie e **anote** | É com ele que você entra e usa `sudo` |
| 5 | Particionamento | Guiado, usar o disco inteiro, tudo em uma partição | O mais simples; o disco só guarda o clone e o build |
| 6 | Espelho do repositório | O primeiro que aparecer; sem proxy | Baixa os pacotes do Debian |
| 7 | Seleção de software | **Desmarque** o ambiente de área de trabalho e o GNOME; **marque** "servidor SSH" e "utilitários padrão do sistema" | A VM é de build, sem janela; o SSH permite colar comandos |
| 8 | GRUB | Sim, no disco principal (`/dev/sda`) | Para a VM iniciar pelo disco |
| 9 | Tela final | Continue com Enter | Reinicia a VM |

**Deve aparecer:** a VM reinicia e mostra `login:`.

**Se voltar ao instalador:** desligue e remova o DVD:

```powershell
Stop-VM $vm -TurnOff
Get-VMDvdDrive -VMName $vm
Remove-VMDvdDrive -VMName $vm -ControllerNumber 0 -ControllerLocation 1
Start-VM $vm
```

Use no `Remove-VMDvdDrive` os números que o `Get-VMDvdDrive` mostrar.

## 8. Conferir o KVM

**Onde:** console da VM (bash), logado como o usuário comum.

**O que fazer:**

```bash
egrep -c '(vmx|svm)' /proc/cpuinfo
ls -l /dev/kvm
lsmod | grep kvm
```

**Por quê:** confirma que o processador expõe a virtualização à VM, que o dispositivo `/dev/kvm` existe e que o módulo do KVM está carregado.

**Deve aparecer:** um número igual ao de vCPU (4), o dispositivo `crw-rw---- 1 root kvm ... /dev/kvm` e `kvm_amd` (ou `kvm_intel`) na lista. Atenção às maiúsculas: o módulo se chama `kvm_amd`, e `grep KVM` não acha nada.

**Se não aparecer:** se o `/dev/kvm` faltar, rode `sudo modprobe kvm_amd` (CPU AMD) ou `sudo modprobe kvm_intel` (Intel) e confira de novo; se continuar faltando, volte ao passo 6.3 e confira `ExposeVirtualizationExtensions`.

## 9. Acessar por SSH

**Quando:** depois da instalação, para colar comandos (o console do Hyper-V não aceita colar).

**Por quê:** o IP da VM no `Default Switch` muda quando o Windows reinicia, mas o nome `<nome-da-vm>.mshome.net`, resolvido pelo Windows, continua valendo.

**O que fazer (Git Bash do Windows):**

```bash
ssh -o StrictHostKeyChecking=accept-new <usuario>@<nome-da-vm>.mshome.net
```

**Deve aparecer:** o pedido da senha do usuário comum e, depois, o prompt da VM.

**Se não aparecer:** `Could not resolve hostname` indica que o nome da VM está errado ou a VM está desligada; `Connection refused` indica que o servidor SSH não foi instalado no passo 7.2 (item 7).

**Para entrar sem senha (opcional)**, copie a chave pública (Git Bash):

```bash
cat ~/.ssh/<sua-chave>.pub | ssh <usuario>@<nome-da-vm>.mshome.net 'mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys'
```

**Para o `sudo` não pedir senha (opcional, só em VM de laboratório;** desfaz com `sudo rm /etc/sudoers.d/<usuario>-nopasswd`**), no Git Bash:**

```bash
ssh -t <usuario>@<nome-da-vm>.mshome.net 'echo "<usuario> ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/<usuario>-nopasswd >/dev/null && sudo chmod 440 /etc/sudoers.d/<usuario>-nopasswd && sudo -n true && echo SUDO-OK'
```

**Deve aparecer:** `SUDO-OK` no fim.

## 10. Preparar o build e validar

**Onde:** na VM (bash), como usuário comum com `sudo`.

**O que fazer:**

```bash
sudo apt-get update
sudo apt-get install -y --no-install-recommends git ca-certificates live-build debootstrap xorriso squashfs-tools shellcheck qemu-system-x86 qemu-utils curl
sudo apt-get install -y docker.io
git clone https://github.com/MixuriM/nexus-os.git ~/nexus-os
cd ~/nexus-os
tests/lint-repo.sh
sudo scripts/build-iso.sh
tests/iso.sh dist/nexus-os-poc-amd64.iso
tests/iso-smoke.sh dist/nexus-os-poc-amd64.iso virtualizacao,libvirt
```

**Por quê:** os dois primeiros comandos instalam as ferramentas do build e dos testes; depois clona o repositório; `lint-repo.sh` confere os arquivos; `build-iso.sh` gera a ISO; `iso.sh` confere que ela inicia; `iso-smoke.sh` roda dois testes dentro dela. O `docker.io` é necessário porque o build baixa a imagem FRR (veja [ambiente-de-build.md](ambiente-de-build.md)).

**Deve aparecer (medido em 23/10/2026):** `OK: lint-repo`, `OK: dist/nexus-os-poc-amd64.iso, 688914432 bytes, 348 s`, `OK: ISO chegou ao login ... em 21 s, com KVM` e `OK: 2 teste(s) sem falha em 24 s, com KVM`. A palavra `com KVM` precisa aparecer: sem ela o QEMU caiu em emulação (veja o problema do grupo `kvm` na seção 12). Para a RC2 com desktop, use os comandos de "Gerar a ISO" do [manual](manual.md).

**Se não aparecer:** `FALHA:` em algum comando: leia a mensagem, veja a seção 12 e, se for novo, relate (seção 13).

## 11. Desligar e apagar a VM

**Quando:** só quando não precisar mais da VM. **Apagar o disco não tem volta:** tudo dentro da VM (clone, ISOs geradas) some. Copie antes o que quiser guardar (por exemplo `dist/*.iso` com `scp`).

**O que fazer (PowerShell como administrador):**

```powershell
Stop-VM -Name $vm -TurnOff
Remove-VM -Name $vm -Force
Remove-Item "C:\HyperV\$vm.vhdx"
```

**Por quê:** `Stop-VM -TurnOff` desliga a VM (se já estiver desligada, o comando acusa e pode ser ignorado); `Remove-VM` tira a VM do Hyper-V; `Remove-Item` apaga o arquivo do disco, que o `Remove-VM` não apaga. A ISO do Debian em `C:\HyperV` **não** é apagada.

**Deve aparecer:** nada. Confira com `Get-VM`: a VM não deve mais constar.

## 12. Problemas conhecidos

- **Só 528 MB de RAM na VM:** a Memória Dinâmica está ligada. Desligue a VM, rode o `Set-VMMemory` do passo 6.2 e ligue de novo.
- **`sem KVM (emulação por software)` na saída dos testes:** o usuário não acessa `/dev/kvm`. Rode `sudo usermod -aG kvm <usuario>`, saia e entre de novo.
- **VirtualBox e Hyper-V na mesma máquina:** com o hypervisor ligado, VMs do VirtualBox não têm KVM (nem nested). Mantenha uma VM só para os testes com KVM, no Hyper-V, e não ligue as duas ao mesmo tempo por causa da RAM.
- **Teste de `virsh` falha em outro idioma:** o `virsh` traduz o estado (em pt_BR, `executando`). Os testes `tests/virtualizacao.sh` e `tests/libvirt.sh` fixam `LC_ALL=C` e funcionam em qualquer idioma.
- **A ISO muda a cada build:** o tamanho se repete (688914432 bytes na ISO da prova de conceito), mas o SHA256 difere entre builds, por conteúdo variável. Confira o `.sha256` gerado junto com a ISO que você vai usar.
- **Não testado:** versão do VirtualBox mais nova que a 7.2.20 e WSL2 como alternativa de KVM.

## 13. Como relatar uma falha

**Quando:** para cada falha que se repete, para qualquer erro de comando deste documento e para tudo que ele não explicou (falha de documentação).

**Onde:** uma **issue** no repositório do projeto no GitHub.

**Título:** `<tarefa>: <passo>: <resumo curto>`. Exemplo: `F3.x: hyperv.md passo 6.3: ExposeVirtualizationExtensions continua False`.

**Corpo, com quatro blocos:** **Passos** (o que você fez, com os comandos exatos), **Saída** (o texto exato, copiado e colado), **Esperado** (o que o documento dizia) e **Ambiente** (versão do Windows, CPU AMD ou Intel, RAM do Windows, versão da configuração da VM, o que `Get-VMProcessor` mostrou). Uma issue por falha, sem dado pessoal (regra 4).

## 14. Perguntas frequentes

**Posso dar menos de 8 GB à VM?** Pode, até 6 GB (troque nos dois comandos), se o Windows estiver sem RAM. Menos que isso faz o build e os testes da RC2 com desktop ficarem apertados (veja [requisitos.md](requisitos.md)).

**Preciso do SSH?** Não é obrigatório, mas o console do Hyper-V não cola texto; para comandos longos o SSH é bem mais prático.

**Posso usar outro Linux?** O projeto só testou o Debian 13. Outro sistema é problema seu: o build exige live-build do Debian.

**Onde está o resto da documentação?** [Índice dos documentos](README.md), [manual](manual.md), [ambiente de build](ambiente-de-build.md) e [requisitos](requisitos.md).
