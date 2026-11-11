#!/usr/bin/env bash
# Teste da demonstração da RC3 dentro da ISO (dinâmico, na VM de build): roda tests/cenarios-guest/demo.sh pelo
# "tests/iso-smoke.sh --extra" e imprime a contagem e os tempos por ato (linhas NEXUS-DEMO-ATO da serial).
# Variáveis: NEXUS_SMOKE_MEM (RAM do convidado, padrão 2560 MiB, a recomendada da demonstração) e as NEXUS_SMOKE_* do iso-smoke.
# Uso: tests/demo.sh <iso>   (precisa de qemu-system-x86 e xorriso)
set -euo pipefail

fail() { echo "FALHA: $*" >&2; exit 1; }
raiz=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

[ $# -eq 1 ] || fail "uso: tests/demo.sh <iso>"
[ -f "$1" ] || fail "ISO não encontrada: $1"
export NEXUS_SMOKE_MEM=${NEXUS_SMOKE_MEM:-2560}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export NEXUS_SMOKE_SERIAL=$tmp/serial.log
rc=0
"$raiz/tests/iso-smoke.sh" --extra "$raiz/tests/cenarios-guest/demo.sh" "$1" demo || rc=$?
{ tr -d '\r' <"$tmp/serial.log" | grep -aE 'NEXUS-DEMO-(ATO|TOTAL) ' | sort -u; } >"$tmp/atos.txt" || true
cat "$tmp/atos.txt"
[ "$rc" -eq 0 ] || fail "o teste da demonstração falhou (código $rc)"
n=$(grep -c 'NEXUS-DEMO-ATO .* OK ' "$tmp/atos.txt" || true)
[ "$n" -eq 4 ] || fail "esperava 4 atos OK na serial, achei $n"
echo "OK: tests/demo.sh ($n de 4 atos, RAM do convidado ${NEXUS_SMOKE_MEM} MiB)"
