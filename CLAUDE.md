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
- Libvirt dentro da ISO (F3.3): `tests/iso-smoke.sh dist/nexus-os-poc-amd64.iso virtualizacao,libvirt`; na ISO, `nexus-vm criar|listar|remover`
- Docker e imagens offline na ISO (F3.4): `tests/iso-smoke.sh dist/nexus-os-poc-amd64.iso containers`; o build precisa de Docker e internet na VM (`scripts/prepare-offline.sh`, veja `docs/containers.md`)
- Smoke test dentro da ISO: `tests/iso-smoke.sh dist/nexus-os-poc-amd64.iso sdn` (QEMU sem rede; veja `docs/integracao-iso.md`)
- FRR e Containerlab dentro da ISO (F3.5 e F3.7): `tests/iso-smoke.sh dist/nexus-os-poc-amd64.iso frr,nfv`; na ISO, `sudo containerlab deploy -t /usr/share/nexus-os/labs/containerlab/frr-duo.clab.yml`; o build baixa o `.deb` do Containerlab (SHA256 em `live-build/offline/containerlab.sha256`, veja `docs/nfv.md`)
- Orquestração da VNF FRR (F3.6): `sudo tests/orquestracao.sh` (precisa de Docker e Containerlab); na ISO, `sudo nexus-vnf up|status|down` e `tests/iso-smoke.sh dist/nexus-os-poc-amd64.iso orquestracao`
- Requisitos de hardware e RC1 (F3.9 e F3.11): `tests/requisitos.sh` (estático, roda também no Git Bash); a RAM e o disco da ISO saem do `OK:` do `tests/iso-smoke.sh dist/nexus-os-poc-amd64.iso all` (veja `docs/requisitos.md` e `docs/rc1.md`)
- Todos os testes da Fase 2 em ordem (para no primeiro erro): `tests/run-fase2.sh [iso]`
- Documentação (F3.8 e F3.12): `tests/docs.sh` (estático, roda também no Git Bash); manual executado dentro da ISO: `tests/manual.sh dist/nexus-os-rc1-amd64.iso`; manual em `docs/manual.md`, GNS3 em `docs/gns3.md`
- Ambiente gráfico (F3.14, desktop XFCE com `lightdm`, já instalado na ISO pela F3.15): `tests/gui-spec.sh` (estático, roda também no Git Bash); documento em `docs/gui.md`
- Desktop na ISO e atalhos (F3.15 e F3.16): `tests/atalhos.sh` (estático, roda também no Git Bash; `desktop-file-validate` só na VM com `desktop-file-utils`); `tests/iso-smoke.sh dist/nexus-os-poc-amd64.iso desktop` (o `all` já o roda por último); sem KVM, `NEXUS_SMOKE_KVM=0 NEXUS_SMOKE_SMP=1 NEXUS_SMOKE_MEM=2048`; `tests/iso.sh` usa `NEXUS_ISO_MEM` (padrão 2048); o smoke anexa um disquete vazio (como o Hyper-V Geração 1), `NEXUS_SMOKE_FLOPPY=0` o dispensa (padrão 1)
- Identidade visual (F3.17): `tests/identidade.sh` (estático, roda também no Git Bash); gerar as imagens: `python3 scripts/gerar-identidade.py` (na VM, precisa de `librsvg2-bin`); documento em `docs/branding.md`
- Barra, programas, idioma e boot (rodada 3 da RC2, F3.17): `docs/gui.md` ("Barra, tema de ícones e idioma" e "Programas incluídos"); tema de ícones `Nexus` e menu de boot (`live-build/config/bootloaders/`) saem do `scripts/gerar-identidade.py`; documentação em HTML offline: `nexus-docs-html docs /tmp/docs-html` (precisa de `python3-markdown`)
- RC2 (F3.18): `docs/rc2.md`; requisitos com desktop em `docs/requisitos.md`, seção "Com ambiente gráfico"; roteiro humano na parte H de `docs/checklist-teste-documentacao.md`
- Todos os testes da Fase 3 em ordem (para no primeiro erro): `tests/run-fase3.sh [iso]`
- Desktop (F3.15 e F3.16): os atalhos `nexus-*.desktop` ficam em `live-build/config/includes.chroot/usr/share/applications/` e a cópia idêntica em `.../etc/skel/Desktop/` (o `tests/atalhos.sh` exige as duas); arquivos com LF, comando de terminal sempre pelo `nexus-atalho`; o smoke `desktop` precisa de VM com vídeo (`-vga std`)
