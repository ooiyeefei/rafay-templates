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
# CASE 1: Use the provided external endpoint.
openaiBaseApiUrls: ["${external_vllm_endpoint}"]
%{ else ~}
  %{ if enable_ollama_workload ~}
# CASE 2: No external endpoint, but internal Ollama is enabled.
# Point to the correct service name, which is derived from the workload's metadata.name.
openaiBaseApiUrls: ["http://ollama-server-${namespace}.svc.cluster.local:11434"]
  %{ else ~}
# CASE 3: No external or internal endpoint. The UI will have no models.
openaiBaseApiUrls: []
  %{ endif ~}
%{ endif ~}

ollama:
  # Ollama will be handled separately if enabled
  enabled: false