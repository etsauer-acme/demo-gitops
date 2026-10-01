# Vault Platform User Onboarding (uhit-dev)

This repository manages the Vault objects in namespace `admin/uhit-dev` on the `uhit-dev-vault` HCP Vault Dedicated
cluster, through the `vault-platform-user-uhit-dev` workspace (HCP Terraform org `team-rts-fiserv`, project `uhit-dev`).

## Introduction

This documentation will provide guidance for how to create Vault objects inside your application team's ("APM's") own
Vault namespace using this repository. This repository is scaffolded for you when the platform team onboards you, and it
is the only repository you need in order to manage the Vault objects your applications depend on.

## Prerequisites

* __Your APM's namespace already exists in Vault__
    * It is created by the platform team's onboarding. This repository never creates, renames, or references any other
      namespace - each folder below is namespace-scoped by design
* __This repository's own TFE workspace already exists and is VCS-connected to it__
    * The workspace is named `vault-platform-user-<your_apm_name>`, with auto-apply enabled - so committing to `main`
      starts a run and the change applies without a manual approval (the standard onboarding sets auto-apply on; if your
      workspace has it disabled, approve the plan in TFE)
* __The auth backend you intend to attach a role to already exists__
    * See the folder you're using for what it expects to already be in place

## Steps to Perform

1. Pick the folder that matches the Vault object you want to create - each folder has its own `README.md` describing the
   yaml it expects:

    | Folder | Creates |
    |---|---|
    | `kv/` | KV secret entries under your namespace's fixed `secret/` mount |
    | `approles/` | AppRole roles on an existing AppRole auth backend |
    | `jwt-roles/` | JWT/OIDC roles on an existing JWT auth backend |
    | `pki-roles/` | Leaf-certificate roles on an existing issuing CA mount |
    | `ssh-roles/` | SSH CA roles on an existing SSH secret engine |
    | `mounts/` | New secret engine mounts |
    | `policies/` | ACL policies for paths inside your namespace |
    | `k8s-cluster-onboarding/` | A JWT auth backend per external cluster (EKS/AKS/OpenShift), connected to that cluster's token issuer |
    | `k8s-workload-onboarding/` | Workload JWT roles + generated KV-read policies under an onboarded cluster's backend |

2. Create a `<name_you_want_for_the_object>.yaml` file within that folder, defining the configuration of the object you
   want to create - use the folder's own `README.md` for the argument list and examples
3. Commit the file to the `main` branch

## How this repository is consumed

* Every `*.yaml` file under each of the folders above (nested subfolders included) is read on the workspace's next run
  and merged into the corresponding input of the TFE-registry-published `vault-platform-user` module
  (`vault-platform-user/vault`)
* Each entry carries its own name field (`role_name`, `name`, `workload_name`, `path`, ... - see the folder's README);
  the top-level key is only the entry label. The keys from every file in a folder are merged together, so a key may
  only be used once per folder - a duplicate key silently overrides the earlier one
* Only `.yaml` files are read - a file ending in `.yml` is ignored
* Each entry only needs the arguments it actually uses - entries in a folder do not have to match each other's shape.
  Any optional argument an entry omits takes the module's own default, per entry
* An empty folder is fine - nothing is created or destroyed by leaving one empty
* Committing to `main` is the deployment mechanism: there is no local `terraform apply`, and the workspace applies your
  change automatically

## Guardrails

Two independent layers keep this repository scoped to your own namespace:

* __Terraform-side__ - the module rejects out-of-bounds configuration (mount prefixes outside its allow-list, non
  allow-listed engine types, root/intermediate PKI mount paths, `sudo` capabilities, path traversal) before a plan is
  produced
* __Vault-side__ - the ACL policy the platform team attaches to your workspace's own identity physically cannot reach
  outside your namespace, regardless of what is written in this repository

## What this repository intentionally does not do

Everything below is the platform team's territory, and lives in a separate repository you don't need to touch:

* Creating your namespace, or referencing any namespace other than your own
* Enabling auth backends (AppRole, JWT, Kubernetes) or creating the shared JWT backend your workspace authenticates with
* Creating root or intermediate PKI certificate authorities
* `sys/*` system-level configuration
* Org-wide or root-namespace policies

If you need one of the above, ask the platform team rather than adding it here.

## FAQ

* _Do I have to run Terraform myself?_
    * No. Committing to `main` is the whole workflow - the repository's own TFE workspace runs on commit with auto-apply
      enabled
* _What happens if I remove an entry from a yaml file?_
    * The object that entry created is destroyed on the next run. Removing a `kv/` entry destroys the secret it held
* _How do I see whether my change applied?_
    * Watch the `vault-platform-user-<your_apm_name>` workspace's run in TFE - the plan shows exactly what will be
      created, changed, or destroyed, and the run's log shows the result once it completes
* _Why does my run fail to authenticate to Vault?_
    * Until the platform team completes the Vault JWT trust wiring for your workspace (`namespace_onboarding` entry
      matching this workspace's `terraform_full_workspace` claim), runs can't establish a Vault session. Raise it with
      them rather than working around it here

## Notes on this repository's plumbing

* The workspace is VCS-connected with a GitLab access token scoped to just this project - not the shared org-wide oauth
  token every other VCS-connected workspace in this org uses
* `main.tf` and `variables.tf` here wire the folders above into the module; `provider.tf` carries this workspace's own
  `cloud {}` block and the Vault provider authenticated via TFE Dynamic Credentials. These three files are managed by
  the platform team's module - add your objects in the folders, not in them
