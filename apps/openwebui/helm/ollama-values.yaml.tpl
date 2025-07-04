# Values for the independent, official Ollama chart.

# --- Common Settings ---
persistence:
  enabled: true
  storageClass: "gp3"
  size: 50Gi

%{ if length(ollama_models) > 0 ~}
models:
%{ for model in ollama_models ~}
  - name: "${model}"
%{ endfor ~}
%{ endif ~}


# --- GPU-Specific Settings ---
%{ if ollama_on_gpu ~}
nodeSelector:
  accelerator: "nvidia"

tolerations:
  - key: "nvidia.com/gpu"
    operator: "Equal"
    value: "true"
    effect: "NoSchedule"

resources:
  limits:
    nvidia.com/gpu: 1
%{ endif ~}