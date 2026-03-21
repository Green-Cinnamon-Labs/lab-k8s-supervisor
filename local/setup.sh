#!/usr/bin/env bash
# setup.sh — cria o cluster Kind e deploya a planta + operator
#
# Pré-requisitos:
#   - docker rodando
#   - kind instalado (v0.27+)
#   - kubectl instalado
#   - imagens já buildadas:
#       docker build -t te-plant:latest  <path-to-fork-tennesseeEastman>
#       docker build -t plc-operator:latest <path-to-cluster-api-provider-plc>
#
# Uso: bash setup.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLUSTER_NAME="tep-lab"

echo "=== TEP Lab Local Setup ==="

# ── 1. Criar cluster Kind ──────────────────────────────────────────────────
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    echo "[ok] Cluster '${CLUSTER_NAME}' já existe."
else
    echo "[1/4] Criando cluster Kind '${CLUSTER_NAME}'..."
    kind create cluster --config "${SCRIPT_DIR}/kind-config.yaml"
fi

# Garantir que kubectl aponta pro cluster certo
kubectl cluster-info --context "kind-${CLUSTER_NAME}" > /dev/null 2>&1 || {
    echo "[erro] Não consegui conectar ao cluster '${CLUSTER_NAME}'."
    exit 1
}
kubectl config use-context "kind-${CLUSTER_NAME}"

# ── 2. Carregar imagens no Kind ────────────────────────────────────────────
echo "[2/4] Carregando imagens Docker no cluster..."

if docker image inspect te-plant:latest > /dev/null 2>&1; then
    kind load docker-image te-plant:latest --name "${CLUSTER_NAME}"
    echo "  ✓ te-plant:latest"
else
    echo "  ⚠ te-plant:latest não encontrada. Builde antes:"
    echo "    docker build -t te-plant:latest <path-to-fork-tennesseeEastman>"
fi

if docker image inspect plc-operator:latest > /dev/null 2>&1; then
    kind load docker-image plc-operator:latest --name "${CLUSTER_NAME}"
    echo "  ✓ plc-operator:latest"
else
    echo "  ⚠ plc-operator:latest não encontrada. Builde antes:"
    echo "    docker build -t plc-operator:latest <path-to-cluster-api-provider-plc>"
fi

# ── 3. Aplicar CRD ────────────────────────────────────────────────────────
echo "[3/4] Aplicando CRD e manifests..."
if [ -f "${SCRIPT_DIR}/k8s/crd.yaml" ]; then
    kubectl apply -f "${SCRIPT_DIR}/k8s/crd.yaml"
else
    echo "  ⚠ CRD não encontrado em k8s/crd.yaml. Copie de cluster-api-provider-plc:"
    echo "    cp config/crd/bases/infrastructure.greenlabs.io_plcmachines.yaml local/k8s/crd.yaml"
fi

# ── 4. Deploy planta + operator + CR ───────────────────────────────────────
echo "[4/4] Deploy da planta, operator e CR..."
for f in plant-deployment.yaml operator-deployment.yaml plcmachine-sample.yaml; do
    if [ -f "${SCRIPT_DIR}/k8s/${f}" ]; then
        kubectl apply -f "${SCRIPT_DIR}/k8s/${f}"
        echo "  ✓ ${f}"
    else
        echo "  ⚠ ${f} não encontrado em k8s/"
    fi
done

echo ""
echo "=== Setup concluído ==="
echo ""
echo "Comandos úteis:"
echo "  kubectl get pods                    # ver pods"
echo "  kubectl get plcmachines             # ver CRs do operator"
echo "  kubectl logs -f deploy/te-plant     # logs da planta"
echo "  kubectl logs -f deploy/plc-operator # logs do operator"
echo "  kind delete cluster --name ${CLUSTER_NAME}  # destruir cluster"
