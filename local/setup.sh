#!/usr/bin/env bash
# setup.sh — cria o cluster Kind e deploya o operator supervisório.
#
# A planta TEP roda FORA do cluster, como container Docker standalone.
# O operator roda DENTRO do Kind e conecta na planta via gRPC.
#
# Pré-requisitos:
#   - docker rodando
#   - kind instalado (v0.27+)
#   - kubectl instalado
#   - imagem do operator já buildada:
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
    echo "[1/3] Criando cluster Kind '${CLUSTER_NAME}'..."
    kind create cluster --config "${SCRIPT_DIR}/kind-config.yaml"
fi

# Garantir que kubectl aponta pro cluster certo
kubectl cluster-info --context "kind-${CLUSTER_NAME}" > /dev/null 2>&1 || {
    echo "[erro] Não consegui conectar ao cluster '${CLUSTER_NAME}'."
    exit 1
}
kubectl config use-context "kind-${CLUSTER_NAME}"

# ── 2. Carregar imagem do operator no Kind ─────────────────────────────────
echo "[2/3] Carregando imagem do operator no cluster..."

if docker image inspect plc-operator:latest > /dev/null 2>&1; then
    kind load docker-image plc-operator:latest --name "${CLUSTER_NAME}"
    echo "  ✓ plc-operator:latest"
else
    echo "  ⚠ plc-operator:latest não encontrada. Builde antes:"
    echo "    docker build -t plc-operator:latest <path-to-cluster-api-provider-plc>"
fi

# ── 3. Aplicar CRD + deploy operator ──────────────────────────────────────
echo "[3/3] Aplicando CRD e manifests do operator..."

if [ -f "${SCRIPT_DIR}/k8s/crd.yaml" ]; then
    kubectl apply -f "${SCRIPT_DIR}/k8s/crd.yaml"
    echo "  ✓ crd.yaml"
else
    echo "  ⚠ CRD não encontrado em k8s/crd.yaml. Copie de cluster-api-provider-plc:"
    echo "    cp config/crd/bases/infrastructure.greenlabs.io_plcmachines.yaml local/k8s/crd.yaml"
fi

for f in operator-deployment.yaml plcmachine-sample.yaml; do
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
echo "A planta TEP roda separada (docker standalone)."
echo "O operator dentro do Kind conecta nela via gRPC."
echo ""
echo "Comandos úteis:"
echo "  kubectl get pods                    # ver pods do operator"
echo "  kubectl get plcmachines             # ver CRs"
echo "  kubectl logs -f deploy/plc-operator # logs do operator"
echo "  kind delete cluster --name ${CLUSTER_NAME}  # destruir cluster"
