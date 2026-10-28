#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Gera o tema de janelas Nexus-Dark do xfwm4 (F3.17) recolorindo o Greybird-dark do Debian.

O Greybird (pacote greybird-gtk-theme, GPL-2+ ou CC-BY-SA-3.0+) traz as formas dos botões e das bordas;
este script só troca os cinzas escuros pelo azul-escuro da logo do Nexus OS e o verde-água de destaque
pelo azul da logo. O resultado é versionado em live-build/config/includes.chroot/usr/share/themes/Nexus-Dark/xfwm4,
então a ISO não precisa mais do pacote greybird-gtk-theme.

Uso: python3 scripts/gerar-tema-xfwm4.py <pasta xfwm4 do Greybird-dark>
     (por exemplo: apt-get download greybird-gtk-theme; dpkg -x greybird-gtk-theme_*.deb x; ... x/usr/share/themes/Greybird-dark/xfwm4)
"""
import pathlib
import re
import shutil
import sys

RAIZ = pathlib.Path(__file__).resolve().parent.parent
DESTINO = RAIZ / "live-build/config/includes.chroot/usr/share/themes/Nexus-Dark/xfwm4"

# Cores exatas do Greybird-dark para as do Nexus OS (barra de título, linhas de realce e borda escura).
EXATAS = {"1D1F1F": "14152A", "3B3E3F": "23253E", "414343": "34376A", "19B1A2": "2B66A8"}


def recolore(m):
    hexa = m.group(1).upper()
    if hexa in EXATAS:
        return "#" + EXATAS[hexa]
    r, g, b = (int(hexa[i:i + 2], 16) for i in (0, 2, 4))
    # cinza escuro qualquer: mesma luminosidade, matiz azul-escuro da logo
    if max(r, g, b) - min(r, g, b) <= 8 and max(r, g, b) < 0x60:
        v = (r + g + b) / 3
        return "#%02X%02X%02X" % (min(255, round(v * .86)), min(255, round(v * .9)), min(255, round(v * 1.45)))
    return "#" + hexa


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    origem = pathlib.Path(sys.argv[1])
    if not (origem / "themerc").is_file():
        sys.exit(f"FALHA: {origem}/themerc não existe")
    if DESTINO.exists():
        shutil.rmtree(DESTINO)
    DESTINO.mkdir(parents=True)
    for arq in sorted(origem.iterdir()):
        if arq.suffix == ".xpm":
            texto = re.sub(r"#([0-9A-Fa-f]{6})", recolore, arq.read_text(encoding="utf-8"))
            (DESTINO / arq.name).write_text(texto, encoding="utf-8", newline="\n")
    tema = (origem / "themerc").read_text(encoding="utf-8")
    # sem os comentários de autoria do arquivo original (nomes e e-mails): a origem fica no cabeçalho abaixo
    tema = re.sub(r"(?m)^#.*\n", "", tema)
    tema = ("# Tema Nexus-Dark do xfwm4, derivado do Greybird-dark (pacote greybird-gtk-theme do Debian,\n"
            "# GPL-2+ ou CC-BY-SA-3.0+), recolorido por scripts/gerar-tema-xfwm4.py.\n") + tema
    tema = re.sub(r"(?m)^active_text_color=.*$", "active_text_color=#ffffff", tema)
    tema = re.sub(r"(?m)^inactive_text_color=.*$", "inactive_text_color=#9ea3cf", tema)
    (DESTINO / "themerc").write_text(tema, encoding="utf-8", newline="\n")
    print(f"escrito {DESTINO.relative_to(RAIZ)} ({len(list(DESTINO.iterdir()))} arquivos)")


if __name__ == "__main__":
    main()
