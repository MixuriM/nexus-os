#!/usr/bin/env bash
# Cenário T1 (F4.2a): boot da ISO e requisitos de hardware. Critérios em docs/plano-de-testes.md:
# (a) SHA256 confere com o .sha256 e com docs/rc2.md; (b) tests/iso.sh chega ao login:; (c) o convidado
# mostra os serviços ativos e o iso-smoke all passa com a RAM recomendada de docs/requisitos.md, com repouso,
# pico e disco comparados com os documentados (diferença acima de 25% vira AVISO e issue); (d) controle
# negativo: com um passo (256 MiB) abaixo do mínimo documentado o all tem de falhar.
# Uso: tests/cenario-t1.sh <iso>   (na VM de build; precisa de qemu-system-x86 e xorriso)
set -uo pipefail

raiz=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=/dev/null
. "$raiz/tests/lib-cenario.sh"

cen_init T1 "${1:-}"
req=$raiz/docs/requisitos.md
rc2=$raiz/docs/rc2.md

# Segunda coluna da linha de tabela de docs/requisitos.md cujo primeiro campo começa com o rótulo.
campo() {
    awk -F'|' -v r="$1" '
        { a = $2; gsub(/^[ \t]+|[ \t]+$/, "", a) }
        index(a, r) == 1 { v = $3; gsub(/^[ \t`]+|[ \t`]+$/, "", v); print v; exit }
    ' "$req"
}
ref_repouso=$(campo "Desktop: RAM em repouso")
ref_pico=$(campo "Desktop: RAM de pico")
ref_rec=$(campo "Desktop: RAM recomendada")
ref_min=$(campo "Desktop: mínimo de RAM dos smokes")
ref_root=$(campo "Desktop: disco do root em memória")
ref_docker=$(grep -oE 'Docker segue com [0-9]+' "$req" | grep -oE '[0-9]+' | head -n 1)
for v in "$ref_repouso" "$ref_pico" "$ref_rec" "$ref_min" "$ref_root" "$ref_docker"; do
    [[ $v =~ ^[0-9]+$ ]] || cen_fim FALHA "valor de referência ausente ou não numérico em docs/requisitos.md"
done
passo=256
neg=$((ref_min - passo))

# (a) SHA256
# shellcheck disable=SC2016  # o $1 e o $2 são do bash -c
if ! cen_exec bash -c 'cd "$1" && sha256sum -c "$2"' _ "$(dirname "$CEN_ISO")" "$(basename "$CEN_ISO").sha256"; then
    cen_fim FALHA "o SHA256 da ISO não confere com o .sha256"
fi
# shellcheck disable=SC2016  # as crases são parte do padrão
doc_sha=$(sed -n 's/^| SHA256 | `\([0-9a-f]\{64\}\)`.*/\1/p' "$rc2" | head -n 1)
[ "$doc_sha" = "$CEN_SHA" ] || cen_fim FALHA "o SHA256 da ISO difere do registrado em docs/rc2.md"
CEN_METRICAS+=("sha256_12: ${CEN_SHA:0:12}")

# (b) boot até o login: (o limite é o do próprio tests/iso.sh)
out=$(cen_exec "$raiz/tests/iso.sh" "$CEN_ISO")
rc=$?
[ "$rc" -eq 0 ] || cen_fim FALHA "tests/iso.sh não chegou ao login: (saída $rc)"
login_s=$(grep -aoE 'em [0-9]+ s' <<<"$out" | tail -n 1 | grep -oE '[0-9]+')
[ -n "$login_s" ] || cen_fim FALHA "tempo até o login: não lido da saída do tests/iso.sh"
CEN_METRICAS+=("tempo_ate_login_s: $login_s")

# (c) convidado com a RAM recomendada: serviços ativos e depois o all com medição
export NEXUS_SMOKE_MEM=$ref_rec
cen_convidado "$CEN_GUEST" t1 || cen_fim FALHA "o convidado do T1 falhou (serviços ou ambiente)"
out=$(cen_exec "$raiz/tests/iso-smoke.sh" "$CEN_ISO" all)
rc=$?
[ "$rc" -eq 0 ] || cen_fim FALHA "iso-smoke all falhou com ${ref_rec} MiB, a RAM recomendada (saída $rc)"
ok=$(grep -a '^OK: ' <<<"$out" | tail -n 1)
repouso=$(sed -n 's/.*RAM usada: repouso \([0-9]*\) MiB.*/\1/p' <<<"$ok")
pico=$(sed -n 's/.*pico \([0-9]*\) MiB de.*/\1/p' <<<"$ok")
disco_root=$(sed -n 's/.*repouso:\/=\([0-9]*\) MiB.*/\1/p' <<<"$ok")
disco_docker=$(sed -n 's/.*repouso:\/var\/lib\/docker=\([0-9]*\) MiB.*/\1/p' <<<"$ok")
total_s=$(sed -n 's/.*sem falha em \([0-9]*\) s.*/\1/p' <<<"$ok")
for v in "$repouso" "$pico" "$disco_root" "$disco_docker" "$total_s"; do
    [[ $v =~ ^[0-9]+$ ]] || cen_fim FALHA "o OK do iso-smoke all não trouxe RAM e disco: $ok"
done
CEN_METRICAS+=("ram_do_convidado_mib: $ref_rec" "all_total_s: $total_s")

aviso=0
# diferenca <chave> <medido> <documentado>: registra a diferença em % e avisa quando passa de 25%.
diferenca() {
    local pct=$((($2 - $3) * 100 / $3))
    CEN_METRICAS+=("$1: medido $2 MiB, documentado $3 MiB, diferença ${pct}%")
    if [ "${pct#-}" -gt 25 ]; then
        aviso=1
        echo "AVISO: $1 diverge ${pct}% do documentado (abrir issue 'requisitos desatualizados')" | tee -a "$CEN_LOG"
        CEN_METRICAS+=("AVISO_$1: diferença acima de 25%, abrir issue requisitos desatualizados")
    fi
}
diferenca ram_repouso "$repouso" "$ref_repouso"
diferenca ram_pico "$pico" "$ref_pico"
diferenca disco_root "$disco_root" "$ref_root"
diferenca disco_docker "$disco_docker" "$ref_docker"

# (d) controle negativo: um passo abaixo do mínimo documentado o all tem de falhar
lim=${NEXUS_T1_LIMITE_NEGATIVO:-400}
out=$(cen_exec env NEXUS_SMOKE_MEM="$neg" NEXUS_SMOKE_LIMIT="$lim" "$raiz/tests/iso-smoke.sh" "$CEN_ISO" all)
rc=$?
if [ "$rc" -eq 0 ]; then
    cen_fim FALHA "o all passou com ${neg} MiB: o mínimo documentado de ${ref_min} MiB está errado (issue de prioridade alta)"
fi
grep -qE 'FALHA: (NEXUS-SMOKE-DONE não apareceu|smoke com falhas|QEMU terminou antes do DONE)' <<<"$out" ||
    cen_fim FALHA "o controle negativo com ${neg} MiB falhou por outro motivo"
CEN_METRICAS+=("controle_negativo_mib: $neg (o all falhou, como esperado)")

if [ "$aviso" -eq 1 ]; then
    cen_fim OK "boot, RAM recomendada e controle negativo, com AVISO de requisitos desatualizados"
fi
cen_fim OK "boot, RAM recomendada e controle negativo"
