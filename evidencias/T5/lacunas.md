# Lacunas do manual encontradas no T5 (parte automática)

Execução de 09/11/2026 com KVM na RC2 (`evidencias/T5/2026-11-09-kvm.md`): o único bloco da seção "Containerlab" do `docs/manual.md` passou, sem alteração. Nenhum bloco falhou nem dependeu de comando ausente, ordem errada ou pré-condição calada. Os dois pontos abaixo são imprecisões do texto, sem efeito no resultado. A correção é do manual v2 (bloco 6), não deste teste. A rodada humana "sem ajuda externa" do T5 continua pendente (bloco 7).

| Bloco | O que faltou | Correção proposta |
| --- | --- | --- |
| Seção "Containerlab", bloco 1 | A "Saída esperada" diz que a convergência levou de 12 s a 16 s, sem dizer de onde a contagem começa. Medida do início do `deploy` até a adjacência `Full` e as rotas, o T5 deu 19,01 s (limite do teste: 120 s). | Dizer que os 12 s a 16 s são contados depois do `deploy` (como no `tests/nfv.sh`) e acrescentar a medida desde o início do `deploy`. |
| Seção "Containerlab", texto antes do bloco | O texto diz que o `vtysh` imprime o aviso `Can't open configuration file /etc/frr/vtysh.conf`, mas o bloco manda o erro do `docker exec` para `/dev/null`: o aviso não aparece na saída do bloco (0 ocorrências na evidência). | Tirar o aviso do texto ou dizer que ele só aparece ao rodar o `docker exec ... vtysh` à mão. |
