#!/usr/bin/env bash
# Cenário T6 (F4.3): cenário integrado ponta a ponta dentro da ISO, do zero, em 3 execuções seguidas, cada uma
# num QEMU novo e sem persistência: ponte Open vSwitch com regras OpenFlow escritas à mão, dois nós FRR do
# Containerlab ligados a ela, subida pelo nexus-vnf, OSPF Full e a prova de que a regra de descarte do protocolo
# 89 derruba a adjacência e a rota. O script do convidado é tests/cenarios-guest/t6.sh, que tem a linha
# "#@PAYLOAD@" no lugar dos arquivos do cenário (a topologia, as configurações, as regras e o nexus-vnf.sh do
# repositório vão dentro do script, porque a RC2 ainda não os traz) e a linha "limite=" para o parâmetro.
# Variáveis: T6_EXECUCOES (padrão 3), T6_LIMITE (segundos até a convergência inicial, padrão 120), T6_FLOWS
# (outro arquivo de regras, usado nas mutações) e NEXUS_SMOKE_MEM (RAM do convidado, padrão 2560 MiB). Uma evidência por execução em evidencias/T6/.
# Uso: tests/cenario-t6.sh <iso>   (na VM de build; precisa de qemu-system-x86 e xorriso)
set -uo pipefail

raiz=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=/dev/null
. "$raiz/tests/lib-cenario.sh"

# RAM do convidado: a recomendada com o desktop em docs/requisitos.md (NEXUS_SMOKE_MEM troca).
export NEXUS_SMOKE_MEM=${NEXUS_SMOKE_MEM:-2560}
cen_init T6 "${1:-}"
CEN_METRICAS+=("ram_convidado_mib: $NEXUS_SMOKE_MEM")
execucoes=${T6_EXECUCOES:-3}
limite=${T6_LIMITE:-120}
{ [[ $execucoes =~ ^[1-9][0-9]*$ ]] && [[ $limite =~ ^[0-9]+$ ]]; } || cen_fim FALHA "T6_EXECUCOES ou T6_LIMITE inválido"

arquivos=(labs/containerlab/integrado.clab.yml labs/containerlab/configs/int-r1 labs/containerlab/configs/int-r2
    sdn/flows/integrado.flows nfv/nexus-vnf.sh)
for f in "${arquivos[@]}"; do
    [ -e "$raiz/$f" ] || cen_fim FALHA "arquivo do cenário ausente no repositório: $f"
done
mkdir "$CEN_TMP/pay"
(cd "$raiz" && cp -a --parents "${arquivos[@]}" "$CEN_TMP/pay/")
[ -z "${T6_FLOWS:-}" ] || cp "$T6_FLOWS" "$CEN_TMP/pay/sdn/flows/integrado.flows"
{
    # shellcheck disable=SC2016  # as variáveis são do script do convidado
    echo 'mkdir -p "$t6dir"'
    echo "base64 -d <<'T6-PAYLOAD' | tar xz -C \"\$t6dir\""
    tar czf - -C "$CEN_TMP/pay" . | base64
    echo 'T6-PAYLOAD'
} >"$CEN_TMP/payload.txt"
awk -v lim="$limite" -v pay="$CEN_TMP/payload.txt" '
    $0 == "#@PAYLOAD@" { while ((getline l < pay) > 0) print l; achou = 1; next }
    /^limite=/ { print "limite=" lim; next }
    { print }
    END { if (!achou) exit 1 }
' "$CEN_GUEST" >"$CEN_TMP/t6-completo.sh" || cen_fim FALHA "tests/cenarios-guest/t6.sh sem a linha #@PAYLOAD@"

base_metricas=("${CEN_METRICAS[@]}")
ok=0
for i in $(seq 1 "$execucoes"); do
    : >"$CEN_LOG"
    CEN_METRICAS=("${base_metricas[@]}" "execucao: $i de $execucoes")
    inicio=$SECONDS
    if cen_convidado "$CEN_TMP/t6-completo.sh" t6; then res=OK; else res=FALHA; fi
    CEN_METRICAS+=("tempo_total_s: $((SECONDS - inicio)) (do boot ao desligamento do QEMU)")
    echo "$res: execução $i de $execucoes" >>"$CEN_LOG"
    evidencia_registrar T6 "$MODO" "$CEN_CMD (execução $i de $execucoes)" "$CEN_LOG" "$res" "$CEN_ISO" "${CEN_METRICAS[@]}"
    if [ "$res" != OK ]; then
        echo "FALHA: cenário T6: a execução $i de $execucoes falhou: veja a evidência em evidencias/T6" >&2
        exit 1
    fi
    ok=$((ok + 1))
done
echo "OK: cenário T6 ($ok de $execucoes execuções seguidas, $MODO)"
