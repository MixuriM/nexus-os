#!/usr/bin/env bash
# Teste estático da especificação do ambiente gráfico (F3.14): docs/gui.md existe, está no índice,
# tem as seções exigidas, a tabela de candidatos tem os 5 candidatos com números, a tabela de medição
# tem os 3 finalistas (2 leituras cada, com KVM) e o desktop escolhido é um dos finalistas.
# Roda no Git Bash do Windows e em Linux. Uso: tests/gui-spec.sh
set -uo pipefail

raiz=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$raiz" || exit 1
export LC_ALL=C.UTF-8

erros=0
fail() { echo "FALHA: $*" >&2; erros=$((erros + 1)); }

doc=docs/gui.md
indice=docs/README.md
candidatos=(XFCE LXQt MATE GNOME 'KDE Plasma')
num='^[0-9]+([.,][0-9]+)?$'

[ -f "$doc" ] || { fail "documento ausente: $doc"; echo "FALHA: tests/gui-spec.sh com $erros erro(s)" >&2; exit 1; }
{ [ -f "$indice" ] && grep -qF '(gui.md)' "$indice"; } || fail "$doc não está no índice $indice"
grep -n 'TODO' -- "$doc" >/dev/null && fail "TODO em $doc"

for s in Definição Candidatos Medição Escolha 'Sessão sem janela' 'Impacto nos requisitos' 'Problemas conhecidos'; do
    grep -qxF "## $s" "$doc" || fail "seção ausente em $doc: ## $s"
done

# Linhas de tabela de uma seção, com as células separadas por TAB e sem crases.
linhas() {
    awk -v sec="## $1" '
        $0 == sec { dentro = 1; next }
        /^## / { dentro = 0 }
        dentro && /^\|/ {
            n = split($0, c, "|")
            out = ""
            for (i = 2; i < n; i++) {
                g = c[i]; gsub(/^[ \t]+|[ \t]+$/, "", g); gsub(/`/, "", g)
                out = out (i > 2 ? "\t" : "") g
            }
            print out
        }' "$doc"
}

cand=$(linhas Candidatos)
for c in "${candidatos[@]}"; do
    linha=$(awk -F'\t' -v c="$c" '$1 == c' <<<"$cand")
    if [ -z "$linha" ]; then
        fail "candidato ausente na tabela de Candidatos: $c"
        continue
    fi
    IFS=$'\t' read -r _ _ versao pacotes baixar instalado _ <<<"$linha"
    [[ ${versao:-} =~ ^[0-9][0-9A-Za-z.+:~-]*$ ]] || fail "versão não numérica de $c: '${versao:-}'"
    [[ ${pacotes:-} =~ ^[0-9]+$ ]] || fail "pacotes não numérico de $c: '${pacotes:-}'"
    [[ ${baixar:-} =~ $num ]] || fail "MB a baixar não numérico de $c: '${baixar:-}'"
    [[ ${instalado:-} =~ $num ]] || fail "MB instalados não numérico de $c: '${instalado:-}'"
done

# Medição: uma linha por finalista e leitura (Finalista | Leitura | ISO bytes | Build s | RAM MiB | Sessão s | Modo).
med=$(linhas Medição | awk -F'\t' '$2 ~ /^[0-9]+$/')
finalistas=$(cut -f1 <<<"$med" | sort -u | grep -c . || true)
[ "$finalistas" -eq 3 ] || fail "a tabela de Medição precisa de 3 finalistas, tem $finalistas"
while IFS=$'\t' read -r nome leitura iso build ram sessao modo; do
    [ -n "$nome" ] || continue
    for v in "$iso" "$build" "$ram" "$sessao"; do
        [[ $v =~ $num ]] || fail "medição não numérica de $nome (leitura $leitura): '$v'"
    done
    [[ $modo == *"com KVM"* ]] || fail "modo de $nome (leitura $leitura) não é 'com KVM': '$modo'"
done <<<"$med"
for n in $(cut -f1 <<<"$med" | sort -u | tr ' ' '_'); do
    n=${n//_/ }
    [ "$(awk -F'\t' -v n="$n" '$1 == n' <<<"$med" | wc -l)" -ge 2 ] || fail "finalista $n com menos de 2 leituras"
done

# Escolha: "Desktop escolhido: **NOME**", e NOME é um dos finalistas.
escolhido=$(awk '$0 == "## Escolha" { d = 1; next } /^## / { d = 0 } d' "$doc" \
    | sed -n 's/^Desktop escolhido: \*\*\(.*\)\*\*.*/\1/p' | head -n 1)
if [ -z "$escolhido" ]; then
    fail "seção Escolha sem a linha 'Desktop escolhido: **NOME**'"
elif ! cut -f1 <<<"$med" | grep -qxF "$escolhido"; then
    fail "desktop escolhido não é um finalista medido: $escolhido"
fi

if [ "$erros" -ne 0 ]; then
    echo "FALHA: tests/gui-spec.sh com $erros erro(s)" >&2
    exit 1
fi
echo "OK: tests/gui-spec.sh (${#candidatos[@]} candidatos, $finalistas finalistas, escolhido: $escolhido)"
