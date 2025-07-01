#!/bin/bash
set -e
eval "$(jq -r '@sh "NAMESPACE=\(.namespace) INGRESS_NAME=\(.ingress_name) KUBECONFIG_PATH=\(.kubeconfig_path)"')"

for i in {1..60}; do
  HOSTNAME=$(kubectl --kubeconfig "$KUBECONFIG_PATH" get ingress "$INGRESS_NAME" -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
  if [ -n "$HOSTNAME" ]; then
    jq -n --arg hostname "$HOSTNAME" '{"hostname": $hostname}'
    exit 0
  fi
  sleep 5
done

echo "Error: Timed out waiting for Ingress hostname." >&2
exit 1