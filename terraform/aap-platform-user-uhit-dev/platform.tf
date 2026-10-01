resource "aap_organization" "this" {
  name        = var.organization_name
  description = "uhit-dev demo environment. Managed by the HCP Terraform workspace aap-platform-user-uhit-dev - do not edit by hand."
}

data "aap_credential_type" "scm" {
  name = "Source Control"
  kind = "scm"
}

resource "aap_credential" "scm" {
  name            = "platform-scm"
  description     = "Read-only deploy key for etsauer-acme/demo-gitops terraform/aap-platform-user-uhit-dev."
  organization    = tonumber(aap_organization.this.id)
  credential_type = tonumber(data.aap_credential_type.scm.id)

  inputs_wo = jsonencode({
    username     = "git"
    ssh_key_data = var.scm_deploy_key
  })
  inputs_wo_version = var.scm_deploy_key_version
}
