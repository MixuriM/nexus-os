#!/usr/bin/env bash
# Cenário T5 (F4.2e, parte automática): roda dentro da ISO, sem rede, só os blocos "bash nexus-exec" da seção
# "Containerlab" do manual, na ordem, e confere a topologia frr-duo: OSPF Full dos dois lados, a rota do loopback
# do outro em cada nó e o destroy sem resíduos. O script do convidado é tests/cenarios-guest/t5.sh, que tem a
# linha "#@MANUAL@" no lugar onde entram os blocos do manual.
# Variáveis: T5_LIMITE (segundos até a convergência, padrão 120) e MANUAL_FONTE (outro manual, usado nas mutações).
# A rodada humana "sem ajuda externa" do T5 não é automática (bloco 7). Uso: tests/cenario-t5.sh <iso>
set -uo pipefail

raiz=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=/dev/null
. "$raiz/tests/lib-cenario.sh"
# shellcheck source=/dev/null
. "$raiz/tests/lib-manual.sh"

cen_init T5 "${1:-}"
limite=${T5_LIMITE:-120}
[[ $limite =~ ^[0-9]+$ ]] || cen_fim FALHA "T5_LIMITE inválido: $limite"
manual_extrair "${MANUAL_FONTE:-$raiz/docs/manual.md}" Containerlab >"$CEN_TMP/secao.sh" ||
    cen_fim FALHA "a seção Containerlab do manual não tem bloco 'bash nexus-exec'"
awk -v lim="$limite" -v corpo="$CEN_TMP/secao.sh" '
    $0 == "#@MANUAL@" { while ((getline l < corpo) > 0) print l; achou = 1; next }
    /^limite=/ { print "limite=" lim; next }
    { print }
    END { if (!achou) exit 1 }
' "$CEN_GUEST" >"$CEN_TMP/t5-completo.sh" || cen_fim FALHA "tests/cenarios-guest/t5.sh sem a linha #@MANUAL@"
cen_convidado "$CEN_TMP/t5-completo.sh" t5 || cen_fim FALHA "o convidado falhou: veja a saída em evidencias/T5"
cen_fim OK "seção Containerlab do manual, frr-duo com OSPF Full"
