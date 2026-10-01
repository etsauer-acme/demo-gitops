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
      name = "vault-platform-admin"
    }
  }
}

provider "vault" {
  skip_child_token = true
  address          = var.tfc_vault_dynamic_credentials.default.address
  namespace        = var.tfc_vault_dynamic_credentials.default.namespace

  auth_login_token_file {
    filename = var.tfc_vault_dynamic_credentials.default.token_filename
  }
}

locals {
  namespace_files               = fileset("${path.module}/", "namespaces/**/*.yaml")
  policy_files                  = fileset("${path.module}/", "policies/**/*.yaml")
  pki_mount_files               = fileset("${path.module}/", "pki/mounts/**/*.yaml")
  pki_cert_files                = fileset("${path.module}/", "pki/ca-signing/**/*.yaml")
  pki_role_files                = fileset("${path.module}/", "pki/roles/**/*.yaml")
  kubernetes_auth_backend_files = fileset("${path.module}/", "kubernetes-auth/**/*.yaml")
  kubernetes_auth_role_files    = fileset("${path.module}/", "kubernetes-auth-roles/**/*.yaml")
  approle_auth_backend_files    = fileset("${path.module}/", "approle-auth/**/*.yaml")
  approle_auth_role_files       = fileset("${path.module}/", "approle-auth-roles/**/*.yaml")
  ssh_engine_files              = fileset("${path.module}/", "ssh/**/*.yaml")
  ssh_role_files                = fileset("${path.module}/", "ssh-roles/**/*.yaml")
  jwt_auth_backend_files        = fileset("${path.module}/", "jwt-auth/**/*.yaml")
  jwt_auth_role_files           = fileset("${path.module}/", "jwt-auth-roles/**/*.yaml")
  namespace_onboarding_files    = fileset("${path.module}/", "namespace-onboarding/**/*.yaml")
}

module "vault_platform_admin" {
  source  = "app.terraform.io/team-rts-fiserv/vault-platform-admin/vault"
  version = "0.3.21"

  namespaces               = merge([for file in local.namespace_files : yamldecode(file(file))]...)
  policies                 = merge([for file in local.policy_files : yamldecode(file(file))]...)
  pki_mounts               = merge([for file in local.pki_mount_files : yamldecode(file(file))]...)
  pki_certificates         = merge([for file in local.pki_cert_files : yamldecode(file(file))]...)
  pki_roles                = merge([for file in local.pki_role_files : yamldecode(file(file))]...)
  kubernetes_auth_backends = merge([for file in local.kubernetes_auth_backend_files : yamldecode(file(file))]...)
  kubernetes_auth_roles    = merge([for file in local.kubernetes_auth_role_files : yamldecode(file(file))]...)
  approle_auth_backends    = merge([for file in local.approle_auth_backend_files : yamldecode(file(file))]...)
  approle_auth_roles       = merge([for file in local.approle_auth_role_files : yamldecode(file(file))]...)
  ssh_secret_engines       = merge([for file in local.ssh_engine_files : yamldecode(file(file))]...)
  ssh_roles                = merge([for file in local.ssh_role_files : yamldecode(file(file))]...)
  jwt_auth_backends        = merge([for file in local.jwt_auth_backend_files : yamldecode(file(file))]...)
  jwt_auth_roles           = merge([for file in local.jwt_auth_role_files : yamldecode(file(file))]...)
  namespace_onboardings    = merge([for file in local.namespace_onboarding_files : yamldecode(file(file))]...)
}
