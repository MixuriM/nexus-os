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

docs=(sdn virtualizacao nfv containers integracao-iso requisitos rc1 gns3 manual gui branding rc2 teste-virtualbox)
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

# Manual v2 (F4.4): título, seção "O que mudou da v1" com tabela, comandos exatos de "Gerar a ISO" e lacunas do T5 corrigidas.
if [ -f docs/manual.md ]; then
    [ "$(head -n 1 docs/manual.md)" = '# Manual v2.1 do Nexus OS (RC2 final)' ] || fail "docs/manual.md: o título devia ser '# Manual v2.1 do Nexus OS (RC2 final)' (achei: $(head -n 1 docs/manual.md))"
    grep -qxF '## O que mudou da v1' docs/manual.md || fail "docs/manual.md sem a seção '## O que mudou da v1'"
    mudou=$(awk '/^## /{dentro = ($0 == "## O que mudou da v1")} dentro' docs/manual.md)
    [ "$(grep -c '^| ' <<<"$mudou")" -ge 4 ] || fail "a seção 'O que mudou da v1' devia ter uma tabela com pelo menos 3 linhas de mudança"
    gerar=$(awk '/^## /{dentro = ($0 == "## Gerar a ISO")} dentro' docs/manual.md)
    for cmd in 'git clone https://github.com/MixuriM/nexus-os.git' 'cd nexus-os' 'sudo scripts/build-iso.sh' 'tests/iso.sh dist/nexus-os-poc-amd64.iso' 'cp dist/nexus-os-poc-amd64.iso dist/nexus-os-rc2-amd64.iso' 'sha256sum nexus-os-rc2-amd64.iso'; do
        grep -qF -- "$cmd" <<<"$gerar" || fail "a seção 'Gerar a ISO' do manual sem o comando exato: $cmd"
    done
    cl=$(awk '/^## /{dentro = ($0 == "## Containerlab")} dentro' docs/manual.md)
    ! grep -qF "O \`vtysh\` imprime o aviso" <<<"$cl" || fail "a seção Containerlab ainda diz que o bloco imprime o aviso do vtysh (lacuna do T5)"
    # shellcheck disable=SC2016  # o texto procurado tem crases literais
    grep -qF 'desde o início do `deploy`' <<<"$cl" || fail "a seção Containerlab sem a convergência medida desde o início do deploy (lacuna do T5)"
fi
if [ -f docs/README.md ]; then
    grep -qF '[Manual v2.1 (RC2 final)](manual.md)' docs/README.md || fail "docs/README.md sem o índice do Manual v2.1"
fi

# Manual v2.1 (lacunas da rodada humana H1, 10/11/2026): RC1 separada da RC2, jeito certo por sistema, colar sem rede
# e a prova de controle do cenário integrado completa.
if [ -f docs/manual.md ]; then
    mudou=$(awk '/^## /{dentro = ($0 == "## O que mudou da v1")} dentro' docs/manual.md)
    grep -qF 'v2.1' <<<"$mudou" || fail "a seção 'O que mudou da v1' não tem a linha da v2.1"
    grep -qxF '## Apêndice A: RC1 (histórico)' docs/manual.md || fail "docs/manual.md sem a seção '## Apêndice A: RC1 (histórico)'"
    fora=$(awk '/^## /{dentro = ($0 == "## Apêndice A: RC1 (histórico)")} !dentro' docs/manual.md)
    ! grep -qE 'nexus-os-rc1|nexus-rc1' <<<"$fora" || fail "docs/manual.md cita arquivo ou VM da RC1 fora do apêndice: $(grep -nE 'nexus-os-rc1|nexus-rc1' <<<"$fora" | head -n 1 | cut -c1-80)"
    ini=$(awk '/^## /{dentro = ($0 == "## Iniciar a ISO")} dentro' docs/manual.md)
    grep -qF 'No Windows, use o Jeito 2' <<<"$ini" || fail "'Iniciar a ISO' não diz que no Windows se usa o Jeito 2"
    grep -qF 'Se a VM já existe' <<<"$ini" || fail "'Iniciar a ISO' sem o caso da VM já criada (só Start-VM e vmconnect.exe)"
    grep -qxF '### Jeito 1: QEMU no Linux (só no Linux)' <<<"$ini" || fail "'Iniciar a ISO' sem o título '### Jeito 1: QEMU no Linux (só no Linux)'"
    grep -qxF '### Colar comandos numa VM sem rede' <<<"$ini" || fail "'Iniciar a ISO' sem a seção '### Colar comandos numa VM sem rede'"
    grep -qF 'mousepad /usr/share/nexus-os/docs/manual.md' <<<"$ini" || fail "a seção de colar sem rede não manda abrir o manual da ISO no Mousepad"
    grep -qF 'Ctrl+Shift+V' <<<"$ini" || fail "a seção de colar sem rede não cita Ctrl+Shift+V"
    integ_md=$(awk '/^## /{dentro = ($0 == "## Cenário integrado")} dentro' docs/manual.md)
    [ "$(grep -c 'add-br br-integrado' <<<"$integ_md")" -ge 2 ] || fail "a prova de controle do 'Cenário integrado' não sobe o laboratório sozinha (add-br br-integrado só uma vez)"
    ! grep -qF 'com o laboratório no ar, antes do' <<<"$integ_md" || fail "a prova de controle ainda manda rodar 'com o laboratório no ar', que o bloco anterior já derrubou"
fi

# A seção do desktop precisa de blocos que a máquina executa e do roteiro humano (checklist, parte H).
if [ -f docs/manual.md ]; then
    blocos_gui=$(awk '/^## /{dentro = ($0 == "## Ambiente gráfico")} dentro && /^```bash nexus-exec/{n++} END{print n+0}' docs/manual.md)
    [ "$blocos_gui" -ge 1 ] || fail "docs/manual.md: a seção '## Ambiente gráfico' não tem bloco 'bash nexus-exec'"
fi
if [ -f docs/checklist-teste-documentacao.md ]; then
    grep -q '^## Parte H' docs/checklist-teste-documentacao.md || fail "docs/checklist-teste-documentacao.md sem a '## Parte H' (ambiente gráfico)"
fi

# Rodada 3 da RC2 (F3.17): programas incluídos, internet na VM do Hyper-V e documentação em HTML.
if [ -f docs/gui.md ]; then
    grep -qxF '## Programas incluídos' docs/gui.md || fail "docs/gui.md sem a seção '## Programas incluídos'"
    for prog in LibreOffice Wireshark VLC GIMP Inkscape KeePassXC Mousepad Evince Ristretto Remmina; do
        grep -qF "$prog" docs/gui.md || fail "docs/gui.md não cita o programa $prog"
    done
    grep -qF 'nexus-docs-html' docs/gui.md || fail "docs/gui.md não descreve a documentação em HTML (nexus-docs-html)"
fi
for arq in docs/manual.md docs/checklist-teste-documentacao.md README.md docs/hyperv.md; do
    [ -f "$arq" ] || continue
    grep -qF 'Connect-VMNetworkAdapter' "$arq" || fail "$arq sem o comando Connect-VMNetworkAdapter (internet na VM do Hyper-V)"
done

# Extração por seção do manual (F4.2e): tests/lib-manual.sh e o segundo argumento de tests/manual.sh.
if [ ! -f tests/lib-manual.sh ]; then
    fail "tests/lib-manual.sh ausente"
else
    # shellcheck source=/dev/null
    . tests/lib-manual.sh
    cerca='^```bash nexus-exec[[:space:]]*$'
    esperado=$(grep -c "$cerca" docs/manual.md)
    todos=$(manual_extrair docs/manual.md | grep -c '^echo "MANUAL-BLOCO ')
    [ "$todos" -eq "$esperado" ] || fail "manual_extrair sem seção achou $todos bloco(s), esperado $esperado"
    sec=$(manual_extrair docs/manual.md Containerlab) || fail "manual_extrair não achou a seção Containerlab"
    [ "$(grep -c '^echo "MANUAL-BLOCO ' <<<"$sec")" -eq 1 ] || fail "a seção Containerlab devia ter 1 bloco"
    grep -q 'containerlab deploy' <<<"$sec" || fail "o bloco da seção Containerlab não tem 'containerlab deploy'"
    ! grep -q 'nexus-vnf' <<<"$sec" || fail "a seção Containerlab trouxe bloco de outra seção (nexus-vnf)"
    manual_extrair docs/manual.md "Seção que não existe" >/dev/null 2>&1
    [ $? -eq 3 ] || fail "manual_extrair devia sair com 3 para seção inexistente"
    integ=$(manual_extrair docs/manual.md "Cenário integrado") || fail "o manual não tem a seção '## Cenário integrado' com bloco 'bash nexus-exec'"
    grep -q 'integrado.clab.yml' <<<"$integ" || fail "o bloco da seção 'Cenário integrado' não usa integrado.clab.yml"
    grep -q 'nexus-vnf' <<<"$integ" || fail "o bloco da seção 'Cenário integrado' não sobe pelo nexus-vnf"
    iso_falsa=$(mktemp)
    saida=$(bash tests/manual.sh "$iso_falsa" "Seção que não existe" 2>&1) && fail "tests/manual.sh aceitou seção inexistente"
    grep -q '^FALHA: seção' <<<"$saida" || fail "tests/manual.sh sem 'FALHA: seção' para seção inexistente: $saida"
    rm -f "$iso_falsa"
fi

if [ "$erros" -ne 0 ]; then
    echo "FALHA: tests/docs.sh com $erros erro(s)" >&2
    exit 1
fi
echo "OK: tests/docs.sh (${#docs[@]} documentos, índice, links, seções do gns3.md e do manual.md, blocos do desktop)"
