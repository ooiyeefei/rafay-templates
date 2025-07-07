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
# CASE 1: External endpoint is provided.
# We populate 'openaiBaseApiUrls' and ensure 'ollamaUrls' is empty.
openaiBaseApiUrls:
  - "${external_vllm_endpoint}"
ollamaUrls: []
%{ else ~}
  # No external endpoint, so check if internal Ollama is enabled.
  %{ if enable_ollama_workload ~}
# CASE 2: Internal Ollama is enabled.
# We populate 'ollamaUrls' with the internal FQDN and ensure 'openaiBaseApiUrls' is empty.
openaiBaseApiUrls: []
ollamaUrls:
  - "http://ollama-server-${namespace}.svc.cluster.local:11434"
  %{ else ~}
# CASE 3: No external or internal endpoint. Both must be empty.
openaiBaseApiUrls: []
ollamaUrls: []
  %{ endif ~}
%{ endif ~}

# "http://ollama-server-${namespace}:11434"

ollama:
  # Ollama will be handled separately if enabled
  enabled: false