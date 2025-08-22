terraform {
  required_providers {
    rafay = {
      source = "RafaySystems/rafay"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = ">= 2.20.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# Configure the AWS provider
provider "aws" {
  region = var.aws_region
}

# Configure the Kubernetes provider using credentials injected by the Rafay environment
provider "kubernetes" {
  host                   = var.host
  client_certificate     = base64decode(var.client_certificate_data)
  client_key             = base64decode(var.client_key_data)
  cluster_ca_certificate = base64decode(var.cluster_ca_certificate_data)
}