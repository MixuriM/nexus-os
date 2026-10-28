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
fundos=(
    "$inc/usr/share/backgrounds/nexus-os/papel-de-parede.png"
    "$inc/usr/share/backgrounds/nexus-os/tela-de-login.png"
)
capturas=(docs/img/login.png docs/img/sessao.png)
configs=(
    "$inc/etc/lightdm/lightdm-gtk-greeter.conf"
    "$inc/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml"
    "$inc/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml"
)
gerador=scripts/gerar-identidade.py
todos=("${svgs[@]}" "${fundos[@]}" "${capturas[@]}" "${configs[@]}" "$gerador")

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
    for termo in Debian "Nexus OS" greybird-gtk-theme fonts-dejavu-core tango-icon-theme os-release; do
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
for f in "${svgs[@]}" "${configs[@]:1}"; do
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
grep -qF 'Nexus OS' "$inc/usr/share/backgrounds/nexus-os/tela-de-login.svg" 2>/dev/null || fail "tela-de-login.svg sem o texto 'Nexus OS'"
grep -qF 'Nexus OS' "$inc/usr/share/pixmaps/nexus-os-logo.svg" 2>/dev/null || fail "nexus-os-logo.svg sem o texto 'Nexus OS'"
grep -qF 'papel-de-parede.png' "${configs[1]}" 2>/dev/null || fail "${configs[1]} não aponta para papel-de-parede.png"
grep -qF 'Greybird' "${configs[2]}" 2>/dev/null || fail "${configs[2]} sem o tema Greybird"
hook=live-build/config/hooks/live/0500-nexus-servicos.hook.chroot
grep -qF 'F3.17' "$hook" || fail "$hook sem as linhas da F3.17"
grep -qF 'button-title' "$hook" || fail "$hook não define o título do botão do menu (Nexus OS)"
grep -qx 'LIVE_USER_FULLNAME="Nexus OS"' "$inc/etc/live/config.conf.d/nexus.conf" || fail "nexus.conf sem LIVE_USER_FULLNAME=\"Nexus OS\""
[ ! -e "$inc/etc/os-release" ] || fail "$inc/etc/os-release existe: a base continua Debian, o arquivo não pode mudar"
grep -qxF greybird-gtk-theme live-build/config/package-lists/nexus-desktop.list.chroot || fail "greybird-gtk-theme fora de nexus-desktop.list.chroot"

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
