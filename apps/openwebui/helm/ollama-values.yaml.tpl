# These values are structured to match the official otwld/ollama Helm chart README
# AND your specific EKS cluster's available StorageClasses.

# --- Scheduling Configuration ---
%{ if ollama_on_gpu ~}
nodeSelector:
  accelerator: "nvidia"

tolerations:
  - key: "nvidia.com/gpu"
    operator: "Equal"
    value: "true"
    effect: "NoSchedule"
%{ endif ~}


# --- Persistence Configuration ---
persistentVolume:
  enabled: true
  # REMOVED: The storageClass key has been removed.
  # Kubernetes will now automatically use the default StorageClass on your cluster.
  size: 50Gi


# --- Application Configuration ---
ollama:
  gpu:
    enabled: ${ollama_on_gpu}
    type: "nvidia"
    number: 1

  models:
    pull:
%{ for model in ollama_models ~}
      - ${model}
%{ endfor ~}