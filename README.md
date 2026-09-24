# Nexus OS

Distro Linux baseada em Debian 13 (trixie), especializada em virtualização de redes (SDN/NFV).
É uma remasterização gerada com live-build, não uma distro construída do zero.

## Stack

- Controlador SDN: OpenDaylight, via OpenFlow, com Open vSwitch
- VIM: KVM/QEMU + libvirt
- VNF de exemplo: FRRouting
- Orquestração NFVO/VNFM: representada de forma simplificada (scripts/Ansible)
- Topologia de demonstração: Containerlab (principal) e GNS3 (secundário)

## Estrutura

- `docs/`: documentação técnica
- `live-build/`: configuração da ISO (a ser gerada em Linux)
- `sdn/`: OpenDaylight, OpenFlow, Open vSwitch
- `nfv/`: KVM/QEMU + libvirt, FRRouting, NFVO/VNFM simplificado
- `ansible/`: scripts e playbooks de orquestração
- `labs/containerlab/` e `labs/gns3/`: topologias de demonstração
- `tests/`: testes

## Aviso: build exige Linux

O live-build só roda em Debian/Ubuntu, com root e sistema de arquivos Linux. Não builde em pasta Windows.
Veja [docs/ambiente-de-build.md](docs/ambiente-de-build.md).

Licenciado sob GPL-3.0-or-later.

Projeto Integrador acadêmico, em desenvolvimento.
