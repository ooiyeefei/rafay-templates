terraform {
  required_version = ">= 1.5.0"

  required_providers {
    rafay = {
      source  = "RafaySystems/rafay"
      version = ">=1.1.23"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">=5.0.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">=2.4.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">=0.9.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">=2.20.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">=2.9.0"
    }
  }
}

# Configure AWS provider for Route53 DNS management
provider "aws" {
  region = var.aws_region
}

# Configure Kubernetes provider for direct cluster access
# This enables potential future use of kubernetes resources
provider "kubernetes" {
  host                   = var.host
  client_certificate     = base64decode(var.clientcertificatedata)
  client_key             = base64decode(var.clientkeydata)
  cluster_ca_certificate = base64decode(var.certificateauthoritydata)
}

# Configure Helm provider for Helm chart deployments
# Uses same authentication as Kubernetes provider
provider "helm" {
  kubernetes = {
    host                   = var.host
    client_certificate     = base64decode(var.clientcertificatedata)
    client_key             = base64decode(var.clientkeydata)
    cluster_ca_certificate = base64decode(var.certificateauthoritydata)
  }
}
