terraform {
  required_providers {
    rafay = {
      source  = "RafaySystems/rafay"
      version = ">= 1.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.5.1"
    }
    time = {
      source = "hashicorp/time"
      version = ">= 0.9.1"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = ">= 2.20.0"
    }
    aws = {
      source = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "kubernetes" {
  host                   = var.host
  client_certificate     = base64decode(var.clientcertificatedata)
  client_key             = base64decode(var.clientkeydata)
  cluster_ca_certificate = base64decode(var.certificateauthoritydata)
}