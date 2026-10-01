variable "aap_address" {
  description = "AAP gateway URL, with scheme."
  type        = string
}

variable "aap_username" {
  description = "AAP admin this workspace bootstraps the organization with."
  type        = string
  sensitive   = true
}

variable "aap_password" {
  description = "Password for aap_username."
  type        = string
  sensitive   = true
}

variable "scm_deploy_key" {
  description = "Private half of the read-only GitHub deploy key AAP clones this repository with (OpenSSH format)."
  type        = string
  sensitive   = true
}

variable "scm_deploy_key_version" {
  description = "Bump to re-send scm_deploy_key to AAP. Changing the key without bumping this is a silent no-op."
  type        = number
  default     = 1
}

variable "organization_name" {
  description = "The AAP organization this workspace creates and owns."
  type        = string
  default     = "uhit-dev"
}

variable "tfe_organization" {
  description = "HCP Terraform organization this workspace lives in."
  type        = string
  default     = "team-rts-fiserv"
}
