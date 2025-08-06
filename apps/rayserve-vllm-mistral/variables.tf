# --- Cluster, Rafay & AWS Variables ---
variable "cluster_name" {
  description = "Name of the target EKS cluster for deployment."
  type        = string
}

variable "project_name" {
  description = "The name of the Rafay Project."
  type        = string
}

variable "aws_region" {
  description = "The AWS region where the EKS cluster is located."
  type        = string
}

# --- Application Specific Variables ---
variable "namespace" {
  description = "The Kubernetes namespace for the vLLM RayService."
  type        = string
  default     = "rayserve-vllm"
}

variable "hugging_face_hub_token" {
  description = "The Hugging Face Hub token for pulling models."
  type        = string
  sensitive   = true
}

# --- Kubeconfig Variables (Injected by Rafay Environment) ---
variable "host" {
  description = "The Kubernetes API server endpoint."
  type        = string
  sensitive   = true
}

variable "client_certificate_data" {
  description = "The client certificate data for Kubernetes authentication."
  type        = string
  sensitive   = true
}

variable "client_key_data" {
  description = "The client key data for Kubernetes authentication."
  type        = string
  sensitive   = true
}

variable "cluster_ca_certificate_data" {
  description = "The certificate authority data for the Kubernetes cluster."
  type        = string
  sensitive   = true
}