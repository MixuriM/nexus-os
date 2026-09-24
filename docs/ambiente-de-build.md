# Ambiente de build da ISO

## Por que exige Linux

O live-build só roda em Debian ou Ubuntu, com root e sistema de arquivos Linux.
Ele quebra em pasta Windows e em `/mnt/c` do WSL. Esta pasta serve para editar e versionar.
O build da ISO acontece a partir de um clone do repositório em um ambiente Linux.

## Base da distro

Debian estável. Em 24/09/2026 a estável é o Debian 13.7, codinome trixie (lançada em 12/09/2026).
A versão pontual muda com o tempo; o codinome trixie permanece até a próxima release estável.
Fonte: https://www.debian.org/releases/stable/

## Opções de ambiente

1. **VM Debian**: clonar o repo dentro da VM e buildar no disco da VM.
2. **WSL2 em ext4**: clonar o repo dentro do sistema de arquivos do WSL2 (por exemplo, no home do usuário Linux), nunca em `/mnt/c`.

Status: detalhes de instalação e comandos a serem preenchidos pela equipe.
