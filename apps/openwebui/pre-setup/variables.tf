variable "aws_region" {
  description = "AWS region where the EKS cluster and Secrets Manager reside."
  type        = string
}

variable "cluster_name" {
  description = "The name of the EKS cluster to deploy to."
  type        = string
}

variable "project_name" {
  description = "Rafay Project Name"
  type        = string
}

variable "db_secret_name" {
  description = "The name/ARN of the secret in AWS Secrets Manager containing the database credentials."
  type        = string
}

# --- Kubeconfig Variables (Injected from preceding template) ---

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