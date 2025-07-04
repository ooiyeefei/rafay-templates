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
  # Set the 'enabled' key based on the logic in a single line.
  enabled: %{ if external_vllm_endpoint != "" }false%{ else }${enable_ollama_workload}%{ endif }

  # Add GPU scheduling rules only if NOT using an external endpoint AND ollama_on_gpu is true.
  %{ if external_vllm_endpoint == "" && ollama_on_gpu ~}
  nodeSelector:
    accelerator: "nvidia"
  tolerations:
    - key: "nvidia.com/gpu"
      operator: "Equal"
      value: "true"
      effect: "NoSchedule"
  %{ endif ~}