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

- `docs/`: documentação técnica ([índice](docs/README.md))
- `live-build/`: configuração da ISO (receita em `auto/` e `config/`)
- `sdn/`: laboratório Open vSwitch com regras OpenFlow manuais (`lab-ovs.sh`, `flows/`)
- `nfv/`: VM de teste do libvirt (`libvirt/vm-teste.xml`)
- `ansible/`: scripts e playbooks de orquestração (sem conteúdo ainda)
- `labs/containerlab/`: topologia com dois nós FRR e OSPF. `labs/gns3/`: sem conteúdo ainda
- `scripts/`: build da ISO (`build-iso.sh`) e sincronização das branches (`sync-branches.sh`)
- `tests/`: testes da ISO e dos componentes ([lista](tests/README.md))

## Como gerar a ISO

Exige Linux (VM Debian 13), usuário com `sudo`, Docker, internet e espaço livre: o build limpo ocupou 5383 MiB (medido em 26/10/2026, veja [docs/rc1.md](docs/rc1.md)).
Preparo da VM: [docs/ambiente-de-build.md](docs/ambiente-de-build.md). Resultado esperado e medições: [docs/iso-poc.md](docs/iso-poc.md).

1. Clone o repositório no disco do Linux (nunca em pasta compartilhada com o Windows nem em `/mnt/*`):

   ```
   git clone https://github.com/MixuriM/nexus-os.git
   cd nexus-os
   ```

2. Gere a ISO (516 s medidos com KVM na VM do Hyper-V; o log fica em `live-build/build.log`):

   ```
   sudo scripts/build-iso.sh
   ```

   A saída são `dist/nexus-os-poc-amd64.iso` e `dist/nexus-os-poc-amd64.iso.sha256`. Esses arquivos não vão para o Git.

3. Teste a ISO (confere o SHA256 e inicia a ISO no QEMU até aparecer `login:`):

   ```
   tests/iso.sh dist/nexus-os-poc-amd64.iso
   ```

4. Antes de commitar, rode `tests/lint-repo.sh`.

## Usar a ISO integrada

A RC1 (núcleo, sem ambiente gráfico) está descrita em [docs/rc1.md](docs/rc1.md).

1. Inicie a ISO numa VM (testado: QEMU com KVM; o Hyper-V está descrito em [docs/rc1.md](docs/rc1.md)) com pelo menos **1536 MiB de RAM** e a ISO como CD. Os números medidos estão em [docs/requisitos.md](docs/requisitos.md). Na tela do isolinux, aperte Enter.
2. Entre com o usuário `user` e a senha `live` (credencial pública da Debian Live, de laboratório). O `sudo` não pede senha.
3. Comandos disponíveis (com `sudo`; o `nexus-vm` também funciona sem ele para quem está no grupo `libvirt`, como o `user`):
   - `nexus-sdn up|flows|down`: laboratório Open vSwitch com regras OpenFlow manuais ([docs/sdn.md](docs/sdn.md)).
   - `nexus-vm criar <nome>|listar|remover <nome>`: VMs de teste do libvirt ([docs/virtualizacao.md](docs/virtualizacao.md)).
   - `nexus-vnf up|status|down`: ciclo da VNF FRR sobre o Containerlab ([docs/nfv.md](docs/nfv.md)). A topologia de dois nós: `sudo containerlab deploy -t /usr/share/nexus-os/labs/containerlab/frr-duo.clab.yml`.
   - `nexus-smoke <nome>|all`: smoke tests dos componentes dentro da ISO, com medição de RAM e disco ([docs/integracao-iso.md](docs/integracao-iso.md)).

## Testes dos componentes

Na VM Debian, depois de gerar a ISO, `tests/run-fase2.sh dist/nexus-os-poc-amd64.iso` roda em ordem a verificação do repositório, o boot da ISO e os laboratórios de Open vSwitch, libvirt e FRR com Containerlab, e para no primeiro erro.
Cada laboratório tem o seu guia: [SDN](docs/sdn.md), [virtualização](docs/virtualizacao.md) e [NFV](docs/nfv.md). Para quem vai testar a documentação do zero: [checklist](docs/checklist-teste-documentacao.md).

## Fluxo de trabalho

Branches, PRs e revisão: [docs/fluxo-de-trabalho.md](docs/fluxo-de-trabalho.md).

Integrantes abrem PR somente para a `marcos`, nunca direto para a `main`. Só o revisor final faz merge, e os PRs entram com "Rebase and merge" (histórico linear). Depois de cada merge, o revisor final roda `scripts/sync-branches.sh` para alinhar a `marcos` e as branches pessoais com a `main`.
Cada integrante atualiza a própria branch com:

```
git fetch origin
git switch <sua-branch>
git merge --no-edit origin/main
```

## Aviso: build exige Linux

O live-build deve ser executado em Debian/Ubuntu, com root e sistema de arquivos Linux. Não builde em pasta Windows.
Veja [docs/ambiente-de-build.md](docs/ambiente-de-build.md).

Licenciado sob GPL-3.0-or-later.

Projeto Integrador acadêmico, em desenvolvimento.
