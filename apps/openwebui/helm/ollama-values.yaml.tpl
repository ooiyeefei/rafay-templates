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
  # --- THIS IS THE FINAL FIX ---
  # The 'gpu' key will now always be rendered.
  # Its 'enabled' sub-key will be dynamically set to true or false.
  # This prevents the 'nil pointer' error.
  gpu:
    enabled: ${ollama_on_gpu}
    type: "nvidia" # This can be static, it's ignored if enabled is false.
    
    # We only set the resource limits if GPU is actually enabled.
    %{ if ollama_on_gpu ~}
    number: 1 
    %{ endif ~}


  # This structure for pulling models is correct.
  %{ if length(ollama_models) > 0 ~}
  models:
    pull:
%{ for model in ollama_models ~}
      - ${model}
%{ endfor ~}
  %{ endif ~}