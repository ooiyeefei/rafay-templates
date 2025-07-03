#!/bin/bash
set -e

# 1. Ingest ALL the variables from Terraform, including the kubeconfig_path.
eval "$(jq -r '@sh "NAMESPACE=\(.namespace) SERVICE_NAME=\(.service_name) KUBECONFIG_PATH=\(.kubeconfig_path)"')"

# 2. Poll for the hostname using the dynamically provided kubeconfig path.
# Poll for 5 minutes (60 tries * 5 seconds).
for i in {1..60}; do
  # The --kubeconfig flag now correctly uses the $KUBECONFIG_PATH variable from the eval command.
  HOSTNAME=$(kubectl --kubeconfig "$KUBECONFIG_PATH" get service "$SERVICE_NAME" -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
  
  if [ -n "$HOSTNAME" ]; then
    # If the hostname is found, print it as JSON and exit successfully.
    jq -n --arg hostname "$HOSTNAME" '{"hostname": $hostname}'
    exit 0
  fi
  sleep 5
done

# If the loop finishes without finding a hostname, exit with an error.
echo "Error: Timed out waiting for Load Balancer hostname." >&2
exit 1