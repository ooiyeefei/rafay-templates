variable "name" {
  description = "Name of the VPC and EKS Cluster"
  default     = "automode-cluster"
  type        = string
}

variable "region" {
  description = "region"
  default     = "ap-southeast-3" 
  type        = string
}

variable "eks_cluster_version" {
  description = "EKS Cluster version"
  default     = "1.31"
  type        = string
}

# VPC with 65536 IPs (10.0.0.0/16) for 3 AZs
variable "vpc_cidr" {
  description = "VPC CIDR. This should be a valid private (RFC 1918) CIDR range"
  default     = "10.0.0.0/16"
  type        = string
} 

variable "enable_gpu_nodes" {
  description = "Set to true to enable the GPU-powered node group for this deployment."
  type        = bool
  default     = false
}

variable "gpu_node_count" {
  description = "The number of GPU nodes to run."
  type        = number
  default     = 0
}

variable "enable_spot_nodes" {
  description = "Set to true to enable the cost-optimized Spot instance node group."
  type        = bool
  default     = false
}

variable "spot_node_count" {
  description = "The desired number of Spot nodes to run."
  type        = number
  default     = 0
}


# --- PLATFORM PROFILE DEFINITION ---
# This complex variable defines the available "flavors" of node groups.
# It is required for the logic to work but is NOT intended for direct user interaction in the UI.

variable "node_group_configurations" {
  description = "A map of pre-defined node group profiles that the platform supports."
  type = map(object({
    enabled        = bool
    min_size       = number
    max_size       = number
    desired_size   = number
    instance_types = list(string)
    capacity_type  = string
    disk_size      = number
    disk_type      = string
    labels         = map(string)
    taints = list(object({
      key    = string
      value  = string
      effect = string
    }))
  }))

  default = {
    general = {
      enabled        = true
      min_size       = 1
      max_size       = 5
      desired_size   = 2
      instance_types = ["t3.medium", "t3.large"]
      capacity_type  = "ON_DEMAND"
      disk_size      = 20
      disk_type      = "gp3"
      labels         = { NodeGroup = "general" }
      taints         = []
    },
    gpu = {
      enabled        = false # Disabled by default
      min_size       = 0
      max_size       = 3
      desired_size   = 0
      instance_types = ["g5.xlarge", "g5.2xlarge"]
      capacity_type  = "ON_DEMAND"
      disk_size      = 50
      disk_type      = "gp3"
      labels         = { NodeGroup = "gpu", accelerator = "nvidia" }
      taints = [{
        key    = "nvidia.com/gpu"
        value  = "true"
        effect = "NO_SCHEDULE"
      }]
    },
    spot = {
      enabled        = false # Disabled by default
      min_size       = 0
      max_size       = 5
      desired_size   = 0
      instance_types = ["t3.medium", "c6i.large"]
      capacity_type  = "SPOT"
      disk_size      = 20
      disk_type      = "gp3"
      labels         = { NodeGroup = "spot" }
      taints = [{
        key    = "spot"
        value  = "true"
        effect = "NO_SCHEDULE"
      }]
    }
  }
}