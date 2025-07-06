# These values are structured to match the official otwld/ollama Helm chart README
# AND our specific EKS node configuration. (EKS node taints etc)

# --- Scheduling Configuration ---
# This block is ONLY rendered if 'ollama_on_gpu' is true.
# These values are structured for the otwld/ollama Helm chart version 0.29.0.
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
# This uses the correct 'persistentVolume' key from the README.
persistentVolume:
  enabled: true
  storageClass: "gp3"
  size: 50Gi


# --- Application Configuration ---
ollama:
  # This block correctly enables the GPU features within the container.
  gpu:
    enabled: ${ollama_on_gpu}
    type: "nvidia"
    number: 1
  
  # --- THIS IS THE CRITICAL FIX ---
  # Use the old model format that chart v0.29.0 expects.
  # This should be a simple list of strings.
  %{ if length(ollama_models) > 0 ~}
  models:
%{ for model in ollama_models ~}
    - ${model}
%{ endfor ~}
  %{ endif ~}