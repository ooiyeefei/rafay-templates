# --- Cluster Information ---
variable "cluster_name" {
  type        = string
  description = "Rafay MKS cluster name"
}

variable "project_name" {
  type        = string
  description = "Rafay project name"
}

variable "namespace" {
  type        = string
  default     = "runai"
  description = "Kubernetes namespace for Run:AI"
}

# --- Node Information from Previous Terraform Output ---
variable "nodes_information" {
  type = map(object({
    hostname         = string
    ip_address       = string  # Public IP
    operating_system = string
    private_ip       = string
  }))
  description = "Output from res-upstream-infra-device terraform with nodes information"
}

# Example:
# nodes_information = {
#   "TRY-63524-gpu01" = {
#     hostname         = "TRY-63524-gpu01"
#     ip_address       = "72.25.67.15"
#     operating_system = "Ubuntu24.04"
#     private_ip       = "172.16.0.129"
#   }
# }

variable "runai_chart_version" {
  type        = string
  default     = "2.23.17"
  description = "Run:AI Helm chart version"
}

variable "runai_helm_repo" {
  type        = string
  default     = "https://runai.jfrog.io/artifactory/api/helm/run-ai-charts"
  description = "Run:AI Helm repository URL"
}

# --- DNS Configuration ---
variable "dns_domain" {
  type        = string
  default     = "rafay.dev"
  description = "Base DNS domain for Run:AI clusters"
}

variable "route53_zone_id" {
  type        = string
  description = "AWS Route53 hosted zone ID"
}

variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region for Route53 operations (Route53 is global, but provider needs a region)"
}

# --- cert-manager Configuration ---
variable "letsencrypt_email" {
  type        = string
  description = "Email for Let's Encrypt certificate notifications"
}

variable "cluster_issuer_name" {
  type        = string
  default     = "letsencrypt-prod"
  description = "Name of the cert-manager ClusterIssuer"
}

variable "kubeconfig_yaml" {
    type        = string
    sensitive   = true
    description = "Full kubeconfig YAML content"
  }