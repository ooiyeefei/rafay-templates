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
  }
}

# Configure AWS provider for Route53 DNS management
provider "aws" {
  region = "us-east-1"
}