# SSH Role Onboarding

## Introduction

This documentation will provide guidance for how to create SSH CA roles on an existing SSH secret engine inside your
APM's own Vault namespace using this repository.

## Prerequisites

* __An SSH secret engine already exists at the mount path you reference, and it already has a CA key pair__
    * This folder only ever creates *roles* on an engine that already exists - it never enables the engine or generates
      its CA. Enabling secret engines and signing the CA's public key into your machines' `trusted_user_ca_keys` is the
      platform team's territory
* __The policies the role's token will carry already exist__
    * Those come from this repository's `policies/` folder, or from your namespace's baseline policy

## Steps to Perform

1. Within this `ssh-roles` folder, create a `<name_you_want_for_the_role>.yaml` file that'll define the configuration of
   the SSH role you want to create
    * Below are examples of how you'd configure the yaml file to create certain types of SSH roles
    * The file name is only for your own organization - the top-level key is a label for the entry, and `name` is the
      role's actual name in Vault
    * The top-level keys from every file in this folder are merged together, so each entry name must be unique across the
      whole folder

__For creating a role that signs certificates for your own fleet:__
```yaml
my-app-servers: # The name you want for this entry
    backend: ssh # The mount path of the existing SSH secret engine
    name: my-app-servers # The role's name in Vault
    default_user: ansible # The user the certificate is valid for if the requester doesn't specify one
    allowed_users: ansible # Only this user may be requested
    ttl: "5m"
    max_ttl: "30m"
```

__For creating a role that signs certificates a service can use itself:__
```yaml
my-app-bootstrap:
    backend: ssh
    name: my-app-bootstrap
    key_type: "ca" # Defaults to ca - signs certificates with the engine's CA
    default_user: deploy
    allowed_users: "deploy,ubuntu" # A comma-separated list of allowed users
    allowed_extensions: "permit-pty,permit-port-forwarding"
    default_extensions: {
        permit-pty: ""
    }
    allow_user_certificates: true # Defaults to true
    allow_host_certificates: false # Defaults to false
    ttl: "10m"
    max_ttl: "1h"
```

## Required and optional arguments

* `backend` - __required__ - the mount path of the existing SSH secret engine
* `name` - __required__ - the name of the role as it will exist in Vault

Everything else is optional:

* `key_type` (defaults to `ca`), `default_user`, `allowed_users` and `allowed_extensions` (comma-separated strings, not
  lists), `default_extensions` (a map), `allow_user_certificates` (defaults to `true`), `allow_host_certificates`
  (defaults to `false`), `ttl`, `max_ttl`, `cidr_list`

Note the shape difference: `allowed_users` and `allowed_extensions` take a comma-separated **string** such as
`"deploy,ubuntu"`, whereas `default_extensions` is a map.

## Guardrails

* The module's validation rejects anything referring to the platform team's own reserved paths - if the run fails
  validation, check the mount path you're pointing at
* `allowed_users` is what scopes the role: leaving it empty and relying on `default_user` means the requester can ask for
  any username, so name the users you mean
* The ACL policy the platform team attaches to your workspace's own identity physically cannot reach outside your
  namespace - the guardrails here are defense-in-depth, not the security boundary

## How this folder is consumed

* Every `*.yaml` file under this folder (nested subfolders included) is decoded and merged into the `ssh_roles` input of
  the TFE-registry-published `vault-platform-user` module (`vault-platform-user/vault`)
* A file ending in `.yml` is ignored - only `.yaml` files are read
* Each entry only needs the arguments it actually uses - entries in a folder do not have to match each other's shape.
  Any optional argument an entry omits takes the module's own default for that entry
* Removing an entry destroys the role it created on the next run. Certificates already signed under it remain valid until
  they expire
* Committing to `main` triggers the workspace's run, and auto-apply means the role lands without a manual approval

## FAQ

* _How does a client sign a certificate with this role?_
    * `vault write <backend>/sign/<name> public_key=<ssh_public_key> valid_principals=deploy`
* _What's the difference between a `ca` role and a plain signing role?_
    * `key_type: ca` signs the certificate with the engine's CA key, so it is trusted wherever that CA is trusted;
      `key_type: otp` produces a one-time-use credential instead. The module defaults to `ca`
* _Who is allowed to connect with the signed certificate?_
    * The `valid_principals` in the signed certificate must be within the role's `allowed_users`, and the TTL is capped by
      `max_ttl` - the target host still has to trust the CA and permit that user
* _Can I create or configure the SSH engine from this folder?_
    * No - engine enablement and CA key generation are the platform team's territory
