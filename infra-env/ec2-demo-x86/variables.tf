variable "region" {
  description = "The AWS region where resources will be created. This will be passed from the environment configuration."
  type        = string
}

variable "instance_type" {
  description = "The EC2 instance type for the agent host (must be a non-Graviton, x86_64 type)."
  type        = string
  default     = "t3.xlarge"
}

variable "root_volume_size_gib" {
  description = "The size of the root EBS volume in GiB."
  type        = number
  default     = 100
}

variable "environment_name" {
  description = "The unique name of the environment, injected by Rafay using $(environment.name)$. Used for naming and tagging resources."
  type        = string
  validation {
    condition     = length(var.environment_name) >= 5
    error_message = "The environment_name must be at least 5 characters long to generate a unique prefix."
  }
}