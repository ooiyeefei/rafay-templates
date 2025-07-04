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
  # If an external endpoint is used, the embedded Ollama chart must be disabled.
  enabled: false
  %{ else ~}
  # If using the embedded workload, configure it based on the variables.
  enabled: ${enable_ollama_workload}
  %{ if ollama_on_gpu ~}
  # These keys are now correctly indented because they are inside the "if"
  # statement, which itself is correctly indented under the "ollama:" block.
  tolerations:
    - key: "nvidia.com/gpu"
      operator: "Exists"
      effect: "NoSchedule"
  nodeSelector:
    "nvidia.com/gpu": "true"
  %{ endif ~}
  %{ endif ~}