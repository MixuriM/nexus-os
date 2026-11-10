# Evidências dos testes funcionais

Índice das evidências da Fase 4. Plano, critérios e métricas: [../docs/plano-de-testes.md](../docs/plano-de-testes.md). Formato dos arquivos: [MODELO.md](MODELO.md).

Status: ✅ executado com evidência; 🟡 depende de outra pessoa ou de rodada humana; ⏳ ninguém executou.

| Cenário | Tarefa | Status | Evidência |
| --- | --- | --- | --- |
| T1 | F4.2a | ✅ | [2026-11-09-kvm.md](T1/2026-11-09-kvm.md): OK, com KVM, na RC2 final `5f47083b` (histórico: [2026-11-06-kvm.md](T1/2026-11-06-kvm.md), RC2 da rodada 5); reprodução por outra pessoa pendente |
| T2 | F4.2b | ✅ | [2026-11-09-kvm.md](T2/2026-11-09-kvm.md): OK, com KVM, na RC2 final (histórico: [2026-11-06-kvm.md](T2/2026-11-06-kvm.md)); reprodução por outra pessoa pendente |
| T3 | F4.2c | ✅ | [2026-11-09-kvm-2.md](T3/2026-11-09-kvm-2.md): OK, com KVM, 3 ciclos, na RC2 final (histórico: [2026-11-09-kvm.md](T3/2026-11-09-kvm.md)); reprodução por outra pessoa pendente |
| T4 | F4.2d | ✅ | [2026-11-09-kvm.md](T4/2026-11-09-kvm.md): OK, com KVM, 3 ciclos, na RC2 final (o `virsh` do `user` usa `qemu:///system`, issue 74 corrigida); histórico: [2026-11-06-kvm.md](T4/2026-11-06-kvm.md), FALHA por defeito real na RC2 da rodada 5; reprodução por outra pessoa pendente |
| T5 | F4.2e | 🟡 | [2026-11-09-kvm-2.md](T5/2026-11-09-kvm-2.md): parte automática OK, com KVM, na RC2 final, convergência em 19,21 s (histórico: [2026-11-09-kvm.md](T5/2026-11-09-kvm.md)); lacunas em [lacunas.md](T5/lacunas.md), corrigidas no manual v2; falta a rodada humana "sem ajuda externa" (bloco 7) |
| T6 | F4.3 | ✅ | [-4](T6/2026-11-09-kvm-4.md), [-5](T6/2026-11-09-kvm-5.md) e [-6](T6/2026-11-09-kvm-6.md): OK, com KVM, 3 de 3 execuções seguidas na RC2 final (histórico: [2026-11-09-kvm.md](T6/2026-11-09-kvm.md), [-2](T6/2026-11-09-kvm-2.md) e [-3](T6/2026-11-09-kvm-3.md)); reprodução por outra pessoa pendente |
| T7 | F4.2f | 🟡 | [2026-11-09-kvm-3.md](T7/2026-11-09-kvm-3.md): parte automática OK, com KVM, na RC2 final (5 capturas, sessão em 22,8 s, o Enter fecha os terminais dos atalhos, issue 78 corrigida); histórico: [2026-11-09-kvm.md](T7/2026-11-09-kvm.md) (roteiro sem a etapa do Enter) e [2026-11-09-kvm-2.md](T7/2026-11-09-kvm-2.md) (FALHA por defeito real na RC2 da rodada 5); rodada humana parcial em [humano-2026-11-09.md](T7/humano-2026-11-09.md), a repetir na RC2 final (bloco 7) |
