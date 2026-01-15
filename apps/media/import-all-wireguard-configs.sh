#!/bin/bash
# Script to create ConfigMap with all WireGuard configs organized by region

set -e

WIREGUARD_DIR="/home/rich/wireguard-configs"
NAMESPACE="media"
CONFIGMAP_NAME="wireguard-configs"

echo "=== Creating WireGuard ConfigMap with all 525 configs ==="
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl not found"
    exit 1
fi

# Create namespace if it doesn't exist
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

# Create ConfigMap with all configs
echo "Adding all WireGuard configs to ConfigMap..."

CONFIG_FILES=$(find ${WIREGUARD_DIR} -name "*.conf" -type f | sort)
CONFIG_COUNT=$(echo "${CONFIG_FILES}" | wc -l)

echo "Found ${CONFIG_COUNT} WireGuard configurations"
echo ""

# Build the configmap
kubectl create configmap ${CONFIGMAP_NAME} \
    --from-file=${WIREGUARD_DIR} \
    -n ${NAMESPACE} \
    --dry-run=client -o yaml | kubectl apply -f -

echo "✓ ConfigMap '${CONFIGMAP_NAME}' created with ${CONFIG_COUNT} configs"
echo ""
echo "Available regions:"
echo "${CONFIG_FILES}" | awk -F'/' '{print $NF}' | cut -d'-' -f1-2 | sort -u | head -20
echo "... and more!"
echo ""
echo "To list all available configs:"
echo "  kubectl get configmap ${CONFIGMAP_NAME} -n ${NAMESPACE} -o json | jq -r '.data | keys[]' | sort"
echo ""
