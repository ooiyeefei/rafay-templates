# These values are structured for the otwld/ollama Helm chart version 0.29.0
# and your specific EKS cluster configuration.

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
  # OMITTED: storageClass is removed to use the cluster's default.
  size: 50Gi


# --- Application Configuration ---
ollama:
  # This enables GPU features if the flag is true.
  gpu:
    enabled: ${ollama_on_gpu}
    type: "nvidia"
    number: 1

  # Use the old model format that chart v0.29.0 expects.
  # This is a simple list of strings directly under the 'models' key.
  %{ if length(ollama_models) > 0 ~}
  models:
%{ for model in ollama_models ~}
    - ${model}
%{ endfor ~}
  %{ endif ~}