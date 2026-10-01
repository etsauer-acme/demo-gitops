# Inventory Onboarding

## Introduction

This documentation will provide guidance for how to create inventories, and the hosts and groups inside them, inside
this repository's AAP organization (`IIM-Onboarding`) using this repository.

## Prerequisites

* __The hosts you declare are reachable from the AAP runner__
    * This repository declares objects only; connectivity is the runner's concern at job time

## Steps to Perform

1. Within this `inventories` folder, create a `<inventory-key>.yaml` file that'll define the
   inventory, its hosts and its groups
    * The top-level keys from every file in this folder are merged together, so each key must be unique across the
      whole folder
    * Host and group names are scoped per inventory - two inventories may each define a host called `app-01`

__For creating an inventory with hosts and a group:__
```yaml
my-inventory: # Must match the file name. Only identifies the inventory - job templates reference this key - its AAP name is `name`
    name: "my-inventory"
    description: "Hosts my application runs on"
    variables: "ansible_interpreter: /usr/bin/python3" # JSON or YAML dict syntax
    hosts:
        app-01:
            variables: "ansible_host=192.168.4.201"
        app-02:
            variables: "ansible_host=192.168.4.202"
        app-03-disabled:
            enabled: false # declared but unreachable by jobs
    groups:
        app:
            hosts:
                - "app-01" # must be hosts of this same inventory
                - "app-02"
```

## Required and optional arguments

At the inventory level:

* `name` - __required__ - the object's name in AAP
* `description` - __optional__
* `variables` - __optional__ - JSON or YAML dict syntax; ansible-style `k=v` strings are normalized to YAML for you
* `hosts` - __optional__, defaults to `{}` - map of host name to host settings
* `groups` - __optional__, defaults to `{}` - map of group name to group settings

Within a host:

* `enabled` - __optional__, defaults to `true` - set `false` to declare a host without letting jobs reach it
* `description` - __optional__
* `variables` - __optional__ - same syntax rules as inventory variables

Within a group:

* `hosts` - __optional__, defaults to `[]` - host names that must belong to this same inventory
* `description` - __optional__
* `variables` - __optional__

## Guardrails

* A group naming a host its own inventory does not define is refused at plan time, naming the host and the inventory
  - the provider would otherwise create a dangling reference
* Smart and constructed inventories are **not** supported: they are derived objects that AAP itself owns, and a
  declaration of one here would fight the platform for the same state
* There is no `organization` field anywhere in this repository - the organization is injected from the platform's
  onboarding

## How this folder is consumed

* Every `*.yaml` file under this folder (nested subfolders included) is decoded and merged into the `inventories`
  input of the TFE-registry-published `aap-platform-user` module (`aap-platform-user/aap`)
* A job template or schedule references an inventory by its key; the reference is checked at plan time
* Removing an entry destroys the inventory, its hosts and its groups on the next run; job templates referencing it
  are refused first, naming the missing key
* Committing to `main` triggers the workspace's run, and auto-apply means the inventory lands without a manual
  approval

## FAQ

* _Why did my `ansible_host=192.168.4.201` variables line cause an API error?_
    * AAP parses the `variables` fields as JSON or a YAML dict, not as an ansible-style `k=v` string. The module
      normalizes `k=v` pairs to YAML for you; a string that is already JSON/YAML dict syntax passes through
      untouched
* _How do I take a host out of service without deleting it?_
    * Set `enabled: false` on the host - it stays declared, jobs cannot reach it
* _Can two inventories have the same host name?_
    * Yes - host names are scoped per inventory. A group's host list always refers to its own inventory's hosts
