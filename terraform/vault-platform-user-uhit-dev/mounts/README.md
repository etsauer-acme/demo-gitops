# Secret Engine Mount Onboarding

## Introduction

This documentation will provide guidance for how to create new secret engine mounts inside your APM's own Vault namespace
using this repository, in addition to the KV mount your namespace is created with.

## Prerequisites

* __The engine type you want is one the module's allow-list permits__
    * `allowed_engine_types` defaults to `["kv"]`, so as shipped this folder can only create KV mounts. If you need
      another engine type, that's a change the platform team makes to the module - ask them rather than trying to force
      it here

## Steps to Perform

1. Within this `mounts` folder, create a `<name_you_want_for_the_mount>.yaml` file that'll define the configuration of
   the mount you want to create
    * Below are examples of how you'd configure the yaml file to create mounts
    * The file name is only for your own organization - the top-level key is a label for the entry, and `path` is the
      mount's actual path in Vault
    * The top-level keys from every file in this folder are merged together, so each entry name must be unique across the
      whole folder

__For creating a second KV version 2 mount:__
```yaml
my-app-kv2: # The name you want for this entry
    path: my-app-kv2 # The mount's path in Vault - where you'd address it as my-app-kv2/data/...
    type: kv # The engine type - must be one of allowed_engine_types, which is kv only by default
    description: "Extra KVv2 mount for my-app, separate from the fixed secret/ mount" # Optional
    options: {
        version: "2"
    } # For a KV mount, version "2" is what makes it KVv2 - omit it and you get KVv1
```

__For creating a KV version 1 mount:__
```yaml
my-app-kv1:
    path: my-app-kv1
    type: kv
    description: "KVv1 mount for tooling that can't speak the KVv2 API"
    options: {
        version: "1"
    }
```

## Required and optional arguments

* `path` - __required__ - the mount's path in Vault. It must not target `sys/` or `auth/`, and must not start with `/`
* `type` - __required__ - the engine type. It must be one of `allowed_engine_types`, which is `["kv"]` by default

Optional:

* `description`
* `options` - a map of engine-specific options, e.g. `version: "2"` for KVv2

## Guardrails

* `type` must be in `allowed_engine_types` (KV only by default), and `path` must not overlap `sys/`, `auth/`, or the
  platform team's reserved paths - the module's validation rejects the file before a plan is generated
* The ACL policy the platform team attaches to your workspace's own identity physically cannot reach outside your
  namespace - the guardrails here are defense-in-depth, not the security boundary

## How this folder is consumed

* Every `*.yaml` file under this folder (nested subfolders included) is decoded and merged into the `mounts` input of the
  TFE-registry-published `vault-platform-user` module (`vault-platform-user/vault`)
* A file ending in `.yml` is ignored - only `.yaml` files are read
* Each entry only needs the arguments it actually uses - entries in a folder do not have to match each other's shape.
  Any optional argument an entry omits takes the module's own default for that entry
* Removing an entry **destroys the mount and everything stored in it** - this is the one folder where a config deletion
  is irreversible without a restore, so double-check before removing an entry
* Committing to `main` triggers the workspace's run, and auto-apply means the mount lands without a manual approval

## FAQ

* _Why is a KV mount created with the wrong version?_
    * Because KV defaults to version 1 unless you pass `options: { version: "2" }`. If you want KVv2 semantics (versioned
      secrets, metadata, soft deletes), set it explicitly
* _Can I create a mount for another engine type, e.g. transit or database?_
    * Not as shipped - `allowed_engine_types` is `["kv"]`. The platform team can widen it for your namespace, and
      widening it is a change to the module rather than to this folder
* _Can I point a mount at `sys/` or `auth/`?_
    * No - both are rejected by validation, deliberately
* _How do I write secrets into a mount I created here?_
    * Not from the `kv` folder, which is fixed to the original `secret/` mount. Use the Vault CLI/API directly for a
      secondary mount, or ask the platform team whether the module should manage it
* _What about access to a mount I created here?_
    * A mount on its own grants nobody access - write a policy for its paths in the `policies` folder. Note that the
      default `allowed_mount_prefixes` only covers the `secret/` mount's paths, so a secondary mount's paths need the
      platform team to widen that allow-list as well
