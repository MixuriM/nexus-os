# Modelo de evidência

Formato dos arquivos de `evidencias/<Tn>/`. O plano está em [../docs/plano-de-testes.md](../docs/plano-de-testes.md).

## Registro pela biblioteca

Os cenários fazem `source tests/lib-evidencia.sh` e chamam:

```bash
evidencia_registrar <Tn> <kvm|emul> "<comando exato>" <arquivo com a saída bruta> <OK|FALHA> <iso> ["chave: valor"]...
```

- `<iso>` é o caminho da ISO (o SHA256 sai dela) ou vazio se a variável `EVID_SHA` estiver definida.
- Grava `evidencias/<Tn>/AAAA-MM-DD-<modo>.md` e `AAAA-MM-DD-<modo>.txt`; uma segunda execução no mesmo dia e modo ganha o sufixo `-2`, depois `-3`.
- `evidencia_sanitizar` lê a entrada padrão e imprime a saída sanitizada (usada pelo registro; os cenários podem chamá-la direto).
- Variáveis opcionais: `EVID_DIR` (outra pasta de saída), `EVID_SHA`, `EVID_HOSTNAMES` (nomes de máquina extras a mascarar) e `EVID_AMBIENTE`.

## Campos do `.md`

```markdown
# Evidência T1 (kvm)

- Data: AAAA-MM-DD
- ISO (SHA256, 12 primeiros): 0123456789ab
- Modo: kvm
- Ambiente: VM Debian 13 no Hyper-V (QEMU com KVM dentro dela)
- Comando: `tests/cenario-t1.sh dist/nexus-os-rc2-amd64.iso`
- Resultado: OK
- Saída sanitizada: [AAAA-MM-DD-kvm.txt](AAAA-MM-DD-kvm.txt)

## Métricas

- tempo_login_s: 36
```

O modo `emul` troca o ambiente por "VM Debian 13 no Hyper-V (QEMU dentro dela, sem KVM)". As métricas são linhas `- chave: valor`, uma por medida.

## Sanitização do `.txt`

- Sem CR nem sequências de cor (ANSI).
- Sem IP privado (faixas 10, 172.16 a 172.31 e 192.168), e-mail, caminho de usuário do Windows, pasta pessoal em `/home` (a conta pública `user` da live fica) nem nome de máquina.
- No máximo 300 linhas: início e fim, com a linha `[... N linhas omitidas ...]` no corte; linhas cortadas em 1000 caracteres.
- Cada arquivo de evidência tem até 1 MiB. Nunca grave `.log` (o `.gitignore` ignora): use `.txt`.

`tests/evidencias.sh` confere os campos, o tamanho, a sanitização e a ausência de dado pessoal.
