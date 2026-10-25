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
