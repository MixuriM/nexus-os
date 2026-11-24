#!/usr/bin/env bash
# Mede o desempenho de uma ISO (otimização da RC4, docs/otimizacao.md) e aplica a regra de ganho comprovado.
# Uso: tests/medir-desempenho.sh [--autoteste]
#      tests/medir-desempenho.sh --medir <iso> <rotulo> [N]   (na VM de build, com KVM; N execuções, padrão 3)
#      tests/medir-desempenho.sh --tabela <rotulo>            (reimprime a tabela dos logs de um rótulo)
#      tests/medir-desempenho.sh --decidir <tempo|ram> "<base>" "<novo>"
# Métricas: A (login na serial, tests/iso.sh com 2560 MiB), B (sessão gráfica, segundos desde o boot do kernel, como
# docs/requisitos.md), C (RAM em repouso) e D (RAM de pico) do all com 4096 MiB, E (duração do all com 2560 MiB),
# H (duração de tests/demo.sh) e I (tela preta, ESTIMATIVA: sessão menos a saída do Plymouth). Todas com 2 vCPU.
# O menu de boot espera Enter: o método dos testes existentes (sendkey ret, tempo contado desde o início do QEMU) não muda.
# Logs brutos em ${NEXUS_OTIMIZACAO_LOGS:-$HOME/otimizacao-logs} (fora do Git).
set -euo pipefail

fail() { echo "FALHA: $*" >&2; exit 1; }
raiz=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
logs=${NEXUS_OTIMIZACAO_LOGS:-$HOME/otimizacao-logs}

# stats "v1 v2 v3": imprime "mediana mínimo máximo".
stats() {
    tr ' ' '\n' <<<"$1" | grep -v '^$' | sort -g \
        | awk '{ v[NR] = $1 } END { m = (NR % 2) ? v[(NR + 1) / 2] : (v[NR / 2] + v[NR / 2 + 1]) / 2; print m, v[1], v[NR] }'
}

# decidir <tempo|ram> "<base>" "<novo>": GANHO se a mediana nova é pelo menos 10% (tempo) ou 100 MiB (ram) menor que a
# da base E fica abaixo do mínimo da base; senão SEM-GANHO.
decidir() {
    local tipo=$1 mb minb mn
    read -r mb minb _ <<<"$(stats "$2")"
    read -r mn _ _ <<<"$(stats "$3")"
    awk -v t="$tipo" -v mb="$mb" -v minb="$minb" -v mn="$mn" 'BEGIN {
        ok = (t == "tempo") ? ((mb - mn) / mb >= 0.10) : ((mb - mn) >= 100)
        print (ok && mn < minb) ? "GANHO" : "SEM-GANHO"
    }'
}

# piora "<base>" "<novo>": PIOR se a mediana nova é mais de 5% maior que a da base; senão OK.
piora() {
    local mb mn
    read -r mb _ _ <<<"$(stats "$1")"
    read -r mn _ _ <<<"$(stats "$2")"
    awk -v mb="$mb" -v mn="$mn" 'BEGIN { print ((mn - mb) / mb > 0.05) ? "PIOR" : "OK" }'
}

autoteste() {
    check() {
        [ "$2" = "$3" ] || fail "$1: esperava '$3', veio '$2'"
    }
    check "stats ímpar" "$(stats "30 10 20")" "20 10 30"
    check "stats com decimais" "$(stats "18.7 18.2 19.4")" "18.7 18.2 19.4"
    check "stats cinco valores" "$(stats "5 1 4 2 3")" "3 1 5"
    check "tempo com ganho" "$(decidir tempo "30 33 31" "20 21 22")" "GANHO"
    check "tempo sem 10%" "$(decidir tempo "30 33 31" "28 29 28")" "SEM-GANHO"
    check "tempo 10% mas dentro do intervalo" "$(decidir tempo "20 40 30" "26 27 28")" "SEM-GANHO"
    check "ram com ganho" "$(decidir ram "1000 990 1010" "850 860 870")" "GANHO"
    check "ram sem 100 MiB" "$(decidir ram "1000 990 1010" "920 930 925")" "SEM-GANHO"
    check "piora acima de 5%" "$(piora "100 100 100" "106 106 106")" "PIOR"
    check "sem piora" "$(piora "100 100 100" "105 104 103")" "OK"
    check "stats iguais" "$(stats "7 7 7")" "7 7 7"
    echo "OK: autoteste de tests/medir-desempenho.sh (11 asserções)"
}

# Uma execução de cada métrica; anexa o valor em $logs/<rotulo>-<métrica>.txt.
# tenta <comando...>: roda o comando até 2 vezes (guarda a saída em $saida). O reinício do painel do smoke "desktop" é
# intermitente também na rc3.4: cada falha repetida fica em $logs/<rótulo>-reexecucoes.txt e entra no documento.
tenta() {
    local t
    for t in 1 2; do
        saida=$("$@" 2>&1) && return 0
        echo "execução $i, tentativa $t: $(grep -a 'FALHA:' <<<"$saida" | head -n 1 | cut -c1-140)" >>"$logs/$rotulo-reexecucoes.txt"
    done
    fail "falhou 2 vezes: $saida"
}
registra() { [ -n "$3" ] || fail "métrica $2 sem valor na execução de $1"; echo "$3" >>"$logs/$1-$2.txt"; }

medir() {
    local iso=$1 rotulo=$2 n=${3:-3} i saida serial
    [ -f "$iso" ] || fail "ISO não encontrada: $iso"
    [[ $rotulo =~ ^[A-Za-z0-9._-]+$ ]] || fail "rótulo inválido: $rotulo"
    [[ $n =~ ^[0-9]+$ ]] || fail "N inválido: $n"
    mkdir -p "$logs"
    rm -f "$logs/$rotulo"-*.txt
    for i in $(seq 1 "$n"); do
        echo "== $rotulo, execução $i de $n ($(date +%H:%M:%S))"
        tenta env NEXUS_ISO_MEM=2560 "$raiz/tests/iso.sh" "$iso"
        registra "$rotulo" A "$(sed -nE 's/.* em ([0-9]+) s,.*/\1/p' <<<"$saida" | tail -n 1)"
        serial="$logs/$rotulo-diagnostico-$i.log"
        tenta env NEXUS_SMOKE_MEM=2560 NEXUS_SMOKE_SERIAL="$serial" "$raiz/tests/iso-smoke.sh" --extra "$raiz/tests/cenarios-guest/otimizacao.sh" "$iso" otimizacao
        registra "$rotulo" B "$(sed -nE 's/.*NEXUS-OTIMIZACAO sessao_s ([0-9.]+).*/\1/p' "$serial" | tail -n 1)"
        registra "$rotulo" I "$(sed -nE 's/.*NEXUS-OTIMIZACAO tela_preta_s ([0-9.]+).*/\1/p' "$serial" | tail -n 1)"
        tenta env NEXUS_SMOKE_MEM=4096 "$raiz/tests/iso-smoke.sh" "$iso" all
        registra "$rotulo" C "$(sed -nE 's/.*repouso ([0-9]+) MiB, pico.*/\1/p' <<<"$saida" | tail -n 1)"
        registra "$rotulo" D "$(sed -nE 's/.*pico ([0-9]+) MiB de.*/\1/p' <<<"$saida" | tail -n 1)"
        tenta env NEXUS_SMOKE_MEM=2560 "$raiz/tests/iso-smoke.sh" "$iso" all
        registra "$rotulo" E "$(sed -nE 's/.*sem falha em ([0-9]+) s.*/\1/p' <<<"$saida" | tail -n 1)"
        tenta "$raiz/tests/demo.sh" "$iso"
        registra "$rotulo" H "$(sed -nE 's/.*sem falha em ([0-9]+) s.*/\1/p' <<<"$saida" | tail -n 1)"
    done
    tabela "$rotulo"
}

tabela() {
    local rotulo=$1 m v med mn mx
    printf '%-4s %-9s %8s %8s %8s  %s\n' métrica nome mediana mínimo máximo valores
    for m in A:login_s B:sessão_s C:RAM_repouso_MiB D:RAM_pico_MiB E:all_2560_s H:demo_s I:tela_preta_s; do
        [ -f "$logs/$rotulo-${m%%:*}.txt" ] || continue
        v=$(paste -sd' ' "$logs/$rotulo-${m%%:*}.txt")
        read -r med mn mx <<<"$(stats "$v")"
        printf '%-4s %-9s %8s %8s %8s  %s\n' "${m%%:*}" "${m#*:}" "$med" "$mn" "$mx" "$v"
    done
}

case ${1:---autoteste} in
    --autoteste) autoteste ;;
    --medir) [ $# -ge 3 ] || fail "uso: --medir <iso> <rotulo> [N]"; medir "$2" "$3" "${4:-3}" ;;
    --tabela) [ $# -eq 2 ] || fail "uso: --tabela <rotulo>"; tabela "$2" ;;
    --decidir) [ $# -eq 4 ] || fail "uso: --decidir <tempo|ram> \"<base>\" \"<novo>\""; decidir "$2" "$3" "$4" ;;
    *) fail "uso: tests/medir-desempenho.sh [--autoteste|--medir <iso> <rotulo> [N]|--tabela <rotulo>|--decidir <tempo|ram> \"<base>\" \"<novo>\"]" ;;
esac
