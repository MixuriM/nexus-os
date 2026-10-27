#!/usr/bin/env bash
# Executa o manual dentro da ISO (F3.12): extrai de docs/manual.md os blocos marcados "bash nexus-exec",
# em ordem, junta num script com "set -e" e o roda dentro da ISO, sem rede, como o teste "manual" do
# tests/iso-smoke.sh (--extra). Sai com 0 só se todos os blocos passarem e o script chegar ao fim.
# Uso: tests/manual.sh <iso>   (precisa de qemu-system-x86 e xorriso; limite NEXUS_SMOKE_LIMIT)
set -euo pipefail

fail() { echo "FALHA: $*" >&2; exit 1; }

raiz=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
manual=$raiz/docs/manual.md
[ $# -eq 1 ] || fail "uso: tests/manual.sh <iso>"
iso=$1
[ -f "$manual" ] || fail "docs/manual.md ausente"
[ -f "$iso" ] || fail "ISO não encontrada: $iso"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Só a cerca "```bash nexus-exec" abre um bloco; a próxima cerca "```" fecha.
awk '
    /^```bash nexus-exec[[:space:]]*$/ { dentro = 1; n++; printf "echo \"MANUAL-BLOCO %d\"\n", n; next }
    /^```[[:space:]]*$/ && dentro { dentro = 0; next }
    dentro { print }
    END { printf "echo \"MANUAL-FIM %d\"\n", n }
' "$manual" >"$tmp/corpo.sh"
blocos=$(grep -c '^echo "MANUAL-BLOCO ' "$tmp/corpo.sh" || true)
[ "$blocos" -ge 1 ] || fail "docs/manual.md não tem nenhum bloco 'bash nexus-exec'"

{
    echo '#!/usr/bin/env bash'
    echo 'set -e'
    cat "$tmp/corpo.sh"
} >"$tmp/manual.sh"

inicio=$SECONDS
saida=$(NEXUS_SMOKE_SERIAL="$tmp/serial.log" "$raiz/tests/iso-smoke.sh" --extra "$tmp/manual.sh" "$iso" manual 2>&1) || {
    printf '%s\n' "$saida" >&2
    fail "algum bloco do manual falhou dentro da ISO"
}
# O smoke passou; o script também precisa ter chegado ao fim com todos os blocos (nada foi pulado).
grep -aq "MANUAL-FIM $blocos" "$tmp/serial.log" || fail "a serial não mostra MANUAL-FIM $blocos: nem todos os blocos rodaram"
modo=$(sed -n 's/.*sem falha em [0-9]* s, \(com KVM\|sem KVM[^,]*\).*/\1/p' <<<"$saida")
echo "OK: tests/manual.sh ($blocos bloco(s) do manual na ISO, $((SECONDS - inicio)) s, ${modo:-modo não identificado})"
