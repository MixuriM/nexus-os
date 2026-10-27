# Manual v1 do Nexus OS (RC1, núcleo sem desktop)

Manual de instalação, boot e uso de cada componente da ISO. Cobre o núcleo da RC1; a seção do ambiente gráfico entra com a RC2.
Os blocos marcados `bash nexus-exec` são executados por `tests/manual.sh` dentro da ISO, sem rede, em ordem, e cada um limpa o que criou. Os demais blocos são exemplos que o teste não executa.
Roteiro para quem vai executar o manual do zero: [checklist-teste-documentacao.md](checklist-teste-documentacao.md), parte "Manual v1 por componente".

## Visão geral

O Nexus OS é uma remasterização do Debian 13 (trixie) gerada com live-build. A ISO é *live*: roda na memória, sem instalar nada no disco. Traz, já instalados e testados, os componentes para laboratórios de redes definidas por software (SDN) e de virtualização de funções de rede (NFV).

| Componente | Comando | Seção |
| --- | --- | --- |
| Open vSwitch (SDN) | `nexus-sdn up\|flows\|down` | Open vSwitch (nexus-sdn) |
| KVM/QEMU e libvirt (VIM) | `nexus-vm criar\|listar\|remover` | libvirt (nexus-vm) |
| Docker e imagem FRR offline | `docker` | Contêineres e imagens offline |
| FRRouting (VNF) | `vtysh` | FRRouting |
| Containerlab | `containerlab deploy\|destroy` | Containerlab |
| Orquestração NFVO/VNFM simplificada | `nexus-vnf up\|status\|down` | Orquestração (nexus-vnf) |
| Testes dentro da ISO | `nexus-smoke <nome>\|all` | Testes (nexus-smoke) |

Fora da RC1: ambiente gráfico (RC2), OpenDaylight (opcional, trabalho futuro) e GNS3, que só é documentado e não entra na ISO ([gns3.md](gns3.md)). Arquitetura: [README.md](../README.md).

## Gerar a ISO

A ISO só se constrói em Linux (VM Debian 13), com `sudo`, Docker e internet. Passo a passo, tempo e espaço em disco: seção "Como gerar a ISO" do [README.md](../README.md) e [ambiente-de-build.md](ambiente-de-build.md). Em resumo, na raiz do repositório clonado na VM:

```bash
sudo scripts/build-iso.sh
tests/iso.sh dist/nexus-os-poc-amd64.iso
```

O build gera `dist/nexus-os-poc-amd64.iso` e o `.sha256`. A RC1 validada é a cópia `dist/nexus-os-rc1-amd64.iso` (identificação e SHA256 em [rc1.md](rc1.md)). A ISO e o `.sha256` não vão para o Git.

## Iniciar a ISO

Use pelo menos **1536 MiB de RAM** ([requisitos.md](requisitos.md)). A ISO tem boot BIOS (isolinux), então no Hyper-V use VM de Geração 1. Na tela do isolinux, aperte Enter.

**QEMU no Linux** (com KVM se `/dev/kvm` existir; sem `-enable-kvm -cpu host` a emulação por software é bem mais lenta):

```bash
qemu-system-x86_64 -enable-kvm -cpu host -m 2048 -smp 2 -cdrom dist/nexus-os-rc1-amd64.iso -boot d
```

Os testes do repositório usam estas mesmas opções com `-display none` e a serial em arquivo (`tests/iso.sh` e `tests/iso-smoke.sh`). A janela do QEMU não foi exercitada nesta versão do manual.

**Hyper-V no Windows** (PowerShell como administrador; ISO copiada para `C:\HyperV`, fora do repositório). Procedimento validado em [rc1.md](rc1.md), seção "Boot no Hyper-V":

```powershell
$vm = "nexus-rc1-lab"
New-VM -Name $vm -Generation 1 -MemoryStartupBytes 4096MB -BootDevice CD -NoVHD
Set-VMProcessor -VMName $vm -Count 2
Set-VMMemory -VMName $vm -DynamicMemoryEnabled $false -StartupBytes 4096MB
Add-VMDvdDrive -VMName $vm -Path "C:\HyperV\nexus-os-rc1-amd64.iso"
Start-VM -Name $vm
vmconnect.exe localhost $vm
```

Essa VM nasce sem rede e sem KVM. Para a VM de build com KVM, veja [hyperv.md](hyperv.md). O VirtualBox serve só como VM sem KVM: em CPU AMD o KVM aninhado derruba a VM (issue 25).

## Login de laboratório

A sessão do usuário `user` abre sozinha no console. Se pedir login: usuário `user`, senha `live` (credencial pública da Debian Live, de laboratório). O `sudo` não pede senha e `user` está no grupo `libvirt`. Não há hardening de produção.

Confira o sistema e os comandos do Nexus OS:

```bash nexus-exec
grep -qw 'boot=live' /proc/cmdline
cat /etc/debian_version
for c in nexus-sdn nexus-vm nexus-vnf nexus-smoke containerlab docker vtysh virsh ovs-vsctl; do
    command -v "$c" >/dev/null || { echo "FALHA: comando ausente: $c"; exit 1; }
done
ls /usr/share/nexus-os
```

Saída esperada: a versão do Debian (começa com 13) e a lista `docs labs nfv sdn tests` em `/usr/share/nexus-os`.

## Open vSwitch (nexus-sdn)

Bridge `br-nexus` em modo `secure`, sem controlador, e dois namespaces (`h1` e `h2`). Sem as regras de `sdn/flows/basico.flows` a bridge descarta tudo. Detalhes: [sdn.md](sdn.md).

```bash nexus-exec
sudo nexus-sdn up
sudo ovs-vsctl get-fail-mode br-nexus
sudo ovs-ofctl dump-flows br-nexus
sudo ip netns exec h1 ping -c 2 192.0.2.2
sudo ovs-ofctl del-flows br-nexus
if sudo ip netns exec h1 ping -c 2 -W 2 192.0.2.2 >/dev/null 2>&1; then
    echo "FALHA: o ping passou sem as regras"
    exit 1
fi
sudo nexus-sdn flows
sudo ip netns exec h1 ping -c 2 192.0.2.2
sudo nexus-sdn down
```

Saída esperada: `secure`, quatro regras no `dump-flows`, `0% packet loss` no primeiro e no último ping e perda total com as regras removidas.

## libvirt (nexus-vm)

O `nexus-vm` define e inicia uma VM de teste (128 MiB, sem disco) em `qemu:///system`. Usa `virt-type kvm` se existir `/dev/kvm` e `qemu` (emulação) se não. Detalhes: [virtualizacao.md](virtualizacao.md).

```bash nexus-exec
nexus-vm criar manual1
nexus-vm listar
estado=$(LC_ALL=C virsh -c qemu:///system domstate manual1)
echo "estado: $estado"
[ "$estado" = running ]
nexus-vm remover manual1
if LC_ALL=C virsh -c qemu:///system dominfo manual1 >/dev/null 2>&1; then
    echo "FALHA: manual1 ainda existe"
    exit 1
fi
```

Saída esperada: `OK: VM manual1 criada e iniciada (virt-type kvm)` (ou `qemu`), a VM `running` na listagem e `OK: VM manual1 removida`.

## Contêineres e imagens offline

A ISO traz o Docker e a imagem `quay.io/frrouting/frr:10.7.1` dentro dela. No boot, o `nexus-images.service` carrega a imagem sem rede. Os dados do Docker ficam em memória e somem a cada boot. Detalhes: [containers.md](containers.md).

```bash nexus-exec
sudo systemctl is-active nexus-images.service
driver=$(sudo docker info --format '{{.Driver}}')
echo "driver: $driver"
[ "$driver" = overlay2 ]
sudo docker image inspect quay.io/frrouting/frr:10.7.1 --format '{{.Id}}'
versao=$(sudo docker run --rm --network none --entrypoint /usr/lib/frr/zebra quay.io/frrouting/frr:10.7.1 --version)
echo "$versao"
[[ $versao == *10.7.1* ]]
```

Saída esperada: `active`, `overlay2`, o identificador da imagem e `zebra version 10.7.1_git`.

## FRRouting

A ISO traz o pacote `frr` do Debian, com o serviço habilitado. O pacote vem com o `ospfd` desligado; a configuração de exemplo (`/usr/share/nexus-os/nfv/frr/exemplo`) liga o `ospfd` e anuncia o loopback 198.51.100.10/32 na área 0 do OSPF. O bloco abaixo aplica o exemplo e restaura os arquivos originais no fim. Detalhes: [nfv.md](nfv.md).

```bash nexus-exec
versao=$(sudo vtysh -c 'show version')
echo "${versao%%$'\n'*}"
[[ $versao == FRRouting* ]]
copia=$(mktemp -d)
sudo cp -a /etc/frr/daemons /etc/frr/frr.conf "$copia/"
exemplo=/usr/share/nexus-os/nfv/frr/exemplo
sudo install -m 0640 -o frr -g frr "$exemplo/daemons" /etc/frr/daemons
sudo install -m 0640 -o frr -g frr "$exemplo/frr.conf" /etc/frr/frr.conf
sudo systemctl restart frr
ok=nao
for i in $(seq 1 30); do
    conf=$(sudo vtysh -c 'show running-config' 2>/dev/null || true)
    if [[ $conf == *"ip address 198.51.100.10/32"* && $conf == *"router ospf"* ]]; then ok=sim; break; fi
    sleep 2
done
echo "exemplo aplicado: $ok"
sudo cp -a "$copia/daemons" "$copia/frr.conf" /etc/frr/
sudo systemctl restart frr
rm -rf "$copia"
[ "$ok" = sim ]
```

Saída esperada: `FRRouting 10.3` na primeira linha e `exemplo aplicado: sim`.

## Containerlab

Um comando sobe a topologia de demonstração: dois nós FRR (`r1` e `r2`, imagem já na ISO) trocando rotas por OSPF. O Containerlab precisa de root. Sem rede, o `deploy` imprime `Failed fetching latest version information`, que não afeta o resultado. O `vtysh` imprime o aviso `Can't open configuration file /etc/frr/vtysh.conf`, também inofensivo. Detalhes: [nfv.md](nfv.md).

```bash nexus-exec
topo=/usr/share/nexus-os/labs/containerlab/frr-duo.clab.yml
sudo containerlab deploy -t "$topo"
r1=nao
r2=nao
for i in $(seq 1 40); do
    rotas1=$(sudo docker exec clab-frr-duo-r1 vtysh -c 'show ip route ospf' 2>/dev/null || true)
    rotas2=$(sudo docker exec clab-frr-duo-r2 vtysh -c 'show ip route ospf' 2>/dev/null || true)
    [[ $rotas1 == *198.51.100.2/32* ]] && r1=sim
    [[ $rotas2 == *198.51.100.1/32* ]] && r2=sim
    if [ "$r1" = sim ] && [ "$r2" = sim ]; then break; fi
    sleep 3
done
echo "$rotas1"
echo "$rotas2"
sudo containerlab destroy -t "$topo" --cleanup
[ "$r1" = sim ] && [ "$r2" = sim ]
```

Saída esperada: `O>* 198.51.100.2/32` em `r1` e `O>* 198.51.100.1/32` em `r2`. A convergência levou de 12 s a 16 s nas medições.

## Orquestração (nexus-vnf)

O `nexus-vnf` é o NFVO/VNFM simplificado: instancia a VNF FRR (nó `vnf1`, Containerlab com contêiner FRR), consulta o estado e remove. `up` e `down` podem ser repetidos sem efeito colateral. Detalhes: [nfv.md](nfv.md).

```bash nexus-exec
sudo nexus-vnf up
sudo nexus-vnf status
sudo nexus-vnf down
if sudo nexus-vnf status >/dev/null 2>&1; then
    echo "FALHA: status devia sair com 1 depois do down"
    exit 1
fi
```

Saída esperada: `OK: VNF vnf1 rodando` no `status` com a VNF no ar, e código de saída 1 no `status` depois do `down`.

## Testes (nexus-smoke)

O `nexus-smoke` roda dentro da ISO os testes de `/usr/share/nexus-os/tests`, na ordem de `smoke.list`, e imprime a RAM usada. Só root.

```bash
sudo nexus-smoke all > /tmp/smoke.txt 2>&1
grep -a -e NEXUS-SMOKE-END -e NEXUS-SMOKE-DONE -e NEXUS-SMOKE-MEMPEAK /tmp/smoke.txt
```

Saída esperada: sete linhas `NEXUS-SMOKE-END <nome> 0` e `NEXUS-SMOKE-DONE 7 0`. Este bloco não é executado por `tests/manual.sh`, porque o teste do manual já roda dentro do `nexus-smoke`. O bloco abaixo confere que o runner e a lista existem:

```bash nexus-exec
test -x /usr/local/bin/nexus-smoke
[ "$(wc -l < /usr/share/nexus-os/tests/smoke.list)" -eq 7 ]
grep -qx orquestracao /usr/share/nexus-os/tests/smoke.list
```

Para rodar os smokes de fora, na VM de build, sem rede: `tests/iso-smoke.sh dist/nexus-os-rc1-amd64.iso all` ([integracao-iso.md](integracao-iso.md)).

## Requisitos

RAM recomendada 1536 MiB, mínimo de 896 MiB para o Docker carregar a imagem FRR; disco do guest não é usado (a live roda na memória). Tabela medida e método: [requisitos.md](requisitos.md).

## Solução de problemas

| Sintoma | Causa | Correção |
| --- | --- | --- |
| Boot muito lento | Sem `/dev/kvm` o QEMU emula a CPU | Use um host com KVM (Hyper-V com virtualização aninhada, [hyperv.md](hyperv.md)); sem KVM, espere mais |
| `docker image ls` vazio logo após o boot | O `nexus-images.service` ainda carrega a imagem (poucos segundos) | `sudo systemctl status nexus-images.service`; espere ficar `active` |
| `docker load` falha por falta de espaço | Menos de cerca de 896 MiB de RAM; o Docker usa tmpfs (issue 31) | Dê 1536 MiB ou mais à VM |
| `Failed fetching latest version information` no `containerlab deploy` | Sem rede, o Containerlab não consulta a versão | Ignore: a topologia sobe normalmente |
| `Can't open configuration file /etc/frr/vtysh.conf` | Aviso do `vtysh` | Ignore: a configuração está aplicada |
| `show ip route ospf` sem rotas logo depois do `deploy` | O OSPF leva alguns segundos para convergir | Repita o comando depois de 15 s |
| Ping entre `h1` e `h2` falha | As regras OpenFlow foram removidas (modo `secure`) | `sudo nexus-sdn flows` recarrega as regras |
| `nexus-smoke libvirt` falhou uma vez (`domínio smoke1 nao existe`) | Falha intermitente conhecida, causa não confirmada (issue 35) | Rode o teste de novo e registre a ocorrência |
| Ao desligar, a live pede ENTER | Comportamento da live (issue 34) | Aperte Enter no console |
| Sobrou laboratório depois de uma falha | Um comando parou no meio | `sudo nexus-sdn down`, `nexus-vm remover <nome>`, `sudo nexus-vnf down`, `sudo containerlab destroy -t <topologia> --cleanup` |

## Verificação

Na VM de build, sem rede e fora do manual:

```bash
tests/docs.sh
tests/manual.sh dist/nexus-os-rc1-amd64.iso
```

Saída esperada: `OK: tests/docs.sh ...` e `OK: tests/manual.sh ...` (com o número de blocos executados dentro da ISO e o modo, com ou sem KVM). Cada falha ou limitação encontrada ao seguir o manual vira uma issue ([checklist-teste-documentacao.md](checklist-teste-documentacao.md), parte E).
