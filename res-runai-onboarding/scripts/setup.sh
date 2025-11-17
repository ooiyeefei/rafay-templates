#!/bin/bash
set -e

echo "=== Setting up required tools ==="

# Note: BusyBox wget is available in Rafay execution container (used for HTTP requests)

# Download jq (for JSON parsing in create-runai-cluster.sh)
if [ ! -f "./jq" ]; then
  echo "[+] Downloading jq binary..."
  wget -q https://github.com/jqlang/jq/releases/download/jq-1.7/jq-linux64 -O jq
  if [ $? -eq 0 ]; then
    echo "[+] Successfully downloaded jq binary"
    chmod +x ./jq
  else
    echo "[-] Failed to download jq"
    exit 1
  fi
else
  echo "[+] jq already exists, skipping download"
fi

# Download kubectl (for wait commands)
if [ ! -f "./kubectl" ]; then
  echo "[+] Downloading kubectl binary..."
  wget -q "https://dl.k8s.io/release/$(wget -qO- https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" -O kubectl
  if [ $? -eq 0 ]; then
    echo "[+] Successfully downloaded kubectl binary"
    chmod +x ./kubectl
  else
    echo "[-] Failed to download kubectl"
    exit 1
  fi
else
  echo "[+] kubectl already exists, skipping download"
fi

echo "[+] Setup complete"
