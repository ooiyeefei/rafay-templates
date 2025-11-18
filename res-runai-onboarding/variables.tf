# ============================================
# Input Variables for Run:AI Onboarding
# ============================================

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
# Note: Variable name must match upstream output name
# Upstream outputs: { nodes_info = {...}, number_of_nodes = N }
variable "nodes_information" {
  type = object({
    nodes_info = map(object({
      hostname         = string
      ip_address       = string  # Public IP
      operating_system = string
      private_ip       = string
    }))
    number_of_nodes = number
  })
  description = "Output from res-upstream-infra-device terraform with nodes information"

  # Default empty value to allow destroy when upstream resource fails
  # This prevents "reference not found" errors during Rafay cleanup
  # When upstream cluster provisioning fails, Rafay can still evaluate this module
  # for destroy operations without "reference not found" errors
  default = {
    nodes_info      = {}
    number_of_nodes = 0
  }
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
# Note: RUNAI_CONTROL_PLANE_URL, RUNAI_APP_ID, and RUNAI_APP_SECRET
# are provided via Rafay Config Context environment variables (like AWS credentials)
# No Terraform variables needed for these!

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

# --- Run:AI User and Project Configuration ---
variable "user_email" {
  type        = string
  description = "Email for the Run:AI user to be created (will have access to the project)"
}

variable "user_role" {
  type        = string
  default     = "ML engineer"
  description = "Run:AI role to assign to the user (default: 'ML engineer')"
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

# --- Kubeconfig Fetching ---
# The module uses rafay_download_kubeconfig data source to fetch kubeconfig
# directly using the cluster_name variable (already defined above)
# No additional variable needed!

# --- Optional: Rafay Environment Manager Variables ---
# These can be injected from Rafay using Starlark expressions like:
# $(trigger.payload.username)$
# $(trigger.payload.email)$

variable "rafay_triggered_by" {
  type        = string
  default     = ""
  description = "Optional: User who triggered the deployment (from Rafay)"
}
