# PKI Role Onboarding

## Introduction

This documentation will provide guidance for how to create leaf-certificate roles on an existing issuing CA mount inside
your APM's own Vault namespace using this repository.

## Prerequisites

* __An issuing CA mount already exists in your namespace, with its root or intermediate certificate configured__
    * This folder only ever attaches *roles* to a mount that already exists - it never creates a CA or issues an
      intermediate certificate. Creating root or intermediate CAs is the platform team's territory
    * Named roles live under that mount at `auth`-style paths, e.g. `<mount_path>/roles/<name>`, and the role only ever
      issues leaf certificates from the CA already on that mount

## Steps to Perform

1. Within this `pki-roles` folder, create a `<name_you_want_for_the_role>.yaml` file that'll define the configuration of
   the PKI role you want to create
    * Below are examples of how you'd configure the yaml file to create certain types of PKI roles
    * The file name is only for your own organization - the top-level key is a label for the entry, and `name` is the
      role's actual name in Vault
    * The top-level keys from every file in this folder are merged together, so each entry name must be unique across the
      whole folder

__For creating a role that issues short-lived server certificates under one domain:__
```yaml
my-app-server-cert: # The name you want for this entry
    mount_path: pki-int # The mount path of the existing issuing CA
    name: my-app-server-cert # The role's name in Vault
    allowed_domains: [
        "my-app.internal"
    ] # Certificates may only be issued for this domain
    allow_subdomains: true # ...including any subdomain of it
    max_ttl: "720h"
    ttl: "168h"
```

__For creating a role that issues client certificates:__
```yaml
my-app-client-cert:
    mount_path: pki-int
    name: my-app-client-cert
    allowed_domains: [
        "my-app.internal"
    ]
    allow_subdomains: true
    server_flag: false
    client_flag: true
    key_type: "ec"
    key_bits: 256
    max_ttl: "168h"
    ttl: "24h"
    organization: [
        "My Company"
    ]
    ou: [
        "my-app"
    ]
```

## Required and optional arguments

* `mount_path` - __required__ - the mount path of the existing issuing CA. It must be an *issuing* mount: the module
  rejects paths matching `pki-root*` or `pki-intermediate*`, because a leaf-cert role has no business on a root or
  intermediate CA mount
* `name` - __required__ - the name of the role as it will exist in Vault
* `allowed_domains` - __required__ - the domain(s) the role may issue for

Everything else is optional:

* `allow_subdomains`, `allow_glob_domains`, `allow_any_name`, `enforce_hostnames`, `allow_ip_sans`, `server_flag`,
  `client_flag`
* `key_type`, `key_bits`
* `ttl`, `max_ttl` - durations as strings, e.g. `"168h"` or `"24h"`
* `generate_lease`, `require_cn` (defaults to `true`), `organization`, `ou`

## Guardrails

* `mount_path` must be an issuing CA mount - `pki-root*` and `pki-intermediate*` are rejected by the module's validation
  before a plan is generated
* Leave `allow_any_name` and `allow_glob_domains` off unless you genuinely need them; `allowed_domains` plus
  `allow_subdomains` is the tight configuration
* The ACL policy the platform team attaches to your workspace's own identity physically cannot reach outside your
  namespace - the guardrails here are defense-in-depth, not the security boundary

## How this folder is consumed

* Every `*.yaml` file under this folder (nested subfolders included) is decoded and merged into the `pki_roles` input of
  the TFE-registry-published `vault-platform-user` module (`vault-platform-user/vault`)
* A file ending in `.yml` is ignored - only `.yaml` files are read
* Each entry only needs the arguments it actually uses - entries in a folder do not have to match each other's shape.
  Any optional argument an entry omits takes the module's own default for that entry
* Removing an entry destroys the role it created on the next run. Certificates already issued under it are not revoked -
  revoke them from the issuing mount if you need them dead
* Committing to `main` triggers the workspace's run, and auto-apply means the role lands without a manual approval

## FAQ

* _How do I issue a certificate from this role?_
    * `vault write <mount_path>/issue/<name> common_name=app.my-app.internal ttl=24h`
* _Which TTL wins?_
    * The role's `ttl` is the default when the requester doesn't ask for one, and `max_ttl` is the ceiling - a request
      above `max_ttl` is clamped to it
* _Can I create the issuing CA from this folder?_
    * No - generating a root CA or configuring an intermediate is the platform team's territory (`pki-root` and
      `pki-intermediate` mounts exist for that purpose). Ask them to stand one up if your namespace doesn't have an
      issuing mount yet
* _Why does a role that looks right fail at request time?_
    * Common causes are a `common_name` outside `allowed_domains`, a requested TTL above `max_ttl`, or `require_cn`
      (defaults to `true`) rejecting a request with no common name
