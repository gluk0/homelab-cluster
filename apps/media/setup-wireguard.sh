#!/usr/bin/env bash
set -euo pipefail

[ "$#" -ne 1 ] && { echo "Usage: $0 <path-to-wireguard-config.conf>"; exit 1; }
WG_CONFIG_FILE="$1"
[ -f "$WG_CONFIG_FILE" ] || { echo "Error: WireGuard config file not found: $WG_CONFIG_FILE"; exit 1; }

kubectl create namespace media --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic wireguard-config --from-file=wg0.conf="$WG_CONFIG_FILE" -n media --dry-run=client -o yaml | kubectl apply -f -

if kubectl get deployment qbittorrent -n media &>/dev/null; then
    kubectl rollout restart deployment/qbittorrent -n media
    kubectl rollout status deployment/qbittorrent -n media --timeout=120s
fi
