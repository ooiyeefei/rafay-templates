# These values are structured to match the official otwld/ollama Helm chart README
# AND our specific EKS node configuration. (EKS node taints etc)

# --- Scheduling Configuration ---
# This block is ONLY rendered if 'ollama_on_gpu' is true.
%{ if ollama_on_gpu ~}

# This tells the pod to target your specifically labeled GPU nodes.
nodeSelector:
  accelerator: "nvidia"

# This allows the pod to be scheduled on your specifically tainted GPU nodes.
tolerations:
  - key: "nvidia.com/gpu"
    operator: "Equal"
    value: "true"
    effect: "NoSchedule"
%{ endif ~}


# --- Persistence Configuration ---
# This is the correct structure for enabling persistence.
persistentVolume:
  enabled: true
  storageClass: "gp3"
  size: 50Gi


# --- Application Configuration ---
ollama:
  # This block correctly enables the GPU features within the container.
  %{ if ollama_on_gpu ~}
  gpu:
    enabled: true
    type: "nvidia"
    # The chart automatically adds the 'resources' limit when GPU is enabled.
  %{ endif ~}

  # This is the correct structure for pulling models on startup.
  %{ if length(ollama_models) > 0 ~}
  models:
    pull:
%{ for model in ollama_models ~}
      - ${model}
%{ endfor ~}
  %{ endif ~}