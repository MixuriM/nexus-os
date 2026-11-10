#!/usr/bin/env bash
# Confere docs/congelamento.md (F4.6): SHA256 de 64 hexadecimais e igual ao de docs/rc2.md, tamanho numérico,
# commit do build, data AAAA-MM-DD, tempo do build numérico, a regra "nada mais entra na ISO", a seção de
# riscos aceitos (issue 32) e nenhum .iso versionado. A tag no remoto não é conferida aqui (precisa de rede).
# Estático: roda no Git Bash e no Linux. Uso: tests/congelamento.sh
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

doc=docs/congelamento.md
rc2=docs/rc2.md
erros=0
fail() { echo "FALHA: $*" >&2; erros=$((erros + 1)); }

for f in "$doc" "$rc2"; do
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

sha=$(campo "$doc" "SHA256")
sha_rc2=$(campo "$rc2" "SHA256")
[[ $sha =~ ^[0-9a-f]{64}$ ]] || fail "$doc: SHA256 ausente ou inválido (achei '${sha:-}')"
[[ $sha_rc2 =~ ^[0-9a-f]{64}$ ]] || fail "$rc2: SHA256 ausente ou inválido (achei '${sha_rc2:-}')"
[ "$sha" = "$sha_rc2" ] || fail "SHA256 diferente: $doc tem '$sha' e $rc2 tem '$sha_rc2'"

bytes=$(campo "$doc" "Tamanho (bytes)")
if [[ ! $bytes =~ ^[0-9]+$ ]] || [ "$bytes" -eq 0 ]; then
    fail "$doc: 'Tamanho (bytes)' ausente ou não numérico (achei '${bytes:-}')"
fi
rc2_bytes=$(campo "$rc2" "Tamanho" | grep -oE '^[0-9]+' || true)
[ -z "$bytes" ] || [ "$bytes" = "$rc2_bytes" ] || fail "tamanho diferente: $doc tem '$bytes' e $rc2 tem '${rc2_bytes:-}'"

commit=$(campo "$doc" "Commit do build")
[[ $commit =~ ^[0-9a-f]{7,40}$ ]] || fail "$doc: 'Commit do build' ausente ou inválido (achei '${commit:-}')"

data=$(campo "$doc" "Data")
[[ $data =~ ^20[0-9]{2}-[0-9]{2}-[0-9]{2}$ ]] || fail "$doc: 'Data' ausente ou fora de AAAA-MM-DD (achei '${data:-}')"

tempo=$(campo "$doc" "Tempo do build (s)")
[[ $tempo =~ ^[0-9]+$ ]] || fail "$doc: 'Tempo do build (s)' ausente ou não numérico (achei '${tempo:-}')"

grep -qxF '## Riscos aceitos' "$doc" || fail "$doc: seção '## Riscos aceitos' ausente"
grep -qF '#32' "$doc" || fail "$doc: a issue #32 não aparece nos riscos aceitos"
grep -qF 'Nada mais entra na ISO' "$doc" || fail "$doc: regra 'Nada mais entra na ISO' ausente"

iso=$(git ls-files '*.iso' | head -n 1 || true)
[ -z "$iso" ] || fail "ISO versionada no Git: $iso"

[ "$erros" -eq 0 ] || exit 1
echo "OK: congelamento conferido (SHA256 ${sha:0:8}, ${bytes} bytes, commit ${commit}, ${data}, build de ${tempo} s)"
