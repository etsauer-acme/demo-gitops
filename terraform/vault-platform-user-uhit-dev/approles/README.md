# AppRole Role Onboarding

## Introduction

This documentation will provide guidance for how to create AppRole roles on an existing AppRole auth backend inside your
APM's own Vault namespace using this repository.

## Prerequisites

* __An AppRole auth backend already exists at the mount path you reference__
    * This folder only ever creates *roles* on a backend that already exists - it never enables or configures the backend
      itself. Enabling auth backends is the platform team's job; ask them if the mount you need isn't there yet
* __The policies the role's token will carry already exist__
    * A role grants a Vault token carrying the `token_policies` you list - those policies come from this repository's
      `policies/` folder, or from your namespace's baseline policy

## Steps to Perform

1. Within this `approles` folder, create a `<name_you_want_for_the_role>.yaml` file that'll define the configuration
   of the AppRole role you want to create
    * Below are examples of how you'd configure the yaml file to create certain types of AppRole roles
    * The file name is only for your own organization - the role's actual name in Vault is the top-level key
    * The top-level keys from every file in this folder are merged together, so each role name must be unique across the
      whole folder

__For creating a CI/CD deployer role:__
```yaml
ci-deployer: # The entry label - also this file's name
    role_name: ci-deployer # The AppRole role's name in Vault
    backend: approle # The mount path of the existing AppRole auth backend
    token_policies: # The policies the issued token carries
        - my-app-read
    token_ttl: 3600 # 1 hour, in seconds
    token_max_ttl: 14400 # 4 hours, in seconds
    secret_id_ttl: 86400 # 1 day, in seconds
```

__For creating a role that only accepts one short-lived secret_id from your own network:__
```yaml
ci-deployer:
    role_name: ci-deployer
    backend: approle
    bind_secret_id: true
    secret_id_bound_cidrs: [
        "10.0.0.0/8"
    ]
    secret_id_num_uses: 1
    token_policies: [
        "my-app-read"
    ]
    token_bound_cidrs: [
        "10.0.0.0/8"
    ]
    token_no_default_policy: true
```

## Required and optional arguments

* `role_name` - __required__ - the AppRole role's name in Vault (the top-level key is only the entry label)
* `backend` - __required__ - the mount path of the existing AppRole auth backend

Everything else is optional:

* `bind_secret_id`, `secret_id_bound_cidrs`, `secret_id_num_uses`, `secret_id_ttl`
* `token_ttl`, `token_max_ttl`, `token_policies`, `token_bound_cidrs`, `token_explicit_max_ttl`,
  `token_no_default_policy`, `token_num_uses`, `token_period`, `token_type`

## Guardrails

* `token_policies` must not include `sudo` or `root` - the module's validation rejects the file before a plan is
  generated
* Even if that validation were bypassed, the ACL policy the platform team attaches to your workspace's own identity
  physically cannot reach outside your namespace - the guardrails here are defense-in-depth, not the security boundary

## How this folder is consumed

* Every `*.yaml` file under this folder (nested subfolders included) is decoded and merged into the `approle_roles` input
  of the TFE-registry-published `vault-platform-user` module (`vault-platform-user/vault`)
* A file ending in `.yml` is ignored - only `.yaml` files are read
* Each entry only needs the arguments it actually uses - entries in a folder do not have to match each other's shape.
  Any optional argument an entry omits takes the module's own default for that entry
* Removing an entry destroys the role and its KV credential entry on the next run
* For each role, the module writes the login credentials (the role's `role_id` and a generated
  `secret_id`) to the KV entry `approles/<role_name>` in your namespace's `secret` mount - named
  after the role, so a client logs in with values read straight from KV
* Committing to `main` triggers the workspace's run, and auto-apply means the role lands without a manual approval

## FAQ

* _How does a client actually authenticate with this role?_
    * Read the credential entry the module wrote - KV `approles/<role_name>` - and exchange both
      values for a token:
      `vault write auth/<backend>/login role_id=<role_id> secret_id=<secret_id>`
* _What happens to the credential entry when I change the role?_
    * Changing the role's own configuration does not invalidate existing secret IDs, but the module
      issues a fresh secret_id on any role change and writes it as a new version of
      `approles/<role_name>` - re-read the entry after a run to pick up the current one
* _Can I enable the AppRole auth backend from this folder?_
    * No - backend enablement is the platform team's territory. If the mount you want to attach a role to doesn't exist
      yet, ask them to enable it
