variable "cluster_name" {
  description = "A name for the VPC, typically matching the first cluster that will use it."
  type        = string
}

variable "aws_region" {
  description = "The AWS region to deploy the VPC into."
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR. This should be a valid private (RFC 1918) CIDR range"
  default     = "10.0.0.0/16"
  type        = string
} 