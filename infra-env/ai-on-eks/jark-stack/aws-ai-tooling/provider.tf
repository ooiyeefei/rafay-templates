terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 1.0"
    }
  }
}
provider "aws" {
  region = var.aws_region
}

provider "aws" {
  alias  = "ecr"
  region = "us-east-1"
}