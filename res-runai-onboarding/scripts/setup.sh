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

# Download curl (for DELETE requests in delete-runai-cluster.sh)
if [ ! -f "./curl" ]; then
  echo "[+] Downloading curl binary..."
  CURL_VERSION="8.17.0"  # Use latest secure version
  CURL_URL="https://github.com/moparisthebest/static-curl/releases/download/v${CURL_VERSION}/curl-amd64"
  CHECKSUM_URL="${CURL_URL}.sha256"

  # Download binary and checksum
  echo "[+] Downloading curl v${CURL_VERSION}..."
  wget -q "$CURL_URL" -O curl.tmp
  wget -q "$CHECKSUM_URL" -O curl.sha256

  if [ $? -eq 0 ] && [ -f "curl.sha256" ]; then
    # Verify integrity
    echo "[+] Verifying curl binary integrity..."
    if echo "$(cat curl.sha256) curl.tmp" | sha256sum -c --quiet; then
      echo "[+] Checksum verified successfully"
      mv curl.tmp curl
      chmod +x ./curl
      rm curl.sha256
    else
      echo "[-] Checksum verification failed - removing invalid file"
      rm -f curl.tmp curl.sha256
      exit 1
    fi
  else
    echo "[-] Failed to download curl or checksum"
    rm -f curl.tmp curl.sha256
    exit 1
  fi
else
  echo "[+] curl already exists, skipping download"
fi

echo "[+] Setup complete"
