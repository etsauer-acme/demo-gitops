locals {
  kv_files       = fileset("${path.module}/", "kv/**/*.yaml")
  approle_files  = fileset("${path.module}/", "approles/**/*.yaml")
  jwt_files      = fileset("${path.module}/", "jwt-roles/**/*.yaml")
  pki_role_files = fileset("${path.module}/", "pki-roles/**/*.yaml")
  ssh_role_files = fileset("${path.module}/", "ssh-roles/**/*.yaml")
  mount_files    = fileset("${path.module}/", "mounts/**/*.yaml")
  policy_files   = fileset("${path.module}/", "policies/**/*.yaml")
  cluster_files  = fileset("${path.module}/", "k8s-cluster-onboarding/**/*.yaml")
  workload_files = fileset("${path.module}/", "k8s-workload-onboarding/**/*.yaml")
}

module "vault_platform_user" {
  source  = "app.terraform.io/team-rts-fiserv/vault-platform-user/vault"
  version = "0.8.2"

  kv_secrets    = merge([for kv_file in local.kv_files : yamldecode(file(kv_file))]...)
  approle_roles = merge([for approle_file in local.approle_files : yamldecode(file(approle_file))]...)
  jwt_roles     = merge([for jwt_file in local.jwt_files : yamldecode(file(jwt_file))]...)
  pki_roles     = merge([for pki_role_file in local.pki_role_files : yamldecode(file(pki_role_file))]...)
  ssh_roles     = merge([for ssh_role_file in local.ssh_role_files : yamldecode(file(ssh_role_file))]...)
  mounts        = merge([for mount_file in local.mount_files : yamldecode(file(mount_file))]...)
  policies      = merge([for policy_file in local.policy_files : yamldecode(file(policy_file))]...)
  clusters      = merge([for cluster_file in local.cluster_files : yamldecode(file(cluster_file))]...)
  k8s_workloads = merge([for workload_file in local.workload_files : yamldecode(file(workload_file))]...)
}
