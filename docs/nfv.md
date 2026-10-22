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
