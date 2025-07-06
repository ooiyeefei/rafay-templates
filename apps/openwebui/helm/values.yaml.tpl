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

ollamaUrls:
%{ if enable_ollama_workload ~}
  # If internal Ollama is enabled, point to its service.
  - "http://ollama-server-${namespace}:11434"
%{ endif ~}


# This uses the 'openaiBaseApiUrls' key.
%{ if external_vllm_endpoint != "" ~}
openaiBaseApiUrls:
  - "${external_vllm_endpoint}"
%{ endif ~}

ollama:
  # Ollama will be handled separately if enabled
  enabled: false