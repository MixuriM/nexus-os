#!/usr/bin/env bash
# Executa em ordem os testes da Fase 3: lint-repo, docs, gui-spec, atalhos, identidade, iso, iso-smoke (all),
# requisitos e manual.
# Para no primeiro erro com "FALHA:" e imprime um resumo OK/FALHA por teste.
# Uso: tests/run-fase3.sh [iso]   (padrão: dist/nexus-os-poc-amd64.iso; precisa de qemu-system-x86 e xorriso)
set -uo pipefail

raiz=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
iso=${1:-$raiz/dist/nexus-os-poc-amd64.iso}

nomes=(lint-repo docs gui-spec atalhos identidade iso iso-smoke requisitos manual)
resumo=()

for nome in "${nomes[@]}"; do
    echo "=== tests/$nome.sh"
    case $nome in
        iso | manual) "$raiz/tests/$nome.sh" "$iso" ;;
        iso-smoke) "$raiz/tests/iso-smoke.sh" "$iso" all ;;
        *) "$raiz/tests/$nome.sh" ;;
    esac
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
    case $r in FALHA:*) echo "FALHA: tests/run-fase3.sh parou no primeiro erro" >&2; exit 1 ;; esac
done
echo "OK: tests/run-fase3.sh (${#nomes[@]} testes)"
