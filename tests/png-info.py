#!/usr/bin/env python3
"""Confere uma captura de tela PNG (o que o screendump do QEMU grava) sem biblioteca externa.

Uso: python3 -I tests/png-info.py <arquivo.png> [cores_minimo]
     python3 -I tests/png-info.py --teste
Imprime "largura altura cores". "cores" é a contagem de cores distintas, que para ao chegar em cores_minimo
(padrão 16): uma tela preta ou de uma cor só dá 1. Sai com 1 e uma mensagem em stderr se o arquivo não for um PNG
de 8 bits RGB ou RGBA sem entrelaçamento. Usado por tests/cenario-t7.sh (critério de tela não vazia).
"""
import struct
import sys
import zlib

ASSINATURA = b"\x89PNG\r\n\x1a\n"


def info(dados, minimo=16):
    if dados[:8] != ASSINATURA:
        raise ValueError("assinatura PNG ausente")
    pos, idat, ihdr = 8, [], None
    while pos + 8 <= len(dados):
        n, tipo = struct.unpack(">I4s", dados[pos:pos + 8])
        corpo = dados[pos + 8:pos + 8 + n]
        pos += 12 + n
        if tipo == b"IHDR":
            ihdr = struct.unpack(">IIBBBBB", corpo)
        elif tipo == b"IDAT":
            idat.append(corpo)
        elif tipo == b"IEND":
            break
    if ihdr is None or not idat:
        raise ValueError("PNG sem IHDR ou sem IDAT")
    larg, alt, prof, tipo_cor, _, _, entrelaco = ihdr
    if larg == 0 or alt == 0:
        return larg, alt, 0
    if prof != 8 or tipo_cor not in (2, 6) or entrelaco:
        raise ValueError("só PNG de 8 bits RGB ou RGBA sem entrelaçamento")
    bpp = 3 if tipo_cor == 2 else 4
    raw = zlib.decompress(b"".join(idat))
    linha = larg * bpp
    if len(raw) != alt * (linha + 1):
        raise ValueError("tamanho dos dados não confere com a imagem")
    cores, ant = set(), bytearray(linha)
    for y in range(alt):
        filtro = raw[y * (linha + 1)]
        atual = bytearray(raw[y * (linha + 1) + 1:(y + 1) * (linha + 1)])
        for i in range(linha):
            a = atual[i - bpp] if i >= bpp else 0
            b = ant[i]
            c = ant[i - bpp] if i >= bpp else 0
            if filtro == 1:
                atual[i] = (atual[i] + a) & 255
            elif filtro == 2:
                atual[i] = (atual[i] + b) & 255
            elif filtro == 3:
                atual[i] = (atual[i] + ((a + b) >> 1)) & 255
            elif filtro == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                atual[i] = (atual[i] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
            elif filtro != 0:
                raise ValueError("filtro PNG inválido")
        for x in range(0, linha, bpp):
            cores.add(bytes(atual[x:x + 3]))
            if len(cores) >= minimo:
                return larg, alt, len(cores)
        ant = atual
    return larg, alt, len(cores)


def _png(larg, alt, pixel):
    def bloco(t, c):
        return struct.pack(">I", len(c)) + t + c + struct.pack(">I", zlib.crc32(t + c))
    linhas = b"".join(b"\x00" + b"".join(bytes(pixel(x, y)) for x in range(larg)) for y in range(alt))
    cab = struct.pack(">IIBBBBB", larg, alt, 8, 2, 0, 0, 0)
    return ASSINATURA + bloco(b"IHDR", cab) + bloco(b"IDAT", zlib.compress(linhas)) + bloco(b"IEND", b"")


def teste():
    assert info(_png(8, 8, lambda x, y: (0, 0, 0))) == (8, 8, 1), "tela preta tem 1 cor"
    assert info(_png(8, 8, lambda x, y: (x * 30, y * 30, 7)))[2] == 16, "gradiente chega ao mínimo"
    assert info(_png(8, 8, lambda x, y: (x * 30, y * 30, 7)), 100)[2] == 64, "contagem sem corte"
    for ruim in (b"", b"nao e png", ASSINATURA + b"\0" * 20):
        try:
            info(ruim)
        except (ValueError, zlib.error, struct.error):
            continue
        raise AssertionError("PNG inválido foi aceito")
    print("OK: tests/png-info.py --teste")


if __name__ == "__main__":
    try:
        if sys.argv[1:] == ["--teste"]:
            teste()
        elif len(sys.argv) in (2, 3):
            with open(sys.argv[1], "rb") as f:
                print(*info(f.read(), int(sys.argv[2]) if len(sys.argv) == 3 else 16))
        else:
            sys.exit(__doc__)
    except (OSError, ValueError, zlib.error, struct.error) as e:
        sys.exit(f"png-info: {e}")
