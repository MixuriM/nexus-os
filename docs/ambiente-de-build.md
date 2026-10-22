# Ambiente de build da ISO

## Por que exige Linux

O live-build deve ser executado em Debian ou Ubuntu, com root e sistema de arquivos Linux.
Ele quebra em pasta Windows e em `/mnt/c` do WSL. Esta pasta serve para editar e versionar.
O build da ISO acontece a partir de um clone do repositório em um ambiente Linux.

## Base da distro

Debian estável. Em 24/09/2026 a estável é o Debian 13 (codinome trixie), na versão pontual 13.7, publicada em 12/09/2026.
A versão pontual muda com o tempo; o codinome trixie permanece até a próxima release estável.
Fonte: https://www.debian.org/releases/stable/

## Versões medidas (21/10/2026)

Medidas em uma VM Debian 13.7 recém-instalada, com `apt-get update` feito:

| Item | Comando | Resultado |
| --- | --- | --- |
| Debian | `cat /etc/debian_version` | 13.7 |
| live-build | `lb --version` | 20250505+deb13u1 |
| live-build (pacote) | `apt-cache policy live-build` | 1:20250505+deb13u1 (trixie/main) |
| Open vSwitch | `apt-cache policy openvswitch-switch` | 3.5.0-1+b1 (trixie/main) |

## Ambiente escolhido

VM Debian 13 (trixie) no VirtualBox do Windows, com o repositório clonado no disco da VM.
WSL2 não é usado. Nunca buildar em pasta compartilhada com o Windows.

Recursos da VM:

- 4 vCPU, 8 GB de RAM, disco dinâmico de 80 GB.
- Rede NAT com redirecionamento `127.0.0.1:2222` para a porta 22 da VM.
- Instalação mínima, sem ambiente gráfico, com servidor SSH e utilitários padrão.
- Usuário comum no grupo `sudo`, com `NOPASSWD` em `/etc/sudoers.d/` (VM de laboratório).

Criação da VM (PowerShell no Windows), com a ISO netinst do Debian 13 baixada e conferida pelo SHA256 publicado em https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/SHA256SUMS:

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

No instalador do Debian: deixar a senha de root vazia (cria o `sudo` para o usuário comum), particionamento guiado com o disco inteiro e, em "Software selection", desmarcar o ambiente gráfico e marcar apenas "SSH server" e "standard system utilities".

## Preparar a VM para o build

Na VM, como usuário comum com `sudo`:

```bash
sudo apt-get update
sudo apt-get install -y --no-install-recommends git ca-certificates live-build debootstrap xorriso squashfs-tools shellcheck qemu-system-x86 qemu-utils curl
git clone -b marcos https://github.com/MixuriM/nexus-os.git ~/nexus-os
```

Para gerar a ISO, veja a seção "Como gerar a ISO" do `README.md` e [iso-poc.md](iso-poc.md).

## Virtualização aninhada (KVM dentro da VM)

A VM é criada com `--nested-hw-virt=on`. Mesmo assim, com o Hyper-V ou a Plataforma de Hipervisor do Windows ativos,
o VirtualBox não expõe VT-x/AMD-V ao convidado: `/dev/kvm` não existe e `egrep -c '(vmx|svm)' /proc/cpuinfo` retorna 0.
Medido em 21/10/2026: esse é o caso do notebook de build. O teste de boot da ISO (`tests/iso.sh`) então roda o QEMU em emulação por software, mais lento (veja [iso-poc.md](iso-poc.md)).
