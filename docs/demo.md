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
| 3 | Nexus OS (modo de compatibilidade) | Parâmetros de compatibilidade (`noapic nosmp` e outros) para hardware difícil |

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

A preencher com as medições da bateria (SHA256, tamanho, tempo de build, tempos de boot, RAM, tempos dos atos, resultado de cada teste) depois do build final.

### Decisões técnicas verificadas

- **Pacotes do Plymouth (trixie, versão 24.004.60-5):** `plymouth` traz o `plymouthd`, o `plymouth-set-default-theme` e os módulos `script`, `details`, `text` e `tribar`; `plymouth-themes` traz o módulo `two-step` (`two-step.so`) e os temas `spinner`, `spinfinity`, `solar`, `glow`, `fade-in`, `bgrt` e `script`. Por isso `nexus-boot.list.chroot` tem os dois pacotes.
- **Modelo do tema:** `spinner.plymouth` (módulo `two-step`, `ImageDir`, alinhamentos, `Watermark*`, `BackgroundStartColor` e `BackgroundEndColor`, `UseEndAnimation=false`). Quadros: `throbber-NNNN.png` (roda) e `animation-NNNN.png` (animação final). Confirmado no fonte do plugin (`two-step/plugin.c`, tag 24.004.60): sem nenhum `animation-*`, o plugin trata os `throbber-*` como animação final e fica sem roda; por isso o tema leva um `animation-0001.png`.
- **`plymouth.ignore-serial-consoles`:** a string existe no `plymouthd` da versão 24.004.60-5 (junto de `plymouth.splash`, `plymouth.force-splash` e outras).
- **Failsafe do live-build:** o padrão é `boot=live components memtest noapic noapm nodma nomce nosmp nosplash vga=788` (`/usr/share/live/build/functions/configuration.sh`); a opção `--bootappend-live-failsafe` existe em `lb config`. A RC3 troca só `nosplash` por `quiet splash plymouth.ignore-serial-consoles`.
- **`timeout`:** GRUB, `timeout=-1` espera indefinidamente (manual do GRUB, `timeout`); syslinux, `TIMEOUT 0` desativa a contagem (wiki do syslinux, `Config`).
- **`xfce4-terminal`:** as opções `--maximize`, `--title`, `-x` (`--execute`) e `-H` (`--hold`) existem na página de manual do pacote do trixie.
- **Arquivos da rede integrada:** o `scripts/stage-iso-files.sh` copia as pastas inteiras `sdn`, `nfv`, `labs`, `tests` e `docs` para `/usr/share/nexus-os`, então `integrado.clab.yml`, `configs/int-r1`, `int-r2` e `sdn/flows/integrado.flows` já entram na ISO; a RC3 só acrescenta a pasta `demo`.
- **UEFI no teste:** o pacote `ovmf` (2025.02-8+deb13u1) instala `/usr/share/ovmf/OVMF.fd`, usado por `tests/boot-visual.sh --uefi`.

## 7. Estado da execução

Branch `marcos`. Feito: menu de boot, tema Plymouth, `nexus-demo`, `nexus-demo-boot`, testes novos e commits de código. Build B1 em andamento na VM (clone `~/nexus-os-rc3`, log em `~/rc3-logs/build-b1.log`). Falta: capturas, bateria, medições, texto da seção 6, cofre, PR.
