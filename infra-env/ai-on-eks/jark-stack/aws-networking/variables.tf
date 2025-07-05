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

variable "num_azs" {
  description = "The number of Availability Zones to use for the VPC subnets."
  type        = number
  default     = 3 # A good default for high availability
}

variable "tags" {
  description = "A map of additional tags to apply to all resources created by this template."
  type        = map(string)
  default     = {}
}