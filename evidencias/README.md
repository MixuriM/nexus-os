# Evidências dos testes funcionais

Índice das evidências da Fase 4. Plano, critérios e métricas: [../docs/plano-de-testes.md](../docs/plano-de-testes.md). Formato dos arquivos: [MODELO.md](MODELO.md).

Status: ✅ executado com evidência; 🟡 depende de outra pessoa ou de rodada humana; ⏳ ninguém executou.

| Cenário | Tarefa | Status | Evidência |
| --- | --- | --- | --- |
| T1 | F4.2a | ✅ | [2026-11-06-kvm.md](T1/2026-11-06-kvm.md): OK, com KVM; reprodução por outra pessoa pendente |
| T2 | F4.2b | ✅ | [2026-11-06-kvm.md](T2/2026-11-06-kvm.md): OK, com KVM; reprodução por outra pessoa pendente |
| T3 | F4.2c | ✅ | [2026-11-09-kvm.md](T3/2026-11-09-kvm.md): OK, com KVM, 3 ciclos; reprodução por outra pessoa pendente |
| T4 | F4.2d | 🟡 | [2026-11-06-kvm.md](T4/2026-11-06-kvm.md): FALHA por defeito real (`virsh` do `user` usa `qemu:///session`), aguarda a correção da F4.5 |
| T5 | F4.2e | 🟡 | [2026-11-09-kvm.md](T5/2026-11-09-kvm.md): parte automática OK, com KVM, convergência em 19,01 s; lacunas em [lacunas.md](T5/lacunas.md); falta a rodada humana "sem ajuda externa" (bloco 7) |
| T6 | F4.3 | ✅ | [2026-11-09-kvm.md](T6/2026-11-09-kvm.md), [-2](T6/2026-11-09-kvm-2.md) e [-3](T6/2026-11-09-kvm-3.md): OK, com KVM, 3 de 3 execuções seguidas, cada uma num QEMU novo; reprodução por outra pessoa pendente |
| T7 | F4.2f | 🟡 | [2026-11-09-kvm.md](T7/2026-11-09-kvm.md): parte automática OK, com KVM, 5 pontos com captura (sessão em 22,1 s), roteiro sem a etapa do Enter; [2026-11-09-kvm-2.md](T7/2026-11-09-kvm-2.md): FALHA por defeito real (o Enter não fecha o terminal dos atalhos), aguarda a correção da F4.5; rodada humana parcial em [humano-2026-11-09.md](T7/humano-2026-11-09.md) (4 de 5 capturas, sem documentação nem remover), a repetir na ISO final (bloco 7) |
