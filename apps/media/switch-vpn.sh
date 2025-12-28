#!/bin/bash
# Script to switch between WireGuard VPN configs easily

set -e

NAMESPACE="media"
SECRET_NAME="wireguard-config"
CONFIGMAP_NAME="wireguard-configs"

show_usage() {
    echo "Usage: $0 <config-name>"
    echo ""
    echo "Examples:"
    echo "  $0 us-nyc-wg-503.conf         # Use NYC server"
    echo "  $0 us-lax-wg-001.conf         # Use LA server"
    echo "  $0 de-fra-wg-001.conf         # Use Frankfurt server"
    echo ""
    echo "To list all available configs:"
    echo "  $0 --list"
    echo ""
    echo "To list configs by region:"
    echo "  $0 --list-us                  # US configs"
    echo "  $0 --list-de                  # Germany configs"
    echo "  $0 --list-gb                  # UK configs"
    echo ""
}

list_configs() {
    echo "=== Available WireGuard Configurations ==="
    kubectl get configmap ${CONFIGMAP_NAME} -n ${NAMESPACE} -o json 2>/dev/null | \
        jq -r '.data | keys[]' | sort | column -c 120
}

list_region_configs() {
    local region=$1
    echo "=== WireGuard Configs for Region: ${region} ==="
    kubectl get configmap ${CONFIGMAP_NAME} -n ${NAMESPACE} -o json 2>/dev/null | \
        jq -r '.data | keys[]' | grep "^${region}-" | sort
}

if [ -z "$1" ]; then
    show_usage
    exit 1
fi

if [ "$1" == "--list" ]; then
    list_configs
    exit 0
fi

if [[ "$1" == --list-* ]]; then
    region=${1#--list-}
    list_region_configs "${region}"
    exit 0
fi

CONFIG_NAME="$1"

# Check if config exists in ConfigMap
if ! kubectl get configmap ${CONFIGMAP_NAME} -n ${NAMESPACE} -o json 2>/dev/null | \
     jq -e ".data[\"${CONFIG_NAME}\"]" > /dev/null; then
    echo "Error: Config '${CONFIG_NAME}' not found in ConfigMap"
    echo ""
    echo "Available configs (first 20):"
    kubectl get configmap ${CONFIGMAP_NAME} -n ${NAMESPACE} -o json | \
        jq -r '.data | keys[]' | sort | head -20
    echo "..."
    echo ""
    echo "Use '$0 --list' to see all configs"
    exit 1
fi

echo "=== Switching WireGuard VPN Config ==="
echo "New config: ${CONFIG_NAME}"
echo ""

# Extract the config from ConfigMap and create Secret
kubectl get configmap ${CONFIGMAP_NAME} -n ${NAMESPACE} -o json | \
    jq -r ".data[\"${CONFIG_NAME}\"]" | \
    kubectl create secret generic ${SECRET_NAME} \
        --from-file=wg0.conf=/dev/stdin \
        -n ${NAMESPACE} \
        --dry-run=client -o yaml | kubectl apply -f -

echo "✓ Secret '${SECRET_NAME}' updated with ${CONFIG_NAME}"
echo ""

# Restart qBittorrent if it exists
if kubectl get deployment qbittorrent -n ${NAMESPACE} &> /dev/null; then
    echo "Restarting qBittorrent to apply new VPN config..."
    kubectl rollout restart deployment/qbittorrent -n ${NAMESPACE}
    echo "✓ qBittorrent restart initiated"
    echo ""
    echo "Waiting for qBittorrent to be ready..."
    kubectl rollout status deployment/qbittorrent -n ${NAMESPACE} --timeout=120s
    echo ""
    echo "✓ qBittorrent is ready with new VPN config"
    echo ""
    echo "Verifying VPN connection..."
    sleep 10
    VPN_IP=$(kubectl exec -n ${NAMESPACE} deployment/qbittorrent -c qbittorrent -- curl -s --max-time 10 ifconfig.me 2>/dev/null || echo "Unable to determine")
    echo "VPN IP: ${VPN_IP}"
else
    echo "⚠ qBittorrent deployment not found yet"
fi

echo ""
echo "=== VPN Config Switch Complete ==="
