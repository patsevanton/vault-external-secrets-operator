terraform {
  required_version = ">= 1.0.0, < 2.0.0"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = ">= 3.10.0, < 4.0.0"
    }
  }
}