#!/bin/bash
set -e

WIREGUARD_DIR="${1:-/home/rich/wireguard-configs}"
NAMESPACE="media"
CONFIGMAP_NAME="wireguard-configs"

if ! command -v kubectl >/dev/null 2>&1; then
    echo "kubectl not found" >&2
    exit 1
fi

if [ ! -d "$WIREGUARD_DIR" ]; then
    echo "WireGuard config directory not found: $WIREGUARD_DIR" >&2
    exit 1
fi

kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

mapfile -t CONFIG_FILES < <(find "$WIREGUARD_DIR" -name '*.conf' -type f -print | sort)
CONFIG_COUNT=${#CONFIG_FILES[@]}

if [ "$CONFIG_COUNT" -eq 0 ]; then
    echo "No .conf files found in $WIREGUARD_DIR" >&2
    exit 1
fi

kubectl create configmap "${CONFIGMAP_NAME}" --from-file="${WIREGUARD_DIR}" -n "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

echo "ConfigMap '${CONFIGMAP_NAME}' created with ${CONFIG_COUNT} configs"
printf '%s\n' "${CONFIG_FILES[@]}" | awk -F'/' '{print $NF}' | cut -d'-' -f1-2 | sort -u | head -20
echo "... and more!"
