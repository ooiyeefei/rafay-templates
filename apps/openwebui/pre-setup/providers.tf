terraform {
  required_providers {
    rafay = {
      version = "=1.1.38"
      source  = "RafaySystems/rafay"
    }
    aws = {
      source = "hashicorp/aws"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.5.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.20.0"
    }
    random = {
      source = "hashicorp/random"
      version = ">= 3.1.0"
    }
  }
}

# Provider for creating the EKS Pod Identity Association
provider "aws" {
  region = var.aws_region
}

# Provider for creating Kubernetes resources (Namespace, Service Account)
# This is now configured to use the credentials passed in as variables.
provider "kubernetes" {
  host                   = var.host
  client_certificate     = base64decode(var.clientcertificatedata)
  client_key             = base64decode(var.clientkeydata)
  cluster_ca_certificate = base64decode(var.certificateauthoritydata)
}