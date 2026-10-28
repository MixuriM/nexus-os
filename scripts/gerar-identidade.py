#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Gera a identidade visual do Nexus OS (F3.17): marca, logotipo, papel de parede e fundo do login.

Tudo é desenhado aqui com formas geométricas simples: nada vem de terceiros. Escreve os SVG em
live-build/config/includes.chroot e converte os dois fundos para PNG 1920x1080 com o rsvg-convert
(pacote librsvg2-bin, Debian main). O texto "Nexus OS" usa a fonte DejaVu Sans Bold
(pacote fonts-dejavu-core); o PNG já sai com o texto desenhado.

Uso: python3 scripts/gerar-identidade.py   (na raiz do repo; precisa de rsvg-convert e fonts-dejavu-core)
"""
import math
import pathlib
import random
import shutil
import subprocess
import sys

RAIZ = pathlib.Path(__file__).resolve().parent.parent
INC = RAIZ / "live-build/config/includes.chroot"
FUNDOS = INC / "usr/share/backgrounds/nexus-os"
ICONE = INC / "usr/share/icons/hicolor/scalable/apps/nexus-os.svg"
LOGO = INC / "usr/share/pixmaps/nexus-os-logo.svg"

AZUL_ESCURO, MAGENTA, AZUL = "#23253e", "#8d2c79", "#2b66a8"
MAGENTA_VIVO, AZUL_VIVO = "#c0489f", "#3f8fe0"  # tons mais claros da mesma paleta, para a marca sobre fundo escuro
FONTE = "DejaVu Sans, Verdana, sans-serif"

GRADIENTE = (
    f'<linearGradient id="g" gradientUnits="userSpaceOnUse" x1="40" y1="216" x2="216" y2="40">'
    f'<stop offset="0" stop-color="{MAGENTA_VIVO}"/><stop offset="1" stop-color="{AZUL_VIVO}"/></linearGradient>'
)


def marca_formas(fundo=True):
    """Marca em um quadrado de 256: três nós em volta de um nó central, ligados por linhas."""
    nos = [(128 + 78 * math.cos(math.radians(a)), 128 + 78 * math.sin(math.radians(a))) for a in (-90, 30, 150)]
    f = [f'<rect width="256" height="256" rx="56" fill="{AZUL_ESCURO}"/>'] if fundo else []
    f.append(
        '<path d="M{0:.1f} {1:.1f}L{2:.1f} {3:.1f}L{4:.1f} {5:.1f}Z" fill="none" stroke="url(#g)" '
        'stroke-width="6" stroke-linejoin="round" opacity=".55"/>'.format(*nos[0], *nos[1], *nos[2])
    )
    for x, y in nos:
        f.append(f'<line x1="128" y1="128" x2="{x:.1f}" y2="{y:.1f}" stroke="url(#g)" stroke-width="10" stroke-linecap="round"/>')
    for x, y in nos:
        f.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="16" fill="url(#g)"/>')
    f.append('<circle cx="128" cy="128" r="22" fill="#ffffff"/>')
    return "\n    ".join(f)


def svg_icone():
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" width="256" height="256" role="img" aria-labelledby="t">\n'
        '  <title id="t">Nexus OS</title>\n'
        f"  <defs>{GRADIENTE}</defs>\n  {marca_formas()}\n</svg>\n"
    )


def svg_logo():
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 256" width="800" height="256" role="img" aria-labelledby="t">\n'
        '  <title id="t">Nexus OS</title>\n'
        f"  <defs>{GRADIENTE}</defs>\n  {marca_formas()}\n"
        f'  <text x="296" y="164" font-family="{FONTE}" font-weight="700" font-size="112" fill="{AZUL_ESCURO}">Nexus '
        f'<tspan fill="{MAGENTA}">OS</tspan></text>\n</svg>\n'
    )


def rede(largura, altura, semente, quantidade):
    """Grade de nós e linhas bem apagadas para o fundo (determinística: mesma semente, mesmo desenho)."""
    r = random.Random(semente)
    nos = [(r.uniform(0, largura), r.uniform(0, altura)) for _ in range(quantidade)]
    linhas, bolas = [], []
    for i, (x, y) in enumerate(nos):
        vizinhos = sorted(range(len(nos)), key=lambda j: (nos[j][0] - x) ** 2 + (nos[j][1] - y) ** 2)[1:3]
        for j in vizinhos:
            linhas.append(f'<line x1="{x:.0f}" y1="{y:.0f}" x2="{nos[j][0]:.0f}" y2="{nos[j][1]:.0f}"/>')
        bolas.append(f'<circle cx="{x:.0f}" cy="{y:.0f}" r="{r.choice((3, 4, 5, 7))}"/>')
    return (
        '<g stroke="url(#gf)" stroke-width="2" opacity=".22">' + "".join(linhas) + "</g>"
        '<g fill="url(#gf)" opacity=".35">' + "".join(bolas) + "</g>"
    )


def fundo_base():
    return (
        "<defs>"
        '<linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#2a2d4d"/>'
        '<stop offset="1" stop-color="#14162a"/></linearGradient>'
        f'<linearGradient id="gf" gradientUnits="userSpaceOnUse" x1="0" y1="1080" x2="1920" y2="0">'
        f'<stop offset="0" stop-color="{MAGENTA}"/><stop offset="1" stop-color="{AZUL}"/></linearGradient>'
        f'<radialGradient id="brilho" cx="78%" cy="85%" r="55%"><stop offset="0" stop-color="{AZUL}" stop-opacity=".45"/>'
        f'<stop offset="1" stop-color="{AZUL}" stop-opacity="0"/></radialGradient>'
        f"{GRADIENTE}</defs>"
        '<rect width="1920" height="1080" fill="url(#bg)"/>'
        '<rect width="1920" height="1080" fill="url(#brilho)"/>'
    )


def svg_papel_de_parede():
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1920 1080" width="1920" height="1080" role="img" aria-labelledby="t">\n'
        '  <title id="t">Papel de parede do Nexus OS</title>\n'
        f"  {fundo_base()}\n  {rede(1920, 1080, 7, 34)}\n"
        '  <g transform="translate(1340 880) scale(.5)">' + marca_formas() + "</g>\n"
        f'  <text x="1490" y="959" font-family="{FONTE}" font-weight="700" font-size="52" fill="#ffffff" '
        'fill-opacity=".92">Nexus OS</text>\n</svg>\n'
    )


def svg_login():
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1920 1080" width="1920" height="1080" role="img" aria-labelledby="t">\n'
        '  <title id="t">Tela de login do Nexus OS</title>\n'
        f"  {fundo_base()}\n  {rede(1920, 1080, 11, 30)}\n"
        '  <g transform="translate(822 60) scale(.9)">' + marca_formas(fundo=False) + "</g>\n"
        f'  <text x="960" y="380" text-anchor="middle" font-family="{FONTE}" font-weight="700" font-size="96" '
        'fill="#ffffff">Nexus OS</text>\n</svg>\n'
    )


def escreve(caminho, texto):
    caminho.parent.mkdir(parents=True, exist_ok=True)
    caminho.write_text(texto, encoding="utf-8", newline="\n")
    print(f"escrito {caminho.relative_to(RAIZ)}")


def para_png(svg):
    destino = svg.with_suffix(".png")
    subprocess.run(["rsvg-convert", "-w", "1920", "-h", "1080", "-o", str(destino), str(svg)], check=True)
    print(f"escrito {destino.relative_to(RAIZ)} ({destino.stat().st_size} bytes)")


def main():
    if shutil.which("rsvg-convert") is None:
        sys.exit("FALHA: rsvg-convert não encontrado (pacote librsvg2-bin)")
    escreve(ICONE, svg_icone())
    escreve(LOGO, svg_logo())
    escreve(FUNDOS / "papel-de-parede.svg", svg_papel_de_parede())
    escreve(FUNDOS / "tela-de-login.svg", svg_login())
    para_png(FUNDOS / "papel-de-parede.svg")
    para_png(FUNDOS / "tela-de-login.svg")


if __name__ == "__main__":
    main()
