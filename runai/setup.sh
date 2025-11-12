#!/bin/bash
set -e
echo "[+] Downloading setup binaries"


wget https://github.com/jqlang/jq/releases/download/jq-1.7/jq-linux64 -O jq
if [ $? -eq 0 ];
then
    echo "[+] Successfully Downloaded jq binary"
fi
chmod +x ./jq