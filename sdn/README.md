# SDN

Open vSwitch com regras OpenFlow escritas à mão (`ovs-ofctl`), sem controlador. OpenDaylight é opcional e fica fora desta fase.

- `lab-ovs.sh`: sobe (`up`), recarrega as regras (`flows`) e derruba (`down`) o laboratório.
- `flows/basico.flows`: regras OpenFlow carregadas na bridge `br-nexus`.

Status: validado em VM Debian 13 (F2.5). Passos e medições em [docs/sdn.md](../docs/sdn.md). Teste: `sudo tests/sdn.sh`.
