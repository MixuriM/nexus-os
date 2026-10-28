#!/usr/bin/env bash
# Teste estático dos atalhos do desktop (F3.16): os 10 arquivos nexus-*.desktop existem no menu e na
# área de trabalho (cópias iguais), passam em desktop-file-validate, têm chaves obrigatórias, texto em
# português, Exec que aponta para um comando versionado ou do pacote, e nenhum fica ignorado pelo git.
# Roda no Git Bash do Windows e em Linux. Uso: tests/atalhos.sh
set -uo pipefail

raiz=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$raiz" || exit 1
export LC_ALL=C.UTF-8

erros=0
fail() { echo "FALHA: $*" >&2; erros=$((erros + 1)); }

inc=live-build/config/includes.chroot
menu=$inc/usr/share/applications
area=$inc/etc/skel/Desktop
esperados=(
    nexus-terminal nexus-virt-manager nexus-sdn-lab
    nexus-vnf-up nexus-vnf-status nexus-vnf-down
    nexus-clab-deploy nexus-clab-destroy nexus-docs nexus-configuracoes
)

valor() { grep -m1 "^$2=" "$1" | cut -d= -f2- | tr -d '\r'; }

if command -v desktop-file-validate >/dev/null; then
    validador=1
else
    validador=0
fi

for n in "${esperados[@]}"; do
    f=$menu/$n.desktop
    c=$area/$n.desktop
    [ -f "$f" ] || { fail "atalho ausente no menu: $f"; continue; }
    [ -f "$c" ] || fail "cópia ausente na área de trabalho: $c"
    { [ ! -f "$c" ] || cmp -s "$f" "$c"; } || fail "cópia diferente do menu: $c"
    if [ "$validador" -eq 1 ]; then
        saida=$(desktop-file-validate "$f" 2>&1) || fail "desktop-file-validate: $saida"
    fi
    for k in Type Name Exec Icon Categories; do
        [ -n "$(valor "$f" "$k")" ] || fail "$f sem a chave $k"
    done
    [ "$(valor "$f" Type)" = Application ] || fail "$f com Type diferente de Application"
    case $(valor "$f" Categories) in *X-Nexus-OS*) ;; *) fail "$f fora da categoria X-Nexus-OS" ;; esac
    grep -qE '(^|[^[:alpha:]])(de|do|da|para|com|em|na|no)([^[:alpha:]]|$)' <<<"$(valor "$f" Comment)" \
        || fail "$f com Comment ausente ou fora do português"
    # Exec: cada palavra que é comando conhecido precisa existir no repo ou ser de um pacote da lista.
    for w in $(valor "$f" Exec | tr -d '"'); do
        case $w in
            nexus-atalho) [ -f "$inc/usr/local/bin/nexus-atalho" ] || fail "$f: nexus-atalho não versionado" ;;
            nexus-vnf) [ -f nfv/nexus-vnf.sh ] || fail "$f: nfv/nexus-vnf.sh ausente" ;;
            nexus-sdn) [ -f sdn/lab-ovs.sh ] || fail "$f: sdn/lab-ovs.sh ausente" ;;
            /usr/share/nexus-os/labs/*) [ -f "${w#/usr/share/nexus-os/}" ] || fail "$f: ${w#/usr/share/nexus-os/} ausente" ;;
            /usr/share/nexus-os/docs-html/*) [ -f "$inc/usr/local/bin/nexus-docs-html" ] || fail "$f: gerador nexus-docs-html não versionado" ;;
            xfce4-terminal | virt-manager | thunar | firefox-esr | xfce4-settings-manager | containerlab | sudo) ;;
        esac
    done
done

grep -qE '^\s*uri_default\s*=\s*"qemu:///system"' "$inc/etc/libvirt/libvirt.conf" 2>/dev/null \
    || fail "$inc/etc/libvirt/libvirt.conf sem uri_default = \"qemu:///system\""
[ -f "$inc/etc/xdg/menus/applications-merged/nexus-os.menu" ] || fail "menu Nexus OS ausente (nexus-os.menu)"
[ -f "$inc/usr/share/desktop-directories/nexus-os.directory" ] || fail "nexus-os.directory ausente"

# Programas padrão por tipo de arquivo (mimeapps.list) e documentação em HTML offline.
mime=$inc/etc/xdg/mimeapps.list
if [ -f "$mime" ]; then
    for par in text/markdown=org.xfce.mousepad.desktop text/plain=org.xfce.mousepad.desktop         application/pdf=org.gnome.Evince.desktop image/png=org.xfce.ristretto.desktop text/html=firefox-esr.desktop; do
        grep -qxF "$par" "$mime" || fail "$mime sem $par"
    done
else
    fail "mimeapps.list ausente: $mime"
fi
[ -f "$inc/usr/local/bin/nexus-docs-html" ] || fail "gerador da documentação em HTML ausente (nexus-docs-html)"
lista=live-build/config/package-lists/nexus-desktop.list.chroot
for pacote in mousepad evince ristretto file-roller galculator xfce4-screenshooter python3-markdown     libreoffice-writer libreoffice-calc libreoffice-impress vlc wireshark gimp inkscape keepassxc remmina     tcpdump iperf3 nmap firefox-esr-l10n-pt-br libreoffice-l10n-pt-br locales; do
    grep -qxF "$pacote" "$lista" || fail "$pacote fora de $lista"
done
for pacote in thunderbird gparted; do
    ! grep -qxF "$pacote" "$lista" || fail "$pacote não deveria estar em $lista (fora do escopo decidido)"
done

# Nenhum .desktop (nem o wrapper) pode estar ignorado pelo .gitignore.
while IFS= read -r a; do
    git check-ignore -q -- "$a" && fail "ignorado pelo .gitignore: $a"
done < <(find "$inc" \( -name '*.desktop' -o -name nexus-atalho \) 2>/dev/null)

if [ "$erros" -ne 0 ]; then
    echo "FALHA: tests/atalhos.sh com $erros erro(s)" >&2
    exit 1
fi
if [ "$validador" -eq 1 ]; then
    echo "OK: tests/atalhos.sh (${#esperados[@]} atalhos, menu e área de trabalho, desktop-file-validate)"
else
    echo "AVISO: tests/atalhos.sh sem desktop-file-validate: só chaves obrigatórias conferidas (${#esperados[@]} atalhos)"
fi
