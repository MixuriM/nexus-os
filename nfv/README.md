# NFV

KVM/QEMU + libvirt como VIM, FRRouting como VNF de exemplo.
Orquestração NFVO/VNFM representada de forma simplificada.

- `libvirt/vm-teste.xml`: domínio de teste do `virsh` (sem disco, 128 MiB).

Status: libvirt validado em VM Debian 13, em emulação por software (F2.6). Passos em [docs/virtualizacao.md](../docs/virtualizacao.md). Teste: `sudo tests/virtualizacao.sh`.
O FRRouting com Containerlab foi validado em [labs/containerlab/](../labs/containerlab/README.md) (F2.7). Passos em [docs/nfv.md](../docs/nfv.md). Teste: `sudo tests/nfv.sh`.
