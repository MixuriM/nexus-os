#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Gera a identidade visual do Nexus OS (F3.17) a partir da logo original do projeto.

A logo vem de assets/logo-nexus-os.svg e entra na ISO sem redesenho: o script só a copia, recorta a marca
(losango com o N) e a compõe com o fundo. Os ícones dos 9 atalhos e os fundos do desktop e do login são
desenhados aqui, com formas geométricas e a paleta da logo. Escreve os SVG em live-build/config/includes.chroot
e converte os dois fundos para PNG 1920x1080 com o rsvg-convert (pacote librsvg2-bin, Debian main).

Uso: python3 scripts/gerar-identidade.py   (na raiz do repo; precisa de rsvg-convert)
"""
import pathlib
import re
import shutil
import subprocess
import sys

RAIZ = pathlib.Path(__file__).resolve().parent.parent
INC = RAIZ / "live-build/config/includes.chroot"
LOGO_ORIGINAL = RAIZ / "assets/logo-nexus-os.svg"
FUNDOS = INC / "usr/share/backgrounds/nexus-os"
ICONES = INC / "usr/share/icons/hicolor/scalable/apps"
LOGO = INC / "usr/share/pixmaps/nexus-os-logo.svg"

# Paleta da logo (azul, magenta, azul-escuro) e tons do mesmo matiz para superfícies e texto.
AZUL_ESCURO, MAGENTA, AZUL = "#23253e", "#8d2c79", "#2b66a8"
FUNDO_PROFUNDO = "#14152a"
AZUL_VIVO, MAGENTA_VIVO = "#4a8fe0", "#c04aa3"


def partes_da_logo():
    """Separa os 4 caminhos da logo original: fundo, marca, 'NEXUS' e 'OS' (nesta ordem no arquivo)."""
    svg = LOGO_ORIGINAL.read_text(encoding="utf-8")
    caminhos = re.findall(r'<path ([^>]*?) d="([^"]*)"', svg)
    if len(caminhos) != 4:
        sys.exit(f"FALHA: {LOGO_ORIGINAL} deveria ter 4 caminhos, achei {len(caminhos)}")
    return [d for _, d in caminhos]


FUNDO_D, MARCA_D, NEXUS_D, OS_D = partes_da_logo()
# Gradiente original da marca (coordenadas do viewBox 1600x1600 da logo).
GRAD_LOGO = ('<linearGradient id="gl" gradientUnits="userSpaceOnUse" x1="1074.2" y1="965.6" x2="525.6" y2="344.5">'
             f'<stop offset="0" stop-color="{MAGENTA}"/><stop offset="1" stop-color="{AZUL}"/></linearGradient>')


def logo_sem_fundo(escala, cx, cy):
    """Marca e texto da logo original, sem o quadrado azul-escuro, centrados em (cx, cy) à escala dada."""
    # caixa da composição na logo: x 151..1454 e y 95..1444
    tx = cx - escala * (151 + 1454) / 2
    ty = cy - escala * (95 + 1444) / 2
    return (f'<g transform="translate({tx:.1f} {ty:.1f}) scale({escala})">'
            f'<path fill="url(#gl)" fill-rule="evenodd" d="{MARCA_D}"/>'
            f'<path fill="#ffffff" fill-rule="evenodd" d="{NEXUS_D}"/>'
            f'<path fill="{MAGENTA}" fill-rule="evenodd" d="{OS_D}"/></g>')


def svg_marca():
    """Ícone `nexus-os`: a logo original só com a marca (sem o texto), recentrada no quadrado."""
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1600 1600" width="256" height="256" role="img" aria-labelledby="t">\n'
        '  <title id="t">Nexus OS</title>\n'
        f"  <defs>{GRAD_LOGO}</defs>\n"
        f'  <path fill="{AZUL_ESCURO}" fill-rule="evenodd" d="{FUNDO_D}"/>\n'
        # a marca ocupa y 95..1216 (centro 655): desce 145 para centrar no quadrado
        f'  <path transform="translate(0 145)" fill="url(#gl)" fill-rule="evenodd" d="{MARCA_D}"/>\n'
        "</svg>\n"
    )


# ---------- ícones dos 9 atalhos: contorno em gradiente sobre o quadrado azul-escuro da logo ----------
def tile(corpo):
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" width="256" height="256" role="img" aria-labelledby="t">\n'
        '  <title id="t">Nexus OS</title>\n'
        '  <defs><linearGradient id="g" gradientUnits="userSpaceOnUse" x1="50" y1="60" x2="206" y2="200">'
        f'<stop offset="0" stop-color="{AZUL_VIVO}"/><stop offset="1" stop-color="{MAGENTA_VIVO}"/></linearGradient></defs>\n'
        f'  <rect width="256" height="256" rx="58" fill="{AZUL_ESCURO}"/>\n'
        '  <rect x="3" y="3" width="250" height="250" rx="55" fill="none" stroke="#ffffff" stroke-opacity=".06" stroke-width="2"/>\n'
        '  <g fill="none" stroke="url(#g)" stroke-width="13" stroke-linecap="round" stroke-linejoin="round">\n'
        f"{corpo}\n  </g>\n</svg>\n"
    )


ICONES_ATALHOS = {
    "nexus-terminal": '    <rect x="52" y="62" width="152" height="132" rx="20"/>\n'
                      '    <polyline points="82,108 108,128 82,148"/>\n    <line x1="122" y1="150" x2="170" y2="150"/>',
    "nexus-vm": '    <rect x="50" y="62" width="156" height="104" rx="16"/>\n    <line x1="128" y1="166" x2="128" y2="192"/>\n'
                '    <line x1="92" y1="194" x2="164" y2="194"/>\n    <rect x="88" y="94" width="80" height="40" rx="8"/>',
    "nexus-sdn": '    <line x1="128" y1="128" x2="70" y2="76"/>\n    <line x1="128" y1="128" x2="186" y2="76"/>\n'
                 '    <line x1="128" y1="128" x2="128" y2="196"/>\n    <circle cx="128" cy="128" r="22"/>\n'
                 '    <circle cx="70" cy="76" r="13"/>\n    <circle cx="186" cy="76" r="13"/>\n    <circle cx="128" cy="196" r="13"/>',
    "nexus-vnf-up": '    <polygon points="96,70 96,186 190,128"/>',
    "nexus-vnf-status": '    <polyline points="46,134 92,134 112,78 148,184 168,134 210,134"/>',
    "nexus-vnf-down": '    <rect x="76" y="76" width="104" height="104" rx="16"/>',
    "nexus-clab-up": '    <line x1="82" y1="168" x2="174" y2="168"/>\n    <circle cx="82" cy="168" r="17"/>\n    <circle cx="174" cy="168" r="17"/>\n'
                     '    <line x1="128" y1="62" x2="128" y2="122"/>\n    <line x1="98" y1="92" x2="158" y2="92"/>',
    "nexus-clab-down": '    <line x1="82" y1="168" x2="174" y2="168"/>\n    <circle cx="82" cy="168" r="17"/>\n    <circle cx="174" cy="168" r="17"/>\n'
                       '    <line x1="104" y1="68" x2="152" y2="116"/>\n    <line x1="152" y1="68" x2="104" y2="116"/>',
    "nexus-docs": '    <path d="M78 58h66l40 40v100a8 8 0 0 1-8 8H78a8 8 0 0 1-8-8V66a8 8 0 0 1 8-8z"/>\n'
                  '    <polyline points="144,58 144,98 184,98"/>\n    <line x1="94" y1="132" x2="160" y2="132"/>\n'
                  '    <line x1="94" y1="158" x2="160" y2="158"/>',
}


# ---------- fundos ----------
def fundo_base():
    return (
        "<defs>"
        f'<linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#2a2d52"/>'
        f'<stop offset=".55" stop-color="{AZUL_ESCURO}"/><stop offset="1" stop-color="{FUNDO_PROFUNDO}"/></linearGradient>'
        f'<radialGradient id="brilho-m" cx=".12" cy=".92" r=".55"><stop offset="0" stop-color="{MAGENTA}" stop-opacity=".55"/>'
        f'<stop offset="1" stop-color="{MAGENTA}" stop-opacity="0"/></radialGradient>'
        f'<radialGradient id="brilho-a" cx=".9" cy=".08" r=".6"><stop offset="0" stop-color="{AZUL}" stop-opacity=".6"/>'
        f'<stop offset="1" stop-color="{AZUL}" stop-opacity="0"/></radialGradient>'
        # sombra escura atrás da logo: as cores originais (azul e magenta médios) ganham contraste
        f'<radialGradient id="halo" cx=".5" cy=".5" r=".5"><stop offset="0" stop-color="{FUNDO_PROFUNDO}" stop-opacity=".62"/>'
        f'<stop offset=".6" stop-color="{FUNDO_PROFUNDO}" stop-opacity=".3"/>'
        f'<stop offset="1" stop-color="{FUNDO_PROFUNDO}" stop-opacity="0"/></radialGradient>'
        '<linearGradient id="linha" gradientUnits="userSpaceOnUse" x1="500" y1="900" x2="1420" y2="160">'
        f'<stop offset="0" stop-color="{MAGENTA_VIVO}"/><stop offset="1" stop-color="{AZUL_VIVO}"/></linearGradient>'
        f"{GRAD_LOGO}</defs>"
        '<rect width="1920" height="1080" fill="url(#bg)"/>'
        '<rect width="1920" height="1080" fill="url(#brilho-m)"/>'
        '<rect width="1920" height="1080" fill="url(#brilho-a)"/>'
    )


def losangos(cx, cy):
    """Losangos concêntricos (o formato da marca) bem apagados."""
    saida = ['<g fill="none" stroke="url(#linha)" stroke-width="2">']
    for r, op in ((330, .30), (470, .20), (640, .13), (840, .08), (1080, .05)):
        saida.append(f'<polygon opacity="{op}" points="{cx},{cy - r} {cx + r},{cy} {cx},{cy + r} {cx - r},{cy}"/>')
    saida.append("</g>")
    return "".join(saida)


def pontos():
    """Grade de pontos discreta sobre o fundo."""
    return ('<pattern id="grade" width="48" height="48" patternUnits="userSpaceOnUse"><circle cx="2" cy="2" r="1.6" fill="#b9bde0"/>'
            '</pattern><rect width="1920" height="1080" fill="url(#grade)" opacity=".07"/>')


def svg_papel_de_parede():
    cx, cy = 960, 520
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1920 1080" width="1920" height="1080" role="img" aria-labelledby="t">\n'
        '  <title id="t">Papel de parede do Nexus OS</title>\n'
        f"  {fundo_base()}\n  {pontos()}\n  {losangos(cx, cy - 20)}\n"
        f'  <circle cx="{cx}" cy="{cy}" r="470" fill="url(#halo)"/>\n'
        f"  {logo_sem_fundo(.40, cx, cy)}\n</svg>\n"
    )


def svg_login():
    cx, cy = 960, 218
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1920 1080" width="1920" height="1080" role="img" aria-labelledby="t">\n'
        '  <title id="t">Tela de login do Nexus OS</title>\n'
        f"  {fundo_base()}\n  {pontos()}\n  {losangos(960, 540)}\n"
        f'  <circle cx="{cx}" cy="{cy}" r="330" fill="url(#halo)"/>\n'
        f"  {logo_sem_fundo(.26, cx, cy)}\n</svg>\n"
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
    # A logo original entra sem alteração (cópia byte a byte); o ícone da barra é só a marca dela.
    LOGO.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(LOGO_ORIGINAL, LOGO)
    print(f"copiado {LOGO.relative_to(RAIZ)}")
    escreve(ICONES / "nexus-os.svg", svg_marca())
    for nome, corpo in ICONES_ATALHOS.items():
        escreve(ICONES / f"{nome}.svg", tile(corpo))
    escreve(FUNDOS / "papel-de-parede.svg", svg_papel_de_parede())
    escreve(FUNDOS / "tela-de-login.svg", svg_login())
    para_png(FUNDOS / "papel-de-parede.svg")
    para_png(FUNDOS / "tela-de-login.svg")


if __name__ == "__main__":
    main()
