# terraform-vault-vault-platform-admin-deployment (uhit-dev)

Tier 1 (platform-admin) consumer config for the `uhit-dev` HCP Vault Dedicated cluster
(`uhit-dev-vault`, created by `terraform-hcp-platform-uhit-dev`). Drives the `vault-platform-admin`
workspace in HCP Terraform org `team-rts-fiserv`, project `uhit-dev` - VCS-driven, auto-apply.

Sources `app.terraform.io/team-rts-fiserv/vault-platform-admin/vault` (repo
`zisom-hc/terraform-vault-vault-platform-admin-module`, tag-published).

## Authentication

HCP Terraform Dynamic Provider Credentials, no standing Vault credential. Workspace env vars:

| Variable | Value |
|---|---|
| `TFC_VAULT_PROVIDER_AUTH` | `true` |
| `TFC_VAULT_ADDR` | uhit-dev-vault public endpoint |
| `TFC_VAULT_NAMESPACE` | `admin` |
| `TFC_VAULT_AUTH_PATH` | `jwt/tfe` |
| `TFC_VAULT_RUN_ROLE` | `vault-platform-admin` |

HCP Vault Dedicated only exposes the `admin` namespace, so `admin` plays the role the root namespace
plays on a self-managed cluster: the provider runs in `admin`, and every namespace-relative path in the
YAML below (e.g. an onboarded APM's `uhit-dev`) lands under `admin/`.

The `jwt/tfe` backend, the `vault-platform-admin` role and the `root-admin` policy were created once
with the cluster's bootstrap admin token (the `admin_token` output of `uhit-dev-hcp-platform`) and
imported by this workspace's first run - this workspace cannot log in until they exist.

## Layout

Every `*.yaml` under a folder is merged into the matching module input (top-level key = object key,
unique per folder). `.yaml.example` files are ignored.

| Folder | Module input |
|---|---|
| `namespaces/` | `namespaces` |
| `policies/` | `policies` |
| `pki/mounts/`, `pki/ca-signing/`, `pki/roles/` | `pki_mounts`, `pki_certificates`, `pki_roles` |
| `kubernetes-auth/`, `kubernetes-auth-roles/` | `kubernetes_auth_backends`, `kubernetes_auth_roles` |
| `approle-auth/`, `approle-auth-roles/` | `approle_auth_backends`, `approle_auth_roles` |
| `ssh/`, `ssh-roles/` | `ssh_secret_engines`, `ssh_roles` |
| `jwt-auth/`, `jwt-auth-roles/` | `jwt_auth_backends`, `jwt_auth_roles` |
| `namespace-onboarding/` | `namespace_onboardings` |

## Onboarding another team namespace

Add `namespace-onboarding/<apm>.yaml` (copy `uhit-dev.yaml`), then add the team's
`vault-platform-user-<apm>` workspace in `terraform-tfe-platform-workspace-onboarding-deployment`
with `TFC_VAULT_RUN_ROLE=<apm>-workspace-identity-vault`.
