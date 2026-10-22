#!/usr/bin/env bash
# Executa em ordem os testes da Fase 2: lint-repo, iso, sdn, virtualizacao, nfv.
# Para no primeiro erro com "FALHA:" e imprime um resumo OK/FALHA por teste.
# Uso: tests/run-fase2.sh [iso]   (padrão: dist/nexus-os-poc-amd64.iso; usa sudo para sdn, virtualizacao e nfv)
set -uo pipefail

raiz=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
iso=${1:-$raiz/dist/nexus-os-poc-amd64.iso}

as_root() { if [ "$(id -u)" -eq 0 ]; then "$@"; else sudo "$@"; fi; }

nomes=(lint-repo iso sdn virtualizacao nfv)
resumo=()

for nome in "${nomes[@]}"; do
    echo "=== tests/$nome.sh"
    case $nome in
        lint-repo) "$raiz/tests/lint-repo.sh" ;;
        iso) "$raiz/tests/iso.sh" "$iso" ;;
        *) as_root "$raiz/tests/$nome.sh" ;;
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
    case $r in FALHA:*) echo "FALHA: tests/run-fase2.sh parou no primeiro erro" >&2; exit 1 ;; esac
done
echo "OK: tests/run-fase2.sh (${#nomes[@]} testes)"
