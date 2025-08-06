terraform {
  required_providers {
    rafay = {
      version = "= 1.1.47"
      source  = "RafaySystems/rafay"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "2.17.0"
    }
  }
}