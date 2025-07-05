# --- Inputs from the 'aws-networking' template ---
variable "vpc_id" {
  description = "The ID of the VPC to deploy the EKS cluster into."
  type        = string
}

variable "private_subnet_ids" {
  description = "A list of private subnet IDs where EKS nodes will be deployed."
  type        = list(string)
}

# --- Core EKS Cluster Configuration ---
variable "cluster_name" {
  description = "The unique name for the EKS cluster."
  type        = string
}

variable "eks_cluster_version" {
  description = "The Kubernetes version for the EKS cluster."
  type        = string
  default     = "1.29"
}

variable "cluster_endpoint_public_access" {
  description = "Set to true to enable public access to the EKS cluster endpoint. Recommended for testing, not for production."
  type        = bool
  default     = true
}

# --- Node Group Configuration ---
variable "core_node_min_size" {
  description = "Minimum number of nodes for the core node group."
  type        = number
  default     = 2
}

variable "core_node_max_size" {
  description = "Maximum number of nodes for the core node group."
  type        = number
  default     = 8
}

variable "core_node_desired_size" {
  description = "Desired number of nodes for the core node group."
  type        = number
  default     = 2
}

variable "core_node_instance_types" {
  description = "A list of EC2 instance types for the core node group."
  type        = list(string)
  default     = ["m5.xlarge"]
}

# --- Add-on and IAM Configuration ---
variable "enable_cluster_addons" {
  description = "Map of EKS Add-ons to enable or disable."
  type        = map(bool)
  default = {
    coredns                         = true
    kube-proxy                      = true
    vpc-cni                         = true
    aws-ebs-csi-driver              = true
    eks-pod-identity-agent          = true
    amazon-cloudwatch-observability = false
  }
}

variable "kms_key_admin_roles" {
  description = "A list of additional IAM role ARNs to be administrators of the EKS KMS key."
  type        = list(string)
  default     = []
}

# --- General ---
variable "tags" {
  description = "A map of tags to apply to all resources."
  type        = map(string)
  default     = {}
}

variable "aws_region" {
  description = "The AWS region to deploy the VPC into."
  type        = string
}