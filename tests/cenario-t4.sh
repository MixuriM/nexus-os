#!/usr/bin/env bash
# Cenário T4 (F4.2d): KVM e libvirt pelo nexus-vm dentro da ISO, em 3 ciclos seguidos.
# O script do convidado é tests/cenarios-guest/t4.sh; os critérios estão em docs/plano-de-testes.md.
# Uso: tests/cenario-t4.sh <iso>   (na VM de build; precisa de qemu-system-x86 e xorriso)
set -uo pipefail

raiz=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=/dev/null
. "$raiz/tests/lib-cenario.sh"

cen_init T4 "${1:-}"
cen_convidado "$CEN_GUEST" t4 || cen_fim FALHA "o convidado falhou: veja a saída em evidencias/T4"
cen_fim OK "nexus-vm criar, listar e remover em 3 ciclos"
