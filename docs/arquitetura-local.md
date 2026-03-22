# Arquitetura do Ambiente Local

Este documento explica como o ambiente local funciona: o que roda onde, por que cada coisa é assim, e como os componentes se comunicam.

## O que roda na máquina do desenvolvedor

Na máquina do dev existem **dois containers Docker**, cada um com uma função completamente diferente:

```
Máquina do Dev (Docker Desktop)
│
├── Container 1: te-plant (Rust)
│   └── Simulação Tennessee Eastman + servidor gRPC
│   └── Porta exposta: 50051
│   └── Roda standalone, não sabe que o Kubernetes existe
│
└── Container 2: Kind (nó Kubernetes)
    └── containerd (runtime de containers do K8s)
        ├── Pod: plc-operator (Go, controller-runtime)
        ├── Pod: kube-apiserver
        ├── Pod: etcd
        ├── Pod: coredns
        └── Pod: kube-controller-manager, kube-scheduler, kube-proxy

Comunicação:
  plc-operator ──gRPC──▶ te-plant (via host.docker.internal:50051)
```

O **Container 1** é a planta. Um processo Rust que simula o processo químico Tennessee Eastman e expõe métricas via gRPC. Ele não tem nada a ver com Kubernetes.

O **Container 2** é o nó Kind. Dentro dele roda um Kubernetes real e completo, com seu próprio runtime de containers (containerd). O operator roda como Pod dentro desse Kubernetes.

## O que roda DENTRO do Kind

O Kind (Kubernetes in Docker) é um container Docker que simula um nó Kubernetes. Dentro dele:

- Roda um **Kubernetes real** com todos os componentes: etcd, kube-apiserver, controller-manager, scheduler.
- O runtime de containers **não é o Docker** — é o containerd, que o Kubernetes usa pra subir Pods.
- O operator (`plc-operator`) roda como um **Pod** gerenciado pelo Kubernetes.

Sim, tecnicamente o operator é um **container dentro de um container**. Isso é específico do Kind — é o custo de simular um cluster inteiro na sua máquina. Em produção, o nó seria uma VM real (ou bare metal) e não haveria essa aninhação.

## Por que o operator precisa rodar DENTRO do Kubernetes

O Kubernetes só gerencia o que roda dentro dele. Ele não sabe que existem containers Docker avulsos na sua máquina. Se o operator rodasse fora do cluster, ele seria apenas um binário Go solto, sem orquestração.

Rodando como Pod dentro do Kubernetes, o operator ganha:

1. **Acesso nativo aos CRs** — O operator precisa ler o spec dos PLCMachine e escrever no status. Rodando como Pod, ele faz isso via controller-runtime, usando o ServiceAccount e o RBAC do cluster.

2. **Lifecycle management** — O Kubernetes garante que o operator está rodando. Se o Pod cair, o Deployment recria. Se precisar escalar, é só ajustar as réplicas.

3. **Observabilidade** — Logs, events, conditions, métricas — tudo integrado no ecossistema K8s.

## Por que o operator precisa de uma imagem Docker própria

Qualquer programa que roda no Kubernetes precisa estar empacotado como imagem de container. Não tem como rodar um `.exe` ou um binário Go direto num Pod.

O `plc-operator:latest` é o código Go compilado dentro de uma imagem minimal (distroless). O Kubernetes baixa essa imagem e sobe como Pod.

O comando `kind load docker-image plc-operator:latest` copia a imagem do Docker Desktop da máquina pra dentro do nó Kind. Isso é necessário porque são ambientes isolados — o Docker Desktop e o containerd dentro do Kind não compartilham imagens. Sem esse `kind load`, o Kubernetes tentaria puxar a imagem de um registry remoto e falharia.

## Por que a planta NÃO roda dentro do Kind

A planta é um **sistema externo** que o operator supervisiona. Ela não é parte do Kubernetes — é o "mundo real" que o operator observa.

Num cenário de produção, a planta seria:
- Um **PLC físico** numa fábrica
- Uma **simulação** rodando em outro servidor
- Um **sistema legado** que expõe dados via protocolo industrial

Rodar a planta dentro do Kind criaria uma falsa dependência. O Kubernetes não gerencia a planta — ele só gerencia o operator que a observa. Manter a planta fora do cluster é mais realista e reflete a separação de responsabilidades: a planta é o processo, o operator é o supervisor.

## Como os dois containers se comunicam

O operator (dentro do Kind) precisa alcançar a planta (container standalone). A comunicação acontece pela rede Docker:

1. A planta expõe a porta 50051 no host (`docker run -p 50051:50051`)
2. O operator se conecta em `host.docker.internal:50051`
3. `host.docker.internal` é um DNS especial que o Docker resolve pro IP da máquina host

No CRD, o endereço é configurado no spec:
```yaml
spec:
  plantAddress: "host.docker.internal:50051"
```

Se `host.docker.internal` não funcionar (alguns ambientes Linux), use o IP da bridge Docker:
```bash
docker network inspect bridge | grep Gateway
# Exemplo: 172.17.0.1
```
E configure: `plantAddress: "172.17.0.1:50051"`
