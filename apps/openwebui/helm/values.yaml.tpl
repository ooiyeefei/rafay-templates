# Open WebUI Helm Chart Values

# Configure persistence to use S3
persistence:
  enabled: true
  provider: "s3"
  s3:
    bucket: "${s3_bucket_name}"
    region: "${region}"
    endpointUrl: "https://s3.${region}.amazonaws.com"

# Configure service account for Pod Identity
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: ${openwebui_iam_role_arn}
  enable: true
  name: "open-webui-pia"

# Configure environment variables
extraEnvVars:
  - name: "DATABASE_URL"
    valueFrom:
      secretKeyRef:
        name: "openwebui-db-credentials"
        key: "url"
  - name: "VECTOR_DB"
    value: "pgvector"
  - name: "SIGNUP_ENABLED"
    value: "true"
  - name: WEBUI_AUTH
    value: "False"

tolerations:
- key: "spot"
  operator: "Equal"
  value: "true"
  effect: "NoSchedule"

pipelines:
  enabled: false

%{ if external_vllm_endpoint != "" ~}
# --- Use External vLLM Endpoint ---
openaiBaseApiUrls: ["${external_vllm_endpoint}"]
%{ else ~}
# --- Use Embedded Ollama Workload ---
openaiBaseApiUrls: ["http://localhost:11434"]
%{ endif ~}

ollama:
  %{ if external_vllm_endpoint != "" ~}
  # CASE 1: An external endpoint is provided.
  enabled: false
  %{ else ~}
  # CASE 2 & 3: Embedded Ollama (GPU or non-GPU)
  enabled: ${enable_ollama_workload}
  image:
    repository: ollama/ollama
    tag: "${ollama_image_version}"

  persistence:
    enabled: true
    storageClass: "gp3"
    size: 50Gi

  models:
  %{ for model in ollama_models ~}
    - name: "${model}"
  %{ endfor ~}

  # GPU-specific settings are conditionally added below
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
  %{ endif ~}