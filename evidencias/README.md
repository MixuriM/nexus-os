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
| T6 | F4.3 | ⏳ | (nenhuma ainda) |
| T7 | F4.2f | ⏳ | (nenhuma ainda) |
