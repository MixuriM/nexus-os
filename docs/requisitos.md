# Requisitos mínimos de hardware da ISO (F3.9 e F3.18)

RAM e disco da ISO integrada, medidos em boot live com os serviços ativos. As seções "Resultado" e "Método" são da RC1 (núcleo, sem ambiente gráfico); a seção "Com ambiente gráfico" é da RC2 (com o desktop XFCE). Todos os números abaixo vêm de execuções reais; o que não foi medido está nas seções de limitações.

## Resultado

Medido em 2026-10-26, **com KVM**, ISO da RC1 (veja [rc1.md](rc1.md)), guest QEMU com 2 vCPU e 4096 MiB (execução que coleta o pico).

| Item | Valor | Unidade | Como foi medido |
| --- | --- | --- | --- |
| RAM em repouso | 796 | MiB | `used` do `free -m` antes do primeiro teste (serviços ativos: Open vSwitch, libvirt, Docker, FRR) |
| RAM de pico | 813 | MiB | maior `used` do `free -m` durante `nexus-smoke all`, amostrado a cada 5 s e depois de cada teste |
| RAM recomendada | 1536 | MiB | `ceil((pico + 512) / 512) * 512`, validada com `NEXUS_SMOKE_MEM=1536` (abaixo) |
| Disco do root em memória | 24 | MiB | `df -m /` (a raiz da live é um overlay sobre tmpfs; não há disco no guest) |
| Disco do Docker | 193 | MiB | `df -m /var/lib/docker` (tmpfs com a imagem FRR carregada, constante do início ao fim) |
| ISO (bytes) | 921698304 | bytes | tamanho do arquivo (879 MiB) |
| Data | 2026-10-26 | | dia da medição |
| SHA256 | `6a194300113308bcf340759cd4cd5d5f471a99e7690ef5f378bcce9f97d3bfe1` | | `sha256sum` da ISO, o mesmo de [rc1.md](rc1.md) |

Recomendação: **1536 MiB de RAM** e uma mídia (CD, DVD, pendrive ou ISO anexada) de pelo menos 879 MiB. A live não usa disco do guest: tudo o que a sessão grava fica na RAM e some ao desligar.

## Com ambiente gráfico

Medido em 2026-10-27, **com KVM**, na ISO da RC2 (commit `7ddf021`, [rc2.md](rc2.md)), guest QEMU com 2 vCPU, `-vga std` e sem rede. As duas execuções completas do `nexus-smoke all` (8 testes, o último é o `desktop`) seguem o método abaixo: a primeira com 4096 MiB coleta o pico e a segunda, com a RAM recomendada, valida.

| Item | Valor | Unidade | Como foi medido |
| --- | --- | --- | --- |
| Desktop: RAM em repouso | 854 | MiB | média de duas execuções, cada uma com 3 leituras de `free -m` (`used`) a partir de 30 s depois de a sessão ficar ativa: 848 e 859 MiB |
| Desktop: RAM de pico | 1045 | MiB | maior `used` durante `nexus-smoke all` com 4096 MiB (8 testes, amostrado a cada 5 s) |
| Desktop: RAM recomendada | 2048 | MiB | `ceil((pico + 512) / 512) * 512`, validada com `NEXUS_SMOKE_MEM=2048` (abaixo) |
| Desktop: disco do root em memória | 27 | MiB | `df -m /` (overlay sobre tmpfs; a live não usa disco do guest); o Docker segue com 193 MiB |
| Desktop: ISO (bytes) | 1268842496 | bytes | tamanho do arquivo (1210 MiB) |
| Desktop: diferença da ISO para a RC1 (bytes) | 347144192 | bytes | 1268842496 menos 921698304 (+37,7%) |
| Desktop: tempo até a sessão (s) | 20 | s | início do último processo do desktop (`xfce4-session`, `xfce4-panel`, `xfwm4`, `xfdesktop`) em segundos de uptime do guest: 20,4 e 20,1 |
| Desktop: mínimo de RAM do tests/iso.sh (MiB) | 512 | MiB | `NEXUS_ISO_MEM`: 1024, 768 e 512 chegam ao `login:` em 33 s; valores abaixo de 512 não foram testados |
| Desktop: mínimo de RAM dos smokes (MiB) | 1024 | MiB | `NEXUS_SMOKE_MEM` com o `all`: 1280 e 1024 passam, 768 falha |
| Desktop: SHA256 | `0692c04a9d17a42b6d94c9591ea42b1c367ecd702f06552262d9eee9839c5520` | | `sha256sum` da ISO, o mesmo de [rc2.md](rc2.md) |

Recomendação com o desktop: **2048 MiB de RAM** para a VM e uma mídia de pelo menos 1210 MiB. O desktop soma cerca de 58 MiB ao repouso medido na RC1 e 232 MiB ao pico (veja "Resultado").

### Execuções completas do `all`

| RAM do guest (MiB) | Resultado | Repouso | Pico |
| --- | --- | --- | --- |
| 4096 (coleta do pico) | `OK: 8 teste(s) sem falha em 126 s`, `desktop=42s` | 993 MiB | 1045 MiB |
| 2048 (recomendada) | `OK: 8 teste(s) sem falha em 117 s`, `desktop=41s` | 756 MiB | 936 MiB |
| 1280 | `OK` em 133 s, `desktop=45s` | 733 MiB | 932 MiB |
| 1024 | `OK` em 228 s, `desktop=107s` | 732 MiB | 902 MiB |
| 768 | `FALHA: NEXUS-SMOKE-DONE não apareceu em 400 s` | | |

Uma execução por valor. Com 1024 MiB o `all` passa, mas o `desktop` leva mais que o dobro do tempo (107 s contra 42 s com 4096 MiB): é o mínimo, não um valor confortável. O repouso de 993 MiB do primeiro `all` é lido ainda no fim do boot, com o desktop subindo; os 854 MiB acima são lidos com a sessão estável.

### Mínimo do `tests/iso.sh`

O `tests/iso.sh` só espera o `login:` na serial. Medido com `NEXUS_ISO_MEM`, uma execução por valor, com KVM: 1024, 768 e 512 MiB chegam ao `login:` em 33 s, com o SHA256 conferido. O menor valor testado que passa é 512 MiB. O padrão do script continua 2048 MiB.

### Limitações com o desktop

- Medido só com KVM, em um ambiente (VM de build no Hyper-V). Sem KVM, o `desktop` do `all` passou uma vez na F3.15 (477 s no total, 1 vCPU, 2048 MiB), veja [gui.md](gui.md); o resto não foi repetido sem KVM.
- Uma execução por valor de RAM; a RAM em repouso varia entre execuções (veja a issue 33).
- O `tests/iso.sh` só chega ao `login:` na serial: não prova que a sessão gráfica sobe com 512 MiB. O mínimo que cobre a sessão e todos os componentes é o dos smokes, 1024 MiB.
- Hyper-V (Geração 1 e 2), VirtualBox e vídeo real não foram medidos com o desktop.

## Método

1. O `nexus-smoke` da ISO imprime, na serial, `NEXUS-SMOKE-MEM <ponto> <MiB>` (em repouso e depois de cada teste), `NEXUS-SMOKE-MEMPEAK <MiB>` e `NEXUS-SMOKE-DISK <ponto>:<caminho> <MiB>`. O `tests/iso-smoke.sh` repassa os valores no `OK:`. Marcadores: [integracao-iso.md](integracao-iso.md).
2. RAM "usada" é a coluna `used` do `free -m` (o total menos o disponível): não conta o cache de arquivos, que o kernel devolve sob pressão.
3. Execução 1: `NEXUS_SMOKE_MEM=4096 tests/iso-smoke.sh <iso> all` (7 testes, 69 s). Dela saem o repouso e o pico da tabela.
4. Fórmula: pico 813 MiB, mais 512 MiB de margem, dá 1325; arredondado para cima em múltiplos de 512, 1536 MiB.
5. Execução 2: a mesma, com `NEXUS_SMOKE_MEM=1536`. Resultado: `OK: 7 teste(s) sem falha em 73 s, com KVM`, repouso 539 MiB e pico 637 MiB. O requisito vale por esta execução completa.
6. `tests/requisitos.sh` confere esta tabela (valores numéricos, recomendada igual à fórmula e maior ou igual ao pico, mesmo SHA256 de `rc1.md`).

## Mínimo de RAM do smoke `containers`

O smoke `containers` é o que mais pesa no boot: o `nexus-images.service` carrega a imagem FRR no Docker, cujos dados ficam num tmpfs com `size=50%` da RAM (`var-lib-docker.mount`). Esse 50% é o teto do Docker. Medido com `NEXUS_SMOKE_MEM`, com KVM, 2 execuções por valor:

| RAM do guest (MiB) | Execução 1 | Execução 2 |
| --- | --- | --- |
| 1024 | OK, pico 565 MiB | OK, pico 571 MiB |
| 896 | OK, pico 511 MiB | OK, pico 544 MiB |
| 768 | FALHA | FALHA |

Com 768 MiB o guest enxerga 715 MiB, o tmpfs do Docker fica com 358 MiB e o `docker load` falha: `no space left on device` (`journalctl -u nexus-images.service`), então o teste dá `FALHA: imagem quay.io/frrouting/frr:10.7.1 não carregada`. O menor valor testado que passa é **896 MiB**; valores entre 768 e 896 não foram testados. Esse mínimo vale só para o smoke `containers`: o `all` foi validado com 1536 MiB.

## Comparação com a ISO PoC

| Item | ISO PoC | RC1 |
| --- | --- | --- |
| Tamanho | 363855872 bytes | 921698304 bytes (+557842432) |
| Boot até `login:` com KVM | não medido na PoC (a ISO da parte 1, com 386924544 bytes, levou 21 s) | 27 s e 28 s (`tests/iso.sh`, 2 execuções) |
| Boot até `login:` sem KVM | 104 a 827 s | não medido nesta parte |
| Serviços ativos | nenhum de rede | Open vSwitch, libvirt, Docker, FRR, `nexus-images`, Containerlab |

A PoC não tinha RAM medida; o crescimento de tamanho vem de libvirt e QEMU (+301989888 bytes na F3.3), Docker e a imagem FRR (+204472320 bytes na F3.4), FRR e Containerlab (+28311552 na F3.5 e F3.7).

## Limitações

- Todas as medições são **com KVM** (VM de build no Hyper-V). Sem KVM não foram repetidas: os tempos sobem muito (veja [iso-poc.md](iso-poc.md)) e o pico de RAM pode diferir.
- O pico é amostrado a cada 5 s; um pico mais curto que isso pode escapar. `used` não inclui o cache de arquivos.
- A RAM em repouso varia entre execuções: três execuções com 4096 MiB deram 796, 775 e 674 MiB e uma com 1536 MiB deu 539 MiB. A causa não foi investigada (issue #33). O repouso é lido ainda perto do fim do boot, cerca de 20 s depois do início.
- Esta seção é só do núcleo, sem ambiente gráfico: a medição com o desktop está em "Com ambiente gráfico".
- Rodada no Hyper-V sem KVM (Geração 1, 4096 MiB, 2 vCPU): pico de RAM 790 MiB, 708 MiB usados depois do `all`; o `all` teve 1 falha intermitente do `libvirt`, veja [rc1.md](rc1.md). A reprodução em outra máquina continua pendente.
