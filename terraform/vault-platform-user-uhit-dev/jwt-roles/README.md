# JWT / OIDC Role Onboarding

## Introduction

This documentation will provide guidance for how to create JWT/OIDC roles on an existing JWT auth backend inside your
APM's own Vault namespace using this repository.

## Prerequisites

* __A JWT/OIDC auth backend already exists at the mount path you reference__
    * This folder only ever creates *roles* on a backend that already exists - it never enables or configures the backend
      itself. Enabling auth backends is the platform team's job
    * The backend the platform team uses for TFE Dynamic Credentials is a single shared backend, referenced by its mount
      path - the path your workspace itself authenticates through was fixed at onboarding, so don't change it here
* __The policies the role's token will carry already exist__
    * Those come from this repository's `policies/` folder, or from your namespace's baseline policy

## Steps to Perform

1. Within this `jwt-roles` folder, create a `<name_you_want_for_the_role>.yaml` file that'll define the configuration of
   the JWT role you want to create
    * Below are examples of how you'd configure the yaml file to create certain types of JWT/OIDC roles
    * The file name is only for your own organization - the top-level key is a label for the entry, and `role_name` is
      the role's actual name in Vault
    * The top-level keys from every file in this folder are merged together, so each entry name must be unique across the
      whole folder

__For a role that trusts a TFE workspace's workload identity (Dynamic Credentials):__
```yaml
tfe-dynamic-creds: # The name you want for this entry
    backend: jwt # The mount path of the existing JWT auth backend
    role_name: tfe-dynamic-creds # The role's name in Vault
    role_type: jwt # Optional - defaults to jwt
    user_claim: terraform_full_workspace # The claim the token's subject is taken from
    bound_audiences: [
        "vault.workload.identity"
    ] # Only tokens carrying this audience are accepted
    bound_claims: {
        terraform_full_workspace: "organization:my-org:project:my-project:workspace:my-workspace"
    } # Only this exact workspace may assume the role
    token_policies: [
        "my-app-read"
    ]
    token_ttl: 900
```

__For a role that trusts an application's OIDC provider:__
```yaml
my-app-oidc:
    backend: jwt
    role_name: my-app-oidc
    role_type: oidc
    user_claim: sub
    groups_claim: groups
    oidc_scopes: [
        "openid",
        "profile"
    ]
    bound_audiences: [
        "vault"
    ]
    bound_claims_type: glob
    bound_claims: {
        sub: "repo:my-org/my-app:*"
    }
    token_policies: [
        "my-app-read",
        "my-app-write"
    ]
    token_ttl: 3600
```

## Required and optional arguments

* `backend` - __required__ - the mount path of the existing JWT auth backend
* `role_name` - __required__ - the name of the role as it will exist in Vault
* `user_claim` - __required__ - the claim to use as the token's identity

Everything else is optional:

* Role-shape arguments: `role_type` (defaults to `jwt`), `groups_claim`, `bound_audiences`, `bound_claims`,
  `bound_claims_type`, `bound_subject`, `claim_mappings`, `oidc_scopes`
* Token arguments: `token_ttl`, `token_max_ttl`, `token_policies`, `token_bound_cidrs`, `token_explicit_max_ttl`,
  `token_no_default_policy`, `token_num_uses`, `token_period`, `token_type`

## Guardrails

* `token_policies` must not include `sudo` or `root` - the module's validation rejects the file before a plan is
  generated
* Note that `bound_claims` is an exact-match map unless you set `bound_claims_type: glob` - a role with no bound claims
  and no bound subject trusts any token that carries the right audience, so tighten it before relying on it
* The ACL policy the platform team attaches to your workspace's own identity physically cannot reach outside your
  namespace - the guardrails here are defense-in-depth, not the security boundary

## How this folder is consumed

* Every `*.yaml` file under this folder (nested subfolders included) is decoded and merged into the `jwt_roles` input of
  the TFE-registry-published `vault-platform-user` module (`vault-platform-user/vault`)
* A file ending in `.yml` is ignored - only `.yaml` files are read
* Each entry only needs the arguments it actually uses - entries in a folder do not have to match each other's shape.
  Any optional argument an entry omits takes the module's own default for that entry
* Removing an entry destroys the role it created on the next run
* Committing to `main` triggers the workspace's run, and auto-apply means the role lands without a manual approval

## FAQ

* _How does a client authenticate with this role?_
    * Present the JWT to Vault: `vault write auth/<backend>/login role=<role_name> jwt=<token>`
* _How does my own workspace authenticate to Vault?_
    * Through a role the platform team generates for you at onboarding (`<your_apm>-workspace-identity-vault`), bound to your
      workspace's `terraform_full_workspace` claim. Nothing in this folder needs to change for that to work
* _Can I enable the JWT auth backend from this folder?_
    * No - backend enablement is the platform team's territory. Ask them if you need a backend that doesn't exist yet
* _Do changes here apply to the current run?_
    * Not to the run that creates them - a Terraform run authenticates once at its start, so a role created during a run
      is picked up by the *next* run
