# Lab Local — Kind + TEP

Lab local para rodar o experimento Tennessee Eastman completo no seu PC.

Sao tres pecas:

| Peca | Container | Funcao |
|------|-----------|--------|
| **te-plant** | Docker standalone | Planta TEP (Rust). Simula o processo quimico e expoe metricas via gRPC na porta 50051. |
| **plc-operator** | Pod dentro do Kind | Operator K8s (Go). Conecta na planta, le XMEAS, grava status no CRD, e (futuramente) toma acoes de controle. |
| **tep-ihm** | Docker standalone | Dashboard web (Python). Mostra graficos e tabelas da planta em tempo real na porta 8080. |

**Nenhuma cloud.** So Docker + Kind.

## Pre-requisitos

| Ferramenta | Versao minima | Instalacao |
|------------|---------------|------------|
| Docker     | 20.10+        | [docs.docker.com](https://docs.docker.com/get-docker/) |
| Kind       | 0.27+         | `choco install kind` ou [kind.sigs.k8s.io](https://kind.sigs.k8s.io/docs/user/quick-start/#installation) |
| kubectl    | 1.28+         | `choco install kubernetes-cli` ou [kubernetes.io](https://kubernetes.io/docs/tasks/tools/) |

## Estrutura

```
local/
├── docker-compose.yml            # Sobe planta + IHM juntos
├── kind-config.yaml              # Config do cluster Kind
├── setup.sh                      # Script que sobe o cluster + operator
├── k8s/
│   ├── crd.yaml                  # CRD PLCMachine (copiar do operator)
│   ├── operator-deployment.yaml  # Deploy + RBAC do operator
│   └── plcmachine-sample.yaml   # CR de exemplo (politica supervisoria)
└── README.md                     # Este arquivo
```

---

## Teste completo — passo a passo

### 1. Buildar as tres imagens

Antes de tudo, as imagens Docker precisam existir na sua maquina. Cada uma vem de um repo diferente:

```bash
# Planta (tep-plant)
cd <path-to-tep-plant>
docker build -t te-plant:latest .

# Operator (tep-operator)
cd <path-to-tep-operator>
docker build -t plc-operator:latest .

# IHM (tep-ihm)
cd <path-to-tep-ihm>
docker build -t tep-ihm:latest .
```

Apos o build, confirme que as tres imagens aparecem no Docker Desktop ou via `docker images`.

### 2. Subir planta + IHM (docker compose)

```bash
cd tep-supervisor/local/
docker compose up
```

Isso sobe dois containers:
- `te-plant` — planta rodando gRPC na porta 50051
- `tep-ihm` — dashboard na porta 8080, conectando na planta pela rede interna do Compose

A IHM ja consegue mostrar dados da planta mesmo sem o Kind rodando.

Abra `http://localhost:8080` e voce deve ver:
- Graficos de pressao, temperatura, nivel e vazao atualizando em tempo real
- Tabelas de XMEAS e XMV com valores, unidades e nomes
- Painel de alarmes
- Status do solver (Steady-state / Slow transient / Fast transient)

### 3. Subir o Kind + operator (setup.sh)

Em outro terminal:

```bash
cd tep-supervisor/local/
bash setup.sh
```

O script:
1. Cria o cluster Kind `tep-lab` (se nao existir)
2. Copia a imagem `plc-operator:latest` do Docker Desktop pra dentro do Kind (`kind load`)
3. Aplica o CRD PLCMachine
4. Deploya o operator e o CR de exemplo

### 4. Verificar

```bash
# Operator rodando?
kubectl get pods

# Status do PLCMachine com metricas reais da planta?
kubectl get plcmachines
kubectl get plcmachine tep-baseline -o yaml
```

O que voce deve ver:

- Pod `plc-operator-*` com status `Running`
- PLCMachine `tep-baseline` com `phase: Stable`
- No `.status.variables`: valores reais de XMEAS lidos da planta
- No `.status.plantTime`: tempo de simulacao avancando

### 5. Copiar o CRD (se necessario)

O CRD e gerado pelo `controller-gen` no repo do operator. Se voce alterou os types do CRD, copie a versao atualizada:

```bash
cp <path-to-tep-operator>/config/crd/bases/infrastructure.greenlabs.io_plcmachines.yaml local/k8s/crd.yaml
```

---

## Conectividade

```
Docker Desktop (host)
├── te-plant (:50051)         ← container Compose
├── tep-ihm  (:8080)          ← container Compose, conecta em te-plant:50051 via rede Compose
└── tep-lab-control-plane     ← container Kind
    └── plc-operator (Pod)    ← conecta em host.docker.internal:50051
```

- A **IHM** conecta na planta pelo nome do service do Compose (`te-plant:50051`).
- O **operator** (dentro do Kind) conecta na planta via `host.docker.internal:50051`, porque a planta expoe a porta 50051 no host e o Kind acessa o host por essa rota.
- O Kind e o Compose sao redes Docker separadas, mas ambos conseguem alcancar a planta pela porta exposta no host.

---

## Comandos uteis

```bash
# Parar planta + IHM
docker compose down

# Logs do operator
kubectl logs -f deploy/plc-operator

# Detalhes do PLCMachine
kubectl describe plcmachine tep-baseline

# Destruir o cluster Kind
kind delete cluster --name tep-lab

# Rebuildar so uma imagem (ex: IHM apos mudanca no frontend)
cd <path-to-tep-ihm>
docker build -t tep-ihm:latest .
docker compose up -d tep-ihm    # reinicia so a IHM
```

## Issues relacionadas

- [#39 — Setup Kind cluster local](https://github.com/Green-Cinnamon-Labs/tep-supervisor/issues/39)
- [#40 — Deploy operator como Deployment](https://github.com/Green-Cinnamon-Labs/tep-supervisor/issues/40)
- [#42 — Dashboard de observabilidade](https://github.com/Green-Cinnamon-Labs/spec-tennessee-eastman/issues/42)
