# Plano de testes funcionais (F4.1)

Plano da Fase 4: sete cenários (T1 a T7), cada um com executor, comando, critério de sucesso, métricas e evidência esperada. Todos os valores de referência vêm de [requisitos.md](requisitos.md), [rc2.md](rc2.md) e [manual.md](manual.md); onde esses documentos não dão limite, o critério é passa ou falha mais a métrica registrada. A evidência segue o formato de [../evidencias/MODELO.md](../evidencias/MODELO.md) e o índice está em [../evidencias/README.md](../evidencias/README.md).

Cada cenário é o script `tests/cenario-tN.sh <iso>`, rodado no host (a VM de build). Ele chama `tests/iso.sh` ou `tests/iso-smoke.sh` (com `--extra` para o script do convidado, em `tests/cenarios-guest/tN.sh`), registra a evidência pela `tests/lib-evidencia.sh` e termina com `OK: cenário Tn` ou `FALHA: ...`. `tests/run-fase4.sh [iso]` roda T1 a T7 em ordem e para no primeiro erro; um cenário sem script termina em `FALHA: cenário Tn ainda não implementado`. `tests/evidencias.sh` confere esta base de forma estática (roda também no Git Bash).

## Ambiente e ISO sob teste

| Item | Valor |
| --- | --- |
| ISO | `dist/nexus-os-rc2-amd64.iso` (RC2 da rodada 5, [rc2.md](rc2.md)) |
| SHA256 | `bb6d89c68970fb24bb6e35ec3db0a74a88490b257eed166729edb941ce673e58` (um `.sha256` ao lado da ISO) |
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
- **Critério de sucesso:** o ciclo de `tests/orquestracao.sh` (`up`, `status` com código 0, `down`, `status` com código 1, `up` e `down` repetidos sem recriar nem falhar, nada sobra, uso inválido sai com 2) passa dentro da ISO.
- **Métricas:** tempo de `up` e de `down`.
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
- **Critério de sucesso:** os comandos do manual, na ordem, criam a topologia `frr-duo`; cada nó aprende o loopback do outro por OSPF em até 90 s (limite de `tests/nfv.sh`); a topologia é removida no fim. Lacuna do manual vira issue.
- **Métricas:** tempo de convergência do OSPF.
- **Evidência esperada:** `evidencias/T5/AAAA-MM-DD-<modo>.md` e `.txt`.

### T6: cenário integrado ponta a ponta (F4.3)

- **Objetivo:** provar o conjunto: topologia Containerlab, OVS com regras OpenFlow, FRR roteando e subida pelo script, do zero, três vezes seguidas.
- **Pré-condições:** T1 a T5 verdes; script do convidado `tests/cenarios-guest/t6.sh`; ISO RC2 em máquina limpa (convidado novo a cada execução).
- **Executor:** dono nominal conforme a tabela "Acompanhamento" da Fase 4; executor real: Marcos.
- **Comando:** `tests/cenario-t6.sh dist/nexus-os-rc2-amd64.iso`
- **Critério de sucesso:** em cada uma das 3 execuções seguidas, `nexus-vnf up`, a topologia no Containerlab, as regras no OVS e a rota OSPF entre os nós passam e tudo é removido no fim; 3 de 3.
- **Métricas:** tempo total e tempo de convergência, por execução.
- **Evidência esperada:** `evidencias/T6/AAAA-MM-DD-<modo>.md` e `.txt`, com as 3 execuções.

### T7: sessão gráfica na RC2 (F4.2f)

- **Objetivo:** provar o desktop XFCE da RC2 em VM com vídeo e sem internet.
- **Pré-condições:** RC2; VM com vídeo (`-vga std`) e sem rede; capturas de tela.
- **Executor:** Marcos (tarefa dele no plano); a reprodução por outra pessoa continua pendente.
- **Comando:** `tests/cenario-t7.sh dist/nexus-os-rc2-amd64.iso`
- **Critério de sucesso:** boot até o desktop com login automático; abrir o `virt-manager` e ver a VM criada por `nexus-vm`; subir a VNF FRR e a topologia Containerlab pelos atalhos; abrir a documentação local; capturas de tela em `evidencias/T7/`.
- **Métricas:** tempo até a sessão (referência 23 s, [requisitos.md](requisitos.md)) e as capturas de tela.
- **Evidência esperada:** `evidencias/T7/AAAA-MM-DD-<modo>.md`, `.txt` e capturas `.png` (até 1 MiB cada arquivo).

## Como rodar T1, T2 e T4 e mutações

Na VM de build, na raiz do clone, com a ISO em `dist/` (cada comando termina em `OK: cenário Tn` ou `FALHA: ...` e grava a evidência em `evidencias/Tn/`):

```bash
tests/cenario-t1.sh dist/nexus-os-rc2-amd64.iso   # cerca de 7 min: boot, all com 2560 MiB e controle negativo com 1536 MiB
tests/cenario-t2.sh dist/nexus-os-rc2-amd64.iso   # cerca de 1 min
tests/cenario-t4.sh dist/nexus-os-rc2-amd64.iso   # cerca de 1 min
```

Mutações (provam que o cenário falha de verdade): rode o cenário com `CENARIO_GUEST=<cópia modificada do script do convidado>` e `EVID_DIR=<pasta temporária>` (para não gravar em `evidencias/`). Para o T1, aponte para uma cópia da ISO por link simbólico com o `.sha256` alterado.

| Mutação | Alteração | Falha esperada |
| --- | --- | --- |
| T1-M1 | `.sha256` com um dígito alterado | `o SHA256 da ISO não confere com o .sha256` |
| T2-M1 | `t2.sh` sem a regra de descarte | `ping de A para C passou` |
| T2-M2 | `t2.sh` com a regra de permissão A para B saindo pela porta 3 | `ping de A para B falhou` |
| T4-M1 | `t4.sh` com `systemctl stop libvirtd` antes do criar | `libvirtd inativo antes do criar` |
| T4-M2 | `t4.sh` com o `nexus-vm remover` trocado por `true` | `sobrou depois do remover` |

## Problemas conhecidos

- T4: o `user` da ISO usa `qemu:///session` no `virsh`, não `qemu:///system`. O libvirt só lê o `/etc/libvirt/libvirt.conf` para o root; o usuário comum lê `~/.config/libvirt/libvirt.conf`. Medido na RC2: `virsh uri` como `user` dá `qemu:///session`; com o arquivo `uri_default = "qemu:///system"` em `~/.config/libvirt/libvirt.conf` dá `qemu:///system`. O T4 fica sem ✅ até a correção (por exemplo, o arquivo em `/etc/skel/.config/libvirt/` na ISO, na F4.5). Sem esse ponto, o resto do T4 passou numa cópia de diagnóstico do script (3 ciclos, `type='kvm'`), que não é evidência.

## Fora do escopo

- OpenDaylight (F3.1): opcional e fora da Fase 4; o T2 usa regras OpenFlow manuais, sem controlador.
- GNS3: só documentado ([gns3.md](gns3.md)), sem teste.
- Ansible: fora do escopo.
- Desempenho em hardware real: todas as medições são em VM (Hyper-V e QEMU dentro dela).
