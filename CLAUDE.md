# Nexus OS

Distro Linux remasterizada (Debian estável, live-build) para virtualização de redes. Projeto Integrador acadêmico.

## Stack (travada, não questionar)
- Controlador SDN: OpenDaylight via OpenFlow, com Open vSwitch
- VIM: KVM/QEMU + libvirt
- VNF de exemplo: FRRouting
- NFVO/VNFM: simplificado (scripts/Ansible)
- Demonstração: Containerlab (principal) e GNS3 (secundário)

Escopo em revisão: OpenDaylight opcional, GNS3 só documentado, Ansible fora (aguardando aprovação). Ver plano de desenvolvimento.

## Regras
- Build da ISO só em Linux (VM Debian ou WSL2 em ext4), nunca em pasta Windows nem em /mnt/c.
- Arquivos sempre com LF.
- Repo público: nunca commitar segredo, chave, credencial nem dado pessoal (equipe, professor, empresas).
- Documentação em português do Brasil. Sem travessão (em dash): use vírgula ou dois-pontos.
- Uso de IA da disciplina: a redação de metodologia, resultados e conclusão do relatório é humana e não deve ser gerada por IA. Este repo não contém o relatório.
- Sempre pedir confirmação a Marcos antes de qualquer comando git ou gh que altere estado.
- Não criar configuração do live-build (auto/, config/, hooks/) no Windows: gerar com `lb config` em Linux.
- Não inventar conteúdo técnico, comandos nem versões.

## Comandos
Em Linux (VM Debian 13), na raiz do repo:
- Gerar a ISO: `sudo scripts/build-iso.sh` (saída em `dist/`, log em `live-build/build.log`)
- Testar a ISO: `tests/iso.sh dist/nexus-os-poc-amd64.iso`
- Verificação estática do repo (roda também no Git Bash): `tests/lint-repo.sh`
- Laboratório Open vSwitch (F2.5): `sudo tests/sdn.sh`
- Libvirt com `virsh` (F2.6): `sudo tests/virtualizacao.sh`
- FRR com Containerlab (F2.7): `sudo tests/nfv.sh` (precisa de Docker e Containerlab)
