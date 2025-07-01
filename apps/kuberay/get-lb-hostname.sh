#!/bin/bash
set -e

eval "$(jq -r '@sh "KUBECONFIG_PATH=\(.kubeconfig_path)"')"

SHARED_INGRESS_NAMESPACE="kube-system"
SHARED_INGRESS_NAME="shared-alb-ingress"

for i in {1..60}; do
  HOSTNAME=$(kubectl --kubeconfig "$KUBECONFIG_PATH" get ingress "$SHARED_INGRESS_NAME" -n "$SHARED_INGRESS_NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
  
  if [ -n "$HOSTNAME" ]; then
    jq -n --arg hostname "$HOSTNAME" '{"hostname": $hostname}'
    exit 0
  fi
  sleep 5
done

echo "Error: Timed out waiting for Shared ALB Ingress hostname to be populated." >&2
exit 1