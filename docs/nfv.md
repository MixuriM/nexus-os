# NFV: FRRouting com Containerlab

Validação da F2.7: dois nós FRR em uma topologia Containerlab versionada trocam rotas por OSPF (área 0). FRRouting é a VNF de exemplo do Nexus OS.

## Resultado (22/10/2026)

| Item | Valor |
| --- | --- |
| Ambiente | VM Debian 13 (trixie), sem KVM |
| Runtime | Docker, pacote `docker.io` 26.1.5+dfsg1-9+deb13u1 (`docker --version`: 26.1.5+dfsg1, build a72d7cd) |
| Containerlab | 0.81.1, commit 1e15948d5 (`containerlab version`), instalado pelo script oficial |
| Imagem FRR | `quay.io/frrouting/frr:10.7.1` (tag fixa; `vtysh -c 'show version'` dentro da imagem: FRRouting 10.7.1_git) |
| Topologia | `labs/containerlab/frr-duo.clab.yml`: nós `r1` e `r2`, um enlace `eth1` a `eth1` |
| Configuração | `labs/containerlab/configs/r1/` e `r2/` (`daemons` com `ospfd=yes` e `frr.conf`), montados por `binds` em `/etc/frr` |
| Teste | `sudo tests/nfv.sh`: `OK: tests/nfv.sh (r1 e r2 trocaram os loopbacks por OSPF em 16 s)`, código 0 |

Endereços de laboratório (blocos reservados para documentação, RFC 5737): loopbacks 198.51.100.1/32 (`r1`) e 198.51.100.2/32 (`r2`), enlace 203.0.113.0/30.

## Instalação

Na VM Debian:

```bash
sudo apt install docker.io curl
bash -c "$(curl -sL https://get.containerlab.dev)"
```

O segundo comando é o método de instalação do Containerlab indicado em https://containerlab.dev/install (script que detecta o Debian e instala o pacote `.deb` da versão mais recente). Confira a versão instalada:

```bash
containerlab version
docker pull quay.io/frrouting/frr:10.7.1
```

O Containerlab precisa de root: use `sudo` nos comandos `containerlab`. O `docker exec` funciona com o usuário no grupo `docker` (vale a partir do próximo login) ou com `sudo`.

## Subir e destruir

Na raiz do repositório:

```bash
sudo containerlab deploy -t labs/containerlab/frr-duo.clab.yml
sudo docker exec clab-frr-duo-r1 vtysh -c 'show ip route ospf'
sudo docker exec clab-frr-duo-r2 vtysh -c 'show ip route ospf'
sudo containerlab destroy -t labs/containerlab/frr-duo.clab.yml --cleanup
```

Os contêineres se chamam `clab-frr-duo-r1` e `clab-frr-duo-r2`. A convergência do OSPF levou 16 s no teste.

## Tabela de rotas dos dois nós

Saída de `show ip route ospf` com a rede convergida:

```text
r1:
O>* 198.51.100.2/32 [110/10] via 203.0.113.2, eth1, weight 1, 00:00:01

r2:
O>* 198.51.100.1/32 [110/10] via 203.0.113.1, eth1, weight 1, 00:00:01
```

`show ip ospf neighbor` em `r1`: vizinho `198.51.100.2` em `Full/-`, interface `eth1:203.0.113.1`.

## Teste automatizado

```bash
sudo tests/nfv.sh
```

O teste implanta a topologia, espera até 90 s pela rota OSPF do loopback do outro nó nos dois lados, imprime as duas tabelas, destrói a topologia (`--cleanup`) e confere que nenhum contêiner do laboratório sobrou.

## Decisões e problemas conhecidos

- A topologia usa `kind: linux` com `binds`, e não o `kind: frr` nativo que o Containerlab oferece desde a versão 0.80 (em https://containerlab.dev/manual/kinds/frr). O `kind: linux` mantém `daemons` e `frr.conf` visíveis e versionados em `configs/`, e funciona com a imagem FRR padrão. Migrar para `kind: frr` é possível depois.
- O `vtysh` imprime em cada chamada `Can't open configuration file /etc/frr/vtysh.conf` e `Configuration file[/etc/frr/frr.conf] processing failure: 11`. A configuração está aplicada (as rotas OSPF aparecem e `show running-config` mostra o `frr.conf`), então o aviso é cosmético. A causa não foi investigada a fundo; o teste descarta o `stderr` do `vtysh`.
- A imagem `quay.io/frrouting/frr:10.7.1` é baixada da internet na primeira vez. Sem rede, o `deploy` falha. A Fase 3 (F3.4) trata das imagens offline.
- Sem KVM a VM é mais lenta, mas os nós FRR são contêineres e não dependem dele.

## Na ISO (F3.5 e F3.7)

A ISO traz o FRRouting do pacote Debian e o Containerlab, sem precisar de internet depois do boot. Os dois coexistem com papéis diferentes:

| Item | Versão | Para que serve |
| --- | --- | --- |
| Pacote `frr` (Debian 13 main) | 10.3-3+deb13u1 (`apt-cache policy frr`) | FRR no próprio sistema da ISO, serviço `frr.service` habilitado como o pacote instala |
| Imagem `quay.io/frrouting/frr:10.7.1` | 10.7.1 | Nós `r1` e `r2` da topologia Containerlab; vem dentro da ISO (veja [containers.md](containers.md)) |
| Containerlab | 0.81.1, pacote `.deb` oficial | Sobe a topologia de demonstração |

A versão do pacote (10.3) é diferente da imagem de contêiner (10.7.1). Isso não afeta a topologia, porque os nós usam a imagem, e não o FRR do sistema.

### Configuração de exemplo do FRR

`nfv/frr/exemplo/daemons` e `nfv/frr/exemplo/frr.conf`: um roteador `ex1` com `zebra=yes`, `ospfd=yes` e o loopback 198.51.100.10/32 em OSPF área 0 (bloco RFC 5737). Na ISO ficam em `/usr/share/nexus-os/nfv/frr/exemplo/`. O pacote não ativa o `ospfd` por padrão: para usar o exemplo, copie os dois arquivos para `/etc/frr/` (dono `frr:frr`, modo 0640) e reinicie o serviço:

```bash
sudo install -m 0640 -o frr -g frr /usr/share/nexus-os/nfv/frr/exemplo/daemons /etc/frr/daemons
sudo install -m 0640 -o frr -g frr /usr/share/nexus-os/nfv/frr/exemplo/frr.conf /etc/frr/frr.conf
sudo systemctl restart frr
sudo vtysh -c 'show running-config'
sudo vtysh -c 'show ip ospf'
```

O smoke `frr` (`tests/frr.sh`) faz exatamente isso, confere o loopback e o `router ospf` na configuração em execução e o `ospfd`, e restaura os arquivos originais no fim.

### Topologia em um comando

```bash
sudo containerlab deploy -t /usr/share/nexus-os/labs/containerlab/frr-duo.clab.yml
sudo docker exec clab-frr-duo-r1 vtysh -c 'show ip route ospf'
sudo containerlab destroy -t /usr/share/nexus-os/labs/containerlab/frr-duo.clab.yml --cleanup
```

O smoke `nfv` é o `tests/nfv.sh` da F2.7, sem alteração, rodando dentro da ISO sem rede com a imagem que já está nela.

### Como o `.deb` do Containerlab entra na ISO

`scripts/prepare-offline.sh` baixa `containerlab_0.81.1_linux_amd64.deb` de `https://github.com/srl-labs/containerlab/releases/download/v0.81.1/` para `live-build/config/packages.chroot/` (pasta ignorada pelo git, lida pelo live-build) e confere o SHA256 contra `live-build/offline/containerlab.sha256`. Divergência é `FALHA:`. A release publica `checksums.txt`, e o SHA256 gravado coincide com ele e com o `digest` da API do GitHub. O pacote não declara dependências (`dpkg -I`) e instalou no chroot sem erro. Para trocar a versão, baixe o novo `.deb`, confira com o `checksums.txt` da release e atualize o arquivo `containerlab.sha256`.

### Medições (25/10/2026, com KVM no Hyper-V, sem rede)

| Item | Valor |
| --- | --- |
| Build da ISO | 346 s, 921698304 bytes (a ISO da parte 3 tinha 893386752: +28311552) |
| SHA256 da ISO | `392e651860a1e25c8682befcc42d14319ce5364bd2888aa1004704df016f68ef` |
| `tests/iso-smoke.sh dist/nexus-os-poc-amd64.iso frr,nfv` | `OK: 2 teste(s) sem falha em 48 s`, `frr=1s`, `nfv=18s` |
| `tests/iso-smoke.sh ... all` | `OK: 6 teste(s) sem falha em 60 s` (`sdn=8s`, `virtualizacao=2s`, `libvirt=1s`, `containers=1s`, `frr=1s`, `nfv=19s`) |
| Convergência do OSPF na ISO (`tests/nfv.sh`) | 12 s e 15 s (duas medições) |
| Deploy da topologia na ISO | 4 s até os dois contêineres rodando |
| RAM do FRR do pacote em repouso (configuração padrão do pacote, `ospfd=no`) | processos `watchfrr`, `zebra`, `mgmtd` e `staticd`: 28,3 MiB de RSS somados; `free -m` "usada" foi de 767 MiB sem o `frr` para 780 MiB com ele |
| RED (ISO da parte 3, com os testes via `--extra`) | `FALHA: vtysh não instalado (pacote frr)` e `FALHA: containerlab não instalado`, `NEXUS-SMOKE-END frr 1` e `nfv 1` |

### Problemas conhecidos (ISO)

- Sem rede, o `containerlab deploy` imprime `Failed fetching latest version information` depois de cerca de 3 s (medido no log do deploy, entre a criação do enlace e o aviso). A mensagem aponta a consulta da versão mais recente do Containerlab como causa. O binário tem a variável `CLAB_VERSION_CHECK`, mas `CLAB_VERSION_CHECK=disable` não removeu o aviso nos testes; o valor correto não foi confirmado.
- O `hostname ex1` do `frr.conf` de exemplo não aparece em `show running-config` (aparece o nome do sistema), embora o loopback e o OSPF sejam aplicados. O mesmo comando digitado no `vtysh` aparece como linha extra. A causa não foi investigada; o smoke não depende disso.
- O pacote `frr` traz `ospfd=no`. O smoke troca os arquivos de `/etc/frr` pelo exemplo e restaura os originais; o FRR do pacote não faz parte da topologia Containerlab.
- O `.deb` do Containerlab define o binário com setuid e o grupo `clab_admins`; na ISO use `sudo` nos comandos `containerlab`.
- O `tests/iso.sh` falhou uma vez (`login: não apareceu em 300 s, com KVM`) em 6 execuções com a ISO nova; as outras 5 passaram em 27 s e a falha não se repetiu. A causa não foi diagnosticada (a serial não foi guardada nessa execução).
- Reprodução por segunda pessoa pendente.

## Orquestração (F3.6)

Um script único, `nfv/nexus-vnf.sh`, faz o papel simplificado de NFVO/VNFM: instancia a VNF FRR, consulta o estado e remove a VNF. Não usa Ansible.

**Infraestrutura usada:** Containerlab com um contêiner FRR (Docker, imagem `quay.io/frrouting/frr:10.7.1`). O libvirt não participa da orquestração nesta fase; as máquinas virtuais continuam no `nexus-vm` (F3.3).

```bash
sudo nexus-vnf up        # na ISO; no repositório: sudo nfv/nexus-vnf.sh up
sudo nexus-vnf status
sudo nexus-vnf down
sudo nexus-vnf up labs/containerlab/integrado.clab.yml   # topologia opcional (F4.3)
```

Na ISO, `/usr/local/bin/nexus-vnf` é um link (criado pelo hook) para `/usr/share/nexus-os/nfv/nexus-vnf.sh`; o script resolve o caminho real com `readlink -f` para achar a topologia.

A VNF é o nó `vnf1` de `labs/containerlab/vnf-frr.clab.yml` (laboratório `vnf-frr`, contêiner `clab-vnf-frr-vnf1`), com `labs/containerlab/configs/vnf1/{daemons,frr.conf}`: loopback 198.51.100.11/32 em OSPF área 0. O nó não tem enlaces: o Containerlab aceitou a topologia sem a seção `links`, medido na VM de laboratório.

| Comando | Efeito | Código de saída |
| --- | --- | --- |
| `up` | `containerlab deploy` e espera até 60 s pelo `vtysh`; se a VNF já roda, imprime `OK: ... já instanciada` e não recria | 0, ou 1 com `FALHA:` |
| `status` | estado do contêiner, primeira linha de `show version` e o loopback de `show running-config` | 0 se roda, 1 se não roda |
| `down` | `containerlab destroy --cleanup` e confere que nenhum contêiner nem a rede `clab` sobrou; repetir é seguro | 0, ou 1 com `FALHA:` |
| outro | ajuda no erro padrão | 2 |

**Topologia opcional (F4.3):** cada comando aceita, depois do nome, o caminho de um arquivo de topologia (`up|status|down [topologia.clab.yml]`). Sem ele vale a VNF padrão, com as mesmas saídas de antes. Com ele, o script usa o nome da linha `name:` do arquivo como laboratório (filtro `containerlab=<nome>`), espera o `vtysh` de cada nó FRR do laboratório no `up`, mostra contêiner, versão e loopback de cada nó no `status` e destrói o laboratório no `down`, com as mesmas conferências (nenhum contêiner nem a rede `clab` sobra). Arquivo inexistente ou argumento a mais sai com 2 (`FALHA: topologia não encontrada: ...` na saída de erro). O script não cria nada fora do Containerlab: a ponte Open vSwitch do cenário integrado é criada e removida por quem o roda.

Saída do `status` com a VNF rodando (VM de laboratório, 26/10/2026):

```text
contêiner: clab-vnf-frr-vnf1 (running)
versão: FRRouting 10.7.1_git (vnf1) on Linux(6.12.113+deb13-amd64).
loopback: 198.51.100.11/32
OK: VNF vnf1 rodando
```

### Teste

`sudo tests/orquestracao.sh` roda `up`, `status` (0, com FRR e o loopback), `down`, `status` (1), `up` duas vezes (o contêiner não é recriado), `down` duas vezes, confere que nada sobrou e que o uso inválido sai com 2. Depois, a topologia opcional: arquivo inexistente e argumento a mais saem com 2, a VNF padrão passada por extenso se comporta como sem argumento e a `frr-duo` sobe, informa os dois nós, não é recriada pelo segundo `up`, desce sem resíduo e dá `status` 1. Na ISO é o smoke `orquestracao`, que usa o link `/usr/local/bin/nexus-vnf` (a RC2 traz o script anterior ao argumento opcional, então esse teste novo só passa na ISO gerada depois deste commit).

### Medições (26/10/2026, VM Debian 13 no Hyper-V, com KVM, sem rede na ISO)

| Item | Valor |
| --- | --- |
| RED no laboratório (antes do script) | `FALHA: script ausente: nfv/nexus-vnf.sh`, código 1 |
| GREEN no laboratório | `OK: tests/orquestracao.sh`, 2,6 s |
| Mutação M1 (`destroy` comentado no `down`) | `FALHA: down saiu com 1: FALHA: contêiner da VNF sobrou depois do destroy`, código 1 |
| Mutação M2 (tag `frr:10.7.99`) | `FALHA: up saiu com 1: FALHA: containerlab deploy falhou`, código 1 |
| Regressão `sudo tests/nfv.sh` | `OK` (OSPF em 16 s) |
| Build da ISO | 435 s, 921698304 bytes (igual à ISO anterior), SHA256 `729572f567dce43e455a87cf3fc37d2b94fb19c772121added3f8c5eb59637bb` |
| `tests/iso-smoke.sh dist/nexus-os-poc-amd64.iso all` | `OK: 7 teste(s) sem falha em 75 s, com KVM` (`sdn=7s`, `virtualizacao=3s`, `libvirt=4s`, `containers=2s`, `frr=1s`, `nfv=18s`, `orquestracao=9s`) |
| `tests/iso.sh` | `OK` em 28 s, com KVM |

O build levou mais que os 346 s da parte anterior; a internet da VM oscilou durante o build, que terminou sem erro (SHA256 do `.deb` do Containerlab e `tar` da imagem conferidos).

### Problemas conhecidos

- O `down` assume o nome de rede `clab`, o padrão do Containerlab; se alguém mudar `mgmt` na topologia, a verificação precisa mudar junto.
- O `status` lê o loopback da configuração em execução (primeiro `ip address 198.51.100.x/32`); não confere se o OSPF anunciou o endereço, porque a VNF sozinha não tem vizinhos.
- Reprodução por segunda pessoa pendente.

## Cenário integrado (F4.3)

Topologia `labs/containerlab/integrado.clab.yml` (laboratório `integrado`): `r1` e `r2` (imagem `quay.io/frrouting/frr:10.7.1`, OSPF área 0, `hello-interval 1` e `dead-interval 4`) ligados por UMA ponte Open vSwitch, `br-integrado`, em modo `secure` e sem controlador. As regras OpenFlow escritas à mão estão em `sdn/flows/integrado.flows`: ARP e IP entre as portas `ovsp1` (`r1`) e `ovsp2` (`r2`), e o OSPF (protocolo IP 89) com regra própria de prioridade maior. Configurações em `labs/containerlab/configs/int-r1/` e `int-r2/`.

| Item | Valor |
| --- | --- |
| Loopbacks | 198.51.100.21/32 (`r1`) e 198.51.100.22/32 (`r2`), sem colidir com o `vnf1` (198.51.100.11/32) nem com a `frr-duo` (.1 e .2) |
| Enlace | 203.0.113.4/30: `r1` 203.0.113.5 e `r2` 203.0.113.6 (blocos de documentação, RFC 5737) |
| Mecanismo de ligação | `kind: ovs-bridge` do Containerlab 0.81.1 (a versão travada em `live-build/offline/containerlab.sha256`) |
| Página consultada | https://containerlab.dev/manual/kinds/ovs-bridge (consulta de 09/11/2026) |

**Mecanismo.** Segundo essa página, o Containerlab não cria a ponte: ela tem de existir antes (`ovs-vsctl add-br`), entra na topologia como um nó `kind: ovs-bridge` com o mesmo nome da ponte, e cada enlace usa o nome do nó e o de uma interface nova (`br-integrado:ovsp1`, que não pode colidir com interface existente). O `containerlab deploy --help` da versão 0.81.1 não lista os kinds; a conferência foi o `deploy` real, que ligou as duas portas (`ovs-vsctl list-ports br-integrado` mostra `ovsp1` e `ovsp2`) e as tirou da ponte no `destroy`. As regras usam o nome das portas (`in_port=ovsp1`), que o `ovs-ofctl` resolve para o número do OpenFlow depois do `deploy`; por isso as regras são carregadas depois do `up`.

Ordem dos comandos (o bloco `bash nexus-exec` equivalente está em [manual.md](manual.md), seção "Cenário integrado"):

```bash
sudo ovs-vsctl add-br br-integrado -- set bridge br-integrado fail_mode=secure
sudo nexus-vnf up labs/containerlab/integrado.clab.yml
sudo ovs-ofctl add-flows br-integrado sdn/flows/integrado.flows
sudo docker exec clab-integrado-r1 vtysh -c 'show ip ospf neighbor'
sudo ovs-ofctl add-flow br-integrado 'priority=200,ip,nw_proto=89,actions=drop'   # derruba a adjacência
sudo ovs-ofctl --strict del-flows br-integrado 'priority=200,ip,nw_proto=89'      # restaura
sudo nexus-vnf down labs/containerlab/integrado.clab.yml
sudo ovs-vsctl del-br br-integrado
```

### Teste T6 (F4.3)

`tests/cenario-t6.sh <iso>` roda o cenário 3 vezes seguidas, cada uma num QEMU novo, sem rede e sem persistência, com 2560 MiB (a RAM recomendada com o desktop, [requisitos.md](requisitos.md)). Os arquivos do cenário vão dentro do script do convidado, porque a RC2 ainda não os traz; entram na ISO a partir da próxima geração. Critérios por execução e mutações: [plano-de-testes.md](plano-de-testes.md). Medido em 09/11/2026, com KVM, na RC2 (evidências em `evidencias/T6/`):

| Execução | `nexus-vnf up` | Convergência inicial (a partir do `up`) | Queda após o descarte do protocolo 89 | Recuperação após remover o descarte | `down` | Tempo no convidado | Tempo total (boot ao desligamento) |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 6,91 s | 13,53 s | 4,54 s | 6,13 s | 0,52 s | 29,07 s | 69 s |
| 2 | 6,99 s | 13,55 s | 4,54 s | 6,15 s | 0,53 s | 29,09 s | 69 s |
| 3 | 7,11 s | 13,68 s | 4,52 s | 6,14 s | 0,55 s | 29,25 s | 69 s |

Limites do teste: convergência inicial 120 s (parâmetro `T6_LIMITE`), queda 12 s (3 vezes o `dead-interval` de 4 s lido de `configs/int-r1/frr.conf`) e recuperação 30 s. RAM do convidado: pico de 1216 a 1225 MiB de 2560 MiB, abaixo da recomendada; não foi preciso pedir mais RAM.

### Problemas conhecidos (integrado)

- A RC2 não traz `integrado.clab.yml`, `integrado.flows` nem o `nexus-vnf` com topologia opcional: o T6 os carrega no script do convidado. O `tests/orquestracao.sh` e o `tests/manual.sh` completos (o bloco "Cenário integrado") só passam em ISO gerada depois deste commit.
- A regra de IP geral (prioridade 90) também deixa o OSPF passar; é a regra explícita do protocolo 89 (prioridade 100) que o teste exige com pacotes contados, e o descarte (prioridade 200) manda mais que as duas.
- Reprodução por segunda pessoa pendente.
