#!/usr/bin/env bash
# Confere docs/requisitos.md (F3.9 e F3.18), docs/rc1.md (F3.11) e docs/rc2.md (F3.18): tabela de RAM e disco
# com valores numéricos, RAM recomendada = ceil((pico + 512) / 512) * 512 e o mesmo SHA256 da ISO nos
# documentos. A seção "Com ambiente gráfico" repete a conferência para a ISO com desktop (RC2).
# Estático: roda no Git Bash e no Linux. Uso: tests/requisitos.sh
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

req=docs/requisitos.md
rc1=docs/rc1.md
rc2=docs/rc2.md
erros=0
fail() { echo "FALHA: $*" >&2; erros=$((erros + 1)); }

for f in "$req" "$rc1" "$rc2"; do
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

# numerico <variável> <rótulo>: guarda o valor na variável (sem subshell, para o fail contar) e exige inteiro.
numerico() {
    local valor
    valor=$(campo "$req" "$2")
    if [[ $valor =~ ^[0-9]+$ ]]; then
        printf -v "$1" '%s' "$valor"
    else
        printf -v "$1" '%s' ''
        fail "$req: '$2' ausente ou não numérico (achei '${valor:-}')"
    fi
}

numerico repouso "RAM em repouso"
numerico pico "RAM de pico"
numerico recomendada "RAM recomendada"
numerico disco_root "Disco do root em memória"
numerico disco_docker "Disco do Docker"
numerico bytes "ISO (bytes)"

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

# Seção "Com ambiente gráfico" (F3.18): mesmos valores para a ISO com o desktop. Rótulos "Desktop: ...".
grep -qxF '## Com ambiente gráfico' "$req" || fail "$req: seção '## Com ambiente gráfico' ausente"
numerico d_repouso "Desktop: RAM em repouso"
numerico d_pico "Desktop: RAM de pico"
numerico d_recomendada "Desktop: RAM recomendada"
numerico d_disco "Desktop: disco do root em memória"
numerico d_bytes "Desktop: ISO (bytes)"
numerico d_delta "Desktop: diferença da ISO para a RC1 (bytes)"
numerico d_sessao "Desktop: tempo até a sessão (s)"
numerico d_mem_iso "Desktop: mínimo de RAM do tests/iso.sh (MiB)"
numerico d_mem_smoke "Desktop: mínimo de RAM dos smokes (MiB)"
if [ -n "$d_pico" ] && [ -n "$d_recomendada" ]; then
    [ "$d_recomendada" -ge "$d_pico" ] || fail "RAM recomendada com desktop ($d_recomendada) menor que o pico ($d_pico)"
    esperada=$(((d_pico + 512 + 511) / 512 * 512))
    [ "$d_recomendada" -eq "$esperada" ] || fail "RAM recomendada com desktop ($d_recomendada) difere da fórmula = $esperada"
fi
if [ -n "$d_repouso" ] && [ -n "$d_pico" ]; then
    [ "$d_pico" -ge "$d_repouso" ] || fail "RAM de pico com desktop ($d_pico) menor que o repouso ($d_repouso)"
fi
if [ -n "$d_bytes" ] && [ -n "$d_delta" ] && [ -n "$bytes" ]; then
    [ "$d_delta" -eq $((d_bytes - bytes)) ] || fail "diferença para a RC1 ($d_delta) difere de $d_bytes - $bytes = $((d_bytes - bytes))"
fi
sha_d=$(campo "$req" "Desktop: SHA256")
sha_rc2=$(campo "$rc2" "SHA256")
[[ $sha_d =~ ^[0-9a-f]{64}$ ]] || fail "$req: 'Desktop: SHA256' ausente ou inválido (achei '${sha_d:-}')"
[[ $sha_rc2 =~ ^[0-9a-f]{64}$ ]] || fail "$rc2: SHA256 ausente ou inválido (achei '${sha_rc2:-}')"
[ "$sha_d" = "$sha_rc2" ] || fail "SHA256 diferente: $req tem '$sha_d' e $rc2 tem '$sha_rc2'"

[ "$erros" -eq 0 ] || exit 1
echo "OK: requisitos conferidos (repouso ${repouso} MiB, pico ${pico} MiB, recomendada ${recomendada} MiB, ISO ${bytes} bytes; com desktop: repouso ${d_repouso} MiB, pico ${d_pico} MiB, recomendada ${d_recomendada} MiB, ISO ${d_bytes} bytes)"
