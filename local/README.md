# Lab Local — Kind + TEP

Lab local para rodar o operator supervisório dentro de um cluster Kind no seu próprio PC.

A **planta TEP roda fora do cluster**, como container Docker standalone.
O **operator roda dentro do Kind** e conecta na planta via gRPC.

**Nenhuma cloud.** Só Docker + Kind.

## Pré-requisitos

| Ferramenta | Versão mínima | Instalação |
|------------|---------------|------------|
| Docker     | 20.10+        | [docs.docker.com](https://docs.docker.com/get-docker/) |
| Kind       | 0.27+         | `choco install kind` ou [kind.sigs.k8s.io](https://kind.sigs.k8s.io/docs/user/quick-start/#installation) |
| kubectl    | 1.28+         | `choco install kubernetes-cli` ou [kubernetes.io](https://kubernetes.io/docs/tasks/tools/) |

## Estrutura

```
local/
├── kind-config.yaml              # Config do cluster Kind
├── setup.sh                      # Script que sobe o cluster + operator
├── k8s/
│   ├── crd.yaml                  # CRD PLCMachine (copiar do operator)
│   ├── operator-deployment.yaml  # Deploy + RBAC do operator
│   └── plcmachine-sample.yaml   # CR de exemplo (política supervisória)
└── README.md                     # Este arquivo
```

## Passo a passo

### 1. Subir a planta (Docker standalone)

A planta roda fora do Kind, como um container normal:

```bash
cd <path-to-fork-tennesseeEastman>
docker build -t te-plant:latest .
docker run --rm -p 50051:50051 te-plant:latest
```

A planta fica acessível em `localhost:50051` (gRPC).

### 2. Buildar a imagem do operator

```bash
cd <path-to-cluster-api-provider-plc>
docker build -t plc-operator:latest .
```

### 3. Copiar o CRD

O CRD é gerado pelo `controller-gen` no repo do operator. Copie ele pra cá:

```bash
cp <path-to-cluster-api-provider-plc>/config/crd/bases/infrastructure.greenlabs.io_plcmachines.yaml local/k8s/crd.yaml
```

### 4. Rodar o setup

```bash
cd local/
bash setup.sh
```

O script:
1. Cria o cluster Kind `tep-lab` (se não existir)
2. Carrega a imagem do operator no cluster (`kind load`)
3. Aplica o CRD
4. Deploya o operator e CR de exemplo

### 5. Verificar

```bash
# Operator rodando?
kubectl get pods
kubectl logs -f deploy/plc-operator

# Status do CR?
kubectl get plcmachines
kubectl describe plcmachine tep-baseline
```

### 6. Conectividade operator → planta

O operator dentro do Kind precisa alcançar a planta que roda no host.
No `plcmachine-sample.yaml`, o `plantAddress` deve apontar pro IP do host
visto de dentro do Kind. Em geral:

- **Linux:** `host.docker.internal:50051` ou o IP da bridge docker
- **Windows/Mac:** `host.docker.internal:50051` funciona direto

## Destruir o lab

```bash
kind delete cluster --name tep-lab
```

## Issues relacionadas

- [#39 — Setup Kind cluster local](https://github.com/Green-Cinnamon-Labs/lab-k8s-supervisor/issues/39)
- [#40 — Deploy operator como Deployment](https://github.com/Green-Cinnamon-Labs/lab-k8s-supervisor/issues/40)
- [#41 — Teste E2E](https://github.com/Green-Cinnamon-Labs/lab-k8s-supervisor/issues/41)
