#!/usr/bin/env bash
# Confere a identidade visual do Nexus OS (F3.17): os arquivos existem, cada um está em docs/branding.md com a
# licença preenchida, os SVG são XML bem formado, os PNG têm o tamanho certo, "Nexus OS" aparece no login e
# na sessão, o /etc/os-release não muda e nenhum arquivo está ignorado pelo .gitignore.
# Estático: roda no Git Bash e no Linux. Uso: tests/identidade.sh
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
export LC_ALL=C.UTF-8

erros=0
fail() { echo "FALHA: $*" >&2; erros=$((erros + 1)); }

inc=live-build/config/includes.chroot
doc=docs/branding.md

svgs=(
    "$inc/usr/share/backgrounds/nexus-os/papel-de-parede.svg"
    "$inc/usr/share/backgrounds/nexus-os/tela-de-login.svg"
    "$inc/usr/share/icons/hicolor/scalable/apps/nexus-os.svg"
    "$inc/usr/share/pixmaps/nexus-os-logo.svg"
)
# Ícones próprios dos 10 atalhos (um por atalho do menu e da área de trabalho).
for i in terminal vm sdn vnf-up vnf-status vnf-down clab-up clab-down docs configuracoes; do
    svgs+=("$inc/usr/share/icons/hicolor/scalable/apps/nexus-$i.svg")
done
# Tema de ícones Nexus: os ícones padrão da área de trabalho (pasta pessoal, lixeira, unidades) no estilo dos próprios.
tema_icones=$inc/usr/share/icons/Nexus
for i in places/user-home places/user-trash places/user-trash-full devices/media-floppy devices/media-optical     devices/drive-optical devices/drive-removable-media devices/drive-harddisk devices/computer \
    apps/org.xfce.thunar apps/system-file-manager; do
    svgs+=("$tema_icones/scalable/$i.svg")
done
fundos=(
    "$inc/usr/share/backgrounds/nexus-os/papel-de-parede.png"
    "$inc/usr/share/backgrounds/nexus-os/tela-de-login.png"
)
capturas=(docs/img/login.png docs/img/sessao.png)
configs=(
    "$inc/etc/lightdm/lightdm-gtk-greeter.conf"
    "$inc/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml"
    "$inc/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml"
    "$inc/etc/xdg/xfce4/panel/default.xml"
)
# Arquivos que não são XML: tema GTK e das janelas, terminal, vídeo do Hyper-V, hooks e geradores.
extras=(
    "$inc/usr/share/themes/Nexus-Dark/index.theme"
    "$inc/usr/share/themes/Nexus-Dark/gtk-3.0/gtk.css"
    "$inc/usr/share/themes/Nexus-Dark/xfwm4/themerc"
    "$inc/etc/xdg/xfce4/terminal/terminalrc"
    "$inc/etc/X11/xorg.conf.d/20-hyperv.conf"
    "$tema_icones/index.theme"
    "$inc/usr/share/firefox-esr/distribution/policies.json"
    live-build/config/bootloaders/splash.svg
    live-build/config/bootloaders/syslinux_common/menu.cfg
    live-build/config/bootloaders/syslinux_common/live.cfg.in
    live-build/config/bootloaders/isolinux/isolinux.cfg
    live-build/config/bootloaders/grub-pc/config.cfg
    live-build/config/bootloaders/grub-pc/live-theme/theme.txt
    live-build/config/hooks/live/0600-nexus-identidade.hook.chroot
    scripts/gerar-identidade.py
    scripts/gerar-tema-xfwm4.py
)
todos=("${svgs[@]}" "${fundos[@]}" "${capturas[@]}" "${configs[@]}" "${extras[@]}")

for f in "${todos[@]}" "$doc"; do
    [ -f "$f" ] || fail "arquivo ausente: $f"
done

# 1. Cada arquivo está em docs/branding.md, numa linha de tabela com a licença (4ª coluna) preenchida.
if [ -f "$doc" ]; then
    for f in "${todos[@]}"; do
        linha=$(grep -F -- "\`$f\`" "$doc" | grep '^|' | head -n 1 || true)
        if [ -z "$linha" ]; then
            fail "$f não está na tabela de $doc"
            continue
        fi
        lic=$(awk -F'|' '{ v = $5; gsub(/^[ \t`]+|[ \t`]+$/, "", v); print v }' <<<"$linha")
        [ "${#lic}" -ge 3 ] || fail "$f sem licença na tabela de $doc"
    done
    for termo in Debian "Nexus OS" greybird-gtk-theme papirus-icon-theme fonts-inter os-release; do
        grep -qF -- "$termo" "$doc" || fail "$doc não menciona '$termo'"
    done
fi

# 2. SVG e XML bem formados (python3, python ou xmllint, o primeiro que roda).
xml_ok() {
    local py
    for py in python3 python; do
        if "$py" -c 'import sys' >/dev/null 2>&1; then
            "$py" -c 'import xml.etree.ElementTree as E, sys; E.parse(sys.argv[1])' "$1" 2>/dev/null
            return
        fi
    done
    command -v xmllint >/dev/null || { echo "FALHA: sem python3, python nem xmllint para validar XML" >&2; exit 1; }
    xmllint --noout "$1" 2>/dev/null
}
for f in "${svgs[@]}" "${configs[@]:1}" live-build/config/bootloaders/splash.svg; do
    [ -f "$f" ] || continue
    xml_ok "$f" || fail "XML mal formado: $f"
done

# 3. PNG: assinatura, tamanho do papel de parede e do login (1920x1080) e no máximo 300 KB nas capturas.
png_dim() { # largura e altura (bytes 16 a 23 do IHDR, big-endian)
    od -An -tu1 -j16 -N8 -- "$1" | awk '{ print $1 * 16777216 + $2 * 65536 + $3 * 256 + $4, $5 * 16777216 + $6 * 65536 + $7 * 256 + $8 }'
}
png_ok() { [ "$(od -An -tx1 -N8 -- "$1" | tr -d ' \n')" = 89504e470d0a1a0a ]; }
for f in "${fundos[@]}" "${capturas[@]}"; do
    [ -f "$f" ] || continue
    png_ok "$f" || { fail "sem assinatura PNG: $f"; continue; }
done
for f in "${fundos[@]}"; do
    [ -f "$f" ] || continue
    png_ok "$f" || continue
    dim=$(png_dim "$f")
    [ "$dim" = "1920 1080" ] || fail "$f tem ${dim:-?} (esperado 1920 1080)"
done
for f in "${capturas[@]}"; do
    [ -f "$f" ] || continue
    tam=$(wc -c <"$f")
    [ "$tam" -le 307200 ] || fail "$f com $tam bytes (máximo 307200)"
done

# 4. O nome Nexus OS no login e na sessão, e a base Debian intacta.
greeter=${configs[0]}
if [ -f "$greeter" ]; then
    grep -qF 'tela-de-login.png' "$greeter" || fail "$greeter não aponta para tela-de-login.png"
fi
grep -qF 'Nexus OS' "$inc/usr/share/backgrounds/nexus-os/tela-de-login.svg" 2>/dev/null || fail "tela-de-login.svg sem o nome 'Nexus OS'"
# A logo dentro da ISO é a original do projeto, sem redesenho.
cmp -s assets/logo-nexus-os.svg "$inc/usr/share/pixmaps/nexus-os-logo.svg" || fail "nexus-os-logo.svg difere de assets/logo-nexus-os.svg (a logo original)"
grep -qF 'papel-de-parede.png' "${configs[1]}" 2>/dev/null || fail "${configs[1]} não aponta para papel-de-parede.png"
grep -qF 'Nexus-Dark' "${configs[2]}" 2>/dev/null || fail "${configs[2]} sem o tema Nexus-Dark"
grep -qF 'theme-name=Nexus-Dark' "$greeter" 2>/dev/null || fail "$greeter sem theme-name=Nexus-Dark"
grep -qF 'kmsdev' "$inc/etc/X11/xorg.conf.d/20-hyperv.conf" 2>/dev/null || fail "20-hyperv.conf sem a opção kmsdev"
hook=live-build/config/hooks/live/0600-nexus-identidade.hook.chroot
grep -qF 'purge -y light-locker' "$hook" || fail "$hook não remove o light-locker (a tela não deve bloquear)"
grep -qF 'F3.17' "$hook" || fail "$hook sem as linhas da F3.17"
grep -qx 'LIVE_USER_FULLNAME="Nexus OS"' "$inc/etc/live/config.conf.d/nexus.conf" || fail "nexus.conf sem LIVE_USER_FULLNAME=\"Nexus OS\""
# Fundos sem faixas nos gradientes: ruído fino (feTurbulence) por cima.
for f in papel-de-parede tela-de-login; do
    grep -qF 'feTurbulence' "$inc/usr/share/backgrounds/nexus-os/$f.svg" 2>/dev/null || fail "$f.svg sem ruído feTurbulence (faixas nos gradientes)"
done
# Tema de ícones Nexus herda do Papirus-Dark e vira o padrão do desktop e do login.
grep -qx 'Inherits=Papirus-Dark,hicolor' "$tema_icones/index.theme" 2>/dev/null || fail "$tema_icones/index.theme sem Inherits=Papirus-Dark,hicolor"
grep -qxF 'icon-theme-name=Nexus' "$greeter" 2>/dev/null || fail "$greeter sem icon-theme-name=Nexus"
grep -qF 'value="Nexus"' live-build/config/hooks/live/0600-nexus-identidade.hook.chroot || fail "hook 0600 não define IconThemeName Nexus"
grep -qF 'XfdesktopIconView' "$inc/usr/share/themes/Nexus-Dark/gtk-3.0/gtk.css" 2>/dev/null || fail "gtk.css sem o estilo dos rótulos da área de trabalho (XfdesktopIconView)"
# Barra estilo Windows: uma barra só, embaixo, com a lista de janelas abertas; sem seletor de áreas de trabalho.
painel=${configs[3]}
if [ -f "$painel" ]; then
    grep -qF 'value="tasklist"' "$painel" || fail "$painel sem o plugin tasklist (janelas abertas)"
    ! grep -qF 'value="pager"' "$painel" || fail "$painel ainda tem o seletor de áreas de trabalho (pager)"
    [ "$(grep -c 'name="panel-[0-9]*" type="empty"' "$painel")" -eq 1 ] || fail "$painel deveria ter uma barra só"
    grep -qF 'value="p=10;' "$painel" || fail "$painel com a barra fora da parte de baixo (p=10)"
    grep -qF 'value="Nexus OS"' "$painel" || fail "$painel sem o título Nexus OS no botão do menu"
    grep -qF 'name="button-icon" type="string" value="nexus-os"' "$painel" || fail "$painel sem o ícone nexus-os no botão do menu"
fi
grep -qF 'name="workspace_count" type="int" value="1"' "${configs[2]}" 2>/dev/null || fail "${configs[2]} sem workspace_count 1"
# Menu de boot (syslinux e GRUB) com a identidade Nexus OS, sem capacete nem texto do Debian, e com contagem de 5 s.
boot=live-build/config/bootloaders
grep -qF 'Nexus OS' "$boot/syslinux_common/menu.cfg" 2>/dev/null || fail "$boot/syslinux_common/menu.cfg sem 'Nexus OS'"
grep -qF 'Nexus OS' "$boot/syslinux_common/live.cfg.in" 2>/dev/null || fail "$boot/syslinux_common/live.cfg.in sem 'Nexus OS'"
grep -qF 'Nexus OS' "$boot/grub-pc/live-theme/theme.txt" 2>/dev/null || fail "$boot/grub-pc/live-theme/theme.txt sem 'Nexus OS'"
grep -qE '^timeout [1-9][0-9]*$' "$boot/isolinux/isolinux.cfg" 2>/dev/null || fail "$boot/isolinux/isolinux.cfg sem contagem (timeout 50)"
grep -qxF 'set timeout=5' "$boot/grub-pc/config.cfg" 2>/dev/null || fail "$boot/grub-pc/config.cfg sem set timeout=5"
for f in "$boot"/splash.svg "$boot"/syslinux_common/* "$boot"/grub-pc/live-theme/theme.txt; do
    [ -f "$f" ] || continue
    ! grep -qiE 'debian|live-build|live boot menu' "$f" || fail "$f cita Debian, live-build ou 'Live Boot Menu'"
done
# Idioma, teclado, fuso, nome da máquina e tela sem bloqueio (padrões do live-config e do Xorg).
conf=$inc/etc/live/config.conf.d/nexus.conf
for par in 'LIVE_LOCALES="pt_BR.UTF-8"' 'LIVE_TIMEZONE="America/Sao_Paulo"' 'LIVE_KEYBOARD_LAYOUTS="br"' 'LIVE_HOSTNAME="nexus-os"'; do
    grep -qxF "$par" "$conf" 2>/dev/null || fail "$conf sem $par"
done
grep -qF 'XkbLayout' "$inc/etc/X11/xorg.conf.d/00-nexus-teclado.conf" 2>/dev/null || fail "00-nexus-teclado.conf sem XkbLayout (teclado ABNT2 no X)"
grep -qF 'BlankTime' "$inc/etc/X11/xorg.conf.d/10-nexus-sem-bloqueio.conf" 2>/dev/null || fail "10-nexus-sem-bloqueio.conf sem BlankTime (tela sem apagar)"
[ ! -e "$inc/etc/os-release" ] || fail "$inc/etc/os-release existe: a base continua Debian, o arquivo não pode mudar"
for pacote in papirus-icon-theme fonts-inter xfce4-screenshooter mousepad; do
    grep -qxF "$pacote" live-build/config/package-lists/nexus-desktop.list.chroot || fail "$pacote fora de nexus-desktop.list.chroot"
done

# 5. Nada de identidade ignorado pelo .gitignore.
for f in "${todos[@]}"; do
    [ -e "$f" ] || continue
    ! git check-ignore -q -- "$f" || fail "ignorado pelo .gitignore: $f"
done

if [ "$erros" -ne 0 ]; then
    echo "FALHA: tests/identidade.sh com $erros erro(s)" >&2
    exit 1
fi
echo "OK: tests/identidade.sh (${#svgs[@]} SVG, ${#fundos[@]} fundos 1920x1080, ${#capturas[@]} capturas, licenças em $doc)"
