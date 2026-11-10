# SDN

Open vSwitch com regras OpenFlow escritas à mão (`ovs-ofctl`), sem controlador. OpenDaylight é opcional e fica fora desta fase.

- `lab-ovs.sh`: sobe (`up`), recarrega as regras (`flows`) e derruba (`down`) o laboratório.
- `flows/basico.flows`: regras OpenFlow carregadas na bridge `br-nexus`.
- `flows/integrado.flows` (F4.3): regras da ponte `br-integrado` do cenário integrado, que liga dois nós FRR do Containerlab (ARP, IP e OSPF, protocolo IP 89). Veja [docs/nfv.md](../docs/nfv.md), seção "Cenário integrado (F4.3)".

Status: validado em VM Debian 13 (F2.5). Passos e medições em [docs/sdn.md](../docs/sdn.md). Teste: `sudo tests/sdn.sh`.

## Como usar, passo a passo

**Onde:** na raiz do repositório, numa VM Debian 13 com `sudo` (ou, dentro da ISO, com `nexus-sdn` no lugar de `sdn/lab-ovs.sh`).

1. **Criar o laboratório:** `sudo sdn/lab-ovs.sh up`. **Por quê:** cria a ponte `br-nexus` em modo `secure`, os namespaces `h1` e `h2` e carrega `flows/basico.flows`. **Deve aparecer:** nenhuma mensagem de falha. **Se não aparecer:** sobra de uma tentativa anterior: `sudo sdn/lab-ovs.sh down` e repita.
2. **Conferir:** `sudo ip netns exec h1 ping -c 2 192.0.2.2`. **Deve aparecer:** `0% packet loss`. **Se não aparecer:** `sudo sdn/lab-ovs.sh flows` recarrega as regras.
3. **Desmontar:** `sudo sdn/lab-ovs.sh down`.
4. **Testar tudo de uma vez:** `sudo tests/sdn.sh`. **Deve aparecer:** `OK: tests/sdn.sh (...)`.

O passo a passo completo, com cada comando explicado, está em [docs/sdn.md](../docs/sdn.md).
