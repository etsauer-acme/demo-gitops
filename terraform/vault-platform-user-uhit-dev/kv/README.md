# KV Secret Onboarding

## Introduction

This documentation will provide guidance for how to write key/value secret entries into your APM's own Vault namespace
using this repository.

## Prerequisites

* __The KV version 2 engine already exists at the `secret` path inside your namespace__
    * It is created for you when the platform team onboards your namespace, together with placeholder paths at
      `credentials`, `clusters`, and `approles`
    * The mount and the namespace are deliberately **not** settable from this folder - so a mistake here can never write
      into another mount or another namespace

## Steps to Perform

1. Within this `kv` folder, create a `<name_you_want_for_the_entry>.yaml` file that'll define the secret entries you want
   to write
    * Below are examples of how you'd configure the yaml file to write one entry, or several entries in one file
    * Every `*.yaml` file under this folder is read on the workspace's next run - nested subfolders included, so you can
      group entries by application
    * The top-level keys from every file in this folder are merged together, so each name you choose must be unique
      across the whole folder

__For writing a single secret entry:__
```yaml
my-app-config: # The name you want for this entry - a label you choose, it does not have to match the path
    path: my-app-config # The secret's path under the mount, i.e. secret/data/<path>
    data_json: '{"username": "svc-account", "password": "changeme"}' # The key/value pairs, written as a JSON string
```

__For writing several entries in a single file:__
```yaml
my-app-config:
    path: my-app-config
    data_json: '{"username": "svc-account", "password": "changeme"}'
my-app-api-key:
    path: api-keys/my-app # Paths can be nested - this one lands at secret/data/api-keys/my-app
    data_json: '{"api_key": "changeme", "rotation_days": 90}'
```

## Required and optional arguments

* `path` - __required__ - the secret's path within the fixed `secret/` mount. Must be relative: no leading `/` and no
  `..` segments
* `data_json` - __required__ - the secret's key/value pairs as a JSON string. It must be valid JSON, so wrap the value in
  single quotes in the yaml whenever it contains double quotes

There are no other arguments for this folder - `mount` and `namespace` are fixed by the platform team's onboarding of
your namespace.

## How this folder is consumed

* Every `*.yaml` file under this folder (nested subfolders included) is decoded and merged into the `kv_secrets` input of
  the TFE-registry-published `vault-platform-user` module (`vault-platform-user/vault`)
* Naming a file `<something>.yml` means it is ignored - only `.yaml` files are read
* Each entry only needs the arguments it actually uses - entries in a folder do not have to match each other's shape.
  Any optional argument an entry omits takes the module's own default for that entry
* An empty folder is fine - nothing is created or destroyed by leaving it empty
* Committing to `main` triggers the workspace's run, and auto-apply means the entries land without a manual approval

## FAQ

* _How do I rotate a secret value?_
    * Edit the `data_json` value in the yaml file and commit - the new value is written on the next run
* _What happens if I remove an entry from a yaml file?_
    * The secret that entry created is destroyed on the next run - deleting from this folder is a delete operation in
      Vault, not just a config removal
* _Are the values in this folder actually secret?_
    * No. They are plain text in the git repository and in the workspace's Terraform state, so treat both as sensitive
      material. Don't commit anything you wouldn't want readable by everyone with access to this repository and to the
      workspace state
* _Can I create a second KV mount?_
    * Not from this folder - the mount is fixed at `secret`. An additional mount comes from the `mounts` folder, which is
      limited to KV engines by default
* _What happened to the `credentials`, `clusters`, and `approles` paths that were already there?_
    * Those were seeded by the platform team when your namespace was onboarded and carry placeholder values. There is
      nothing stopping you from overwriting them from this folder, but coordinate with your team first - they may already
      be relied on
