#!/bin/bash
# Script to configure WireGuard VPN for qBittorrent

set -e

echo "===="
echo ""

if [ -z "$1" ]; then
    echo "Usage: $0 <path-to-wireguard-config.conf>"
    echo ""
    exit 1
fi

WG_CONFIG_FILE="$1"

if [ ! -f "$WG_CONFIG_FILE" ]; then
    echo "Error: WireGuard config file not found: $WG_CONFIG_FILE"
    exit 1
fi

echo "✓ Found WireGuard config: $WG_CONFIG_FILE"
echo ""


echo "Creating/updating wireguard-config secret in media namespace..."
kubectl create namespace media --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic wireguard-config \
    --from-file=wg0.conf="$WG_CONFIG_FILE" \
    -n media \
    --dry-run=client -o yaml | kubectl apply -f -

echo "✓ WireGuard config secret created/updated"
echo ""

if kubectl get deployment qbittorrent -n media &> /dev/null; then
    echo "Restarting qBittorrent to apply new VPN config..."
    kubectl rollout restart deployment/qbittorrent -n media
    echo "✓ qBittorrent restart initiated"
    echo ""
    echo "Waiting for qBittorrent to be ready..."
    kubectl rollout status deployment/qbittorrent -n media --timeout=120s
else
    echo "⚠ qBittorrent deployment not found yet. It will use this config when deployed."
fi

