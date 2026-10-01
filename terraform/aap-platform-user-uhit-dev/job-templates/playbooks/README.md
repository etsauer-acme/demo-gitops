# Playbook Onboarding

## Introduction

This documentation will provide guidance for the Ansible content your job templates run, stored under this
`job-templates/playbooks` folder. This directory is the reason the repository is its own SCM project: the playbook a
job template names in `playbook` is resolved here, at the commit that launched it.

Unlike every other folder in this repository, nothing here is Terraform-managed - these are your playbooks, plain
Ansible files, and the only contract is the path a job template names.

## Prerequisites

* __The collections a playbook imports are present in the execution environment__
    * The platform's default EE carries `ansible.posix`, `community.general` and the certified `hashicorp.vault`. If
      your playbook needs more, say so when you request the job template - a missing collection surfaces as a task
      failure in the job output, not as a plan error here

## Steps to Perform

1. Add the playbook under this folder, e.g. `job-templates/playbooks/deploy.yml`
2. Point a job template at it - the `playbook` field is relative to the repository root:

__For referencing a playbook from a job template:__
```yaml
deploy-my-app: # in job-templates/
    name: "deploy-my-app"
    project: "my-app"
    playbook: "job-templates/playbooks/deploy.yml" # path relative to the repository
    inventory: "my-inventory"
```

__Minimal playbook shape:__
```yaml
---
- name: Say hello
  hosts: all
  gather_facts: false
  tasks:
    - name: Say hello
      ansible.builtin.debug:
        msg: "hello from {{ inventory_hostname }}"
```

## Required and optional arguments

Not applicable - these are Ansible files, not declarations. The rules that bind are:

* The `playbook` field in `job-templates/` must match the path, relative to the repository root
* The project the job template runs from must have synced before the job template is created - AAP validates the
  playbook against the project's checkout, so an unsynced project fails with `Playbook not found for project.`

## Guardrails

* **Use the certified `hashicorp.vault` collection** (`ansible-collections/hashicorp.vault`) for anything that
  talks to Vault. It is the supported collection for this platform; the community collection is not installed in
  the execution environments, and a playbook depending on it fails at run time, not at apply time
* **Do not fetch secrets from Vault in the playbook when the platform can inject them instead.** A job template's
  Vault credential is resolved *before* the playbook starts, so the playbook can read the value as a normal
  variable. That is the supported path, and it keeps the credential's life to the run that minted it
* A playbook that outgrows one file can be split into a subdirectory under `job-templates/playbooks/` - keep the
  entry point at the top of its own subtree rather than importing across subtrees, so the template's `playbook`
  field stays meaningful when the subtree moves

## How this folder is consumed

* Nothing here is read by Terraform - this folder is excluded from the module's yaml filesets (`.yml` playbook files
  are not declarations)
* AAP clones this repository through the project's SCM credential and validates playbooks against the checkout at
  job-template creation and at sync
* Playbook changes take effect on the next job run - there is no Terraform run involved, and no state to drift
* Committing to `main` updates the repository AAP clones from; with `scm_update_on_launch` on the project (the
  default), the next launch pulls the new commit

## FAQ

* _Why does my job fail with "Playbook not found for project." when the file is right here?_
    * The project has not synced the commit yet, or it cannot clone at all - check the project's last update in AAP
      before looking at the playbook
* _Why does my Vault lookup task fail while a job-template identity exists?_
    * The community Vault collection is not installed. Use the certified `hashicorp.vault` collection, or better,
    let the platform inject the value before the playbook starts
* _Where do playbook variables come from?_
    * Extra vars and survey answers at launch, inventory and host variables, and platform-injected secrets - the
      usual Ansible variable precedence applies
