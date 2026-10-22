# Virtualização: KVM/QEMU com libvirt

Validação da F2.6: o `virsh` define e inicia uma VM de teste em `qemu:///system`. KVM/QEMU com libvirt é o VIM do Nexus OS.

## Resultado (22/10/2026)

| Item | Valor |
| --- | --- |
| Ambiente | VM Debian 13 (trixie) de desenvolvimento no VirtualBox, dentro de um host Windows 11 |
| libvirt | 11.3.0 (`virsh --version`), pacotes `libvirt-daemon-system` e `libvirt-clients` 11.3.0-3+deb13u3 |
| QEMU | 10.0.13, Debian 1:10.0.13+ds-0+deb13u1 (`qemu-system-x86_64 --version`) |
| Modo | emulação por software (`virt-type qemu`, TCG), sem KVM |
| VM de teste | `nfv/libvirt/vm-teste.xml`: domínio `nexus-vm-teste`, 128 MiB, 1 vCPU, sem disco |
| Teste | `sudo tests/virtualizacao.sh`: `OK: tests/virtualizacao.sh (virt-type qemu, domínio nexus-vm-teste running e removido)`, código 0 |

## Premissa 1 do TAP: VT-x/AMD-V

Medido na VM de desenvolvimento:

```text
$ egrep -c '(vmx|svm)' /proc/cpuinfo
0
$ ls -l /dev/kvm
ls: cannot access '/dev/kvm': No such file or directory
```

A VM não recebe as extensões de virtualização. No host Windows, `HypervisorPresent` e `VirtualizationFirmwareEnabled` retornam `True`: a virtualização está habilitada no firmware, mas o Hyper-V do Windows ocupa o hardware e o VirtualBox não repassa VT-x à VM.
Virtualização aninhada indisponível nesta máquina; testes em emulação por software.

Consequências: o KVM não é testado aqui, e as VMs dentro do Nexus OS rodam em TCG (lento: o boot da ISO sem KVM variou de 104 s a 827 s). A premissa 1 continua aberta para as máquinas que tiverem `/dev/kvm`.
O teste usa `virt-type kvm` automaticamente quando `/dev/kvm` existe.

## Passos

Na VM Debian:

```bash
sudo apt install libvirt-daemon-system libvirt-clients qemu-system-x86
sudo systemctl is-active libvirtd
```

Defina e inicie a VM de teste (sem KVM, o `type='qemu'` do XML já serve; com `/dev/kvm`, troque para `type='kvm'`):

```bash
sudo virsh -c qemu:///system define nfv/libvirt/vm-teste.xml
sudo virsh -c qemu:///system start nexus-vm-teste
sudo virsh -c qemu:///system list --all
```

Saída esperada do último comando: o domínio `nexus-vm-teste` com estado `running`. Para remover:

```bash
sudo virsh -c qemu:///system destroy nexus-vm-teste
sudo virsh -c qemu:///system undefine nexus-vm-teste
```

O teste automatizado faz esse roteiro e a limpeza, e registra `vmx/svm` e `/dev/kvm`:

```bash
sudo tests/virtualizacao.sh
```

## Problemas conhecidos

- Sem `/dev/kvm`, a VM roda em emulação por software. Serve para provar criar e iniciar, não para medir desempenho.
- A VM de teste não tem disco nem sistema: o QEMU inicia e fica tentando boot. O teste prova só que o domínio é definido e entra em `running`.
- O teste valida `qemu:///system` com root. Para usar `virsh` sem `sudo`, o usuário precisa estar no grupo `libvirt` (a mudança vale a partir do próximo login).
- Desligar o Hyper-V do Windows (para liberar o VT-x ao VirtualBox) afeta o WSL2 e o Docker Desktop do host. A decisão é do dono da máquina e não foi tomada.
