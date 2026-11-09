# Containerlab

Topologia de demonstração principal, usando Containerlab.

- `frr-duo.clab.yml`: dois nós FRR (`r1` e `r2`) ligados por um enlace, OSPF área 0, um loopback /32 anunciado por nó.
- `configs/r1/` e `configs/r2/`: `daemons` e `frr.conf`, montados em `/etc/frr` por `binds`.

Status: validado em VM Debian 13 (F2.7), imagem `quay.io/frrouting/frr:10.7.1`. Passos em [docs/nfv.md](../../docs/nfv.md). Teste: `sudo tests/nfv.sh`.

- `vnf-frr.clab.yml`: um nó FRR (`vnf1`, loopback 198.51.100.11/32) instanciado pelo `nfv/nexus-vnf.sh` (F3.6). Veja [nfv/README.md](../../nfv/README.md).

- `integrado.clab.yml` (F4.3): `r1` e `r2` (loopbacks 198.51.100.21/32 e 198.51.100.22/32, OSPF área 0, configurações em `configs/int-r1/` e `int-r2/`) ligados por UMA ponte Open vSwitch, `br-integrado`, pelo `kind: ovs-bridge` do Containerlab. A ponte é criada antes (`ovs-vsctl add-br br-integrado -- set bridge br-integrado fail_mode=secure`), as regras são `sdn/flows/integrado.flows` e a subida é `sudo nexus-vnf up labs/containerlab/integrado.clab.yml`. Teste: `tests/cenario-t6.sh <iso>`. Passos e medições: [docs/nfv.md](../../docs/nfv.md), seção "Cenário integrado (F4.3)".
