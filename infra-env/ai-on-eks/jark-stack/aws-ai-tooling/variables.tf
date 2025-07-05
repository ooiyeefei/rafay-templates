# --- Inputs from 'aws-platform-eks' template ---
variable "cluster_name" {
  description = "The name of the EKS cluster to deploy tooling to."
  type        = string
}

variable "aws_region" {
  description = "The AWS region to deploy the VPC into."
  type        = string
}

variable "oidc_provider_arn" {
  description = "The ARN of the OIDC provider for the EKS cluster."
  type        = string
}

variable "cluster_oidc_issuer_url" {
  description = "The OIDC issuer URL for the EKS cluster."
  type        = string
}

variable "karpenter_instance_profile_name" {
  description = "The name of the EC2 instance profile for Karpenter nodes to use."
  type        = string
}

variable "efs_csi_driver_role_arn" {
  description = "ARN of the IAM role to be used by the EFS CSI driver."
  type        = string
}

variable "aws_load_balancer_controller_irsa_role_arn" {
  description = "ARN of the IAM role for the AWS Load Balancer Controller."
  type        = string
}

variable "karpenter_irsa_role_arn" {
  description = "The ARN for the Karpenter controller IAM Role."
  type        = string
}


# --- Tooling Configuration ---
variable "karpenter_chart_version" {
  description = "The version of the Karpenter Helm chart to install."
  type        = string
  default     = "1.4.0""
}

variable "kuberay_chart_version" {
  description = "The version of the KubeRay Operator Helm chart to install."
  type        = string
  default     = "1.4.0"
}

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