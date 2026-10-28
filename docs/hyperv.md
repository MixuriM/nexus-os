# VM de build no Hyper-V (com KVM)

Passo a passo para criar, no Hyper-V do Windows 11 Pro, uma VM Debian 13 com virtualização aninhada. Serve para quem precisa de `/dev/kvm` dentro da VM de build: o VirtualBox 7.2.20 em CPU AMD aborta a VM quando o QEMU interno usa KVM (`Guru Meditation -4060 (VERR_SVM_UNKNOWN_EXIT)`, issue #25). A visão geral do ambiente está em [ambiente-de-build.md](ambiente-de-build.md).

Medido em 23/10/2026 nesta VM (Debian 13, Geração 2, 4 vCPU, 8 GB estáticos): `/dev/kvm` presente, `tests/iso.sh` com `OK` em 21 s, build da ISO em 348 s, smokes com `OK` em 24 s. A Microsoft documenta nested em AMD (Ryzen e EPYC) para host Windows 11 e VM de configuração versão 9.3 ou mais nova: https://learn.microsoft.com/windows-server/virtualization/hyper-v/enable-nested-virtualization

Tempo estimado: 1 hora, quase toda no download e na instalação.

## Pré-requisitos

- Windows 11 Pro ou Enterprise (o Hyper-V não existe no Home).
- Virtualização ligada no firmware (VT-x ou AMD-V).
- 20 GB livres no disco e, no mínimo, 16 GB de RAM no Windows (a VM usa 8 GB).
- Internet (a instalação do Debian baixa pacotes).
- Os comandos `PowerShell` abaixo rodam como administrador: menu Iniciar, digite `PowerShell`, botão direito, **Executar como administrador**. Os comandos `bash` rodam no terminal da VM ou no Git Bash do Windows, conforme o rótulo de cada bloco.

## 1. Preparar o Windows

1. Confira se o recurso Hyper-V está habilitado (PowerShell):

    ```powershell
    dism /online /get-featureinfo /featurename:Microsoft-Hyper-V-All
    ```

    Deve aparecer `Estado : Habilitado` (ou `State : Enabled`). Se aparecer `Desabilitado`, habilite e reinicie o Windows:

    ```powershell
    dism /online /enable-feature /all /featurename:Microsoft-Hyper-V
    ```

    No PowerShell 7, `Get-WindowsOptionalFeature` falha com "Classe não registrada"; use o `dism`, como acima.

2. Garanta que o hypervisor inicia com o Windows (PowerShell):

    ```powershell
    bcdedit /set hypervisorlaunchtype auto
    bcdedit /enum | Select-String hypervisorlaunchtype
    ```

    Deve aparecer `hypervisorlaunchtype    Auto`.

3. Reinicie o Windows pelo menu Iniciar, **Reiniciar** (não "Desligar", por causa da inicialização rápida) e confirme (PowerShell):

    ```powershell
    (Get-CimInstance Win32_ComputerSystem).HypervisorPresent
    Get-VMHost | Select-Object Name
    ```

    Deve aparecer `True` e o nome do computador. Se o `Get-VMHost` der "classe não registrada", rode o mesmo comando no Windows PowerShell (o azul, antigo).

Com o hypervisor ligado, WSL2 e Docker Desktop continuam funcionando. O VirtualBox passa a rodar sobre o Hyper-V e **não** oferece KVM: use o Hyper-V para os testes com KVM.

## 2. Baixar o Debian

Baixe a ISO **netinst amd64** do Debian 13 em https://www.debian.org/distrib/netinst (seção "CDs pequenos ou pendrives USB", link `amd64`). Salve em `C:\HyperV` e anote o nome exato do arquivo (algo como `debian-13.x.x-amd64-netinst.iso`). O SHA256 publicado fica em https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/SHA256SUMS.

## 3. Criar a VM

Troque `NOME-DA-ISO.iso` pelo arquivo do passo 2 e rode um comando por vez (PowerShell):

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

O que cada comando faz:

- `New-VM`: cria a VM de Geração 2 (UEFI) com disco dinâmico de 80 GB e a rede `Default Switch` (NAT, com internet).
- `Set-VMProcessor ... -ExposeVirtualizationExtensions $true`: expõe `svm` à VM. É o que permite o KVM. Só funciona com a VM desligada.
- `Set-VMMemory ... -DynamicMemoryEnabled $false`: **fixa os 8 GB**. Com a Memória Dinâmica ligada a VM enxergou só cerca de 528 MB (`MemTotal`) e o build não tem RAM.
- `Set-VMFirmware ... -EnableSecureBoot Off`: o instalador do Debian não inicia com a Secure Boot padrão do Hyper-V.
- `Add-VMDvdDrive` e `-FirstBootDevice`: colocam a ISO e a fazem iniciar primeiro.

Para uma VM que só **testa a ISO do Nexus OS** (sem disco, Geração 1, como no [manual](manual.md)), a rede não vem pronta: o `New-VM` sem `-SwitchName` deixa a VM sem rede, e o Firefox da ISO acusa `NS_ERROR_OFFLINE`. Para dar internet a ela (PowerShell como administrador): `Connect-VMNetworkAdapter -VMName <nome-da-vm> -SwitchName "Default Switch"`.

Confira a configuração:

```powershell
Get-VMProcessor -VMName $vm | Select-Object Count, ExposeVirtualizationExtensions
Get-VMMemory -VMName $vm | Select-Object DynamicMemoryEnabled, Startup
(Get-VM $vm).Version
```

Deve aparecer `4` e `True`; `False` e `8589934592`; versão `9.3` ou maior. Se a versão for menor, com a VM desligada: `Update-VMVersion $vm`. Se faltar RAM no Windows, troque `8GB` por `6GB` nos dois comandos que usam 8 GB.

## 4. Instalar o Debian

Ligue a VM e abra o console (PowerShell):

```powershell
Start-VM -Name $vm
vmconnect.exe localhost $vm
```

Clique dentro da janela e escolha **Install** (modo texto) com Enter. No instalador:

1. Idioma e país: o que preferir. Teclado: o seu (no Brasil, ABNT2).
2. Nome da máquina: o que preferir. Domínio: vazio.
3. **Senha do root: deixe em branco.** Assim o usuário comum entra no grupo `sudo`.
4. Crie um usuário comum e uma senha, e anote.
5. Particionamento: guiado, usar o disco inteiro, tudo em uma partição.
6. Espelho do repositório: o primeiro que aparecer. Sem proxy.
7. Seleção de software: **desmarque** o ambiente de área de trabalho e o GNOME; **marque** "servidor SSH" e "utilitários padrão do sistema".
8. GRUB: sim, no disco principal (`/dev/sda`).
9. Na tela final, continue com Enter.

A VM reinicia e mostra `login:`. Se voltar ao instalador, desligue e remova o DVD (PowerShell):

```powershell
Stop-VM $vm -TurnOff
Get-VMDvdDrive -VMName $vm
Remove-VMDvdDrive -VMName $vm -ControllerNumber 0 -ControllerLocation 1
Start-VM $vm
```

Use no `Remove-VMDvdDrive` os números que o `Get-VMDvdDrive` mostrar.

## 5. Conferir o KVM

No console da VM (bash), logado como o usuário comum:

```bash
egrep -c '(vmx|svm)' /proc/cpuinfo
ls -l /dev/kvm
lsmod | grep kvm
```

Deve aparecer um número igual ao de vCPU (4), o dispositivo `crw-rw---- 1 root kvm ... /dev/kvm` e `kvm_amd` (ou `kvm_intel`) na lista. Atenção às maiúsculas: o módulo se chama `kvm_amd`, e `grep KVM` não acha nada. Se o `/dev/kvm` faltar, rode `sudo modprobe kvm_amd` (CPU AMD) ou `sudo modprobe kvm_intel` (Intel) e confira de novo; se continuar faltando, volte ao passo 3 e confira `ExposeVirtualizationExtensions`.

## 6. Acessar por SSH

O IP da VM no `Default Switch` muda quando o Windows reinicia, mas o nome `<nome-da-vm>.mshome.net`, resolvido pelo Windows, continua valendo. No Git Bash do Windows:

```bash
ssh -o StrictHostKeyChecking=accept-new <usuario>@<nome-da-vm>.mshome.net
```

Para entrar sem senha, copie a chave pública (bash, Git Bash):

```bash
cat ~/.ssh/<sua-chave>.pub | ssh <usuario>@<nome-da-vm>.mshome.net 'mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys'
```

Para o `sudo` não pedir senha (opcional, só em VM de laboratório; desfaz com `sudo rm /etc/sudoers.d/<usuario>-nopasswd`), no Git Bash:

```bash
ssh -t <usuario>@<nome-da-vm>.mshome.net 'echo "<usuario> ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/<usuario>-nopasswd >/dev/null && sudo chmod 440 /etc/sudoers.d/<usuario>-nopasswd && sudo -n true && echo SUDO-OK'
```

O console do Hyper-V não aceita colar texto. Para rodar comandos longos, conecte por SSH e cole no terminal do Git Bash.

## 7. Preparar o build e validar

Na VM (bash), como usuário comum com `sudo`:

```bash
sudo apt-get update
sudo apt-get install -y --no-install-recommends git ca-certificates live-build debootstrap xorriso squashfs-tools shellcheck qemu-system-x86 qemu-utils curl
git clone https://github.com/MixuriM/nexus-os.git ~/nexus-os
cd ~/nexus-os
tests/lint-repo.sh
sudo scripts/build-iso.sh
tests/iso.sh dist/nexus-os-poc-amd64.iso
tests/iso-smoke.sh dist/nexus-os-poc-amd64.iso virtualizacao,libvirt
```

Saídas esperadas, medidas em 23/10/2026: `OK: lint-repo`, `OK: dist/nexus-os-poc-amd64.iso, 688914432 bytes, 348 s`, `OK: ISO chegou ao login ... em 21 s, com KVM` e `OK: 2 teste(s) sem falha em 24 s, com KVM`. A palavra `com KVM` precisa aparecer: sem ela o QEMU caiu em emulação (veja o problema do grupo `kvm` abaixo).

## Problemas conhecidos

- **Só 528 MB de RAM na VM:** a Memória Dinâmica está ligada. Desligue a VM, rode o `Set-VMMemory` do passo 3 e ligue de novo.
- **`sem KVM (emulação por software)` na saída dos testes:** o usuário não acessa `/dev/kvm`. Rode `sudo usermod -aG kvm <usuario>`, saia e entre de novo.
- **VirtualBox e Hyper-V na mesma máquina:** com o hypervisor ligado, VMs do VirtualBox não têm KVM (nem nested). Mantenha uma VM só para os testes com KVM, no Hyper-V, e não ligue as duas ao mesmo tempo por causa da RAM.
- **Teste de `virsh` falha em outro idioma:** o `virsh` traduz o estado (em pt_BR, `executando`). Os testes `tests/virtualizacao.sh` e `tests/libvirt.sh` fixam `LC_ALL=C` e funcionam em qualquer idioma.
- **A ISO muda a cada build:** o tamanho se repete (688914432 bytes), mas o SHA256 difere entre builds, por conteúdo variável. Confira o `.sha256` gerado junto com a ISO que você vai usar.
- **Não testado:** versão do VirtualBox mais nova que a 7.2.20 e WSL2 como alternativa de KVM.
