# Nexus OS

Distro Linux baseada em Debian 13 (trixie), especializada em virtualização de redes (SDN/NFV).
É uma remasterização gerada com live-build, não uma distro construída do zero.

## Versões confirmadas (21/10/2026)

- Debian 13 (trixie), versão pontual 13.7
- live-build 20250505+deb13u1 (`lb --version`)
- Open vSwitch 3.5.0-1+b1 (pacote `openvswitch-switch` no trixie/main)

Como foram medidas: [docs/ambiente-de-build.md](docs/ambiente-de-build.md).

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
- `scripts/`: comando único de build da ISO
- `tests/`: testes

## Como gerar a ISO

Exige Linux (VM Debian 13), usuário com `sudo`, cerca de 10 GB livres e internet.
Preparo da VM: [docs/ambiente-de-build.md](docs/ambiente-de-build.md). Resultado esperado e medições: [docs/iso-poc.md](docs/iso-poc.md).

1. Clone o repositório no disco do Linux (nunca em pasta compartilhada com o Windows nem em `/mnt/*`):

   ```
   git clone https://github.com/MixuriM/nexus-os.git
   cd nexus-os
   ```

2. Gere a ISO (leva cerca de 25 minutos; o log fica em `live-build/build.log`):

   ```
   sudo scripts/build-iso.sh
   ```

   A saída são `dist/nexus-os-poc-amd64.iso` e `dist/nexus-os-poc-amd64.iso.sha256`. Esses arquivos não vão para o Git.

3. Teste a ISO (confere o SHA256 e inicia a ISO no QEMU até aparecer `login:`):

   ```
   tests/iso.sh dist/nexus-os-poc-amd64.iso
   ```

4. Antes de commitar, rode `tests/lint-repo.sh`.

## Aviso: build exige Linux

O live-build deve ser executado em Debian/Ubuntu, com root e sistema de arquivos Linux. Não builde em pasta Windows.
Veja [docs/ambiente-de-build.md](docs/ambiente-de-build.md).

Licenciado sob GPL-3.0-or-later.

Projeto Integrador acadêmico, em desenvolvimento.
