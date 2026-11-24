# Otimização da ISO (RC4)

Este documento registra a otimização do boot do Nexus OS feita sobre a rc3.4: o método de medição, a linha de base, o diagnóstico da tela preta, cada alavanca tentada (com o número antes e depois e a decisão), o que foi descartado e por quê, o resultado final e como repetir. As releases `v1.0.0-rc2`, `v1.0.0-rc3` e `v1.0.0-rc3.1` a `v1.0.0-rc3.4` não foram alteradas.

## 1. Resumo

- A rc3.4 já tinha tudo o que o sistema promete. A otimização atacou a espera até o desktop, que era a limitação registrada em [demo.md](demo.md) (tela preta de cerca de 18 s depois da roda do Plymouth).
- Uma alavanca ficou: a carga da imagem FRR no boot (`nexus-images.service`) passou a rodar com `Nice=5`. Com ela, o login na serial caiu de 46 s para 33 s, a sessão gráfica de 25,4 s para 18,1 s, o `all` com 2560 MiB de 282 s para 228 s e a demonstração de 108 s para 81 s.
- A RAM em repouso e o pico não pioraram (1068 MiB e 2010 MiB, contra 1082 MiB e 2010 MiB).
- Duas alavancas foram desfeitas: o zram (piorou a RAM em repouso em 7,7%) e a prioridade forte do `nexus-images` (`CPUWeight=20` e `IOWeight=20`, que deixou o teste do painel falhar com mais frequência).
- Trabalho futuro: o parâmetro `toram`, descrito na seção 9.

## 2. Método de medição

Todas as medições são com KVM, 2 vCPU, sem rede, ISO local da VM de build, nada mais pesado rodando, e mediana de 3 execuções (a tabela mostra também mínimo e máximo). O menu de boot espera o Enter, então a medição usa o método dos testes existentes: o `sendkey ret` e o tempo contado desde o início do QEMU. Esse método não mudou.

| Métrica | O que mede | Como |
| --- | --- | --- |
| A | Segundos até o `login:` na serial | `tests/iso.sh` com 2560 MiB |
| B | Segundos até a sessão gráfica | início do último processo do desktop (`xfce4-session`, `xfce4-panel`, `xfwm4`, `xfdesktop`), em segundos desde o boot do kernel |
| C e D | RAM em repouso e RAM de pico | `all` com 4096 MiB, marcadores `NEXUS-SMOKE-MEM` e `NEXUS-SMOKE-MEMPEAK` |
| E | Duração do `all` | com 2560 MiB |
| F | Menor RAM em que o `all` passa | 2048, 1792 e 1536 MiB, uma execução por valor |
| H | Duração de `tests/demo.sh` | `nexus-demo tudo --auto` com 2560 MiB |
| I | Tela preta | estimativa: B menos o instante em que o `lightdm.service` fica ativo |

A métrica I é uma estimativa. O `lightdm.service` tem `Conflicts=plymouth-quit.service`, então o Plymouth sai quando o X assume a tela e o `plymouth-quit.service` nunca roda. Os quadros do `tests/boot-visual.sh` confirmam a ordem, mas não são um cronômetro.

**Regra de ganho comprovado.** Uma alavanca fica só se a mediana melhorar pelo menos 10% (tempos) ou 100 MiB (RAM), fora do intervalo mínimo-máximo da linha de base, sem nenhuma outra métrica piorar mais de 5% na mediana e sem nenhum teste existente falhar a mais. Quem aplica a regra é o `tests/medir-desempenho.sh` (`--decidir`).

## 3. Linha de base: rc3.4

SHA256 `d9afcb00db65586b665a8c5373077cc4f672ec9f2005674dfba64e1410690a7c`, 2044821504 bytes.

| Métrica | Mediana | Mínimo | Máximo |
| --- | --- | --- | --- |
| A, login (s) | 46 | 45 | 46 |
| B, sessão (s) | 25,4 | 24,5 | 25,8 |
| C, RAM em repouso (MiB) | 1082 | 1049 | 1101 |
| D, RAM de pico (MiB) | 2010 | 1993 | 2010 |
| E, `all` com 2560 MiB (s) | 282 | 282 | 291 |
| H, demonstração (s) | 108 | 106 | 111 |
| I, tela preta (s, estimativa) | 7,3 | 7,0 | 7,9 |

Menor RAM em que o `all` passa (F): 2048 MiB (falha em 1792 e em 1536 MiB).

Referência histórica, medida em outras condições e em outras ISOs: RC2, login em 36 s e sessão em cerca de 23 s; RC3 original, login em 33 s, sessão em 18,7 s e RAM em repouso de 987 MiB ([requisitos.md](requisitos.md) e [demo.md](demo.md)). A rc3.4 ficou mais lenta que a RC3 original porque trouxe o firmware AMD, os autostarts novos e o Plymouth.

## 4. Diagnóstico da tela preta

Os quadros do `tests/boot-visual.sh` na rc3.4 mostram, em ordem: o menu do isolinux (carga do kernel), a tela de carregamento do Plymouth, uma tela totalmente preta, só a barra sem ícones nem papel de parede e, por fim, o desktop completo. Em segundos de uptime:

- `live-config.service` termina em cerca de 10 s e é protegido (não pode ser mexido).
- `lightdm.service` fica ativo em cerca de 12,8 s e a sessão em cerca de 18,9 s.
- `nexus-images.service` (carga da imagem FRR no Docker) só termina em cerca de 26 s, durante a pintura do desktop, e disputa as 2 vCPU com o X e a sessão XFCE.

A hipótese, confirmada pela medição: baixar a prioridade da carga da imagem faz o desktop subir mais cedo. O plano proposto de manter o Plymouth visível durante a tela preta não foi aplicado (mudaria quando o Plymouth sai, o que a tarefa proíbe).

## 5. Alavancas

| Alavanca | Antes (rc3.4) | Depois | Decisão | Motivo |
| --- | --- | --- | --- | --- |
| Prioridade da carga da imagem FRR, `Nice=5` | B 25,4 s; A 46 s; E 282 s; H 108 s | B 18,1 s; A 33 s; E 228 s; H 81 s | **mantida** | passa a regra de ganho em A, B, E, H e I; C e D não pioraram |
| Prioridade forte, `Nice=10`, `CPUWeight=20`, `IOWeight=20` | B 25,4 s | B 17,9 s | desfeita | o teste do painel falhou em 3 de 9 execuções do `all` com 4096 MiB |
| zram (`systemd-zram-generator`, metade da RAM, zstd) | C 1082 MiB; F 2048 MiB | C 1165 MiB (+7,7%); F 1536 MiB ou menos | desfeita | piorou a RAM em repouso em mais de 5%, fora da regra |
| Compressão do `squashfs` em zstd (L5) | `xz`, 1943109632 bytes | não medida | pulada | o zstd comprime menos que o xz, e a ISO só tem 96 MiB de folga até 2 GiB |
| Compressão do initramfs (L4) | já em zstd | sem mudança | pulada | já é zstd; remover módulos é proibido |
| Desligar timers e serviços sem função (L2) e autostarts (L3) | não medidos | não medidos | pulados | ganho esperado abaixo de 10%; cada tentativa custa um build e uma hora de medição |

Valores das ISOs intermediárias, para conferência: a `dev1` (prioridade forte mais zram) deu login em 33 s, sessão em 18,2 s, `all` em 219 s e demonstração em 81 s; a `dev2` (prioridade forte, sem zram) deu 33 s, 17,9 s, 220,5 s e 78 s; a `dev3` (a mantida) deu 33 s, 17,6 s, 222 s e 78 s, com tela preta estimada de 5,4 s (de 7,3 s).

## 6. Intermitência do teste do painel

O teste `desktop` do `all` reinicia o painel (`nexus-icone`, `nexus-barra`) e espera ele voltar. Esse passo é intermitente também na rc3.4: no `all` com 4096 MiB ela falhou em 1 de 11 execuções (`M7`). A `dev3` falhou em 2 de 8 (`D9` e `M9`). A prioridade forte (`dev2`) falhou em 3 de 9. Na ISO final, a medição de desempenho teve 3 falhas do `D9` em 12 execuções do `all` com 4096 MiB, as três seguidas na 3ª rodada.

Para saber se a diferença era real, foi feito um controle com 6 execuções do `all` com 4096 MiB em cada ISO, alternadas (rc3.4, rc4, rc3.4, rc4 e assim por diante), sem repetir as que falhassem: a rc3.4 passou 6 de 6 e a rc4 passou 6 de 6. Somando tudo, a rc3.4 falhou 1 vez em 17 e a ISO final 3 vezes em 12 (0 em 6 no controle). Com tão poucas execuções a diferença não é estatisticamente significativa, e as três falhas seguidas indicam um estado da VM naquele momento, não uma falha constante da ISO. Também não há motivo técnico para o `Nice=5` afetar o teste: a carga da imagem termina por volta de 20 s e o `D9` roda depois de 70 s.

Nenhum teste foi enfraquecido nem editado. O `tests/medir-desempenho.sh` repete uma vez o passo que falhar e registra cada falha em `~/otimizacao-logs/<rótulo>-reexecucoes.txt`. Este é um risco conhecido, a investigar separadamente: o reinício do painel espera um tempo fixo, que fica curto quando a máquina está carregada.

## 7. Resultado final

ISO `nexus-os-rc4-amd64.iso`, gerada do commit `1c65487` (a `main` pode ter commits de documentação depois dele, sem mudança em `live-build`).

- SHA256: `8c2e32c2e2da7dfd5183c1a538d86c0e302e43f44be8d2aaab164de85fc739e3`
- Tamanho: 2046820352 bytes (limite de 2147483648 bytes; folga de cerca de 96 MiB)
- Tempo de build: 1115 s (cerca de 18,6 min)

Medição final (mediana de 3 execuções, mínimo e máximo), contra a linha de base da seção 3:

| Métrica | rc3.4 | rc4 | Mínimo | Máximo | Variação |
| --- | --- | --- | --- | --- | --- |
| A, login (s) | 46 | 33 | 33 | 33 | -28% |
| B, sessão (s) | 25,4 | 18,1 | 18,1 | 18,4 | -29% |
| C, RAM em repouso (MiB) | 1082 | 1068 | 1066 | 1087 | -1% |
| D, RAM de pico (MiB) | 2010 | 2010 | 1998 | 2019 | 0% |
| E, `all` com 2560 MiB (s) | 282 | 228 | 228 | 232 | -19% |
| H, demonstração (s) | 108 | 81 | 81 | 84 | -25% |
| I, tela preta (s, estimativa) | 7,3 | 5,6 | 5,5 | 5,9 | -23% |

Todos os tempos melhoraram mais de 10%, com a mediana abaixo do mínimo da rc3.4, e a RAM não piorou. A menor RAM em que o `all` passa (F) não foi medida de novo na ISO final.

Bateria de testes na ISO final:

| Teste | Resultado |
| --- | --- |
| `tests/iso.sh` | passou: login em 33 s, SHA256 conferido |
| `tests/iso-smoke.sh ... all` com 2560 MiB | passou: 8 testes em 219 s, RAM em repouso 987 MiB e pico 1852 MiB |
| `tests/demo.sh` | passou: 4 de 4 atos em 78 s |
| `tests/manual.sh` | passou: 14 blocos do manual, 102 s |
| `tests/boot-visual.sh` (entradas 1, 2, 3 e UEFI) | passou: logo, roda girando, sem linhas de texto, passagem limpa para o desktop |
| `tests/docs.sh`, `gui-spec.sh`, `atalhos.sh`, `identidade.sh`, `requisitos.sh` | passaram |
| `tests/lint-repo.sh` na VM | falha por um aviso informativo do shellcheck (SC2015) em `nexus-montar-discos`, arquivo que não mudou desde a rc3.4 (no Git Bash a etapa do shellcheck é pulada) |
| `tests/run-fase4.sh` (T1 a T7) | não se aplica: o T1 exige o SHA256 da RC2 registrado em `docs/rc2.md` (documento congelado), então os cenários só passam com a ISO da RC2 |

Os quadros do `tests/boot-visual.sh` foram conferidos por Marcos e aprovados: tela de carregamento igual à da rc3.4, com menos quadros de tela preta e o desktop completo aparecendo antes.

## 8. Limitações

- As medições vêm de uma VM com disco rápido. Num pendrive real, o boot e a primeira abertura de programas tendem a ser mais lentos, e o ganho percentual pode ser diferente.
- A métrica I é uma estimativa.
- O Firefox não ficou mais rápido: a alavanca só mexe no boot. O tempo de abertura do Firefox não foi medido.
- A ISO continua com folga curta até o limite de 2 GiB do GitHub (cerca de 96 MiB).

## 9. Trabalho futuro: `toram`

O parâmetro de boot `toram` copia todo o sistema para a RAM no início. Depois disso os programas abrem sem ler o pendrive, o que acelera principalmente a primeira abertura do Firefox e de outros aplicativos.

- **Custo no boot:** copiar a ISO (cerca de 2 GiB) do pendrive para a RAM leva de dezenas de segundos a alguns minutos, conforme a velocidade do pendrive.
- **Custo de RAM:** precisa de mais RAM, estimada em 4 GiB no mínimo e 6 a 8 GiB com folga. Sem RAM suficiente, o boot falha.
- **Proposta:** uma entrada opcional nova no menu de boot, por exemplo "Iniciar na memória (precisa de 6 GB de RAM)", mantendo as três entradas atuais.
- **Por que não entrou:** o menu de boot é protegido, a tarefa descartou o `toram` e a medição só tem valor em hardware real com a RAM necessária. Exige decisão do grupo, novo build e nova bateria.

## 10. Como repetir

Na VM de build (Linux, com KVM), na raiz do repositório:

1. Gere a ISO: `sudo scripts/build-iso.sh`. Deve aparecer `OK: dist/nexus-os-poc-amd64.iso`. Se não aparecer, veja `live-build/build.log`.
2. Meça: `tests/medir-desempenho.sh --medir <iso> <rótulo> 3`. Leva cerca de 40 minutos e imprime a tabela. Se um teste falhar duas vezes seguidas, o script para e mostra a saída.
3. Compare duas ISOs: `tests/medir-desempenho.sh --decidir tempo "<medianas da base>" "<medianas novas>"` (use `ram` para RAM). Deve aparecer `GANHO` ou `SEM-GANHO`.
4. Confira o autoteste do script: `tests/medir-desempenho.sh --autoteste`. Deve aparecer `OK: autoteste ... (11 asserções)`.

Os logs brutos ficam fora do Git, em `~/otimizacao-logs/`.
