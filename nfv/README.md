# NFV

KVM/QEMU + libvirt como VIM, FRRouting como VNF de exemplo.
Orquestração NFVO/VNFM representada de forma simplificada.

- `libvirt/vm-teste.xml`: domínio de teste do `virsh` (sem disco, 128 MiB).
- `frr/exemplo/`: `daemons` e `frr.conf` de exemplo do FRR do pacote (roteador `ex1`, loopback 198.51.100.10/32 em OSPF área 0), aplicados pelo smoke `frr`.

Status: libvirt validado em VM Debian 13, em emulação por software (F2.6). Passos em [docs/virtualizacao.md](../docs/virtualizacao.md). Teste: `sudo tests/virtualizacao.sh`.
O FRRouting com Containerlab foi validado em [labs/containerlab/](../labs/containerlab/README.md) (F2.7). Passos em [docs/nfv.md](../docs/nfv.md). Teste: `sudo tests/nfv.sh`.
Na ISO (F3.5 e F3.7): pacote `frr` e Containerlab 0.81.1 incluídos, smokes `frr` e `nfv` passam com KVM e sem rede (seção "Na ISO" de [docs/nfv.md](../docs/nfv.md)). Topologia na ISO: `sudo containerlab deploy -t /usr/share/nexus-os/labs/containerlab/frr-duo.clab.yml`. Reprodução por segunda pessoa pendente.
