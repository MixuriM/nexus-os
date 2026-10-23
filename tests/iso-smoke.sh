#!/usr/bin/env bash
# Smoke test dentro da ISO: inicia a ISO no QEMU com um CD extra (rótulo NEXUS_SMOKE) que diz quais
# testes rodar. O serviço nexus-smoke da ISO roda os testes, imprime os marcadores na serial e
# desliga a máquina. Veja docs/integracao-iso.md.
# Uso: tests/iso-smoke.sh [--extra arq.sh]... <iso> <nome[,nome]...|all>
# Ambiente: NEXUS_SMOKE_LIMIT (segundos), NEXUS_SMOKE_MEM (MiB, padrão 4096), NEXUS_SMOKE_SMP (vCPU, padrão 2),
# NEXUS_SMOKE_SERIAL (arquivo onde guardar a serial inteira, para diagnóstico).
set -euo pipefail

fail() { echo "FALHA: $*" >&2; exit 1; }

extras=()
while [ $# -gt 0 ]; do
    case $1 in
        --extra)
            [ $# -ge 2 ] || fail "--extra precisa de um arquivo"
            [ -f "$2" ] || fail "arquivo --extra não encontrado: $2"
            [[ $(basename "$2") =~ ^[A-Za-z0-9_-]+\.sh$ ]] || fail "--extra precisa ser um .sh com nome simples: $2"
            extras+=("$2")
            shift 2
            ;;
        *) break ;;
    esac
done

[ $# -eq 2 ] || fail "uso: tests/iso-smoke.sh [--extra arq.sh]... <iso> <nome[,nome]...|all>"
iso=$1
nomes=$2
[ -f "$iso" ] || fail "ISO não encontrada: $iso"
[[ $nomes =~ ^[A-Za-z0-9_-]+(,[A-Za-z0-9_-]+)*$ ]] || fail "lista de testes inválida: $nomes"
for cmd in qemu-system-x86_64 xorriso; do
    command -v "$cmd" >/dev/null || fail "$cmd não instalado"
done

if [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
    accel=(-enable-kvm -cpu host)
    limit_padrao=900
    modo="com KVM"
else
    accel=(-cpu max)
    limit_padrao=2400
    modo="sem KVM (emulação por software)"
fi
limit=${NEXUS_SMOKE_LIMIT:-$limit_padrao}
mem=${NEXUS_SMOKE_MEM:-4096}
smp=${NEXUS_SMOKE_SMP:-2}
[[ $limit =~ ^[0-9]+$ ]] || fail "NEXUS_SMOKE_LIMIT inválido: $limit"
[[ $mem =~ ^[0-9]+$ ]] || fail "NEXUS_SMOKE_MEM inválido: $mem"
[[ $smp =~ ^[0-9]+$ ]] || fail "NEXUS_SMOKE_SMP inválido: $smp"

tmp=$(mktemp -d)
qpid=
dpid=
# shellcheck disable=SC2317  # chamada indiretamente pelo trap
cleanup() {
    if [ -n "$qpid" ]; then
        kill "$qpid" 2>/dev/null || true
        wait "$qpid" 2>/dev/null || true
    fi
    if [ -n "$dpid" ]; then
        kill "$dpid" 2>/dev/null || true
    fi
    [ -n "${NEXUS_SMOKE_SERIAL:-}" ] && [ -f "$tmp/serial.log" ] && cp "$tmp/serial.log" "$NEXUS_SMOKE_SERIAL"
    rm -rf "$tmp"
}
trap cleanup EXIT

# CD de comando: testes.txt (um nome por linha) e extra/ com os scripts adicionais.
mkdir -p "$tmp/cd/extra"
printf '%s\n' "${nomes//,/$'\n'}" >"$tmp/cd/testes.txt"
for f in "${extras[@]}"; do
    cp "$f" "$tmp/cd/extra/"
done
xorriso -as mkisofs -quiet -V NEXUS_SMOKE -r -J -o "$tmp/smoke.iso" "$tmp/cd" >/dev/null 2>"$tmp/xorriso.err" \
    || fail "xorriso não criou o CD: $(tail -n 3 "$tmp/xorriso.err")"

serial="$tmp/serial.log"
: >"$serial"
# Monitor do QEMU por FIFOs dentro do mktemp (modo 0700): só o usuário que roda o teste alcança.
# Não usar TCP: qualquer usuário local conseguiria mandar comandos ao QEMU.
mkfifo "$tmp/mon.in" "$tmp/mon.out"
exec 3<>"$tmp/mon.in"
cat "$tmp/mon.out" >/dev/null &
dpid=$!
# Sem rede (-nic none): nada pode baixar. A ISO é o CD de índice 2 (boot d); o CD de comando, o 3.
qemu-system-x86_64 "${accel[@]}" -m "$mem" -smp "$smp" \
    -drive "file=$iso,media=cdrom,readonly=on,index=2" \
    -drive "file=$tmp/smoke.iso,media=cdrom,readonly=on,index=3" \
    -boot d -nic none -display none -serial "file:$serial" \
    -chardev "pipe,id=mon,path=$tmp/mon" -mon chardev=mon,mode=readline 2>"$tmp/qemu.err" &
qpid=$!

ultimas() {
    echo "--- últimas 15 linhas da serial ---" >&2
    tr -d '\r' <"$serial" | tail -n 15 >&2 || true
}

# O menu do isolinux espera uma tecla (timeout 0): manda Enter nos primeiros 60 s.
start=$SECONDS
done_line=
while [ $((SECONDS - start)) -lt "$limit" ]; do
    done_line=$(tr -d '\r' <"$serial" | grep -aoE 'NEXUS-SMOKE-DONE [0-9]+ [0-9]+' | tail -n 1 || true)
    [ -z "$done_line" ] || break
    if ! kill -0 "$qpid" 2>/dev/null; then
        ultimas
        fail "QEMU terminou antes do DONE: $(tail -n 3 "$tmp/qemu.err")"
    fi
    if [ $((SECONDS - start)) -lt 60 ]; then
        printf 'sendkey ret\n' >&3
    fi
    sleep 3
done
total_s=$((SECONDS - start))
if [ -z "$done_line" ]; then
    ultimas
    fail "NEXUS-SMOKE-DONE não apareceu em ${limit} s, $modo"
fi

read -r _ total falhas <<<"$done_line"
texto=$(tr -d '\r' <"$serial")
ruins=$(grep -aoE 'NEXUS-SMOKE-END [A-Za-z0-9_-]+ [0-9]+' <<<"$texto" | awk '$3 != 0' || true)
if [ "$falhas" -ne 0 ] || [ "$total" -lt 1 ] || [ -n "$ruins" ]; then
    ultimas
    fail "smoke com falhas: DONE $total $falhas${ruins:+, END com erro: ${ruins//$'\n'/; }}"
fi
# Cada teste pedido precisa ter terminado com código 0 (um runner que ignora a lista não passa).
if [ "$nomes" != all ]; then
    IFS=, read -ra pedidos <<<"$nomes"
    for n in "${pedidos[@]}"; do
        grep -aqE "NEXUS-SMOKE-END $n 0\$" <<<"$texto" || { ultimas; fail "sem END $n 0 na serial"; }
    done
fi

tempos=$(grep -aoE 'NEXUS-SMOKE-TIME [A-Za-z0-9_-]+ [0-9]+' <<<"$texto" | awk '{printf "%s%s=%ss", s, $2, $3; s=", "}')
echo "OK: $total teste(s) sem falha em ${total_s} s, $modo${tempos:+, por teste: $tempos}"
