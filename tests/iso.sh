#!/usr/bin/env bash
# Teste da ISO: confere o SHA256 e inicia a ISO em QEMU até aparecer "login:" na serial.
# Uso: tests/iso.sh <iso>   (o arquivo <iso>.sha256 precisa estar ao lado)
# Ambiente: NEXUS_ISO_MEM (MiB, padrão 2048: o desktop da F3.15 roda com 1024 MiB no mínimo, veja docs/gui.md).
set -euo pipefail

fail() { echo "FALHA: $*" >&2; exit 1; }

[ $# -eq 1 ] || fail "uso: tests/iso.sh <iso>"
iso=$1
[ -f "$iso" ] || fail "ISO não encontrada: $iso"
[ -f "$iso.sha256" ] || fail "arquivo SHA256 não encontrado: $iso.sha256"
command -v qemu-system-x86_64 >/dev/null || fail "qemu-system-x86_64 não instalado"
[[ ${NEXUS_ISO_MEM:-2048} =~ ^[0-9]+$ ]] || fail "NEXUS_ISO_MEM inválido: $NEXUS_ISO_MEM"

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
    rm -rf "$tmp"
}
trap cleanup EXIT

serial="$tmp/serial.log"
: >"$serial"
# Monitor do QEMU por FIFOs dentro do mktemp (modo 0700): só o usuário que roda o teste alcança.
# Não usar TCP: qualquer usuário local conseguiria mandar comandos ao QEMU.
mkfifo "$tmp/mon.in" "$tmp/mon.out"
exec 3<>"$tmp/mon.in"
cat "$tmp/mon.out" >/dev/null &
dpid=$!
qemu-system-x86_64 "${accel[@]}" -m "${NEXUS_ISO_MEM:-2048}" -smp 2 -cdrom "$iso" -boot d \
    -display none -serial "file:$serial" \
    -chardev "pipe,id=mon,path=$tmp/mon" -mon chardev=mon,mode=readline 2>"$tmp/qemu.err" &
qpid=$!

# O menu do isolinux tem contagem de 5 s (timeout 50): manda Enter nos primeiros 60 s para adiantar o boot.
start=$SECONDS
while [ $((SECONDS - start)) -lt "$limit" ]; do
    kill -0 "$qpid" 2>/dev/null || fail "QEMU terminou antes do login: $(tail -n 3 "$tmp/qemu.err")"
    if [ $((SECONDS - start)) -lt 60 ]; then
        printf 'sendkey ret\n' >&3
    fi
    # Sem âncora no fim da linha: com KVM o kernel imprime erros de fd0 logo após o prompt.
    linha=$(tr -d '\r' <"$serial" | grep -aE '[[:alnum:]-]+ login:' | tail -n 1 || true)
    if [ -n "$linha" ]; then
        echo "OK: ISO chegou ao login (\"$linha\") em $((SECONDS - start)) s, $modo, SHA256 conferido"
        exit 0
    fi
    sleep 3
done

echo "--- últimas linhas da serial ---" >&2
tail -n 10 "$serial" >&2 || true
fail "login: não apareceu em ${limit} s, $modo"
