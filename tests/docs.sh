#!/usr/bin/env bash
# Teste estático da documentação (F3.12 e F3.18): os documentos por componente, do desktop (gui, branding) e da
# RC2 existem, estão no índice docs/README.md, os links locais resolvem, gns3.md e manual.md têm as seções
# exigidas (inclusive "Ambiente gráfico" com blocos executáveis) e não sobrou "TODO".
# Roda no Git Bash do Windows e em Linux. Uso: tests/docs.sh
set -uo pipefail

raiz=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$raiz" || exit 1
export LC_ALL=C.UTF-8

erros=0
fail() { echo "FALHA: $*" >&2; erros=$((erros + 1)); }

docs=(sdn virtualizacao nfv containers integracao-iso requisitos rc1 gns3 manual gui branding rc2)
indice=docs/README.md
[ -f "$indice" ] || fail "índice ausente: $indice"

for d in "${docs[@]}"; do
    arq=docs/$d.md
    if [ ! -f "$arq" ]; then
        fail "documento ausente: $arq"
        continue
    fi
    if [ -f "$indice" ] && ! grep -qF "($d.md)" "$indice"; then
        fail "$arq não está no índice $indice"
    fi
    if grep -n 'TODO' -- "$arq" >/dev/null; then
        fail "TODO em $arq"
    fi
    # Links locais [texto](destino): ignora http(s), mailto e âncora pura; resolve a partir da pasta do documento.
    while IFS= read -r destino; do
        destino=${destino%%#*}
        case $destino in '' | http://* | https://* | mailto:*) continue ;; esac
        [ -e "docs/$destino" ] || fail "link quebrado em $arq: $destino"
    done < <(grep -oE '\]\([^)]*\)' -- "$arq" | sed -e 's/^](//' -e 's/)$//')
done

secoes_gns3=('## Pré-requisitos' '## Instalação' '## Uso' '## Fora da ISO' '## Problemas conhecidos')
if [ -f docs/gns3.md ]; then
    for s in "${secoes_gns3[@]}"; do
        grep -qxF "$s" docs/gns3.md || fail "seção ausente em docs/gns3.md: $s"
    done
fi

# Uma seção por assunto do manual v1 (D9): visão geral, gerar, iniciar, login, um componente por seção, requisitos e problemas.
secoes_manual=(
    '## Visão geral'
    '## Gerar a ISO'
    '## Iniciar a ISO'
    '## Login de laboratório'
    '## Open vSwitch (nexus-sdn)'
    '## libvirt (nexus-vm)'
    '## Contêineres e imagens offline'
    '## FRRouting'
    '## Containerlab'
    '## Orquestração (nexus-vnf)'
    '## Testes (nexus-smoke)'
    '## Ambiente gráfico'
    '## Requisitos'
    '## Solução de problemas'
)
if [ -f docs/manual.md ]; then
    for s in "${secoes_manual[@]}"; do
        grep -qxF "$s" docs/manual.md || fail "seção ausente em docs/manual.md: $s"
    done
fi

# A seção do desktop precisa de blocos que a máquina executa e do roteiro humano (checklist, parte H).
if [ -f docs/manual.md ]; then
    blocos_gui=$(awk '/^## /{dentro = ($0 == "## Ambiente gráfico")} dentro && /^```bash nexus-exec/{n++} END{print n+0}' docs/manual.md)
    [ "$blocos_gui" -ge 1 ] || fail "docs/manual.md: a seção '## Ambiente gráfico' não tem bloco 'bash nexus-exec'"
fi
if [ -f docs/checklist-teste-documentacao.md ]; then
    grep -q '^## Parte H' docs/checklist-teste-documentacao.md || fail "docs/checklist-teste-documentacao.md sem a '## Parte H' (ambiente gráfico)"
fi

if [ "$erros" -ne 0 ]; then
    echo "FALHA: tests/docs.sh com $erros erro(s)" >&2
    exit 1
fi
echo "OK: tests/docs.sh (${#docs[@]} documentos, índice, links, seções do gns3.md e do manual.md, blocos do desktop)"
