variable "sub_domain" {
  description = "Subdomain where Route53 entry will be created"
  type        = string
  validation {
    condition     = length(var.sub_domain) > 0
    error_message = "Route53 zone id cannot not be empty."
  }
}

variable "ingress_ip" {
  description = "Ingress IP"
  type        = string
}

variable "route53_zone_id" {
  description = "Route53 zone id"
  type        = string
  validation {
    condition     = length(var.route53_zone_id) > 0
    error_message = "Route53 zone id cannot not be empty."
  }
}

variable "project" {
  description = "The name of the project cluster belongs"
  type        = string
  validation {
    condition     = length(var.project) > 0
    error_message = "The project cannot not be empty."
  }
}

variable "cluster_name" {
  description = "The name of the cluster"
  type        = string
  validation {
    condition     = length(var.cluster_name) > 0
    error_message = "The cluster name cannot not be empty."
  }
}

variable "ingress_domain_type" {
  default = "Rafay"
}

variable "host_cluster_name" {
  description = "The name of the host cluster"
  type        = string
  default     = ""
}

variable "ingress_namespace" {
  description = "Namespace where ingress is deployed"
  type        = string
  default     = "ingress-nginx"
  validation {
    condition     = length(var.ingress_namespace) > 0
    error_message = "The ingress namespace cannot be empty."
  }
}

variable "skip_credentials_validation" {
  default = false
}
variable "skip_metadata_api_check" {
  default = false
}
variable "skip_requesting_account_id" {
  default = false
}
variable "skip_region_validation" {
  default = false
}