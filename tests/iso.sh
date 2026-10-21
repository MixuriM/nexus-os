#!/usr/bin/env bash
# Teste da ISO: confere o SHA256 e inicia a ISO em QEMU até aparecer "login:" na serial.
# Uso: tests/iso.sh <iso>   (o arquivo <iso>.sha256 precisa estar ao lado)
set -euo pipefail

fail() { echo "FALHA: $*" >&2; exit 1; }

[ $# -eq 1 ] || fail "uso: tests/iso.sh <iso>"
iso=$1
[ -f "$iso" ] || fail "ISO não encontrada: $iso"
[ -f "$iso.sha256" ] || fail "arquivo SHA256 não encontrado: $iso.sha256"
command -v qemu-system-x86_64 >/dev/null || fail "qemu-system-x86_64 não instalado"

(cd "$(dirname "$iso")" && sha256sum -c "$(basename "$iso.sha256")" >/dev/null 2>&1) \
    || fail "SHA256 da ISO não confere com $iso.sha256"

if [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
    accel=(-enable-kvm -cpu host)
    limit=300
    modo="com KVM"
else
    accel=(-cpu max)
    limit=900
    modo="sem KVM (emulação por software)"
fi

tmp=$(mktemp -d)
qpid=
# shellcheck disable=SC2317  # chamada indiretamente pelo trap
cleanup() {
    if [ -n "$qpid" ]; then
        kill "$qpid" 2>/dev/null || true
        wait "$qpid" 2>/dev/null || true
    fi
    rm -rf "$tmp"
}
trap cleanup EXIT

serial="$tmp/serial.log"
: >"$serial"
port=$((20000 + RANDOM % 20000))
qemu-system-x86_64 "${accel[@]}" -m 1024 -smp 2 -cdrom "$iso" -boot d \
    -display none -serial "file:$serial" \
    -monitor "tcp:127.0.0.1:$port,server,nowait" 2>"$tmp/qemu.err" &
qpid=$!

# O menu do isolinux espera uma tecla (timeout 0): manda Enter nos primeiros 60 s.
start=$SECONDS
while [ $((SECONDS - start)) -lt "$limit" ]; do
    kill -0 "$qpid" 2>/dev/null || fail "QEMU terminou antes do login: $(tail -n 3 "$tmp/qemu.err")"
    if [ $((SECONDS - start)) -lt 60 ]; then
        ( exec 3<>"/dev/tcp/127.0.0.1/$port" && printf 'sendkey ret\n' >&3 ) 2>/dev/null || true
    fi
    linha=$(tr -d '\r' <"$serial" | grep -aE 'login:[[:space:]]*$' | tail -n 1 || true)
    if [ -n "$linha" ]; then
        echo "OK: ISO chegou ao login (\"$linha\") em $((SECONDS - start)) s, $modo, SHA256 conferido"
        exit 0
    fi
    sleep 3
done

echo "--- últimas linhas da serial ---" >&2
tail -n 10 "$serial" >&2 || true
fail "login: não apareceu em ${limit} s, $modo"
