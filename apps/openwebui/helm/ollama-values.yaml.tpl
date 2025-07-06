# These values are structured to match the official otwld/ollama Helm chart README
# AND our specific EKS node configuration. (EKS node taints etc)

# --- Scheduling Configuration ---
# This block is ONLY rendered if 'ollama_on_gpu' is true.
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
  storageClass: "gp3"
  size: 50Gi

# --- Application Configuration ---
ollama:
  # --- GPU Block ---
  # This block is now self-contained and only handles GPU settings.
  gpu:
    enabled: ${ollama_on_gpu}
    type: "nvidia"
    # The chart ignores 'number' if 'enabled' is false, so it's safe to include.
    # The chart also automatically adds the 'resources' limits based on this.
    number: 1

  # --- Models Block ---
  # This block is now correctly at the same level as the 'gpu' block.
  # We always render the 'pull' key with an empty list if no models are provided.
  # This is the most robust way to prevent template errors.
  models:
    pull:
%{ for model in ollama_models ~}
      - ${model}
%{ endfor ~}