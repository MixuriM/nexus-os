#!/usr/bin/env bash
# Cenário T3 (F4.2c): ciclo de vida da VNF FRR pelo nexus-vnf (up, status, down) dentro da ISO, 3 ciclos seguidos.
# O script do convidado é tests/cenarios-guest/t3.sh; os critérios estão em docs/plano-de-testes.md.
# Uso: tests/cenario-t3.sh <iso>   (na VM de build; precisa de qemu-system-x86 e xorriso)
set -uo pipefail

raiz=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=/dev/null
. "$raiz/tests/lib-cenario.sh"

cen_init T3 "${1:-}"
cen_convidado "$CEN_GUEST" t3 || cen_fim FALHA "o convidado falhou: veja a saída em evidencias/T3"
cen_fim OK "ciclo de vida da VNF FRR pelo nexus-vnf"
