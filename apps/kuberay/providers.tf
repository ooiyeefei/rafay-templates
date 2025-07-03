terraform {
  required_providers {
    rafay = {
      source = "RafaySystems/rafay"
    }
    helm = {
      source = "hashicorp/helm"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    random = {
      source = "hashicorp/random"
    }
    # Added from openwebui pattern
    local = {
      source  = "hashicorp/local"
      version = ">= 2.5.1"
    }
    time = {
      source = "hashicorp/time"
      version = ">= 0.9.1"
    }
    aws = {
      source = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# Added from openwebui pattern
provider "aws" {
  region = var.aws_region
}

provider "kubernetes" {
  host                   = var.host
  client_certificate     = base64decode(var.clientcertificatedata)
  client_key             = base64decode(var.clientkeydata)
  cluster_ca_certificate = base64decode(var.certificateauthoritydata)
}

provider "helm" {
  kubernetes = {
    host                   = var.host
    client_certificate     = base64decode(var.clientcertificatedata)
    client_key             = base64decode(var.clientkeydata)
    cluster_ca_certificate = base64decode(var.certificateauthoritydata)
  }
}