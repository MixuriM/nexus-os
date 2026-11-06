#!/usr/bin/env bash
# Executa em ordem os cenários funcionais da Fase 4: cenario-t1.sh a cenario-t7.sh.
# Para no primeiro erro com "FALHA:" e imprime um resumo OK/FALHA por cenário.
# Um cenário sem script imprime "FALHA: cenário Tn ainda não implementado" e sai com 1.
# Uso: tests/run-fase4.sh [iso]   (padrão: dist/nexus-os-rc2-amd64.iso; precisa de qemu-system-x86 e xorriso)
set -uo pipefail

raiz=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
iso=${1:-$raiz/dist/nexus-os-rc2-amd64.iso}

nomes=(cenario-t1.sh cenario-t2.sh cenario-t3.sh cenario-t4.sh cenario-t5.sh cenario-t6.sh cenario-t7.sh)
resumo=()

for nome in "${nomes[@]}"; do
    echo "=== tests/$nome"
    script=$raiz/tests/$nome
    t=${nome#cenario-}
    t=${t%.sh}
    if [ ! -f "$script" ]; then
        echo "FALHA: cenário ${t^^} ainda não implementado" >&2
        resumo+=("FALHA: $nome (não implementado)")
        break
    fi
    "$script" "$iso"
    cod=$?
    if [ "$cod" -ne 0 ]; then
        resumo+=("FALHA: $nome (saída $cod)")
        break
    fi
    resumo+=("OK: $nome")
done

echo "=== Resumo"
printf '%s\n' "${resumo[@]}"

for r in "${resumo[@]}"; do
    case $r in FALHA:*) echo "FALHA: tests/run-fase4.sh parou no primeiro erro" >&2; exit 1 ;; esac
done
echo "OK: tests/run-fase4.sh (${#nomes[@]} cenários)"
