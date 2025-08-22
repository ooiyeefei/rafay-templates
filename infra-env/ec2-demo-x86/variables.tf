variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.large"
}

variable "num_of_instance" {
  description = "Number of EC2 instances to create"
  type        = number
  default     = 1
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "root_volume_size_gib" {
  description = "The size of the root volume in gibibytes (GiB)"
  type        = number
  default     = 100
}