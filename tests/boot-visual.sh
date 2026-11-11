#!/usr/bin/env bash
# Captura de tela do boot da ISO no QEMU, para conferir a tela de carregamento (RC3) olhando os quadros.
# Espera 8 s no menu (que espera para sempre) e tira menu.png, escolhe a entrada (1, 2 ou 3) com as setas e Enter, e tira
# uma captura por segundo durante 50 s em quadro-NN.png. Nas entradas 1 e 2 espera o "login:" na serial e imprime o tempo.
# Na entrada 3 não há serial (modo de compatibilidade): só captura.
# Variáveis: BOOT_VISUAL_ESC=<segundo> manda a tecla Esc nesse segundo depois do Enter (a tela de carregamento mostra o texto);
# BOOT_VISUAL_MEM (padrão 2560 MiB). Com --uefi usa o firmware OVMF (pacote ovmf).
# Uso: tests/boot-visual.sh [--uefi] <iso> <entrada 1|2|3> <pasta de saída>   (na VM de build, com qemu-system-x86)
set -euo pipefail

fail() { echo "FALHA: $*" >&2; exit 1; }

uefi=0
if [ "${1:-}" = --uefi ]; then
    uefi=1
    shift
fi
[ $# -eq 3 ] || fail "uso: tests/boot-visual.sh [--uefi] <iso> <entrada 1|2|3> <pasta de saída>"
iso=$1
entrada=$2
saida=$3
[ -f "$iso" ] || fail "ISO não encontrada: $iso"
[[ $entrada =~ ^[123]$ ]] || fail "entrada inválida: $entrada (use 1, 2 ou 3)"
esc=${BOOT_VISUAL_ESC:-}
[ -z "$esc" ] || [[ $esc =~ ^[0-9]+$ ]] || fail "BOOT_VISUAL_ESC inválido: $esc"
mem=${BOOT_VISUAL_MEM:-2560}
command -v qemu-system-x86_64 >/dev/null || fail "qemu-system-x86_64 não instalado"
mkdir -p "$saida"
saida=$(cd "$saida" && pwd)
rm -f "$saida"/quadro-*.png "$saida"/menu*.png

bios=()
firmware=BIOS
if [ "$uefi" = 1 ]; then
    fw=
    for f in /usr/share/ovmf/OVMF.fd /usr/share/OVMF/OVMF.fd; do
        if [ -f "$f" ]; then fw=$f; break; fi
    done
    [ -n "$fw" ] || fail "firmware OVMF não encontrado (instale o pacote ovmf)"
    bios=(-bios "$fw")
    firmware=UEFI
fi
if [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
    accel=(-enable-kvm -cpu host)
    modo="com KVM"
else
    accel=(-cpu max)
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
    if [ -n "$dpid" ]; then kill "$dpid" 2>/dev/null || true; fi
    rm -rf "$tmp"
}
trap cleanup EXIT

serial=$tmp/serial.log
: >"$serial"
# Monitor do QEMU por FIFOs dentro do mktemp (modo 0700): só o usuário que roda o teste alcança.
mkfifo "$tmp/mon.in" "$tmp/mon.out"
exec 3<>"$tmp/mon.in"
cat "$tmp/mon.out" >/dev/null &
dpid=$!
qemu-system-x86_64 "${accel[@]}" "${bios[@]}" -m "$mem" -smp 2 -cdrom "$iso" -boot d -nic none -vga std -display none \
    -serial "file:$serial" -chardev "pipe,id=mon,path=$tmp/mon" -mon chardev=mon,mode=readline 2>"$tmp/qemu.err" &
qpid=$!

tecla() { printf 'sendkey %s\n' "$1" >&3; }
captura() {
    printf 'screendump %s -f png\n' "$1" >&3
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        if [ -s "$1" ]; then return 0; fi
        sleep 0.2
    done
    return 0
}
tem_login() { tr -d '\r' <"$serial" | grep -aqE '[[:alnum:]-]+ login:'; }

sleep 8
kill -0 "$qpid" 2>/dev/null || fail "QEMU terminou antes do menu: $(tail -n 3 "$tmp/qemu.err")"
captura "$saida/menu.png"
for _ in $(seq 2 "$entrada"); do
    tecla down
    sleep 0.5
done
captura "$saida/menu-selecionado.png"
tecla ret
inicio=$SECONDS
login=
for i in $(seq 1 50); do
    captura "$saida/quadro-$(printf '%02d' "$i").png"
    if [ -n "$esc" ] && [ "$i" -eq "$esc" ]; then tecla esc; fi
    if [ -z "$login" ] && [ "$entrada" != 3 ] && tem_login; then login=$((SECONDS - inicio)); fi
    # uma captura por segundo: dorme só o que falta do segundo
    falta=$((i - (SECONDS - inicio)))
    if [ "$falta" -gt 0 ]; then sleep "$falta"; fi
done
if [ "$entrada" != 3 ] && [ -z "$login" ]; then
    while [ $((SECONDS - inicio)) -lt 150 ]; do
        if tem_login; then
            login=$((SECONDS - inicio))
            break
        fi
        sleep 2
    done
fi
n=$(find "$saida" -name 'quadro-*.png' -size +0 | wc -l)
[ "$n" -ge 40 ] || fail "poucos quadros capturados: $n de 50"
if [ "$entrada" = 3 ]; then
    echo "OK: entrada 3, $n quadros em $saida, $modo, $firmware"
elif [ -n "$login" ]; then
    echo "OK: entrada $entrada, login: em $login s depois do Enter, $n quadros em $saida, $modo, $firmware"
else
    tail -n 10 "$serial" >&2 || true
    fail "login: não apareceu na serial em 150 s depois do Enter, entrada $entrada, $modo, $firmware"
fi
