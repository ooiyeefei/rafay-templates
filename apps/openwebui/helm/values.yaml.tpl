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
  name: "open-webui-pia"  # Must match the service_account in the Pod Identity association

# Configure environment variables
extraEnvVars:
  # Database configuration for PostgreSQL with pg_vector
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

openaiBaseApiUrls: ["http://vllm-service/v1"]

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
  # The embedded Ollama is simply disabled.
  enabled: false
  %{ else ~}
    # No external endpoint, so check if GPU is requested.
    %{ if ollama_on_gpu ~}
  # CASE 2: No external endpoint, AND GPU is requested.
  # Enable the workload and add the specific GPU scheduling rules.
  enabled: ${enable_ollama_workload}

  image:
    repository: ollama/ollama
    tag: "${ollama_image_version}"

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

  # Loop through the final model list to generate the entries.
  models:
    %{ for model in ollama_models ~}
    - name: "${model}"
    %{ endfor ~}

    %{ else ~}
  # CASE 3: No external endpoint and no GPU.
  # Just enable the workload with no special scheduling.
  enabled: ${enable_ollama_workload}
    %{ endif ~}
  %{ endif ~}