#!/usr/bin/env bash
# Funções comuns dos tests/cenario-tN.sh (Fase 4). Para usar com "source" na VM de build (Linux).
# Variáveis opcionais: CENARIO_GUEST (outro script do convidado, usado nas mutações), EVID_DIR (outra pasta
# de evidência, para não gravar em evidencias/ durante as mutações) e as NEXUS_SMOKE_* do tests/iso-smoke.sh.
# O script do convidado imprime NEXUS-CENARIO-METRICA <chave>: <valor> e termina com NEXUS-CENARIO-OK <tn>.

cen_raiz=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=/dev/null
. "$cen_raiz/tests/lib-evidencia.sh"

# cen_init <Tn> <iso>: valida os insumos, detecta o modo (kvm ou emul) e abre o log do cenário.
cen_init() {
    CEN=$1
    CEN_ISO=${2:-}
    CEN_NOME=${CEN,,}
    [ -n "$CEN_ISO" ] || { echo "FALHA: uso: tests/cenario-$CEN_NOME.sh <iso>" >&2; exit 1; }
    CEN_GUEST=${CENARIO_GUEST:-$cen_raiz/tests/cenarios-guest/$CEN_NOME.sh}
    [ -f "$CEN_GUEST" ] || { echo "FALHA: script do convidado ausente: tests/cenarios-guest/$CEN_NOME.sh" >&2; exit 1; }
    [ -f "$CEN_ISO" ] || { echo "FALHA: ISO não encontrada: $CEN_ISO" >&2; exit 1; }
    if [ "${NEXUS_SMOKE_KVM:-1}" != 0 ] && [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
        MODO=kvm
    else
        MODO=emul
        export NEXUS_SMOKE_SMP=${NEXUS_SMOKE_SMP:-1} NEXUS_SMOKE_MEM=${NEXUS_SMOKE_MEM:-2048}
    fi
    CEN_TMP=$(mktemp -d)
    trap 'rm -rf "$CEN_TMP"' EXIT
    CEN_LOG=$CEN_TMP/log.txt
    : >"$CEN_LOG"
    CEN_METRICAS=("modo_aceleracao: $MODO")
    CEN_CMD="tests/cenario-$CEN_NOME.sh dist/$(basename "$CEN_ISO")"
    CEN_SHA=$(sha256sum "$CEN_ISO" | cut -d' ' -f1)
    export EVID_SHA=$CEN_SHA
}

# cen_exec <comando...>: roda o comando, mostra e guarda a saída no log e devolve o código dele.
cen_exec() {
    echo "\$ $*" | tee -a "$CEN_LOG"
    "$@" 2>&1 | tee -a "$CEN_LOG"
    return "${PIPESTATUS[0]}"
}

# cen_convidado <script> <nome>: roda o script no convidado (smoke <nome>) e junta a saída ao log e as métricas.
# Devolve 0 só se o iso-smoke terminou com 0 e o convidado imprimiu NEXUS-CENARIO-OK <nome>.
cen_convidado() {
    local guest=$1 nome=$2 serial rc m
    cp "$guest" "$CEN_TMP/$nome.sh"
    serial=$CEN_TMP/serial-$nome.txt
    echo "--- tests/iso-smoke.sh --extra $nome.sh <iso> $nome" | tee -a "$CEN_LOG"
    NEXUS_SMOKE_SERIAL=$serial "$cen_raiz/tests/iso-smoke.sh" --extra "$CEN_TMP/$nome.sh" "$CEN_ISO" "$nome" 2>&1 | tee -a "$CEN_LOG"
    rc=${PIPESTATUS[0]}
    echo "--- saída do convidado ($nome)" >>"$CEN_LOG"
    # A serial traz o prefixo do journal ("[ 33.9] nexus-smoke[2249]: "): sai antes de procurar os marcadores.
    tr -d '\r' <"$serial" 2>/dev/null | sed -E 's/^\[ *[0-9.]+\] nexus-smoke\[[0-9]+\]: //' |
        awk -v b="NEXUS-SMOKE-BEGIN $nome" -v e="NEXUS-SMOKE-END $nome" 'index($0, b) { f = 1 } f { print } index($0, e) { f = 0 }' >"$CEN_TMP/guest-$nome.txt"
    cat "$CEN_TMP/guest-$nome.txt" >>"$CEN_LOG"
    while IFS= read -r m; do CEN_METRICAS+=("$m"); done < <(sed -n 's/^NEXUS-CENARIO-METRICA //p' "$CEN_TMP/guest-$nome.txt")
    [ "$rc" -eq 0 ] && grep -aq "^NEXUS-CENARIO-OK $nome\$" "$CEN_TMP/guest-$nome.txt"
}

# cen_fim <OK|FALHA> <mensagem>: registra a evidência e termina o cenário.
cen_fim() {
    local res=$1 msg=$2
    echo "$res: $msg" >>"$CEN_LOG"
    evidencia_registrar "$CEN" "$MODO" "$CEN_CMD" "$CEN_LOG" "$res" "$CEN_ISO" "${CEN_METRICAS[@]}"
    if [ "$res" = OK ]; then
        echo "OK: cenário $CEN ($msg, $MODO)"
        exit 0
    fi
    echo "FALHA: cenário $CEN: $msg" >&2
    exit 1
}
