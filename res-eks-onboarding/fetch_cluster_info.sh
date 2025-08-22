#!/bin/bash
set -e

ENDPOINT=$1
PROJECT=$2
CLUSTER=$3
API_KEY=$4

sleep 30

while true; do
    response=$(wget -qO- --no-check-certificate --header="X-API-KEY: ${API_KEY}" \
      --header="accept: application/json" \
      "https://${ENDPOINT}/apis/infra.k8smgmt.io/v3/projects/${PROJECT}/clusters/${CLUSTER}")

    blueprint_status=$(echo "$response" | jq -r '.status.conditions[] | select(.type=="ClusterBlueprintSyncSucceeded") | .status')
    blueprint_reason=$(echo "$response" | jq -r '.status.conditions[] | select(.type=="ClusterBlueprintSyncSucceeded") | .reason')

    echo "Blueprint Sync Status: $blueprint_status"
    echo "Blueprint Sync Reason: $blueprint_reason"

    if [[ "$blueprint_status" == "True" ]]; then
        echo "Blueprint Sync is successful!"
        exit 0
    elif [[ "$blueprint_status" == "Unknown" ]]; then
        echo "Blueprint Sync is Partially successful!"
        exit 0
    elif [[ "$blueprint_reason" == "blueprint placement created" || "$blueprint_reason" == "blueprint placement processed" ]]; then
        echo "Blueprint placement created, retrying in 30s..."
    elif [[ "$blueprint_status" == "False" ]]; then
        echo "Blueprint Sync Failed!"
        exit 1
    fi
    sleep 30
done