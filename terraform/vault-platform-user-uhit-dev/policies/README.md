# ACL Policy Onboarding

## Introduction

This documentation will provide guidance for how to create ACL policies for paths inside your APM's own Vault namespace
using this repository.

## Prerequisites

* __The paths your policy refers to exist, or are about to be created from this repository__
    * A policy can be written before the secret it grants access to exists - the policy is just text until something
      reads it, so ordering between the `kv` and `policies` folders doesn't matter
* __The mount prefix you want to grant access under is one the module's allow-list permits__
    * `allowed_mount_prefixes` defaults to `["secret/data", "secret/metadata", "secret/delete", "secret/undelete",
      "secret/destroy"]`. If you need to grant access under a different mount, that's a change the platform team makes to
      the module - ask them

## Steps to Perform

1. Within this `policies` folder, create a `<name_you_want_for_the_policy>.yaml` file that'll define the configuration of
   the policy you want to create
    * Below are examples of how you'd configure the yaml file to create certain types of policies
    * The file name is only for your own organization - the required `name` field is the policy's name in Vault
    * The `name` values from every file in this folder must be unique across the whole folder

__For creating a read-only policy for one secret path:__
```yaml
my-app-read: # The entry label - also this file's name
    name: my-app-read # The policy's name in Vault
    rules: # A list of rules - each rule becomes one path block in the rendered policy
        - path_suffix: "my-app-config" # The path within the mount prefix
          capabilities: [
              "read",
              "list"
          ]
```

__For creating a policy with several rules over different subtrees:__
```yaml
my-app-manage:
    name: my-app-manage
    rules:
        - path_suffix: "my-app-config" # Renders as path "secret/data/my-app-config"
          capabilities: [
              "create",
              "read",
              "update",
              "delete"
          ]
        - path_suffix: "api-keys/*" # Renders as path "secret/data/api-keys/*"
          capabilities: [
              "read",
              "list"
          ]
        - mount_prefix: "secret/metadata" # Overrides the default mount prefix for this rule only
          path_suffix: "my-app-config" # Renders as path "secret/metadata/my-app-config"
          capabilities: [
              "read",
              "list",
              "delete"
          ]
```

## Required and optional arguments

At the policy level:

* `rules` - __required__ - a list of rules; each rule becomes one `path "<mount_prefix>/<path_suffix>"` block in the
  policy

Within each rule:

* `path_suffix` - __required__ - the path within the mount prefix. Must be relative: no leading `/` and no `..` segments
* `capabilities` - __required__ - a list of capabilities, e.g. `read`, `list`, `create`, `update`, `delete`, `patch`
* `mount_prefix` - __optional__, defaults to `secret/data` - must be one of `allowed_mount_prefixes`, which by default is
  `secret/data`, `secret/metadata`, `secret/delete`, `secret/undelete`, and `secret/destroy`

## Guardrails

* `capabilities` must not include `sudo` - the module's validation rejects the file before a plan is generated
* `mount_prefix` must be within `allowed_mount_prefixes`, and `path_suffix` must be relative with no `..` segments
* Policies are rendered from this declarative schema - the module doesn't accept raw HCL, so anything the schema can't
  express (e.g. `sys/*` paths, `sudo`) is deliberately out of reach here
* The ACL policy the platform team attaches to your workspace's own identity physically cannot reach outside your
  namespace - the guardrails here are defense-in-depth, not the security boundary

## How this folder is consumed

* Every `*.yaml` file under this folder (nested subfolders included) is decoded and merged into the `policies` input of
  the TFE-registry-published `vault-platform-user` module (`vault-platform-user/vault`)
* A file ending in `.yml` is ignored - only `.yaml` files are read
* `mount_prefix` is per rule, so a policy can freely mix rules that set it with rules that rely on the `secret/data`
  default - each rule is rendered with its own path
* Removing an entry destroys the policy it created on the next run - any role still referencing that policy name then
  carries a token whose policy no longer exists
* Committing to `main` triggers the workspace's run, and auto-apply means the policy lands without a manual approval

## FAQ

* _How do I attach this policy to something?_
    * List its name in the `token_policies` of a role in the `approles` or `jwt-roles` folders.
      Your namespace's baseline policy (`<your_apm>-kv-access`) is attached to your workspace's own identity by the
      platform team
* _Can I write a policy for an org-wide or root-namespace path?_
    * No - policies here are namespace-scoped and limited to the KV paths above. Org-wide and root-level policies live in
      the platform team's own repository
* _Which mount prefix should I use for a plain read of a secret?_
    * `secret/data` (the default). Use `secret/metadata` when you need list/version/delete operations on metadata, and
      `secret/delete` / `secret/undelete` / `secret/destroy` for soft-delete and permanent-destroy actions
* _Do wildcards work?_
    * Yes - in `path_suffix`, e.g. `my-app/*` or `*`. Grant them deliberately; a policy is what decides whether a token
      can read a secret, and a wildcard is the difference between an application reading its own path and reading every
      path in the namespace
