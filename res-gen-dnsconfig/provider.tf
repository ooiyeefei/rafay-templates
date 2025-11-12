terraform {
  required_providers {
    http = {
      source  = "hashicorp/http"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region  = "us-west-2"
  skip_credentials_validation = var.skip_credentials_validation
  skip_metadata_api_check     = var.skip_metadata_api_check
  skip_requesting_account_id  = var.skip_requesting_account_id
  skip_region_validation      = var.skip_region_validation
}

provider "http" {}