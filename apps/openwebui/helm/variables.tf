variable "project_name" {
  description = "Rafay project name"
  type        = string
}

variable "cluster_name" {
  description = "Name of the Rafay/EKS cluster to deploy to"
  type        = string
}

# --- Inputs from pre-setup module ---
variable "namespace" {
  description = "The dynamically generated namespace from the pre-setup module."
  type        = string
}

variable "deployment_suffix" {
  description = "The unique suffix passed from the pre-setup module to ensure consistent naming and versioning."
  type        = string
}

# --- Required inputs from infra setup ---
variable "aws_region" {
  description = "The AWS region."
  type        = string
}

variable "s3_bucket_name" {
  description = "The name of the S3 bucket for OpenWebUI document persistence. This is required by the values.yaml template."
  type        = string
}

variable "openwebui_iam_role_arn" {
  description = "The ARN of the IAM role created for the OpenWebUI application pod identity."
  type        = string
}

# --- Helm Chart Configuration ---

variable "openwebui_helm_repo" {
  description = "Git repository name for the Helm chart"
  type        = string
}

variable "openwebui_chart_name" {
  description = "Helm chart name"
  type        = string
} 

variable "openwebui_chart_version" {
  description = "Helm chart version"
  type        = string
}

# --- Kubeconfig Variables (Injected from res-gen-kubeconfig-user) ---
variable "host" {
  description = "The Kubernetes API server endpoint."
  type        = string
  sensitive   = true
}

variable "clientcertificatedata" {
  description = "The client certificate data for Kubernetes authentication."
  type        = string
  sensitive   = true
}

variable "clientkeydata" {
  description = "The client key data for Kubernetes authentication."
  type        = string
  sensitive   = true
}

variable "certificateauthoritydata" {
  description = "The certificate authority data for the Kubernetes cluster."
  type        = string
  sensitive   = true
}

variable "enable_ollama_workload" {
  description = "Set to true to deploy the Ollama workload."
  type        = string
  default     = false
}

variable "ollama_on_gpu" {
  description = "Set to true to schedule the Ollama workload on GPU nodes."
  type        = string
  default     = false
}

variable "external_vllm_endpoint" {
  description = "The base URL of an external OpenAI-compatible API endpoint (e.g., vLLM). If set, the embedded Ollama will be disabled."
  type        = string
  default     = ""
}