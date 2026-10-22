# Containerlab

Topologia de demonstração principal, usando Containerlab.

- `frr-duo.clab.yml`: dois nós FRR (`r1` e `r2`) ligados por um enlace, OSPF área 0, um loopback /32 anunciado por nó.
- `configs/r1/` e `configs/r2/`: `daemons` e `frr.conf`, montados em `/etc/frr` por `binds`.

Status: validado em VM Debian 13 (F2.7), imagem `quay.io/frrouting/frr:10.7.1`. Passos em [docs/nfv.md](../../docs/nfv.md). Teste: `sudo tests/nfv.sh`.
