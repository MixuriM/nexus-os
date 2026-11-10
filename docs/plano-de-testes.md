# Plano de testes funcionais (F4.1)

Plano da Fase 4: sete cenários (T1 a T7), cada um com executor, comando, critério de sucesso, métricas e evidência esperada. Todos os valores de referência vêm de [requisitos.md](requisitos.md), [rc2.md](rc2.md) e [manual.md](manual.md); onde esses documentos não dão limite, o critério é passa ou falha mais a métrica registrada. A evidência segue o formato de [../evidencias/MODELO.md](../evidencias/MODELO.md) e o índice está em [../evidencias/README.md](../evidencias/README.md).

Cada cenário é o script `tests/cenario-tN.sh <iso>`, rodado no host (a VM de build). Ele chama `tests/iso.sh` ou `tests/iso-smoke.sh` (com `--extra` para o script do convidado, em `tests/cenarios-guest/tN.sh`), registra a evidência pela `tests/lib-evidencia.sh` e termina com `OK: cenário Tn` ou `FALHA: ...`. `tests/run-fase4.sh [iso]` roda T1 a T7 em ordem e para no primeiro erro; um cenário sem script termina em `FALHA: cenário Tn ainda não implementado`. `tests/evidencias.sh` confere esta base de forma estática (roda também no Git Bash).

## Ambiente e ISO sob teste

| Item | Valor |
| --- | --- |
| ISO | `dist/nexus-os-rc2-amd64.iso` (RC2 final, [rc2.md](rc2.md); as execuções de T1 a T7 de 06/11 e 09/11/2026 até o bloco 5 são da RC2 da rodada 5, `bb6d89c68970...3e58`, guardada como `dist/nexus-os-rc2-r5-amd64.iso`) |
| SHA256 | `5f47083bfd5a009a7c11b093e98edfd3bdf21ac593f80f4d549bfe3310c10dbe` (um `.sha256` ao lado da ISO) |
| Host dos testes | VM Debian 13 no Hyper-V Geração 2, com `/dev/kvm` exposto ([hyperv.md](hyperv.md)); clone do repositório em `~/nexus-os` |
| Convidado | QEMU dentro da VM, sem rede, com 2 vCPU; RAM por `NEXUS_SMOKE_MEM` ou `NEXUS_ISO_MEM` |
| Modo | `kvm` quando `/dev/kvm` existe e `lsmod` mostra `kvm`; `emul` caso contrário (`NEXUS_SMOKE_KVM=0 NEXUS_SMOKE_SMP=1`, 2048 MiB) |

Decisão do grupo: T1 a T6 rodam na RC2, não na RC1. A RC2 é a RC1 mais o ambiente gráfico, com o mesmo núcleo. A troca vale para as tarefas F4.2a a F4.2e e F4.3; o T7 (F4.2f) já é da RC2. Se `sha256sum` der outro valor, confira antes se [rc2.md](rc2.md) registra uma ISO final mais nova; sem registro, o teste não começa.

Antes de cada cenário, registrar o modo: `ls -l /dev/kvm` e `lsmod | grep kvm`. Toda evidência diz "kvm" ou "emul".

## Regras de evidência

- Caminho: `evidencias/<Tn>/AAAA-MM-DD-<modo>.md` (campos fixos) mais a saída sanitizada em `AAAA-MM-DD-<modo>.txt`. Nunca `.log` (o `.gitignore` ignora). Duas execuções no mesmo dia e modo ganham sufixo `-2`, `-3`.
- Sanitização: a saída bruta passa por `evidencia_sanitizar` antes de entrar no repositório: sem IP privado, e-mail, caminho de usuário do Windows, `/home/<nome>` (a conta pública `user` da live fica) nem nome de máquina, com no máximo 300 linhas (início e fim, com o corte indicado).
- Tamanho: cada arquivo de evidência tem até 1 MiB (as capturas PNG do T7 entram nesse limite).
- Status: ✅ só com evidência (comando, código de saída e arquivo em `evidencias/`); 🟡 quando falta outra pessoa ou rodada humana; ⏳ quando ninguém executou. Cenário que falha por defeito real fica ⏳ ou 🟡 com a issue, nunca ✅.
- Executor: o dono nominal de cada tarefa está na tabela "Acompanhamento" da Fase 4 do plano de desenvolvimento (os nomes ficam fora do repositório). Sem entrega do dono, Marcos executa e o dono fica de revisor. Isso não conta como execução por segunda pessoa: a reprodução por outra pessoa continua pendente e registrada.
- TDD: o teste do cenário é escrito antes do script do convidado (vermelho por asserção), depois fica verde, e cada cenário é provado por mutações (cópia modificada do script do convidado ou do `.sha256`, que tem de dar `FALHA:`).
- Defeito real vira issue com o ID da tarefa no título; a correção é da geração da RC2 final (F4.5).

## Cenários

### T1: boot da ISO e requisitos de hardware (F4.2a)

- **Objetivo:** provar que a RC2 confere o SHA256, chega ao `login:` e fecha o `nexus-smoke all` com a RAM recomendada; provar que a RAM abaixo do mínimo documentado falha.
- **Pré-condições:** ISO e `.sha256` em `dist/`; `qemu-system-x86` e `xorriso` na VM; modo (kvm ou emul) conferido.
- **Executor:** dono nominal conforme a tabela "Acompanhamento" da Fase 4; executor real: Marcos.
- **Comando:** `tests/cenario-t1.sh dist/nexus-os-rc2-amd64.iso`
- **Critério de sucesso:** (a) `sha256sum -c` confere; (b) `tests/iso.sh` com KVM chega ao `login:` dentro do limite do próprio script (300 s com KVM); (c) `nexus-smoke all` termina em `OK:` com `NEXUS_SMOKE_MEM=2560` (RAM recomendada com desktop, [requisitos.md](requisitos.md)), e repouso, pico e disco ficam registrados e comparados com os documentados (repouso 909 a 1095 MiB, pico 1863 a 2006 MiB, disco do root 28 MiB, disco do Docker 193 MiB); divergência acima de 25% vira issue "requisitos desatualizados"; (d) controle negativo: `all` com `NEXUS_SMOKE_MEM=1536` (um passo abaixo do mínimo documentado de 1792 MiB) tem de falhar; se passar, o requisito documentado está errado (issue de prioridade alta e correção em `docs/requisitos.md` na F4.5). (c) e (d) rodam uma vez cada.
- **Métricas:** tempo até `login:`, RAM em repouso e de pico, disco do root e do Docker, com a diferença para o documentado.
- **Evidência esperada:** `evidencias/T1/AAAA-MM-DD-<modo>.md` e `.txt`.

### T2: Open vSwitch com regras OpenFlow manuais, sem controlador (F4.2b)

- **Objetivo:** provar na ISO que regras escritas à mão com `ovs-ofctl` permitem o tráfego entre dois hosts, descartam o terceiro e mudam o comportamento quando a regra sai ou volta.
- **Pré-condições:** ISO com Open vSwitch ativo; script do convidado `tests/cenarios-guest/t2.sh`.
- **Executor:** dono nominal conforme a tabela "Acompanhamento" da Fase 4; executor real: Marcos.
- **Comando:** `tests/cenario-t2.sh dist/nexus-os-rc2-amd64.iso`
- **Critério de sucesso:** ponte com 3 portas ligadas a 3 namespaces (A, B e C); ARP e IP entre A e B permitidos por prioridade e o tráfego de A para C descartado por regra explícita; `ovs-vsctl get-controller` vazio; ping de A para B passa; ping de A para C falha; `n_packets` das regras de permissão e de descarte maiores que zero; sem a regra de descarte o ping de A para C passa; com a regra de volta falha de novo.
- **Métricas:** contadores `n_packets` finais de cada regra; `dump-flows` na evidência.
- **Evidência esperada:** `evidencias/T2/AAAA-MM-DD-<modo>.md` e `.txt`, com o `dump-flows`.

### T3: VNF FRR e ciclo de vida pelo `nexus-vnf` (F4.2c)

- **Objetivo:** provar o ciclo `up`, `status` e `down` da VNF FRR pelo script de orquestração na ISO.
- **Pré-condições:** ISO com Docker, imagem FRR e Containerlab; script do convidado `tests/cenarios-guest/t3.sh`.
- **Executor:** dono nominal conforme a tabela "Acompanhamento" da Fase 4; executor real: Marcos.
- **Comando:** `tests/cenario-t3.sh dist/nexus-os-rc2-amd64.iso`
- **Critério de sucesso:** com a imagem FRR carregada pelo `nexus-images.service`, o ciclo de `tests/orquestracao.sh` passa dentro da ISO em 3 ciclos seguidos. Por ciclo: `up` sai com 0 e o contêiner `clab-vnf-frr-vnf1` está em execução; `up` repetido sai com 0 e não cria nem recria contêiner; `status` sai com 0 e informa o loopback `198.51.100.11/32`; `down` sai com 0 e não sobra contêiner nem a rede `clab`; `down` repetido sai com 0; `status` depois do `down` sai com 1 (código documentado em `nfv/nexus-vnf.sh`). No fim, o uso inválido sai com 2.
- **Métricas:** tempo de `up` e de `down`, por ciclo.
- **Evidência esperada:** `evidencias/T3/AAAA-MM-DD-<modo>.md` e `.txt`.

### T4: KVM e libvirt pelo `nexus-vm` (F4.2d)

- **Objetivo:** provar o ciclo `criar`, `listar` e `remover` de VM na ISO, três vezes seguidas.
- **Pré-condições:** ISO com libvirt; script do convidado `tests/cenarios-guest/t4.sh`.
- **Executor:** dono nominal conforme a tabela "Acompanhamento" da Fase 4; executor real: Marcos.
- **Comando:** `tests/cenario-t4.sh dist/nexus-os-rc2-amd64.iso`
- **Critério de sucesso:** `nexus-vm criar`, `listar` e `remover` em 3 execuções seguidas; a VM chega a `running` (`virsh domstate`); o XML do domínio tem `type='kvm'` quando há `/dev/kvm` no convidado (senão `qemu`, dito na evidência); `libvirtd` ativo; o `user` consegue `virsh list --all` sem sudo; depois de `remover` não resta domínio nem arquivo temporário.
- **Métricas:** tempo de `criar` até `running`, por execução.
- **Evidência esperada:** `evidencias/T4/AAAA-MM-DD-<modo>.md` e `.txt`.

### T5: topologia no Containerlab seguindo só o manual (F4.2e)

- **Objetivo:** provar que a topologia de demonstração sobe seguindo apenas a seção "Containerlab" de [manual.md](manual.md), sem ajuda externa.
- **Pré-condições:** ISO e manual; script do convidado `tests/cenarios-guest/t5.sh`.
- **Executor:** dono nominal conforme a tabela "Acompanhamento" da Fase 4; executor real: Marcos.
- **Comando:** `tests/cenario-t5.sh dist/nexus-os-rc2-amd64.iso`
- **Parte automática (bloco 3):** `tests/cenario-t5.sh` roda, dentro da ISO e sem rede, só os blocos `bash nexus-exec` da seção "Containerlab" do manual (`tests/manual.sh <iso> Containerlab` faz o mesmo sem as conferências extras). A rodada humana "sem ajuda externa" é do bloco 7: por isso o F4.2e fica 🟡.
- **Critério de sucesso:** os comandos do manual, na ordem, criam a topologia `frr-duo`; a vizinhança OSPF fica `Full` nos dois lados e cada nó aprende o loopback do outro em até 120 s (parâmetro `T5_LIMITE`, consulta a cada 1 s); antes do `containerlab destroy` a adjacência e as rotas continuam; depois dele não sobra contêiner, rede `clab` nem netns. Lacuna do manual (bloco que falha ou depende de algo que o manual não diz) não se corrige no teste: vai para `evidencias/T5/lacunas.md` e vira issue; a correção é do manual v2.
- **Métricas:** tempo do `deploy` até a convergência do OSPF e o limite usado.
- **Evidência esperada:** `evidencias/T5/AAAA-MM-DD-<modo>.md` e `.txt`.

### T6: cenário integrado ponta a ponta (F4.3)

- **Objetivo:** provar o conjunto: topologia Containerlab, OVS com regras OpenFlow, FRR roteando e subida pelo script, do zero, três vezes seguidas.
- **Pré-condições:** T1, T2, T3 e T5 executados (o T4 não entra no T6); script do convidado `tests/cenarios-guest/t6.sh`; ISO RC2 em máquina limpa (convidado novo a cada execução).
- **Executor:** dono nominal conforme a tabela "Acompanhamento" da Fase 4; executor real: Marcos.
- **Comando:** `tests/cenario-t6.sh dist/nexus-os-rc2-amd64.iso`
- **Critério de sucesso:** em cada uma das 3 execuções seguidas, cada uma num QEMU novo, sem persistência e com 2560 MiB (RAM recomendada com o desktop): (1) boot limpo; (2) `nexus-vnf up` da topologia `labs/containerlab/integrado.clab.yml` e `status` saem com 0, com a ponte Open vSwitch `br-integrado` criada antes pelo cenário (modo `secure`, sem controlador); (3) OSPF `Full` entre `r1` e `r2` e a rota do loopback do outro nos dois lados em até 120 s (parâmetro `T6_LIMITE`), mais ping entre os loopbacks; (4) as 6 regras de `sdn/flows/integrado.flows` com `n_packets` maior que zero, inclusive as duas do protocolo 89; (5) prova de controle: a regra `priority=200,ip,nw_proto=89,actions=drop` derruba a adjacência e remove as rotas em até 3 vezes o `dead-interval` configurado (4 s, limite de 12 s), com pacotes contados na regra, e removê-la restaura tudo em até 30 s; (6) `nexus-vnf down` sai com 0 e não sobra contêiner, rede `clab`, porta nem a ponte (removida pelo cenário), nem netns. 3 de 3. A RC2 não traz os arquivos do cenário nem o `nexus-vnf` com topologia opcional: o `tests/cenario-t6.sh` os leva dentro do script do convidado.
- **Métricas:** por execução, `nexus-vnf up`, convergência inicial, tempo de queda, tempo de recuperação, `down`, tempo no convidado e tempo total (do boot ao desligamento do QEMU).
- **Evidência esperada:** `evidencias/T6/AAAA-MM-DD-<modo>.md` e `.txt`, um par por execução (a segunda e a terceira com sufixo `-2` e `-3`).

### T7: sessão gráfica na RC2 (F4.2f)

- **Objetivo:** provar o desktop XFCE da RC2 em VM com vídeo e sem internet.
- **Pré-condições:** RC2; VM com vídeo (`-vga std`) e sem rede; capturas de tela; `python3` na VM de build (o `tests/png-info.py` confere as capturas).
- **Executor:** Marcos (tarefa dele no plano); a reprodução por outra pessoa continua pendente.
- **Comando:** `tests/cenario-t7.sh dist/nexus-os-rc2-amd64.iso`
- **Critério de sucesso:** boot até o desktop com login automático; abrir o `virt-manager` e ver a VM criada por `nexus-vm`; subir a VNF FRR e a topologia Containerlab pelos atalhos e fechar cada terminal com Enter; abrir a documentação local; 5 capturas de tela válidas em `evidencias/T7/`; parte automática e rodada humana OK.
- **Parte automática** (`tests/cenario-t7.sh` no host e `tests/cenarios-guest/t7.sh` no convidado, QEMU com `-vga std`, sem rede, 2560 MiB): o convidado confere que não há rota padrão nem resolução de nomes, espera a sessão `x11` do `user` com os processos do desktop, cria a VM `cen-t7` pelo `nexus-vm`, abre o `virt-manager` pelo atalho, sobe a VNF FRR pelo atalho `nexus-vnf-up`, a derruba pelo `nexus-vnf-down`, sobe e derruba a topologia pelos atalhos `nexus-clab-deploy` e `nexus-clab-destroy` e abre a documentação pelo atalho `nexus-docs`. Cada terminal de atalho fica aberto em "Pressione Enter para fechar..." e é fechado com um Enter de verdade (`NEXUS-SMOKE-TECLA`, `sendkey` do monitor do QEMU): o `xfce4-terminal` tem de sumir em 15 s. Em cada momento o convidado imprime `NEXUS-SMOKE-PONTO <nome>` (`desktop-pronto`, `virt-manager-com-vm`, `vnf-acima`, `clab-acima`, `docs-abertos`) e o `tests/iso-smoke.sh` (variável `NEXUS_SMOKE_CAPTURAS`) tira a captura pelo `screendump -f png` do monitor do QEMU 10.0. No fim a limpeza roda e não pode sobrar contêiner, rede `clab` nem VM.
- **Critério das capturas:** 5 arquivos `PNG` (8 bits, RGB ou RGBA) com largura e altura maiores que zero, pelo menos 2000 cores distintas (parâmetro `T7_CORES`; o desktop pintado tem de 4000 a 20000 e só a barra sobre fundo preto tem cerca de 570, uma tela preta tem 1) e até 1 MiB cada. Captura ausente, vazia, inválida ou grande demais falha o cenário.
- **Rodada humana:** Hyper-V Geração 2, 2560 MiB estáticos, 2 vCPU, sem rede, Secure Boot desligado, a ISO como DVD. Marcos faz o boot até o desktop com login automático (cronômetro até a barra), o `nexus-vm criar` no terminal, o `virt-manager` com a VM, a VNF FRR e a topologia pelos atalhos (com o Enter para fechar cada terminal e os atalhos de remover) e a documentação local, com capturas pelo Windows + Shift + S recortadas na janela da VM, sem dado pessoal. O T7 é ✅ só com a parte automática OK e a rodada humana OK.
- **Métricas:** tempo até a sessão (início do último processo do desktop em segundos de uptime, referência 23 s, [requisitos.md](requisitos.md)), tempo de cada atalho de terminal e as 5 capturas (dimensão e tamanho).
- **Evidência esperada:** `evidencias/T7/AAAA-MM-DD-<modo>.md`, `.txt` e uma captura `AAAA-MM-DD-<modo>-<ponto>.png` por ponto (até 1 MiB cada arquivo); da rodada humana, `humano-AAAA-MM-DD.md` e `humano-AAAA-MM-DD-<ponto>.png`.

## Como rodar T1 a T7 e mutações

**O que é:** cada cenário é um script que inicia a ISO num QEMU, roda um roteiro dentro dela e registra a evidência. Este roteiro é para quem **nunca viu o projeto** e só precisa rodar os cenários: cada passo diz **onde fazer**, **o que fazer**, **por que fazer**, **o que deve aparecer** e **o que fazer se não aparecer**.

**Você precisa de:**

| # | Item | Por quê | Como conseguir |
| --- | --- | --- | --- |
| 1 | A **VM de build** (Debian 13 com `qemu-system-x86`, `xorriso`, `python3`, `sudo`, Docker e Containerlab) | Os cenários iniciam a ISO com o QEMU da própria VM | [ambiente-de-build.md](ambiente-de-build.md) e [hyperv.md](hyperv.md) |
| 2 | O repositório clonado em `~/nexus-os` e a ISO em `dist/nexus-os-rc2-amd64.iso` com o `.sha256` | É o que os cenários testam | [manual.md](manual.md), seção "Gerar a ISO" |
| 3 | `/dev/kvm` na VM (`ls -l /dev/kvm`) | Sem ele os cenários rodam em emulação (`emul`), muito mais lenta; a evidência diz qual modo foi usado | [hyperv.md](hyperv.md), seção "Conferir o KVM" |
| 4 | O SHA256 da ISO igual ao de [rc2.md](rc2.md) | O T1 confere; sem isso o teste não começa | `sha256sum -c dist/nexus-os-rc2-amd64.iso.sha256` e compare com `rc2.md` |

**Regras:** rode um cenário de cada vez (cada um inicia um QEMU); não rode dois ao mesmo tempo; no fim confira que nada sobrou na VM (`pgrep -a qemu`, `sudo docker ps -aq` e `sudo virsh -c qemu:///system list --all --name` devem ficar vazios).

**Onde:** terminal da VM de build, na raiz do clone, com a ISO em `dist/`. **O que fazer:** cada comando abaixo termina em `OK: cenário Tn` ou `FALHA: ...` e grava a evidência em `evidencias/Tn/`. **Deve aparecer:** a linha `OK: cenário Tn (...)` e o caminho `evidência: .../evidencias/Tn/AAAA-MM-DD-<modo>.md`. **Se não aparecer:** a linha `FALHA: cenário Tn: <motivo>` diz o que falhou (SHA256 diferente do `rc2.md`, script do convidado ausente, o convidado imprimiu `FALHA:`, captura ausente ou vazia no T7); a evidência da falha também é gravada. Relate com essa linha (seção "Como relatar uma falha" de [manual.md](manual.md)).


```bash
tests/cenario-t1.sh dist/nexus-os-rc2-amd64.iso   # cerca de 7 min: boot, all com 2560 MiB e controle negativo com 1536 MiB
tests/cenario-t2.sh dist/nexus-os-rc2-amd64.iso   # cerca de 1 min
tests/cenario-t3.sh dist/nexus-os-rc2-amd64.iso   # cerca de 1 min: 3 ciclos de up, status e down da VNF
tests/cenario-t4.sh dist/nexus-os-rc2-amd64.iso   # cerca de 1 min
tests/cenario-t5.sh dist/nexus-os-rc2-amd64.iso   # cerca de 1 min: seção Containerlab do manual
T5_LIMITE=90 tests/cenario-t5.sh dist/nexus-os-rc2-amd64.iso   # outro limite de convergência (padrão 120 s)
tests/manual.sh dist/nexus-os-rc2-amd64.iso Containerlab       # só os blocos de uma seção do manual
tests/cenario-t6.sh dist/nexus-os-rc2-amd64.iso   # cerca de 4 min: 3 execuções, cada uma num QEMU novo, 2560 MiB
T6_EXECUCOES=1 T6_LIMITE=90 tests/cenario-t6.sh dist/nexus-os-rc2-amd64.iso   # uma execução, outro limite de convergência
tests/cenario-t7.sh dist/nexus-os-rc2-amd64.iso   # cerca de 3 min: sessão gráfica, 5 capturas, 2560 MiB
tests/run-fase4.sh dist/nexus-os-rc2-amd64.iso   # T1 a T7 em ordem, para no primeiro erro (cerca de 20 min com KVM)
T7_CORES=1000000 EVID_DIR=/tmp/evid tests/cenario-t7.sh dist/nexus-os-rc2-amd64.iso   # limiar de cores impossível: tem de falhar por captura vazia
python3 -I tests/png-info.py --teste   # autoteste do contador de cores das capturas
```

Mutações (provam que o cenário falha de verdade): rode o cenário com `CENARIO_GUEST=<cópia modificada do script do convidado>` e `EVID_DIR=<pasta temporária>` (para não gravar em `evidencias/`). Para o T1, aponte para uma cópia da ISO por link simbólico com o `.sha256` alterado. Para o T5 também vale `MANUAL_FONTE=<cópia modificada do manual>`; o script do convidado do T5 tem a linha `#@MANUAL@`, trocada pelos blocos da seção.

| Mutação | Alteração | Falha esperada |
| --- | --- | --- |
| T1-M1 | `.sha256` com um dígito alterado | `o SHA256 da ISO não confere com o .sha256` |
| T2-M1 | `t2.sh` sem a regra de descarte | `ping de A para C passou` |
| T2-M2 | `t2.sh` com a regra de permissão A para B saindo pela porta 3 | `ping de A para B falhou` |
| T3-M1 | `t3.sh` com a função `nexus-vnf` ignorando o `down` | `contêiner da VNF sobrou depois do down` |
| T3-M2 | `t3.sh` com `docker kill` do contêiner antes do `status` | `status saiu com 1 depois do up` |
| T4-M1 | `t4.sh` com `systemctl stop libvirtd` antes do criar | `libvirtd inativo antes do criar` |
| T4-M2 | `t4.sh` com o `nexus-vm remover` trocado por `true` | `sobrou depois do remover` |
| T5-M1 | manual sem a linha do `containerlab deploy` (`MANUAL_FONTE`, `T5_LIMITE=30`) | `a adjacência OSPF Full ou as rotas sumiram antes do destroy` |
| T5-M2 | `t5.sh` com o IP de `r2` em `eth1` trocado pelo de `r1` (203.0.113.1/30), `T5_LIMITE=30` | `OSPF não chegou a Full` |
| T6-M1 | `T6_FLOWS` com as regras sem as duas linhas do protocolo 89 (`T6_EXECUCOES=1`) | `esperava 2 regras do protocolo 89` |
| T6-M2 | `t6.sh` sem a linha que insere a regra de descarte (`T6_EXECUCOES=1`) | `não caíram com o descarte do protocolo 89` |
| T6-M3 | `t6.sh` com `desfaz_ponte` trocada por `true`, ou seja, a ponte não é removida (`T6_EXECUCOES=1`) | `sobrou depois do cenário` |
| T7-M1 | `t7.sh` com o atalho `nexus-docs` trocado por `nexus-docs-inexistente` | `gtk-launch nexus-docs-inexistente falhou` |
| T7-M2 | `t7.sh` sem a linha `nexus-vm criar` | `a VM cen-t7 não está em execução` |
| T7-M3 | `T7_CORES=1000000` (nenhuma captura pode ter tantas cores) | `captura vazia: desktop-pronto tem só ... cor(es) distinta(s)` |

T7-M1 e T7-M2 foram provadas duas vezes: com o script do convidado anterior à etapa do Enter (RC2 da rodada 5) e de novo, com a etapa do Enter, na RC2 final (`5f47083b`), com a falha esperada nas duas.

## Problemas conhecidos

- Nenhum defeito de T1 a T7 aberto na RC2 final. Os dois defeitos reais achados na RC2 da rodada 5 foram corrigidos na F4.5 e provados pelos próprios cenários: T4 (o `user` usava `qemu:///session`, issue 74; agora o `~/.config/libvirt/libvirt.conf` vem do `/etc/skel` e o T4 passa em 3 ciclos) e T7 (o Enter não fechava o terminal dos atalhos de forma intermitente, o terminal ficava em modo cru depois do `sudo`, issue 78; agora o `nexus-atalho` faz `stty sane` antes do prompt e o T7 passou em 3 execuções seguidas, com o Enter fechando os 4 terminais em cada uma). As execuções com `FALHA:` na RC2 da rodada 5 ficam como histórico (`evidencias/T4/2026-11-06-kvm.md` e `evidencias/T7/2026-11-09-kvm-2.md`).
- T7: a primeira rodada humana (09/11/2026, RC2 da rodada 5) foi parcial; a segunda, na RC2 final (`humano-2026-11-09-2.md`), passou completa, com o Enter fechando os 4 terminais, e o T7 fica ✅ (parte automática e rodada humana OK). A reprodução por outra pessoa continua pendente.

## Fora do escopo

- OpenDaylight (F3.1): opcional e fora da Fase 4; o T2 usa regras OpenFlow manuais, sem controlador.
- GNS3: só documentado ([gns3.md](gns3.md)), sem teste.
- Ansible: fora do escopo.
- Desempenho em hardware real: todas as medições são em VM (Hyper-V e QEMU dentro dela).
