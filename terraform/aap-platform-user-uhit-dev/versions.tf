terraform {
  required_version = "~>1.16.0"

  cloud {
    organization = "team-rts-fiserv"
    workspaces {
      name = "aap-platform-user-uhit-dev"
    }
  }

  required_providers {
    aap = {
      source  = "tfbrew/aap"
      version = "2.6.0"
    }
    tfe = {
      source  = "hashicorp/tfe"
      version = "~> 0.81.0"
    }
  }
}

provider "aap" {
  endpoint             = var.aap_address
  username             = var.aap_username
  password             = var.aap_password
  insecure_skip_verify = true
}

provider "tfe" {
  organization = var.tfe_organization
}
