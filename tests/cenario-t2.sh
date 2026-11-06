#!/usr/bin/env bash
# Cenário T2 (F4.2b): Open vSwitch com regras OpenFlow escritas à mão, sem controlador, dentro da ISO.
# O script do convidado é tests/cenarios-guest/t2.sh; os critérios estão em docs/plano-de-testes.md.
# Uso: tests/cenario-t2.sh <iso>   (na VM de build; precisa de qemu-system-x86 e xorriso)
set -uo pipefail

raiz=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=/dev/null
. "$raiz/tests/lib-cenario.sh"

cen_init T2 "${1:-}"
cen_convidado "$CEN_GUEST" t2 || cen_fim FALHA "o convidado falhou: veja a saída em evidencias/T2"
cen_fim OK "regras manuais no Open vSwitch"
