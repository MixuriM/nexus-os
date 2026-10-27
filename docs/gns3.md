# GNS3: instalação e uso (só documentado)

F3.8. O GNS3 é a topologia de demonstração secundária do Nexus OS. Por decisão do escopo reduzido ele **só é documentado**: não entra na ISO. A topologia principal é o Containerlab ([nfv.md](nfv.md)).

Cada comando abaixo está marcado:

- **executado**: rodado em 26/10/2026 na VM de build (Debian 13 no Hyper-V, com KVM), com o resultado registrado;
- **da documentação oficial, não executado**: copiado das páginas oficiais, sem execução nesta tarefa.

Fontes (lidas em 26/10/2026):

- Instalação no Linux: https://docs.gns3.com/docs/getting-started/installation/linux
- Servidor remoto: https://docs.gns3.com/docs/getting-started/installation/remote-server
- Um servidor, vários clientes: https://docs.gns3.com/docs/getting-started/installation/one-server-multiple-clients

## Pré-requisitos

- Debian 13 (ou derivado) ou outro Linux, com internet. O GNS3 não está no `apt` do Debian: a página oficial manda usar o `pipx` (conteúdo da página: "GNS3 is not available through apt; you will have to use `pipx`").
- Python 3 e `pipx`. Medido na VM: Python 3.13.5 e `pipx` 1.7.1 (pacote `pipx` 1.7.1-1 do Debian 13).
- Para a interface gráfica (`gns3-gui`): PyQt6 e uma sessão gráfica. A ISO RC1 não tem ambiente gráfico.
- Para nós QEMU: KVM e libvirt (a página oficial lista `qemu-kvm`, `qemu-utils`, `libvirt-clients`, `libvirt-daemon-system` e `virtinst`).
- Para roteadores Cisco IOS (Dynamips): no Debian 13 o pacote `dynamips` saiu do `apt`, então a página oficial manda compilar a partir do código-fonte.
- A página oficial recomenda um servidor dedicado ao GNS3 para a instalação de servidor remoto e avisa que provedores de nuvem costumam bloquear as instruções de virtualização da CPU, o que deixa o QEMU lento.

## Instalação

### Só o servidor (executado)

Método da documentação oficial (`pipx`), com a instalação isolada numa pasta temporária (`PIPX_HOME`), para não deixar rastro na VM:

```bash
sudo apt-get install -y pipx
export PIPX_HOME=/tmp/gns3-pipx PIPX_BIN_DIR=/tmp/gns3-pipx/bin
pipx install gns3-server
/tmp/gns3-pipx/bin/gns3server --version
```

Resultado real, uma única tentativa: `pipx install gns3-server` terminou com código 0 e instalou `gns3-server 3.0.6` com Python 3.13.5; `gns3server --version` imprimiu `3.0.6`. O `apt-get install pipx` mais o `pipx install` levaram 23 s. Depois do teste, a pasta temporária, `~/GNS3`, `~/.config/GNS3`, o pacote `pipx` e as dependências que só ele trouxe foram removidos. A interface gráfica não foi instalada.

Instalação normal, sem pasta temporária (da documentação oficial, não executada):

```bash
pipx install gns3-server
```

### Interface gráfica e emulação (da documentação oficial, não executados)

Debian 13 (a página oficial retira `dynamips` e `software-properties-common` da lista):

```bash
sudo apt update
sudo apt install python3 python3-pip pipx python3-pyqt6 python3-pyqt6.qtwebsockets python3-pyqt6.qtsvg qemu-kvm qemu-utils libvirt-clients libvirt-daemon-system virtinst ca-certificates curl gnupg2
pipx install gns3-server
pipx install gns3-gui
pipx inject gns3-gui gns3-server PyQt6
```

Dynamips no Debian 13, compilado do código-fonte (da documentação oficial, não executado):

```bash
sudo apt update
sudo apt install build-essential cmake libelf-dev libpcap0.8-dev
git clone https://github.com/GNS3/dynamips.git
cd dynamips
mkdir build
cd build
cmake ..
make install
```

A página oficial dá os pacotes de compilação em comandos separados; aqui estão juntos, com os mesmos nomes. Para o Ubuntu a página usa o PPA `ppa:gns3/ppa` e o grupo `ubridge,libvirt,kvm,wireshark,docker`; não se aplica ao Debian e não foi usado.

## Uso

### Servidor (executado)

Com a instalação temporária acima, o servidor sobe e responde pela API (comandos rodados na VM, com a escuta só em `127.0.0.1`):

```bash
/tmp/gns3-pipx/bin/gns3server --host 127.0.0.1 --port 3080
curl -s http://127.0.0.1:3080/v3/version
```

Resultado real: `ss -ltn` mostrou `127.0.0.1:3080` em escuta e o `curl` devolveu `{"controller_host":"127.0.0.1","version":"3.0.6","local":false}`. Opções do `gns3server --help` (3.0.6): `--host`, `--port`, `--ssl`, `--config`, `--local`, `--daemon`, `--logfile`. A porta foi passada de forma explícita; a página oficial não declara a porta padrão do servidor, então ela não está confirmada aqui.

### Cliente gráfico (da documentação oficial, não executado)

Depois de instalar o `gns3-gui`, o comando oficial para abrir a interface é `gns3`. No assistente de configuração, "Run appliances on a remote server" aponta a interface para um servidor GNS3 remoto; os valores de host e porta aparecem na página oficial só em imagens. Um servidor pode atender vários clientes desde o GNS3 2.0.

### Relação com o Nexus OS

O GNS3 não substitui a demonstração do Nexus OS. Para a demonstração use `nexus-vnf` e a topologia `frr-duo` do Containerlab ([manual.md](manual.md)).

## Fora da ISO

Motivos para o GNS3 não entrar na ISO:

- Decisão do escopo reduzido (grupo): o GNS3 é só documentado, e o Containerlab é a topologia principal.
- A instalação oficial no Debian usa `pipx` e baixa pacotes da internet, e a ISO precisa funcionar sem rede. Empacotar as dependências exigiria um espelho offline que o projeto não construiu.
- A interface gráfica exige sessão gráfica; a ISO RC1 não tem desktop.
- No Debian 13 o Dynamips precisa ser compilado, o que não cabe numa receita de live-build simples.

Como usar ao lado da ISO: instale o GNS3 em outra máquina ou VM, seguindo a seção "Instalação", e use a ISO do Nexus OS em seu próprio QEMU ou Hyper-V ([manual.md](manual.md)). Importar a ISO como nó QEMU de um projeto GNS3 não foi testado.

## Problemas conhecidos

- Só o servidor foi instalado e executado; a interface gráfica, o Dynamips e a abertura de um projeto não foram testados.
- A porta padrão do `gns3server` e os valores de conexão do cliente remoto não aparecem em texto nas páginas oficiais lidas; a porta 3080 só foi confirmada porque foi passada com `--port`.
- Um resumo da busca citou que o README do `gns3-server` trata o uBridge como necessário e o QEMU como recomendado no Linux. A página de instalação para Debian não traz comando para o uBridge, e o nome do pacote no Debian 13 não foi conferido.
- O Dynamips compilado do código-fonte e os pacotes da lista do Debian 13 não foram executados.
- A página oficial de instalação mudou de endereço em relação a versões antigas (a raiz `/docs/getting-started/installation/` devolve 404); use as três URLs da lista de fontes.
- Reprodução por segunda pessoa pendente.
