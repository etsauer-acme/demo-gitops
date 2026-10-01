terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "5.11.0"
    }
  }
  required_version = ">= 1.3.0"

  cloud {
    organization = "team-rts-fiserv"
    workspaces {
      name = "vault-platform-user-uhit-dev"
    }
  }
}

provider "vault" {
  skip_child_token = true
  address          = var.tfc_vault_dynamic_credentials.default.address
  namespace        = "${var.tfc_vault_dynamic_credentials.default.namespace}/uhit-dev"

  auth_login_token_file {
    filename = var.tfc_vault_dynamic_credentials.default.token_filename
  }
}
