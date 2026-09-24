# Nexus OS

Distro Linux remasterizada (Debian estável, live-build) para virtualização de redes. Projeto Integrador acadêmico.

## Stack (travada, não questionar)
- Controlador SDN: OpenDaylight via OpenFlow, com Open vSwitch
- VIM: KVM/QEMU + libvirt
- VNF de exemplo: FRRouting
- NFVO/VNFM: simplificado (scripts/Ansible)
- Demonstração: Containerlab (principal) e GNS3 (secundário)

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
Ainda não existem, a preencher.
