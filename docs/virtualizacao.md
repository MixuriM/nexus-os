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

## Na ISO (F3.3)

A ISO já traz o libvirt pronto. Pacotes (`live-build/config/package-lists/nexus-virt.list.chroot`): `libvirt-daemon-system` e `libvirt-clients` 11.3.0-3+deb13u3, `qemu-system-x86` 1:10.0.13+ds-0+deb13u1. A rede `default` precisa de `dnsmasq-base` (2.91) e de `nftables` (1.1.3), que o `libvirt-daemon-driver-network` já puxa por dependência (`apt-cache depends`): nenhum pacote extra foi acrescentado. `qemu-utils` fica de fora porque nenhum script o usa.

- **Serviço:** `libvirtd.service`, habilitado no hook; o `Also=` dele ativa `libvirtd.socket`, `libvirtd-ro.socket` e `libvirtd-admin.socket`. A `nexus-smoke.service` roda depois dele.
- **Rede `default`:** o pacote cria a rede sem autostart, porque o postinst não consegue rodar o `virsh` no chroot. O hook cria o link `/etc/libvirt/qemu/networks/autostart/default.xml`, o mesmo efeito de `virsh net-autostart default`. No boot, `virsh net-list --all` mostra `default` ativa, com autostart (sem internet).
- **Grupo:** o usuário `user` (senha `live`, pública do Debian Live) entra no grupo `libvirt` por `LIVE_USER_DEFAULT_GROUPS` em `/etc/live/config.conf.d/nexus.conf`, que o live-config lê em `/usr/lib/live/init-config.sh`. O arquivo repete a lista padrão do live-config e acrescenta `libvirt`.
- **`nexus-vm`:** link em `/usr/local/bin` para `nfv/libvirt/nexus-vm.sh`. `nexus-vm criar <nome>` define e inicia a VM de `vm-teste.xml` com outro nome (nome `[a-z0-9-]`, sem hífen no início), `virt-type kvm` se existir `/dev/kvm` e `qemu` se não, sempre em `qemu:///system`; `nexus-vm listar`; `nexus-vm remover <nome>`.

Smoke test dentro da ISO (veja [integracao-iso.md](integracao-iso.md)):

```bash
tests/iso-smoke.sh dist/nexus-os-poc-amd64.iso virtualizacao,libvirt
```

`virtualizacao` roda o `tests/virtualizacao.sh` sem alteração. `libvirt` (`tests/libvirt.sh`) confere a rede `default`, o grupo e o ciclo `nexus-vm criar`, `list --all` com `running`, `nexus-vm remover`, domínio e processo QEMU ausentes. Só roda dentro da ISO (`boot=live` em `/proc/cmdline`).

Medições em 23/10/2026, sem KVM no hospedeiro (QEMU em emulação por software, 1 vCPU e 2048 MiB): `OK: 2 teste(s) sem falha em 156 s`, `virtualizacao=23s`, `libvirt=7s`.

O guest da ISO enxerga `/dev/kvm` (`crw-rw---- root kvm 10, 232`), tem `kvm` e `kvm_amd` carregados e 1 CPU com `svm`, mesmo com o hospedeiro em emulação. Por isso os dois testes usaram `virt-type kvm` (saída `OK: tests/virtualizacao.sh (virt-type kvm ...)` e `OK: VM smoke1 criada e iniciada (virt-type kvm)`). O QEMU emula o `svm` do guest, então é um KVM aninhado lento sobre emulação, que só prova criar e iniciar.

## Problemas conhecidos

- **KVM aninhado derruba o VirtualBox (AMD).** Em 23/10/2026, com o hypervisor do Windows desligado e `--nested-hw-virt on`, a VM de build ganhou `/dev/kvm` e `svm`. Quando o QEMU interno usou KVM, o VirtualBox 7.2.20 abortou a VM com `Guru Meditation -4060 (VERR_SVM_UNKNOWN_EXIT)` (`VBox.log`). Aconteceu duas vezes: `tests/iso.sh` com 2 vCPU e 1024 MiB, e o smoke `sdn` com 1 vCPU e 2048 MiB. O changelog oficial da série 7.2 que conseguimos ler (até a 7.2.6) não cita correção de nested em AMD. Por isso a revalidação com KVM (F2.4, F2.6, F3.2) não foi feita e continua 🟡. A VM de build roda sem os módulos `kvm` (`/etc/modprobe.d/nexus-sem-kvm.conf`, só na VM, fora do repositório). Caminhos a avaliar: versão mais nova do VirtualBox, outro hospedeiro de VM (Hyper-V ou VMware) ou WSL2, em máquina diferente.
- Sem `/dev/kvm`, a VM roda em emulação por software. Serve para provar criar e iniciar, não para medir desempenho.
- A VM de teste não tem disco nem sistema: o QEMU inicia e fica tentando boot. O teste prova só que o domínio é definido e entra em `running`.
- O teste valida `qemu:///system` com root. Para usar `virsh` sem `sudo`, o usuário precisa estar no grupo `libvirt` (a mudança vale a partir do próximo login).
- Desligar o Hyper-V do Windows (para liberar o VT-x ao VirtualBox) afeta o WSL2 e o Docker Desktop do host. A decisão é do dono da máquina e não foi tomada.
