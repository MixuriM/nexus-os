# Virtualização: KVM/QEMU com libvirt

Validação da F2.6: o `virsh` define e inicia uma VM de teste em `qemu:///system`. KVM/QEMU com libvirt é o VIM do Nexus OS.

Este documento foi escrito para quem **nunca viu o projeto**: cada passo diz **onde fazer**, **o que fazer**, **por que fazer**, **o que deve aparecer** e **o que fazer se não aparecer**. **O que é:** o **libvirt** é a camada que gerencia máquinas virtuais; o `virsh` é o comando dele; o **QEMU** é o programa que de fato roda a VM, com **KVM** (aceleração por hardware) quando o computador oferece `/dev/kvm`, ou em emulação por software (`virt-type qemu`, mais lenta) quando não oferece. **VIM** (*virtualized infrastructure manager*) é o gerenciador da infraestrutura virtual.

## Sumário

1. [Resultado](#resultado-22102026)
2. [Premissa 1 do TAP: VT-x/AMD-V](#premissa-1-do-tap-vt-xamd-v)
3. [Regras que valem o tempo todo](#regras-que-valem-o-tempo-todo)
4. [O que você precisa ter antes](#o-que-você-precisa-ter-antes)
5. [Passos](#passos)
6. [Com KVM no Hyper-V](#com-kvm-no-hyper-v-23102026)
7. [Na ISO (F3.3)](#na-iso-f33)
8. [Problemas conhecidos](#problemas-conhecidos)
9. [Como relatar uma falha](#como-relatar-uma-falha)

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

Medido em 22/10/2026 na VM de desenvolvimento no VirtualBox (sem KVM; a seção "Com KVM no Hyper-V" abaixo traz a medição de 23/10/2026):

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

## Regras que valem o tempo todo

1. **Faça só o que está escrito aqui** e confira o "Deve aparecer" de cada passo antes de seguir.
2. **Os comandos `virsh -c qemu:///system` usam `sudo`** na VM de build (o `user` da ISO está no grupo `libvirt` e dispensa o `sudo`).
3. **Limpe no fim** (`destroy` e `undefine`): uma VM de teste esquecida faz o passo seguinte falhar com "já existe".
4. **O repositório é público:** nunca cole em issue senha, chave, token ou dado pessoal.

## O que você precisa ter antes

| # | Item | Por quê | Como conseguir |
| --- | --- | --- | --- |
| 1 | Uma VM ou máquina **Debian 13** com `sudo` | O libvirt e o QEMU rodam nela | Veja [ambiente-de-build.md](ambiente-de-build.md) |
| 2 | O repositório clonado | O XML `nfv/libvirt/vm-teste.xml` e os testes estão nele | `git clone https://github.com/MixuriM/nexus-os.git` e `cd nexus-os` |
| 3 | Opcional: `/dev/kvm` | Sem ele a VM roda em emulação (lenta, mas funciona) | Veja a seção "Com KVM no Hyper-V" e [hyperv.md](hyperv.md) |

## Passos

**Onde:** na raiz do repositório, na VM Debian, num terminal.

### Passo 1: instalar o libvirt e conferir o serviço

**O que fazer:**

```bash
sudo apt install libvirt-daemon-system libvirt-clients qemu-system-x86
sudo systemctl is-active libvirtd
```

**Por quê:** instala o serviço do libvirt, o cliente `virsh` e o QEMU; o segundo comando confere que o serviço está rodando. **Deve aparecer:** `active`. **Se não aparecer:** `sudo systemctl start libvirtd` e confira de novo.

### Passo 2: definir e iniciar a VM de teste

**O que fazer:** sem KVM, o `type='qemu'` do XML já serve; com `/dev/kvm`, troque para `type='kvm'`.

```bash
sudo virsh -c qemu:///system define nfv/libvirt/vm-teste.xml
sudo virsh -c qemu:///system start nexus-vm-teste
sudo virsh -c qemu:///system list --all
```

**Por quê:** `define` registra o domínio `nexus-vm-teste` a partir do XML (128 MiB, 1 vCPU, sem disco); `start` o liga; `list --all` lista todos os domínios. **Deve aparecer:** o domínio `nexus-vm-teste` com estado `running`. **Se não aparecer:** `domain already exists` indica uma sobra: faça o passo 3 e repita; `Failed to connect to the hypervisor` indica que o `libvirtd` não está ativo (passo 1).

### Passo 3: remover a VM de teste

**O que fazer:**

```bash
sudo virsh -c qemu:///system destroy nexus-vm-teste
sudo virsh -c qemu:///system undefine nexus-vm-teste
```

**Por quê:** `destroy` desliga a VM (como puxar da tomada) e `undefine` apaga a definição. **Deve aparecer:** `Domain 'nexus-vm-teste' destroyed` e `Domain 'nexus-vm-teste' has been undefined` (ou as mensagens equivalentes em português).

### Passo 4: rodar o teste automatizado

O teste faz esse roteiro e a limpeza, e registra `vmx/svm` e `/dev/kvm`:

```bash
sudo tests/virtualizacao.sh
```

**Deve aparecer:** `OK: tests/virtualizacao.sh (virt-type qemu, domínio nexus-vm-teste running e removido)` (ou `virt-type kvm` com `/dev/kvm`), código 0. **Se não aparecer:** a mensagem `FALHA:` diz o que falhou; relate com ela.

## Com KVM no Hyper-V (23/10/2026)

Em uma VM Debian 13 de Geração 2 no Hyper-V (Windows 11 Pro, hypervisor ligado, 4 vCPU, 8 GB, `Set-VMProcessor -ExposeVirtualizationExtensions $true`), a premissa 1 se confirma: `egrep -c '(vmx|svm)' /proc/cpuinfo` retorna 4 e `/dev/kvm` existe (`crw-rw---- root kvm 10, 232`). A Microsoft documenta nested em AMD (Ryzen e EPYC) para host Windows 11 e VM de versão 9.3 ou mais nova. Medições, todas com KVM:

| Item | Resultado |
| --- | --- |
| `tests/iso.sh dist/ref-parte1.iso` (F2.4) | `OK: ISO chegou ao login ("debian login: ") em 21 s`, com KVM (sem KVM a Fase 2 mediu de 97 s a 827 s) |
| `sudo tests/virtualizacao.sh` (F2.6) | `OK: tests/virtualizacao.sh (virt-type kvm, domínio nexus-vm-teste running e removido)`, código 0 |
| `tests/iso-smoke.sh dist/ref-parte1.iso sdn` (F3.2), padrão do runner, 2 execuções | `OK` em 24 s e `OK` em 24 s, `sdn=5s` nas duas |
| Guest da ISO | `/dev/kvm` presente, 2 CPUs com `svm` e 2 módulos `kvm` (teste descartável por `--extra`) |
| `tests/iso-smoke.sh dist/nexus-os-poc-amd64.iso virtualizacao,libvirt` (F3.3) | `OK: 2 teste(s) sem falha em 24 s`, `virtualizacao=2s`, `libvirt=1s`; os dois usaram `virt-type kvm` dentro da ISO |

O Debian dessa VM estava em português, e o `tests/virtualizacao.sh` falhou: o `virsh` imprime `executando` e o teste esperava `running` (`FALHA: domínio nexus-vm-teste não está running (estado: executando)`). O `tests/virtualizacao.sh` e o `tests/libvirt.sh` agora rodam o `virsh` com `LC_ALL=C`, então funcionam em qualquer idioma. Com a correção o teste passou com o idioma padrão da VM (português) e com `LC_ALL=pt_BR.UTF-8`.

Como o smoke padrão (2 vCPU e 4096 MiB) passou duas vezes seguidas com KVM, o contorno `NEXUS_SMOKE_SMP=1` com 2048 MiB só é necessário na máquina sem KVM.

## Na ISO (F3.3)

A ISO já traz o libvirt pronto. Pacotes (`live-build/config/package-lists/nexus-virt.list.chroot`): `libvirt-daemon-system` e `libvirt-clients` 11.3.0-3+deb13u3, `qemu-system-x86` 1:10.0.13+ds-0+deb13u1. A rede `default` precisa de `dnsmasq-base` (2.91) e de `nftables` (1.1.3), que o `libvirt-daemon-driver-network` já puxa por dependência (`apt-cache depends`): nenhum pacote extra foi acrescentado. `qemu-utils` fica de fora porque nenhum script o usa.

- **Serviço:** `libvirtd.service`, habilitado no hook; o `Also=` dele ativa `libvirtd.socket`, `libvirtd-ro.socket` e `libvirtd-admin.socket`. A `nexus-smoke.service` roda depois dele.
- **Rede `default`:** o pacote cria a rede sem autostart, porque o postinst não consegue rodar o `virsh` no chroot. O hook cria o link `/etc/libvirt/qemu/networks/autostart/default.xml`, o mesmo efeito de `virsh net-autostart default`. No boot, `virsh net-list --all` mostra `default` ativa, com autostart (sem internet).
- **Grupo:** o usuário `user` (senha `live`, pública do Debian Live) entra no grupo `libvirt` por `LIVE_USER_DEFAULT_GROUPS` em `/etc/live/config.conf.d/nexus.conf`, que o live-config lê em `/usr/lib/live/init-config.sh`. O arquivo repete a lista padrão do live-config e acrescenta `libvirt`.
- **`nexus-vm`:** link em `/usr/local/bin` para `nfv/libvirt/nexus-vm.sh`. `nexus-vm criar <nome>` define e inicia a VM de `vm-teste.xml` com outro nome (nome `[a-z0-9-]`, sem hífen no início), `virt-type kvm` se existir `/dev/kvm` e `qemu` se não, sempre em `qemu:///system`; `nexus-vm listar`; `nexus-vm remover <nome>`.

**Como testar dentro da ISO** (veja [integracao-iso.md](integracao-iso.md)), na VM de build, sem rede e sem janela:

```bash
tests/iso-smoke.sh dist/nexus-os-poc-amd64.iso virtualizacao,libvirt
```

**Deve aparecer:** `OK: 2 teste(s) sem falha em <segundos> s`, com `virtualizacao=` e `libvirt=` nos tempos por teste. **Se não aparecer:** `FALHA: smoke com falhas: ... END com erro` indica o teste que falhou; relate com a linha.

**Para criar e remover uma VM à mão na ISO** (como `user`, sem `sudo`):

```bash
nexus-vm criar minha-vm
nexus-vm listar
nexus-vm remover minha-vm
```

**Deve aparecer:** `OK: VM minha-vm criada e iniciada (virt-type kvm)` (ou `qemu`), a VM `running` na listagem e `OK: VM minha-vm removida`. **Se não aparecer:** `FALHA: domínio minha-vm já existe` indica sobra: `nexus-vm remover minha-vm`.

`virtualizacao` roda o `tests/virtualizacao.sh` sem alteração. `libvirt` (`tests/libvirt.sh`) confere a rede `default`, o grupo e o ciclo `nexus-vm criar`, `list --all` com `running`, `nexus-vm remover`, domínio e processo QEMU ausentes. Só roda dentro da ISO (`boot=live` em `/proc/cmdline`).

Medições em 23/10/2026, sem KVM no hospedeiro (QEMU em emulação por software, 1 vCPU e 2048 MiB): `OK: 2 teste(s) sem falha em 156 s`, `virtualizacao=23s`, `libvirt=7s`.

O guest da ISO enxerga `/dev/kvm` (`crw-rw---- root kvm 10, 232`), tem `kvm` e `kvm_amd` carregados e 1 CPU com `svm`, mesmo com o hospedeiro em emulação. Por isso os dois testes usaram `virt-type kvm` (saída `OK: tests/virtualizacao.sh (virt-type kvm ...)` e `OK: VM smoke1 criada e iniciada (virt-type kvm)`). Sem KVM no hospedeiro, o QEMU emula o `svm` do guest e o KVM aninhado fica lento sobre emulação. Com KVM no hospedeiro (Hyper-V), o ciclo `virtualizacao` levou 2 s e `libvirt` 1 s, três níveis de virtualização.

## Problemas conhecidos

- **KVM aninhado derruba o VirtualBox (AMD).** Em 23/10/2026, com o hypervisor do Windows desligado e `--nested-hw-virt on`, a VM de build ganhou `/dev/kvm` e `svm`. Quando o QEMU interno usou KVM, o VirtualBox 7.2.20 abortou a VM com `Guru Meditation -4060 (VERR_SVM_UNKNOWN_EXIT)` (`VBox.log`). Aconteceu duas vezes: `tests/iso.sh` com 2 vCPU e 1024 MiB, e o smoke `sdn` com 1 vCPU e 2048 MiB. O changelog oficial da série 7.2 que conseguimos ler (até a 7.2.6) não cita correção de nested em AMD. No VirtualBox, a revalidação com KVM não pôde ser feita. O mesmo notebook, com o hypervisor do Windows ligado e a VM no Hyper-V, passou em tudo (seção "Com KVM no Hyper-V"). A VM de build do VirtualBox roda sem os módulos `kvm` (`/etc/modprobe.d/nexus-sem-kvm.conf`, só na VM, fora do repositório). Ainda não testamos versão mais nova do VirtualBox nem WSL2. Para validar com KVM, use o Hyper-V; o VirtualBox fica em emulação.
- Sem `/dev/kvm`, a VM roda em emulação por software. Serve para provar criar e iniciar, não para medir desempenho.
- A VM de teste não tem disco nem sistema: o QEMU inicia e fica tentando boot. O teste prova só que o domínio é definido e entra em `running`.
- O teste valida `qemu:///system` com root. Para usar `virsh` sem `sudo`, o usuário precisa estar no grupo `libvirt` (a mudança vale a partir do próximo login).
- Desligar o Hyper-V do Windows (para liberar o VT-x ao VirtualBox) afeta o WSL2 e o Docker Desktop do host. A decisão é do dono da máquina e não foi tomada.

## Como relatar uma falha

**Quando:** para cada falha que se repete, para qualquer erro de comando deste documento e para tudo que ele não explicou. **Onde:** uma **issue** no repositório no GitHub. **Título:** `<tarefa>: <passo>: <resumo curto>`. **Corpo:** **Passos** (comandos exatos), **Saída** (texto exato copiado e colado), **Esperado** (o que o documento dizia) e **Ambiente** (Debian, versão do libvirt e do QEMU, com ou sem `/dev/kvm`, commit). Uma issue por falha, sem dado pessoal.
