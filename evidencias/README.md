# Evidências dos testes funcionais

Índice das evidências da Fase 4. Plano, critérios e métricas: [../docs/plano-de-testes.md](../docs/plano-de-testes.md). Formato dos arquivos: [MODELO.md](MODELO.md).

Status: ✅ executado com evidência; 🟡 depende de outra pessoa ou de rodada humana; ⏳ ninguém executou.

| Cenário | Tarefa | Status | Evidência |
| --- | --- | --- | --- |
| T1 | F4.2a | ✅ | [2026-11-09-kvm-2.md](T1/2026-11-09-kvm-2.md): OK, com KVM, na RC2 final `28efa045` (commit `61e02b9`); histórico: [2026-11-09-kvm.md](T1/2026-11-09-kvm.md) (ISO `5f47083b`) e [2026-11-06-kvm.md](T1/2026-11-06-kvm.md) (RC2 da rodada 5); reprodução por outra pessoa pendente |
| T2 | F4.2b | ✅ | [2026-11-09-kvm-2.md](T2/2026-11-09-kvm-2.md): OK, com KVM, na RC2 final `28efa045`; histórico: [2026-11-09-kvm.md](T2/2026-11-09-kvm.md) e [2026-11-06-kvm.md](T2/2026-11-06-kvm.md); reprodução por outra pessoa pendente |
| T3 | F4.2c | ✅ | [2026-11-09-kvm-3.md](T3/2026-11-09-kvm-3.md): OK, com KVM, 3 ciclos, na RC2 final `28efa045`; histórico: [-2](T3/2026-11-09-kvm-2.md) e [2026-11-09-kvm.md](T3/2026-11-09-kvm.md); reprodução por outra pessoa pendente |
| T4 | F4.2d | ✅ | [2026-11-09-kvm-2.md](T4/2026-11-09-kvm-2.md): OK, com KVM, 3 ciclos, na RC2 final `28efa045` (o `virsh` do `user` usa `qemu:///system`, issue 74 corrigida); histórico: [2026-11-09-kvm.md](T4/2026-11-09-kvm.md) e [2026-11-06-kvm.md](T4/2026-11-06-kvm.md) (FALHA por defeito real na RC2 da rodada 5); reprodução por outra pessoa pendente |
| T5 | F4.2e | 🟡 | [2026-11-09-kvm-3.md](T5/2026-11-09-kvm-3.md): parte automática OK, com KVM, na RC2 final `28efa045`; histórico: [-2](T5/2026-11-09-kvm-2.md) e [2026-11-09-kvm.md](T5/2026-11-09-kvm.md); lacunas em [lacunas.md](T5/lacunas.md), corrigidas no manual v2; falta a rodada humana "sem ajuda externa" (bloco 7) |
| T6 | F4.3 | ✅ | [-7](T6/2026-11-09-kvm-7.md), [-8](T6/2026-11-09-kvm-8.md) e [-9](T6/2026-11-09-kvm-9.md): OK, com KVM, 3 de 3 execuções seguidas na RC2 final `28efa045`; histórico: [-4](T6/2026-11-09-kvm-4.md) a [-6](T6/2026-11-09-kvm-6.md) e [2026-11-09-kvm.md](T6/2026-11-09-kvm.md) a [-3](T6/2026-11-09-kvm-3.md); reprodução por outra pessoa pendente |
| T7 | F4.2f | ✅ | Automático: [2026-11-09-kvm-4.md](T7/2026-11-09-kvm-4.md), OK, com KVM, na RC2 final `28efa045` (5 capturas, sessão em 22,5 s, o Enter fecha os terminais dos atalhos). Humano: [humano-2026-11-09-2.md](T7/humano-2026-11-09-2.md), OK, Hyper-V Geração 2 sem rede, na RC2 final (25,92 s até a barra, os 5 pontos, o Enter nos 4 terminais e os atalhos de remover). Histórico: [2026-11-09-kvm-3.md](T7/2026-11-09-kvm-3.md) (ISO `5f47083b`), [2026-11-09-kvm.md](T7/2026-11-09-kvm.md) (roteiro sem a etapa do Enter), [2026-11-09-kvm-2.md](T7/2026-11-09-kvm-2.md) (FALHA por defeito real na RC2 da rodada 5) e a rodada humana parcial [humano-2026-11-09.md](T7/humano-2026-11-09.md); reprodução por outra pessoa pendente |
