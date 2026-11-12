# Menu de boot, tela de carregamento e modo de demonstração (RC3)

Este documento descreve as três mudanças da RC3 (`v1.0.0-rc3`) sobre a RC2 congelada: o menu de boot sem contagem e com 3 entradas, a tela de carregamento com a logo e uma roda animada, e a demonstração guiada de virtualização de redes dentro da própria ISO. Termina com o roteiro de apresentação, as medições da RC3 e as decisões técnicas verificadas.

## Índice

1. [O menu de boot](#1-o-menu-de-boot)
2. [A tela de carregamento](#2-a-tela-de-carregamento)
3. [O modo de demonstração](#3-o-modo-de-demonstração)
4. [Roteiro de apresentação](#4-roteiro-de-apresentação)
5. [Dicas para compartilhar a tela no Teams](#5-dicas-para-compartilhar-a-tela-no-teams)
6. [Resultado da RC3](#6-resultado-da-rc3)
7. [Estado da execução](#7-estado-da-execução)

## 1. O menu de boot

**O que é:** o menu que aparece ao ligar a máquina com a ISO, na BIOS (isolinux) e na UEFI (GRUB). Na RC2 ele iniciava sozinho em 5 segundos. Na RC3 ele **espera para sempre** a escolha: GRUB com `set timeout=-1` (a documentação do GRUB diz que `-1` espera indefinidamente) e isolinux com `timeout 0` (a documentação do syslinux diz que zero desativa a contagem).

**As 3 entradas, nesta ordem:**

| # | Rótulo | O que faz |
| --- | --- | --- |
| 1 | Iniciar o Nexus OS | Entrada padrão (vem selecionada): abre o desktop, igual à RC2 |
| 2 | Iniciar o Nexus OS (modo de demonstração) | Igual à 1, mais o parâmetro `nexus.demo=1`: depois do login automático abre um terminal maximizado com a demonstração (seção 3) |
| 3 | Nexus OS (modo de compatibilidade) | Parâmetros de compatibilidade (`noapm nodma nomce nosmp` e outros) para hardware difícil |

**Como usar:** ligue a máquina, espere o menu, escolha com as setas, aperte **Enter**. **Deve aparecer:** a tela de carregamento (seção 2). **Se ficar parado no menu:** é o comportamento esperado, ele não inicia sozinho; aperte Enter. **Consequência:** uma máquina sem teclado (por exemplo, uma VM sem console aberto) fica parada no menu. Os testes automáticos (`tests/iso.sh`, `tests/iso-smoke.sh`, `tests/boot-visual.sh`) mandam Enter pelo monitor do QEMU, por isso continuam passando.

## 2. A tela de carregamento

**O que é:** no lugar das linhas de texto do boot, a tela mostra o fundo escuro da marca (`#14152a`), a logo do Nexus OS e uma roda girando logo abaixo, como no Windows. Vale para as 3 entradas. Sem barra de progresso, sem texto.

**Como funciona (resumo técnico):** o tema `nexus-os` do Plymouth (`live-build/config/includes.chroot/usr/share/plymouth/themes/nexus-os/`) usa o módulo `two-step`, a logo como `watermark.png` e a roda como 30 quadros `throbber-NNNN.png`. O hook `0650-nexus-splash.hook.chroot` define o tema como padrão e confere que ele entrou no initramfs. A linha do kernel das entradas 1 e 2 é `boot=live components quiet splash plymouth.ignore-serial-consoles vt.global_cursor_default=0 console=tty0 console=ttyS0,115200n8`; a da entrada 3 é a padrão do live-build trocando `nosplash` por `quiet splash plymouth.ignore-serial-consoles`.

**Para ver as mensagens do boot (diagnóstico):**

1. **Durante a tela de carregamento**, aperte **Esc**. **Por quê:** é o comportamento padrão do Plymouth. **Deve aparecer:** as mensagens de boot em texto.
2. **Antes de iniciar**, no menu do GRUB (UEFI), aperte **e** sobre a entrada, apague `quiet splash` da linha `linux` e aperte **F10**. No menu do isolinux (BIOS), aperte **Tab** e apague `quiet splash`. **Deve aparecer:** o boot em texto, sem a tela de carregamento.

**Limitações verificadas:**

- A tela só aparece depois que o kernel e o initramfs carregam. No boot por BIOS, o syslinux escreve `Loading /live/vmlinuz... ok` e `Loading /live/initrd.img...` entre o Enter e a tela de carregamento: essas duas linhas vêm do carregador e não têm opção documentada para silenciá-las (limitação registrada na seção 6).

## 3. O modo de demonstração

**O que é:** um roteiro guiado, em português, que mostra a virtualização de redes do Nexus OS com os comandos reais do projeto. Só roda dentro da ISO (confere `boot=live`); fora dela avisa e sai com código 2, sem mexer no sistema.

**Como entrar:** escolha **Iniciar o Nexus OS (modo de demonstração)** no menu de boot. Depois do desktop, um terminal maximizado abre sozinho com o menu da demonstração. Na entrada padrão nada abre (o boot fica igual ao da RC2). Também dá para rodar a qualquer momento, num terminal da ISO: `nexus-demo`.

**Memória:** a demonstração recomenda **2560 MiB** de RAM; com menos de 2300 MiB ela avisa que o ato `rede` pode falhar.

**Como usar:**

| Comando | O que faz |
| --- | --- |
| `nexus-demo` | menu numerado (1 a 6, 0 sai) |
| `nexus-demo sdn` | Ato 1: switch Open vSwitch com regras; uma regra de maior prioridade descarta o ping e outra restaura |
| `nexus-demo vnf` | Ato 2: roteador FRR como contêiner (`nexus-vnf up`, `status`, `vtysh`, `down`) |
| `nexus-demo rede` | Ato 3: ponte + dois roteadores em OSPF; descarta o protocolo 89, a rede cai; remove a regra, ela volta |
| `nexus-demo vm` | Ato 4: máquina virtual do libvirt (`nexus-vm criar`, `listar`, `virsh dominfo`, `remover`), sem iniciar sistema operacional dentro dela |
| `nexus-demo tudo` | os quatro atos em sequência |
| `nexus-demo limpar` | remove tudo o que a demonstração pode ter deixado |
| `nexus-demo ajuda` | mostra o uso |
| `--auto` (junto de um ato) | sem pausas nem perguntas; imprime `NEXUS-DEMO-ATO <ato> OK <segundos>` (usado nos testes) |

No modo interativo cada ato mostra **O QUE VAI ACONTECER**, cada comando real com `$` antes de rodar, o resultado e **O QUE ISSO MOSTRA**, com a pausa "Aperte Enter para continuar" entre os passos principais.

**Códigos de saída:** 0 sucesso, 1 falha, 2 uso inválido ou fora da ISO.

**Se travar ou der erro:** aperte Ctrl+C (o script desfaz só o que ele criou) e rode `nexus-demo limpar`. **Deve aparecer:** `tudo limpo`. Confira: `ip netns list`, `sudo docker ps -a` e `virsh -c qemu:///system list --all` sem sobras.

## 4. Roteiro de apresentação

Cinco partes numeradas, sem nomes: quem coordena atribui as partes (com menos pessoas, juntam-se partes seguidas). Cada parte roda sozinha. Os tempos medidos estão na seção 6.

| Parte | Comando | O que explicar (3 frases) |
| --- | --- | --- |
| 1. Menu de boot e desktop (cerca de 30 s) | ligar a máquina e escolher a entrada 1 | O Nexus OS é uma distribuição própria, montada com o live-build sobre a base Debian estável. O menu tem 3 entradas e não inicia sozinho. A tela de carregamento tem a logo e uma roda, e o desktop abre já logado. |
| 2. SDN | `nexus-demo sdn` | Um switch virtual (Open vSwitch) só deixa passar o que as regras permitem. Uma regra nova de maior prioridade bloqueia o ping na hora. Restaurar as regras traz o ping de volta, sem mexer em equipamento. |
| 3. VNF | `nexus-demo vnf` | Um roteador FRRouting vira um contêiner, uma função de rede virtual. Sobe com um comando e responde ao `vtysh` como um equipamento físico. Some em segundos com `nexus-vnf down`. |
| 4. Rede integrada | `nexus-demo rede` | A ponte Open vSwitch liga dois roteadores que se descobrem por OSPF. Descartar o protocolo 89 no switch derruba a adjacência e as rotas. Remover a regra faz a rede se refazer sozinha. |
| 5. Máquina virtual | `nexus-demo vm` | O KVM/QEMU com o libvirt é a camada de virtualização de máquinas. `nexus-vm` cria, lista e remove uma VM de teste. O virt-manager mostra a mesma máquina em janelas. |

## 5. Dicas para compartilhar a tela no Teams

1. Compartilhe a **janela da VM** (ou a tela inteira), não só um aplicativo.
2. No terminal da demonstração, aumente a fonte com **Ctrl** e **+** (várias vezes) antes de começar; o terminal já abre maximizado.
3. Rode **uma parte por vez** (`nexus-demo sdn`, depois `nexus-demo vnf`, e assim por diante) e use Enter para avançar no ritmo da explicação.
4. Antes de ensaiar, rode `nexus-demo limpar` para começar sem sobras.
5. O áudio e o vídeo ficam mais fluidos se a máquina tiver 2560 MiB e 2 vCPU ou mais.

## 6. Resultado da RC3

Medido na VM de build (Debian 13 no Hyper-V Geração 2), **com KVM**, com 4 vCPU, QEMU de 2 vCPU e 2560 MiB. A ISO é construída em clone limpo (`git clone` do commit, `sudo scripts/build-iso.sh`).

| Item | Valor |
| --- | --- |
| Arquivo | `dist/nexus-os-rc3-amd64.iso` (fora do Git) |
| SHA256 | `ef7688809669f984660b5a786d246e42f7c34e236633102dd252707d47c2decc` |
| Tamanho | 1988689920 bytes (RC2: 1990639616 bytes; limite de 2147483648 bytes por arquivo em release do GitHub) |
| Commit do build | `f1cefd1` (antes do rebase do PR) |
| Build | 1128 s (RC2: 1100 s) |

### Boot e memória, RC2 contra RC3

Três execuções de cada, na mesma sessão da VM, mesmo método (login: `tests/iso.sh` com `NEXUS_ISO_MEM=2560`; sessão: início do último processo do desktop em segundos de uptime do convidado, como em `requisitos.md`; RAM em repouso: `NEXUS-SMOKE-MEM repouso` do `tests/iso-smoke.sh`).

| Medida | RC2 (mediana, mínimo, máximo) | RC3 (mediana, mínimo, máximo) |
| --- | --- | --- |
| Tempo até `login:` na serial | 36 s (36, 36) | 30 s (30, 34) |
| Tempo até a sessão gráfica | 23,9 s (22,5 a 24,1) | 18,3 s (18,2 a 18,8) |
| RAM em repouso | 996 MiB (963 a 1038) | 949 MiB (935 a 966) |
| `all` com 2560 MiB (8 testes) | 219 a 228 s | 228 s, repouso 994 MiB, pico 1833 MiB |

A RC3 ficou dentro do custo aceito (até +5 s na sessão e +100 MiB): ficou mais rápida e a RAM em repouso não aumentou. A causa da diferença de tempo não foi investigada.

### A tela de carregamento nas capturas (`tests/boot-visual.sh`)

Entrada 1 (BIOS): o menu mostra 3 entradas, sem contagem, e fica parado; depois do Enter o fundo do menu aparece por cerca de 8 s (o carregador lê o kernel e o initramfs do CD) sem nenhuma linha de texto, e a logo com a roda aparece de 11 s a 21 s depois do Enter, com a roda em quadros diferentes; segue uma tela preta, sem texto, até o desktop (a captura de 45 s já mostra o desktop). Em UEFI (OVMF, GRUB) a logo com a roda aparece de 7 s a 18 s. Com **Esc** (segundo 14) as mensagens de boot aparecem no quadro seguinte. A entrada 3 (modo de compatibilidade, com `nosmp`) mostra a mesma tela e chega ao desktop por volta de 70 s. Quadro de exemplo para o Relatório: `docs/img/boot-carregando.png` (entrada 1, 1280x800).

Tempo até o `login:` depois do Enter, pela serial: 28 s (entrada 1), 28 s (entrada 2), 24 s (entrada 1 em UEFI) e 27 s (entrada 1 com Esc).

### Tempos da demonstração (`tests/demo.sh`, 2560 MiB, com KVM, `--auto`)

| Ato | Tempo |
| --- | --- |
| `sdn` | 9 s |
| `vnf` | 6 s |
| `rede` | 24 s |
| `vm` | 6 s |
| `tudo` | 45 s (alvo: abaixo de 4 minutos) |

Na execução da ISO de desenvolvimento (antes do build final): 6, 7, 24, 7 e 44 s. No modo interativo o tempo é maior, pelas pausas e pela leitura.

### Bateria na ISO final

| Teste | Resultado |
| --- | --- |
| `tests/iso.sh` (2560 MiB) | OK, `login:` em 35 s |
| `tests/iso-smoke.sh` `all` (2560 MiB) | OK, 8 testes em 228 s |
| `tests/demo.sh` | OK, 4 de 4 atos em 82 s |
| `tests/run-fase3.sh` | OK, 9 testes em 371 s |
| T1 | OK, rodado numa cópia do repositório com o SHA256 da RC3 no lugar do da RC2 em `docs/rc2.md` (o T1 compara com esse arquivo, que é da RC2 congelada) |
| T2, T3, T4, T5 | OK (62, 60, 46 e 59 s) |
| T6 (3 execuções) | OK em 200 s; OSPF `Full` em 13,34, 13,48 e 13,98 s; queda do protocolo 89 em cerca de 3,5 s |
| T7 | OK em 151 s |
| `tests/boot-visual.sh` entradas 1, 2, 3, UEFI e Esc | OK (capturas aprovadas por olhar) |
| Estáticos (`lint-repo` na VM com `shellcheck`, `docs`, `gui-spec`, `atalhos`, `identidade`, `requisitos`, `congelamento`, `evidencias`, `boot`) | OK |

Os testes existentes não foram enfraquecidos. Alterações em testes existentes: `tests/identidade.sh` passou a exigir `timeout 0` (isolinux) e `set timeout=-1` (GRUB); os comentários de `tests/iso.sh` e `tests/iso-smoke.sh` deixaram de falar em contagem de 5 s; em `tests/evidencias.sh`, ajuste mínimo para o `shellcheck` (um `# shellcheck disable=SC2016` e aspas num glob), que já falhava no `tests/lint-repo.sh` da VM na RC2 e não muda o comportamento.

### Limitações e problemas conhecidos

- **BIOS (isolinux): acentos no rótulo da entrada 2.** O `vesamenu.c32` do syslinux mostra mal os caracteres `ç` e `ã` do rótulo "Iniciar o Nexus OS (modo de demonstração)": aparecem dois símbolos no lugar de `çã`. No GRUB (UEFI) o rótulo aparece certo. A entrada continua funcionando; só o texto é afetado na BIOS.
- **Tela preta sem texto entre a roda e o desktop:** cerca de 18 s no QEMU com KVM (de 22 s a 40 s depois do Enter), enquanto o X sobe. A otimização de desempenho fica para depois da apresentação.
- **Carregador da BIOS:** no isolinux não há opção documentada para silenciar a mensagem `Loading ...`; nas capturas ela não apareceu.
- **GRUB (UEFI):** entre o Enter e a tela de carregamento aparece um retângulo preto sobre o fundo do menu (transição do GRUB), sem texto.
- **Menu sem contagem:** uma máquina sem teclado (ou sem console aberto) fica parada no menu.
- **Push direto para `marcos`:** recusado pela regra do repositório; a integração é por PR.

### Decisões técnicas verificadas

- **Pacotes do Plymouth (trixie, versão 24.004.60-5):** `plymouth` traz o `plymouthd`, o `plymouth-set-default-theme` e os módulos `script`, `details`, `text` e `tribar`; `plymouth-themes` traz o módulo `two-step` (`two-step.so`) e os temas `spinner`, `spinfinity`, `solar`, `glow`, `fade-in`, `bgrt` e `script`. Por isso `nexus-boot.list.chroot` tem os dois pacotes.
- **Modelo do tema:** `spinner.plymouth` (módulo `two-step`, `ImageDir`, alinhamentos, `Watermark*`, `BackgroundStartColor` e `BackgroundEndColor`, `UseEndAnimation=false`). Quadros: `throbber-NNNN.png` (roda) e `animation-NNNN.png` (animação final). Confirmado no fonte do plugin (`two-step/plugin.c`, tag 24.004.60): sem nenhum `animation-*`, o plugin trata os `throbber-*` como animação final e fica sem roda; por isso o tema leva um `animation-0001.png`. O `show_splash_screen` do mesmo plugin exige `lock.png` (sem ele o Plymouth escreve `can't show splash: No such file or directory` no log de `plymouth.debug` e cai no tema `text`, que só mostra `...` sobre fundo cinza, como visto na primeira ISO de teste); o hook de initramfs do pacote `plymouth` troca o `watermark.png` de todo tema `two-step` pelo `logo-text-version-64.png` do `desktop-base` (a logo do Debian, vista na segunda ISO de teste), então o hook `0650` põe a logo do Nexus OS nesse arquivo antes de gerar o initramfs e confere o tamanho do `watermark.png` dentro dele; e o hook `0650` copia `lock`, `entry`, `bullet`, `keyboard`, `capslock` e `keymap-render` do tema `spinner`.
- **`plymouth.ignore-serial-consoles`:** a string existe no `plymouthd` da versão 24.004.60-5 (junto de `plymouth.splash`, `plymouth.force-splash` e outras).
- **Failsafe do live-build:** o padrão é `boot=live components memtest noapic noapm nodma nomce nosmp nosplash vga=788` (`/usr/share/live/build/functions/configuration.sh`); a opção `--bootappend-live-failsafe` existe em `lb config`. A RC3 troca `nosplash` por `quiet splash plymouth.ignore-serial-consoles` e tira o `noapic`: na rodada humana no Hyper-V Geração 2 o kernel com `noapic` falhou com `ACPI: SCI (IRQ9) allocation failed` e parou no `(initramfs)`. O valor do failsafe da RC3 é `boot=live components memtest noapm nodma nomce nosmp quiet splash plymouth.ignore-serial-consoles vga=788`.
- **`timeout`:** GRUB, `timeout=-1` espera indefinidamente (manual do GRUB, `timeout`); syslinux, `TIMEOUT 0` desativa a contagem (wiki do syslinux, `Config`).
- **`xfce4-terminal`:** as opções `--maximize`, `--title`, `-x` (`--execute`) e `-H` (`--hold`) existem na página de manual do pacote do trixie.
- **Arquivos da rede integrada:** o `scripts/stage-iso-files.sh` copia as pastas inteiras `sdn`, `nfv`, `labs`, `tests` e `docs` para `/usr/share/nexus-os`, então `integrado.clab.yml`, `configs/int-r1`, `int-r2` e `sdn/flows/integrado.flows` já entram na ISO; a RC3 só acrescenta a pasta `demo`.
- **UEFI no teste:** o pacote `ovmf` (2025.02-8+deb13u1) instala `/usr/share/ovmf/OVMF.fd`, usado por `tests/boot-visual.sh --uefi`.

## 7. Estado da execução

Branch `marcos` (commits locais; o push direto para `origin/marcos` é recusado pela regra do repositório, "Cannot update this protected ref", então a integração é por PR). Builds feitos: B1 (tema sem `lock.png`), B2 (tema corrigido), BF1 (clone limpo no commit `f236fc5`, descartado porque depois se ajustaram dois testes para o `shellcheck`) e BF2 (clone limpo no commit `f1cefd1`, ISO final da seção 6). Bateria da seção 6 concluída com tudo OK. Falta: RODADA 1 manual (Hyper-V Geração 2), PR de `marcos` para a `main` e, só depois do merge, a tag `v1.0.0-rc3` e a release.
