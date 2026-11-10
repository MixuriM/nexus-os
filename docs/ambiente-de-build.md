# Ambiente de build da ISO: passo a passo completo

Este documento explica, do zero, como preparar a máquina em que a ISO do Nexus OS é gerada. Foi escrito para quem **nunca viu o projeto**: cada passo diz **onde fazer**, **o que fazer**, **por que fazer**, **o que deve aparecer** e **o que fazer se não aparecer**. Leia a seção do passo inteira antes de executá-lo. Depois de preparar o ambiente, a geração da ISO está na seção "Gerar a ISO" do [manual](manual.md).

## Sumário

1. [Por que exige Linux](#1-por-que-exige-linux)
2. [Base da distro e versões medidas](#2-base-da-distro-e-versões-medidas)
3. [Regras que valem o tempo todo](#3-regras-que-valem-o-tempo-todo)
4. [O que você precisa ter antes](#4-o-que-você-precisa-ter-antes)
5. [Criar a VM de build](#5-criar-a-vm-de-build)
6. [Preparar a VM para o build](#6-preparar-a-vm-para-o-build)
7. [Requisitos medidos do build](#7-requisitos-medidos-do-build)
8. [Virtualização aninhada (KVM dentro da VM)](#8-virtualização-aninhada-kvm-dentro-da-vm)
9. [Problemas conhecidos](#9-problemas-conhecidos)
10. [Como relatar uma falha](#10-como-relatar-uma-falha)
11. [Perguntas frequentes](#11-perguntas-frequentes)

## 1. Por que exige Linux

O live-build deve ser executado em Debian ou Ubuntu, com root e sistema de arquivos Linux. Ele quebra em pasta Windows e em `/mnt/c` do WSL. A pasta do repositório no Windows serve para editar e versionar. O build da ISO acontece a partir de um **clone do repositório em um ambiente Linux**, e o `scripts/build-iso.sh` recusa rodar em `/mnt/*`.

## 2. Base da distro e versões medidas

**Base:** Debian estável. Em 24/09/2026 a estável é o Debian 13 (codinome trixie), na versão pontual 13.7, publicada em 12/09/2026. A versão pontual muda com o tempo; o codinome trixie permanece até a próxima release estável. Fonte: https://www.debian.org/releases/stable/

**Versões medidas (21/10/2026)**, numa VM Debian 13.7 recém-instalada, com `apt-get update` feito:

| Item | Comando | Resultado |
| --- | --- | --- |
| Debian | `cat /etc/debian_version` | 13.7 |
| live-build | `lb --version` | 20250505+deb13u1 |
| live-build (pacote) | `apt-cache policy live-build` | 1:20250505+deb13u1 (trixie/main) |
| Open vSwitch | `apt-cache policy openvswitch-switch` | 3.5.0-1+b1 (trixie/main) |

## 3. Regras que valem o tempo todo

1. **Faça só o que está escrito aqui.** Se precisar de algo que não está escrito, isso é uma falha da documentação: anote e relate (seção 10). Não improvise.
2. **Um passo de cada vez, na ordem**, conferindo o "Deve aparecer" de cada um.
3. **Nunca faça o build em pasta compartilhada com o Windows nem em `/mnt/*`.**
4. **O repositório é público.** Nunca cole em issue ou captura: senha, chave, token, e-mail, nome de usuário do seu computador.
5. **Logs e arquivos de build não vão para o Git:** a ISO, o `.sha256` e `live-build/build.log` ficam fora do repositório.

## 4. O que você precisa ter antes

| # | Item | Por quê | Como conseguir |
| --- | --- | --- | --- |
| 1 | Um computador com **Windows 10 ou 11 (64 bits)** ou um **Linux** para hospedar a VM | A VM de build roda num programa de máquina virtual | Hyper-V (Windows 11 Pro), VirtualBox 7.2 ou o próprio Linux |
| 2 | **8 GB de RAM** livres para a VM (o build e os testes da RC1 rodaram com 6 GB) | O build usa até 1,3 GiB no pico, mas o QEMU dos testes e o sistema precisam do resto | Veja a seção 7 |
| 3 | **80 GB de disco** dinâmico para a VM (o clone ocupa cerca de 14 GiB com o desktop) | Guarda o sistema, o clone, o build e as ISOs | Disco com 20 GB livres no mínimo |
| 4 | A ISO **netinst amd64** do Debian 13 | É o instalador da VM de build | https://www.debian.org/distrib/netinst e o SHA256 em https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/SHA256SUMS |
| 5 | **Internet** na VM | O build baixa pacotes do Debian, o `.deb` do Containerlab e a imagem de contêiner FRR | Conexão normal |

## 5. Criar a VM de build

Há dois caminhos. O **Hyper-V com KVM** é o recomendado: o KVM faz o build e os testes rodarem bem mais rápido. Use o VirtualBox só se o Hyper-V não for possível.

### 5.1 Hyper-V com KVM (recomendado)

**O que é:** em 23/10/2026, em um notebook com CPU AMD, o VirtualBox 7.2.20 não serve para KVM (veja a seção 8 e a issue 25). A alternativa que funcionou foi uma VM Debian 13 de Geração 2 no Hyper-V do Windows 11 Pro, com o hypervisor ligado. Medido: `/dev/kvm` presente, `egrep -c '(vmx|svm)' /proc/cpuinfo` igual ao número de vCPU, build da ISO em 348 s (ISO da prova de conceito) e todos os smokes com KVM.

**Passo a passo completo** (preparo do Windows, instalação do Debian, SSH e validação): [hyperv.md](hyperv.md). Resumo dos comandos de criação (PowerShell 7 como administrador, com a ISO netinst do Debian 13 em `C:\HyperV`; troque `NOME-DA-ISO.iso`):

```powershell
$vm = "<nome-da-vm>"
New-VM -Name $vm -Generation 2 -MemoryStartupBytes 8GB -NewVHDPath "C:\HyperV\$vm.vhdx" -NewVHDSizeBytes 80GB -SwitchName "Default Switch"
Set-VMProcessor -VMName $vm -Count 4 -ExposeVirtualizationExtensions $true
Set-VMMemory -VMName $vm -DynamicMemoryEnabled $false -StartupBytes 8GB
Set-VMFirmware -VMName $vm -EnableSecureBoot Off
Add-VMDvdDrive -VMName $vm -Path "C:\HyperV\NOME-DA-ISO.iso"
Set-VMFirmware -VMName $vm -FirstBootDevice (Get-VMDvdDrive -VMName $vm)
```

**Por quê:** `-ExposeVirtualizationExtensions $true` é o que permite o KVM dentro da VM (só funciona com a VM desligada); a Memória Dinâmica **precisa** ficar desligada (`-DynamicMemoryEnabled $false`): com ela ligada a VM enxergou só cerca de 528 MB (`MemTotal`) e o build não tem RAM; a Secure Boot desligada deixa o instalador do Debian iniciar.

**Deve aparecer:** o `New-VM` imprime o nome da VM, `State Off` e a versão; os outros comandos não imprimem nada quando dão certo.

**Se não aparecer:** veja a seção de problemas do [hyperv.md](hyperv.md).

**Detalhes úteis:** a Microsoft documenta o aninhado em AMD (Ryzen e EPYC) com host Windows 11 e VM de versão 9.3 ou mais nova (https://learn.microsoft.com/windows-server/virtualization/hyper-v/enable-nested-virtualization). O IP da VM no `Default Switch` muda quando o Windows reinicia; o nome `<nome-da-vm>.mshome.net`, resolvido pelo Windows, continua valendo: `ssh <usuario>@<nome-da-vm>.mshome.net`. A instalação do Debian e a preparação do build são as mesmas da seção 6.

### 5.2 VirtualBox (sem KVM, o mais lento)

**O que é:** VM Debian 13 (trixie) no VirtualBox do Windows, com o repositório clonado no disco da VM. WSL2 não é usado. Nunca buildar em pasta compartilhada com o Windows.

**Recursos da VM:** 4 vCPU, 8 GB de RAM, disco dinâmico de 80 GB; rede NAT com redirecionamento `127.0.0.1:2222` para a porta 22 da VM; instalação mínima, sem ambiente gráfico, com servidor SSH e utilitários padrão; usuário comum no grupo `sudo`, com `NOPASSWD` em `/etc/sudoers.d/` (VM de laboratório).

**O que fazer** (PowerShell no Windows, com a ISO netinst do Debian 13 baixada e conferida pelo SHA256 publicado):

```powershell
$vb  = 'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe'
$iso = "$env:USERPROFILE\Downloads\debian-13.7.0-amd64-netinst.iso"
$base = "$env:USERPROFILE\VirtualBox VMs"
$vdi = "$base\nexus-build\nexus-build.vdi"

& $vb createvm --name=nexus-build --ostype=Debian_64 --basefolder="$base" --register
& $vb modifyvm nexus-build --cpus=4 --memory=8192 --vram=16 --graphicscontroller=vmsvga --audio-driver=none --nic1=nat --nat-pf1="ssh,tcp,127.0.0.1,2222,,22" --nested-hw-virt=on
& $vb createmedium disk --filename="$vdi" --size=81920 --format=VDI --variant=Standard
& $vb storagectl nexus-build --name=SATA --add=sata --controller=IntelAhci
& $vb storageattach nexus-build --storagectl=SATA --port=0 --device=0 --type=hdd --medium="$vdi"
& $vb storageattach nexus-build --storagectl=SATA --port=1 --device=0 --type=dvddrive --medium="$iso"
```

**Por quê:** cada linha cria a VM, define processadores, memória, vídeo, a rede NAT com o redirecionamento da porta SSH, cria o disco e liga o disco e o DVD de instalação.

**Deve aparecer:** `Virtual machine 'nexus-build' is created and registered.` no primeiro comando e nada nos demais (o VirtualBox não imprime nada quando dá certo).

**Se não aparecer:** `already exists` indica uma VM com esse nome de uma tentativa anterior (apague-a no VirtualBox Manager). Erro de caminho indica que o `VBoxManage.exe` está em outra pasta: abra `C:\Program Files\Oracle\VirtualBox` no Explorador de Arquivos e ajuste a primeira linha.

**No instalador do Debian:** deixe a senha de root vazia (cria o `sudo` para o usuário comum), particionamento guiado com o disco inteiro e, em "Software selection", desmarque o ambiente gráfico e marque apenas "SSH server" e "standard system utilities".

## 6. Preparar a VM para o build

**Onde:** na VM (bash), como usuário comum com `sudo`.

### Passo 6.1: instalar as ferramentas e clonar o repositório

**O que fazer:**

```bash
sudo apt-get update
sudo apt-get install -y --no-install-recommends git ca-certificates live-build debootstrap xorriso squashfs-tools shellcheck qemu-system-x86 qemu-utils curl
git clone -b marcos https://github.com/MixuriM/nexus-os.git ~/nexus-os
```

**Por quê:** o `live-build` e o `debootstrap` montam o sistema da ISO; `xorriso` e `squashfs-tools` empacotam a ISO; `qemu-system-x86` e `qemu-utils` iniciam a ISO nos testes; `shellcheck` confere os scripts; `git` e `ca-certificates` clonam o repositório; `curl` baixa arquivos. O clone vai para `~/nexus-os` (o ramo `marcos` é o de trabalho; para a versão publicada use o ramo `main`).

**Deve aparecer:** o `apt-get` termina sem erro (muitas linhas `Setting up ...`) e o `git clone` mostra o progresso do download.

**Se não aparecer:** sem internet, `Could not resolve host` ou `Temporary failure resolving`: conecte a VM. `E: Unable to locate package` indica que o `apt-get update` falhou: rode-o de novo e leia a mensagem.

### Passo 6.2: instalar o Docker

**O que fazer:**

```bash
sudo apt-get install -y docker.io
```

**Por quê:** desde a F3.4 o build também precisa de Docker e de internet na VM de build: o `scripts/prepare-offline.sh` baixa as imagens de contêiner (`docker pull`) e as grava na ISO. Medido em 23/10/2026: `docker.io` 26.1.5+dfsg1-9+deb13u1 (`apt-cache policy docker.io`). O `scripts/build-iso.sh` roda como root, então o usuário comum não precisa estar no grupo `docker`. Detalhes: [containers.md](containers.md).

**Deve aparecer:** o `apt-get` termina sem erro. Confira com `sudo docker info`: deve listar `Server Version`.

**Se não aparecer:** `Cannot connect to the Docker daemon` indica que o serviço não subiu: `sudo systemctl start docker` e tente de novo.

### Passo 6.3: gerar a ISO

Os comandos exatos, do clone até o `.sha256`, estão na seção "Gerar a ISO" do [manual](manual.md) e em [iso-poc.md](iso-poc.md); a seção "Como gerar a ISO" do `README.md` tem o resumo.

## 7. Requisitos medidos do build

**RC1 (26/10/2026):** medidos no build limpo da RC1 (clone novo, um comando `sudo scripts/build-iso.sh`), VM Debian 13 no Hyper-V com 4 vCPU e 6 GB de RAM estáticos (5930 MiB visíveis): detalhes em [rc1.md](rc1.md).

| Item | Valor medido |
| --- | --- |
| Tempo | 516 s |
| Disco ocupado ao fim | 5383 MiB no clone (`live-build/` com 4504 MiB) |
| RAM usada no pico | 1332 MiB (amostra a cada 5 s) |
| Internet | `.deb` do Containerlab (26197450 bytes), pacotes do Debian e, na primeira vez, a imagem FRR (`docker pull`) |

**RC2 final (09/11/2026, mesma VM):** tempo 1134 s e disco 14098 MiB no clone (`live-build/` com 10273 MiB, mais as duas cópias da ISO em `dist/`); deixe pelo menos 20 GiB livres.

Não é preciso 8 GB de RAM: o build e todos os testes da RC1 rodaram com 6 GB. Para o `tests/run-fase2.sh` na VM de build (testes de laboratório no host), instale também os pacotes do Open vSwitch: `sudo apt-get install -y openvswitch-switch iproute2 iputils-ping`.

## 8. Virtualização aninhada (KVM dentro da VM)

No VirtualBox, a VM é criada com `--nested-hw-virt=on`. Mesmo assim, com o Hyper-V ou a Plataforma de Hipervisor do Windows ativos, o VirtualBox não expõe VT-x/AMD-V ao convidado: `/dev/kvm` não existe e `egrep -c '(vmx|svm)' /proc/cpuinfo` retorna 0. Medido em 21/10/2026: esse é o caso do notebook de build. O teste de boot da ISO (`tests/iso.sh`) então roda o QEMU em emulação por software, mais lento (veja [iso-poc.md](iso-poc.md)). Por isso o Hyper-V (seção 5.1) é o recomendado.

## 9. Problemas conhecidos

| Sintoma | Causa | Correção |
| --- | --- | --- |
| O build recusa rodar em `/mnt/*` | O live-build quebra em pasta do Windows | Clone o repositório no disco do Linux |
| `FALHA: precisa de root` | Faltou o `sudo` | `sudo scripts/build-iso.sh` |
| A VM enxerga só cerca de 528 MB | Memória Dinâmica ligada no Hyper-V | `Set-VMMemory -DynamicMemoryEnabled $false` ([hyperv.md](hyperv.md)) |
| Testes dizem `sem KVM (emulação por software)` | O usuário não acessa `/dev/kvm` ou a VM não tem aninhado | `sudo usermod -aG kvm <usuario>` e reentre; confira o aninhado ([hyperv.md](hyperv.md)) |
| A primeira execução do build demora e baixa muito | Na primeira vez baixa a imagem FRR (`docker pull`) e os pacotes do Debian | Espere; as vezes seguintes usam o cache |

## 10. Como relatar uma falha

**Quando:** para cada falha que se repete, para qualquer erro de comando deste documento e para tudo que ele não explicou.

**Onde:** uma **issue** no repositório do projeto no GitHub. **Título:** `<tarefa>: <passo>: <resumo curto>`. **Corpo:** **Passos** (comandos exatos), **Saída** (texto exato copiado e colado), **Esperado** (o que o documento dizia) e **Ambiente** (Windows e programa de VM, RAM, vCPU, com ou sem KVM, commit do repositório). Uma issue por falha, sem dado pessoal (regra 4).

## 11. Perguntas frequentes

**Posso gerar a ISO no WSL2?** O projeto não usa o WSL2. Se usar, clone no disco Linux do WSL (ext4), nunca em `/mnt/c`.

**Preciso de Ubuntu em vez de Debian?** O live-build roda em Debian ou Ubuntu, mas o projeto só testou o Debian 13.

**Quanto espaço a ISO ocupa?** 1990639616 bytes (1898 MiB) na RC2 final; o clone com o build ocupa cerca de 14 GiB.

**Onde está o resto da documentação?** [Índice dos documentos](README.md), [manual](manual.md), [hyperv.md](hyperv.md), [iso-poc.md](iso-poc.md) e [requisitos.md](requisitos.md).
