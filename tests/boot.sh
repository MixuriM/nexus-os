#!/usr/bin/env bash
# Confere o menu de boot, a tela de carregamento e o modo de demonstração da RC3 (estático):
# - menu (GRUB e syslinux): 3 entradas, na ordem, com os rótulos certos, sem contagem regressiva (GRUB set timeout=-1,
#   isolinux timeout 0), "nexus.demo=1" só na entrada de demonstração, padrão na primeira;
# - linha do kernel em live-build/auto/config: quiet splash plymouth.ignore-serial-consoles e console=... no fim;
# - Plymouth: lista de pacotes, tema nexus-os (módulo two-step, logo, quadros contínuos) e hook 0650;
# - demonstração: hook 0700, autostart, demo/nexus-demo.sh (bash -n e shellcheck) e o nexus-demo-boot rodado de verdade
#   com NEXUS_CMDLINE e NEXUS_DEMO_TERMINAL falsos.
# Estático: roda no Git Bash e no Linux. Uso: tests/boot.sh
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
export LC_ALL=C.UTF-8

erros=0
fail() { echo "FALHA: $*" >&2; erros=$((erros + 1)); }
tem() { grep -qxF -- "$2" "$1" 2>/dev/null; }

boot='live-build/config/bootloaders'
inc='live-build/config/includes.chroot'
grub=$boot/grub-pc/grub.cfg
live=$boot/syslinux_common/live.cfg.in
rotulo1="Iniciar o Nexus OS"
rotulo2="Iniciar o Nexus OS (modo de demonstração)"
rotulo3="Nexus OS (modo de compatibilidade)"
falha_nova="quiet splash plymouth.ignore-serial-consoles"

# 1. GRUB (UEFI): 3 menuentry na ordem, padrão 0, sem contagem.
mapfile -t entradas < <(grep -oE '^menuentry "[^"]*"' "$grub" 2>/dev/null | sed -E 's/^menuentry "(.*)"$/\1/')
[ "${#entradas[@]}" -eq 3 ] || fail "$grub deveria ter 3 menuentry, achei ${#entradas[@]}"
[ "${entradas[0]:-}" = "$rotulo1" ] || fail "$grub: 1ª entrada deveria ser '$rotulo1'"
[ "${entradas[1]:-}" = "$rotulo2" ] || fail "$grub: 2ª entrada deveria ser '$rotulo2'"
[ "${entradas[2]:-}" = "$rotulo3" ] || fail "$grub: 3ª entrada deveria ser '$rotulo3'"
grep -qF "menuentry \"$rotulo1\" --hotkey=n {" "$grub" 2>/dev/null || fail "$grub: entrada 1 sem --hotkey=n"
grep -qE '^[[:space:]]+linux[[:space:]]+@KERNEL_LIVE@ @APPEND_LIVE@$' "$grub" 2>/dev/null || fail "$grub: entrada 1 sem a linha 'linux @KERNEL_LIVE@ @APPEND_LIVE@'"
grep -qE '^[[:space:]]+linux[[:space:]]+@KERNEL_LIVE@ @APPEND_LIVE@ nexus\.demo=1$' "$grub" 2>/dev/null || fail "$grub: entrada 2 sem 'linux @KERNEL_LIVE@ @APPEND_LIVE@ nexus.demo=1'"
grep -qE '^[[:space:]]+linux[[:space:]]+@KERNEL_LIVE@ @LB_BOOTAPPEND_LIVE_FAILSAFE@$' "$grub" 2>/dev/null || fail "$grub: entrada 3 sem a linha de compatibilidade"
[ "$(grep -c 'nexus\.demo=1' "$grub" 2>/dev/null)" -eq 1 ] || fail "$grub: nexus.demo=1 deveria aparecer só 1 vez (entrada 2)"
tem "$boot/grub-pc/config.cfg" 'set timeout=-1' || fail "$boot/grub-pc/config.cfg sem 'set timeout=-1' (menu sem contagem)"
tem "$boot/grub-pc/config.cfg" 'set default=0' || fail "$boot/grub-pc/config.cfg sem 'set default=0'"

# 2. syslinux (BIOS): 3 labels na ordem, "menu default" só no primeiro, timeout 0.
mapfile -t labels < <(grep -E '^label ' "$live" 2>/dev/null)
[ "${labels[*]:-}" = "label live-@FLAVOUR@ label live-@FLAVOUR@-demo label live-@FLAVOUR@-failsafe" ] \
    || fail "$live: labels deveriam ser live-@FLAVOUR@, -demo e -failsafe, nessa ordem"
grep -qF "menu label ^$rotulo1" "$live" 2>/dev/null || fail "$live: sem 'menu label ^$rotulo1'"
tem "$live" "	menu label $rotulo2" || fail "$live: sem 'menu label $rotulo2'"
tem "$live" "	menu label $rotulo3" || fail "$live: sem 'menu label $rotulo3'"
[ "$(grep -c 'menu default' "$live" 2>/dev/null)" -eq 1 ] || fail "$live: 'menu default' deveria aparecer 1 vez"
awk '/^label /{n++} /menu default/{print n}' "$live" 2>/dev/null | grep -qx 1 || fail "$live: 'menu default' fora da 1ª entrada"
tem "$live" "	append @APPEND_LIVE@ nexus.demo=1" || fail "$live: entrada de demonstração sem 'append @APPEND_LIVE@ nexus.demo=1'"
[ "$(grep -c 'nexus\.demo=1' "$live" 2>/dev/null)" -eq 1 ] || fail "$live: nexus.demo=1 deveria aparecer só 1 vez"
tem "$boot/isolinux/isolinux.cfg" 'timeout 0' || fail "$boot/isolinux/isolinux.cfg sem 'timeout 0' (menu sem contagem)"
! grep -qE '^timeout [1-9]' "$boot/isolinux/isolinux.cfg" 2>/dev/null || fail "$boot/isolinux/isolinux.cfg ainda tem contagem"
tem "$boot/syslinux_common/stdmenu.cfg" 'menu tabmsg Setas escolhem, Enter inicia, Tab edita' || fail "stdmenu.cfg sem o menu tabmsg novo"

# 3. Linha do kernel (auto/config): entradas 1 e 2 e failsafe.
cfg='live-build/auto/config'
grep -qF -- '--bootappend-live "boot=live components quiet splash plymouth.ignore-serial-consoles vt.global_cursor_default=0 console=tty0 console=ttyS0,115200n8"' "$cfg" 2>/dev/null \
    || fail "$cfg: --bootappend-live sem 'quiet splash plymouth.ignore-serial-consoles vt.global_cursor_default=0' e console=... no fim"
if grep -qE -- '--bootappend-live-failsafe .*nosplash' "$cfg" 2>/dev/null; then
    grep -qF 'entrada 3 voltou a nosplash' docs/demo.md 2>/dev/null || fail "$cfg: failsafe com nosplash sem a nota 'entrada 3 voltou a nosplash' em docs/demo.md"
else
    grep -qF -- "--bootappend-live-failsafe \"boot=live components memtest noapic noapm nodma nomce nosmp $falha_nova vga=788\"" "$cfg" 2>/dev/null \
        || fail "$cfg: --bootappend-live-failsafe sem o valor padrão do live-build trocando nosplash por '$falha_nova'"
fi

# 4. Plymouth: lista de pacotes, tema e hook.
tem live-build/config/package-lists/nexus-boot.list.chroot plymouth || fail "nexus-boot.list.chroot sem plymouth"
tem live-build/config/package-lists/nexus-boot.list.chroot plymouth-themes || fail "nexus-boot.list.chroot sem plymouth-themes (traz o plugin two-step)"
tema=$inc/usr/share/plymouth/themes/nexus-os
for k in 'ModuleName=two-step' 'ImageDir=/usr/share/plymouth/themes/nexus-os' 'BackgroundStartColor=0x14152a' 'BackgroundEndColor=0x14152a'; do
    tem "$tema/nexus-os.plymouth" "$k" || fail "$tema/nexus-os.plymouth sem '$k'"
done
for k in 'Name=Nexus OS' '[two-step]'; do
    tem "$tema/nexus-os.plymouth" "$k" || fail "$tema/nexus-os.plymouth sem '$k'"
done
png_ok() { [ "$(od -An -tx1 -N8 -- "$1" 2>/dev/null | tr -d ' \n')" = 89504e470d0a1a0a ]; }
for f in watermark animation-0001; do
    png_ok "$tema/$f.png" || fail "$tema/$f.png ausente ou sem assinatura PNG"
done
quadros=$(find "$tema" -maxdepth 1 -name 'throbber-*.png' 2>/dev/null | wc -l)
{ [ "$quadros" -ge 24 ] && [ "$quadros" -le 36 ]; } || fail "$tema deveria ter de 24 a 36 quadros throbber-NNNN.png, achei $quadros"
for i in $(seq 1 "$quadros"); do
    n=$(printf '%04d' "$i")
    png_ok "$tema/throbber-$n.png" || fail "$tema/throbber-$n.png ausente ou sem assinatura PNG (numeração contínua a partir de 0001)"
done
hook='live-build/config/hooks/live'
for h in 0650-nexus-splash 0700-nexus-demo; do
    [ -f "$hook/$h.hook.chroot" ] || { fail "$hook/$h.hook.chroot ausente"; continue; }
    grep -qxF 'set -e' "$hook/$h.hook.chroot" || fail "$hook/$h.hook.chroot sem 'set -e'"
done
grep -qF 'plymouth-set-default-theme' "$hook/0650-nexus-splash.hook.chroot" 2>/dev/null || fail "hook 0650 não define o tema padrão"
# shellcheck disable=SC2016  # $img é texto do hook, não variável deste teste
grep -qF 'themes/spinner/$img.png' "$hook/0650-nexus-splash.hook.chroot" 2>/dev/null || fail "hook 0650 não copia o lock.png do tema spinner (sem ele o two-step não mostra o tema)"
grep -qF 'logo-text-version-64.png' "$hook/0650-nexus-splash.hook.chroot" 2>/dev/null || fail "hook 0650 não troca o logo do Debian que o hook do initramfs usa como watermark"
grep -qF 'lsinitramfs' "$hook/0650-nexus-splash.hook.chroot" 2>/dev/null || fail "hook 0650 não confere o tema no initramfs (lsinitramfs)"
grep -qF '/usr/local/bin/nexus-demo' "$hook/0700-nexus-demo.hook.chroot" 2>/dev/null || fail "hook 0700 sem o link /usr/local/bin/nexus-demo"

# 5. Demonstração: arquivos, sintaxe, shellcheck e o nexus-demo-boot de verdade.
demo=demo/nexus-demo.sh
[ -f "$demo" ] || fail "$demo ausente"
if [ -f "$demo" ]; then
    bash -n "$demo" || fail "$demo com erro de sintaxe"
    grep -qxF 'set -euo pipefail' "$demo" || fail "$demo sem 'set -euo pipefail'"
    if command -v shellcheck >/dev/null; then
        shellcheck -x "$demo" || fail "shellcheck acusou problema em $demo"
    else
        echo "AVISO: sem shellcheck, $demo só com bash -n" >&2
    fi
fi
grep -qE 'for pasta in .*\bdemo\b' scripts/stage-iso-files.sh 2>/dev/null || fail "scripts/stage-iso-files.sh não copia a pasta demo"
grep -qE 'git ls-files .* demo ' scripts/stage-iso-files.sh 2>/dev/null || fail "scripts/stage-iso-files.sh não lista a pasta demo no git ls-files"
auto=$inc/etc/xdg/autostart/nexus-demo-boot.desktop
for k in 'Type=Application' 'Exec=/usr/local/bin/nexus-demo-boot' 'OnlyShowIn=XFCE;'; do
    tem "$auto" "$k" || fail "$auto sem '$k'"
done
boot_sh=$inc/usr/local/bin/nexus-demo-boot
if [ -f "$boot_sh" ]; then
    bash -n "$boot_sh" || fail "$boot_sh com erro de sintaxe"
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    printf '#!/bin/sh\necho "$@" >>"%s/chamadas"\n' "$tmp" >"$tmp/terminal"
    chmod +x "$tmp/terminal"
    echo 'boot=live components quiet splash console=tty0' >"$tmp/sem"
    echo 'boot=live components quiet splash console=tty0 nexus.demo=1' >"$tmp/com"
    saida=$(NEXUS_CMDLINE="$tmp/sem" NEXUS_DEMO_TERMINAL="$tmp/terminal" bash "$boot_sh" 2>&1)
    rc=$?
    [ "$rc" -eq 0 ] || fail "nexus-demo-boot sem nexus.demo=1 saiu com $rc"
    [ -z "$saida" ] || fail "nexus-demo-boot sem nexus.demo=1 imprimiu: $saida"
    [ ! -e "$tmp/chamadas" ] || fail "nexus-demo-boot sem nexus.demo=1 abriu o terminal"
    NEXUS_CMDLINE="$tmp/com" NEXUS_DEMO_TERMINAL="$tmp/terminal" bash "$boot_sh" >/dev/null 2>&1
    [ "$(wc -l <"$tmp/chamadas" 2>/dev/null || echo 0)" -eq 1 ] || fail "nexus-demo-boot com nexus.demo=1 deveria abrir o terminal 1 vez"
    grep -qF 'nexus-demo' "$tmp/chamadas" 2>/dev/null || fail "nexus-demo-boot não executou nexus-demo no terminal"
    grep -qF -- '--maximize' "$tmp/chamadas" 2>/dev/null || fail "nexus-demo-boot sem --maximize"
    grep -qF 'Demonstração do Nexus OS' "$tmp/chamadas" 2>/dev/null || fail "nexus-demo-boot sem o título 'Demonstração do Nexus OS'"
else
    fail "$boot_sh ausente"
fi

if [ "$erros" -gt 0 ]; then
    echo "FALHA: tests/boot.sh, $erros erro(s)" >&2
    exit 1
fi
echo "OK: tests/boot.sh (menu de 3 entradas sem contagem, linha do kernel, tema Plymouth com $quadros quadros, hooks, nexus-demo e nexus-demo-boot)"
