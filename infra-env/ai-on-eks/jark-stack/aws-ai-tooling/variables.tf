# --- Inputs from 'aws-platform-eks' template ---
variable "cluster_name" {
  description = "The name of the EKS cluster to deploy tooling to."
  type        = string
}

variable "cluster_endpoint" {
  description = "The endpoint for the EKS cluster's API server."
  type        = string
}


variable "aws_region" {
  description = "The AWS region to deploy the VPC into."
  type        = string
}

variable "cluster_certificate_authority_data" {
  description = "The base64 encoded certificate data for the EKS cluster."
  type        = string
}

variable "oidc_provider_arn" {
  description = "The OIDC provider ARN for the EKS cluster."
  type        = string
}

variable "eks_cluster_version" {
  description = "The Kubernetes version of the EKS cluster."
  type        = string
}

# --- Tooling Configuration ---
variable "karpenter_instance_category" {
  description = "List of EC2 instance categories for the default Karpenter NodePool."
  type        = list(string)
  default     = ["c", "m", "r"]
}

variable "karpenter_instance_generation" {
  description = "EC2 instance generations for the default Karpenter NodePool."
  type        = list(string)
  default     = ["5", "6"]
}

variable "karpenter_gpus_instance_family" {
  description = "List of GPU instance families for the GPU Karpenter NodePool (e.g., g5, p4d)."
  type        = list(string)
  default     = ["g5"]
}

variable "karpenter_gpus_instance_types" {
  description = "Specific GPU instance types Karpenter is allowed to provision."
  type        = list(string)
  default     = ["g5.xlarge", "g5.2xlarge"]
}

# --- General ---
variable "tags" {
  description = "A map of tags to apply to all resources."
  type        = map(string)
  default     = {}
}