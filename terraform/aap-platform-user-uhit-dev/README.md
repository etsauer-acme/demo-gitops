# AAP Platform User - uhit-dev demo

## Introduction

This deployment root manages the Ansible Automation Platform side of the uhit-dev demo environment: one AAP
organization, `uhit-dev`, and everything inside it that a demo needs - projects, inventories, credentials, teams,
job templates. The playbooks job templates run live here too, so one commit carries both what runs and how it runs.

It was migrated from `zisom-hc/terraform-aap-platform-user-iim` (the IIM LinuxONE guest-onboarding variant) with all
IIM-specific objects removed: the `iim-guests` inventory, the `iim-onboarding` project, the `guest-baseline` job
template and playbook, and the registrar/SSH-handoff machinery in `platform.tf` are gone. The folder structure and
per-folder READMEs are unchanged.

## What this repository creates

| Object | Where | Purpose |
|---|---|---|
| Organization `uhit-dev` | `platform.tf` | Isolates this work from every other organization on the AAP |
| `platform-scm` credential | `platform.tf` | The read-only deploy key AAP clones this repository with |

Everything else is created by the folders below - each holds one object type, and its `README.md` documents the YAML
schema.

| Folder | Creates |
|---|---|
| `projects/` | SCM projects (the playbooks AAP clones) |
| `inventories/` | Inventories |
| `credentials/` | Credentials |
| `teams/` | Teams and their role assignments |
| `job-templates/` | Job templates |
| `job-templates/playbooks/` | The playbooks those templates run |
| `job-templates/surveys/` | Survey specs (`<template>.json`, name = template entry key) |
| `job-templates/schedules/` | Schedules attached to job templates |
| `job-templates/notifications/` | Notifications attached to job templates |

## Prerequisites

* __The workspace `aap-platform-user-uhit-dev` exists__ in the HCP Terraform org `team-rts-fiserv`, project
  `uhit-dev`, VCS-connected to `terraform/aap-platform-user-uhit-dev` in this repository, with auto-apply on.
* __The workspace has AAP credentials__ (`aap_address`, `aap_username`, `aap_password`) and `scm_deploy_key` set as
  Terraform variables. The deploy key's public half must be authorized as a read-only deploy key on this repository.
* __The workspace has Vault dynamic credentials enabled__ (`TFC_VAULT_PROVIDER_AUTH`, role
  `uhit-dev-workspace-identity-aap`): the pinned module mints Vault-backed credentials for job templates on the
  `uhit-dev-vault` cluster, in namespace `admin/uhit-dev`.

## Steps to Perform

1. Pick the folder that matches the AAP object you want to create and read its `README.md`.
2. Create a `<entry_key>.yaml` file in that folder defining the object (one entry per file; the key must match the
   file name).
3. Commit to `main`. The workspace auto-applies.

A job template that refers to a playbook in this repository uses a path relative to the repository root, e.g.
`terraform/aap-platform-user-uhit-dev/job-templates/playbooks/<name>.yml`; the project it belongs to must set
`scm_credential: "platform"` and clone this repository (SSH form).

## Guardrails

* A yaml file whose key does not match its file name fails the plan (`entry_keys_match_file_names` output precondition).
* The module only creates credential types listed in `allowed_credential_types`, and only execution environments
  listed in `allowed_execution_environments` (empty default = platform's own EE only).
* Job template names must match `^[A-Za-z0-9._-]+$` when they declare a `vault_identity` (the Vault policy and
  AppRole are derived as `aap-<name>`).

## How this repository is consumed

Every `*.yaml` file under each folder (nested subfolders included) is read on the workspace's next run and merged into
the corresponding input of the pinned `aap-platform-user/aap` module (currently **0.4.0** - the team-rts-fiserv
registry's s390x port, which carries all of the APM-pipeline module's logic through lab v0.9.1). A job template that
declares a `vault_identity` also needs `vault_addr` / `vault_namespace` set on the workspace
(`https://uhit-dev-vault-public-vault-a2bd04b8.3eda6ddb.z1.hashicorp.cloud:8200`, namespace `admin/uhit-dev`).

## FAQ

* __Rename an object?__ Add the new name field (or move the entry) and commit - the module recreates only what its
  resolved names changed. Renaming the entry key or file alone touches nothing in AAP.
* __Remove an object?__ Delete its yaml file - the next run destroys it. Anything still referencing it in AAP breaks,
  so remove the references first.
* __Where did the IIM objects go?__ Removed with this migration. The original lives at
  `zisom-hc/terraform-aap-platform-user-iim` (tagged `migrated-to-demo-gitops` at cutover).
