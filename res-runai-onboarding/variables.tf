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
variable "nodes_info" {
  type = map(object({
    hostname         = string
    ip_address       = string  # Public IP
    operating_system = string
    private_ip       = string
  }))
  description = "Output from res-upstream-infra-device terraform with nodes information"
}

# Example:
# nodes_info = {
#   "TRY-63524-gpu01" = {
#     hostname         = "TRY-63524-gpu01"
#     ip_address       = "72.25.67.15"
#     operating_system = "Ubuntu24.04"
#     private_ip       = "172.16.0.129"
#   }
# }

# --- Run:AI Configuration ---
variable "runai_control_plane_url" {
  type        = string
  description = "Run:AI Control Plane URL (e.g., rafay.runailabs-ps.com)"
}

variable "runai_client_secret" {
  type        = string
  sensitive   = true
  description = "Run:AI Control Plane client secret"
}

variable "runai_cluster_uid" {
  type        = string
  description = "Run:AI cluster UID from Control Plane"
}

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
  default     = "runai.langgoose.com"
  description = "Base DNS domain for Run:AI clusters"
}

variable "route53_zone_id" {
  type        = string
  description = "AWS Route53 hosted zone ID"
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

# --- Kubeconfig for kubectl operations ---
variable "host" {
  type        = string
  description = "Kubernetes cluster API endpoint"
}

variable "certificateauthoritydata" {
  type        = string
  description = "Kubernetes cluster CA certificate (base64)"
}

variable "clientcertificatedata" {
  type        = string
  description = "Client certificate data for authentication (base64)"
}

variable "clientkeydata" {
  type        = string
  sensitive   = true
  description = "Client key data for authentication (base64)"
}

# --- Deployment Configuration ---
variable "environment_name" {
  type        = string
  description = "Environment name for unique resource naming (e.g., from Rafay Environment Manager)"
}

variable "deployment_suffix" {
  type        = string
  default     = "v1"
  description = "Suffix for versioning workloads"
}

# --- Optional: Rafay Environment Manager Variables ---
# These can be injected from Rafay using Starlark expressions like:
# $(trigger.payload.username)$
# $(environment.name)$
# $(trigger.payload.email)$

variable "rafay_triggered_by" {
  type        = string
  default     = ""
  description = "User who triggered the deployment (from Rafay)"
}
