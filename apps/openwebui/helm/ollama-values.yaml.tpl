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

persistence:
  enabled: true
  storageClass: "gp3"
  size: 50Gi

# This will run the pull-models job correctly now.
%{ if length(ollama_models) > 0 ~}
models:
%{ for model in ollama_models ~}
  - name: "${model}"
%{ endfor ~}
%{ endif ~}