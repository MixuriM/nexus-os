#!/usr/bin/env bash
# Confere docs/requisitos.md (F3.9) e docs/rc1.md (F3.11): tabela de RAM e disco com valores numéricos,
# RAM recomendada = ceil((pico + 512) / 512) * 512 e o mesmo SHA256 da ISO nos dois documentos.
# Estático: roda no Git Bash e no Linux. Uso: tests/requisitos.sh
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

req=docs/requisitos.md
rc1=docs/rc1.md
erros=0
fail() { echo "FALHA: $*" >&2; erros=$((erros + 1)); }

for f in "$req" "$rc1"; do
    [ -f "$f" ] || fail "arquivo ausente: $f"
done
[ "$erros" -eq 0 ] || exit 1

# Segunda coluna da linha de tabela cujo primeiro campo começa com o rótulo.
campo() {
    awk -F'|' -v r="$2" '
        { a = $2; gsub(/^[ \t]+|[ \t]+$/, "", a) }
        index(a, r) == 1 { v = $3; gsub(/^[ \t`]+|[ \t`]+$/, "", v); print v; exit }
    ' "$1"
}

numerico() {
    local rotulo=$1 valor
    valor=$(campo "$req" "$rotulo")
    [[ $valor =~ ^[0-9]+$ ]] || { fail "$req: '$rotulo' ausente ou não numérico (achei '${valor:-}')"; return 0; }
    printf '%s' "$valor"
}

repouso=$(numerico "RAM em repouso")
pico=$(numerico "RAM de pico")
recomendada=$(numerico "RAM recomendada")
numerico "Disco do root em memória" >/dev/null
numerico "Disco do Docker" >/dev/null
bytes=$(numerico "ISO (bytes)")

data=$(campo "$req" "Data")
[[ $data =~ ^20[0-9]{2}-[0-9]{2}-[0-9]{2}$ ]] || fail "$req: 'Data' ausente ou fora de AAAA-MM-DD (achei '${data:-}')"

if [ -n "$pico" ] && [ -n "$recomendada" ]; then
    [ "$recomendada" -ge "$pico" ] || fail "RAM recomendada ($recomendada) menor que o pico ($pico)"
    esperada=$(((pico + 512 + 511) / 512 * 512))
    [ "$recomendada" -eq "$esperada" ] || fail "RAM recomendada ($recomendada) difere da fórmula ceil((pico + 512) / 512) * 512 = $esperada"
fi
if [ -n "$repouso" ] && [ -n "$pico" ]; then
    [ "$pico" -ge "$repouso" ] || fail "RAM de pico ($pico) menor que a RAM em repouso ($repouso)"
fi
[ -z "$bytes" ] || [ "$bytes" -gt 0 ] || fail "tamanho da ISO inválido: $bytes"

sha_req=$(campo "$req" "SHA256")
sha_rc1=$(campo "$rc1" "SHA256")
[[ $sha_req =~ ^[0-9a-f]{64}$ ]] || fail "$req: SHA256 ausente ou inválido (achei '${sha_req:-}')"
[[ $sha_rc1 =~ ^[0-9a-f]{64}$ ]] || fail "$rc1: SHA256 ausente ou inválido (achei '${sha_rc1:-}')"
[ "$sha_req" = "$sha_rc1" ] || fail "SHA256 diferente: $req tem '$sha_req' e $rc1 tem '$sha_rc1'"

[ "$erros" -eq 0 ] || exit 1
echo "OK: requisitos conferidos (repouso ${repouso} MiB, pico ${pico} MiB, recomendada ${recomendada} MiB, ISO ${bytes} bytes)"
