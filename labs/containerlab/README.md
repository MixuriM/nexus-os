# Containerlab

Topologia de demonstração principal, usando Containerlab.

- `frr-duo.clab.yml`: dois nós FRR (`r1` e `r2`) ligados por um enlace, OSPF área 0, um loopback /32 anunciado por nó.
- `configs/r1/` e `configs/r2/`: `daemons` e `frr.conf`, montados em `/etc/frr` por `binds`.

Status: validado em VM Debian 13 (F2.7), imagem `quay.io/frrouting/frr:10.7.1`. Passos em [docs/nfv.md](../../docs/nfv.md). Teste: `sudo tests/nfv.sh`.

## Como usar, passo a passo

**Onde:** na raiz do repositório, numa VM Debian 13 com Docker e Containerlab (ou, dentro da ISO, com o caminho `/usr/share/nexus-os/labs/containerlab/`). O Containerlab precisa de `sudo`.

1. **Subir a topologia de demonstração:** `sudo containerlab deploy -t labs/containerlab/frr-duo.clab.yml`. **Por quê:** cria os contêineres `clab-frr-duo-r1` e `clab-frr-duo-r2` e o enlace entre eles. **Deve aparecer:** uma tabela com os dois nós `running`. **Se não aparecer:** sem a imagem FRR local o `deploy` falha (veja [docs/nfv.md](../../docs/nfv.md), "Instalação").
2. **Conferir as rotas:** `sudo docker exec clab-frr-duo-r1 vtysh -c 'show ip route ospf'`. **Deve aparecer:** `O>* 198.51.100.2/32` (espere uns 15 s e repita se vier vazio).
3. **Destruir:** `sudo containerlab destroy -t labs/containerlab/frr-duo.clab.yml --cleanup`. **Deve aparecer:** os dois contêineres removidos.

- `vnf-frr.clab.yml`: um nó FRR (`vnf1`, loopback 198.51.100.11/32) instanciado pelo `nfv/nexus-vnf.sh` (F3.6). Veja [nfv/README.md](../../nfv/README.md).

- `integrado.clab.yml` (F4.3): `r1` e `r2` (loopbacks 198.51.100.21/32 e 198.51.100.22/32, OSPF área 0, configurações em `configs/int-r1/` e `int-r2/`) ligados por UMA ponte Open vSwitch, `br-integrado`, pelo `kind: ovs-bridge` do Containerlab. A ponte é criada antes (`ovs-vsctl add-br br-integrado -- set bridge br-integrado fail_mode=secure`), as regras são `sdn/flows/integrado.flows` e a subida é `sudo nexus-vnf up labs/containerlab/integrado.clab.yml`. Teste: `tests/cenario-t6.sh <iso>`. Passos e medições: [docs/nfv.md](../../docs/nfv.md), seção "Cenário integrado (F4.3)".
