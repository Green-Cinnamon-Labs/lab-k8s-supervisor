# Lab Local — Kind + TEP

Lab local para rodar o digital twin da Tennessee Eastman com o operator supervisório, tudo dentro de um cluster Kind no seu próprio PC.

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
├── kind-config.yaml          # Config do cluster Kind (port mappings)
├── setup.sh                  # Script que sobe tudo
├── k8s/
│   ├── crd.yaml              # CRD PLCMachine (copiar do operator)
│   ├── plant-deployment.yaml # Deploy + Service da planta TEP
│   ├── operator-deployment.yaml  # Deploy + RBAC do operator
│   └── plcmachine-sample.yaml   # CR de exemplo (política supervisória)
└── README.md                 # Este arquivo
```

## Passo a passo

### 1. Buildar as imagens Docker

A partir dos repos da planta e do operator:

```bash
# Planta (fork-tennesseeEastman)
cd <path-to-fork-tennesseeEastman>
docker build -t te-plant:latest .

# Operator (cluster-api-provider-plc)
cd <path-to-cluster-api-provider-plc>
docker build -t plc-operator:latest .
```

### 2. Copiar o CRD

O CRD é gerado pelo `controller-gen` no repo do operator. Copie ele pra cá:

```bash
cp <path-to-cluster-api-provider-plc>/config/crd/bases/infrastructure.greenlabs.io_plcmachines.yaml local/k8s/crd.yaml
```

### 3. Rodar o setup

```bash
cd local/
bash setup.sh
```

O script:
1. Cria o cluster Kind `tep-lab` (se não existir)
2. Carrega as imagens Docker no cluster (`kind load`)
3. Aplica o CRD
4. Deploya planta, operator e CR de exemplo

### 4. Verificar

```bash
# Pods rodando?
kubectl get pods

# Planta expondo gRPC?
kubectl logs -f deploy/te-plant

# Operator reconciliando?
kubectl logs -f deploy/plc-operator

# Status do CR?
kubectl get plcmachines
kubectl describe plcmachine tep-baseline
```

### 5. Acessar gRPC da planta externamente

O Kind mapeia a porta 50051 do host pro NodePort 30051 do cluster.
Então, do seu PC, você consegue acessar a planta em `localhost:50051`:

```bash
grpcurl -plaintext localhost:50051 tep.v1.PlantService/GetPlantStatus
```

## Destruir o lab

```bash
kind delete cluster --name tep-lab
```

## Port mappings

| Host (seu PC) | NodePort (cluster) | Serviço |
|----------------|-------------------|---------|
| 50051          | 30051             | gRPC da planta TEP |
| 30000          | 30000             | Reservado (uso futuro) |

## Issues relacionadas

- [#39 — Setup Kind cluster local](https://github.com/Green-Cinnamon-Labs/lab-k8s-supervisor/issues/39)
- [#40 — Deploy planta como Pod + operator como Deployment](https://github.com/Green-Cinnamon-Labs/lab-k8s-supervisor/issues/40)
- [#41 — Teste E2E](https://github.com/Green-Cinnamon-Labs/lab-k8s-supervisor/issues/41)
