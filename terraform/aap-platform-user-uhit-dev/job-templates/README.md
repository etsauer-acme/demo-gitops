# Job Template Onboarding

## Introduction

This documentation will provide guidance for how to create job templates inside this repository's AAP organization (`IIM-Onboarding`)
using this repository. A job template is the runnable unit: it binds a project's playbook to an inventory,
credentials, and - if it needs secrets - its own Vault identity.

## Prerequisites

* __The project the job template runs from already exists__
    * Declared in this repository's `projects/` folder. AAP validates the playbook against the project's checkout, so
      a job template pointing at an un-synced project fails with `Playbook not found for project.` - check the
      project's sync status first
* __The playbook the job template names already exists__
    * Under `job-templates/playbooks/`, at the path this folder's `playbook` field gives (relative to the repository)
* __Any referenced inventory, credentials and survey already exist__
    * Declared in `inventories/`, `credentials/` and `job-templates/surveys/` respectively - the module refuses a
      reference that nothing declares, naming the field and the folder
* __The Vault address is already known to the platform__
    * Set at onboarding; a job template's Vault identity uses it. Nothing for you to configure

## Steps to Perform

1. Within this `job-templates` folder, create a `<template-key>.yaml` file that'll define the
   configuration of the job template you want to create
    * The top-level keys from every file in this folder are merged together, so each key must be unique across the
      whole folder

__For creating a plain job template (no secrets access):__
```yaml
deploy-my-app: # Must match the file name. Only identifies the template - schedules and notifications reference this key - its AAP name is `name`
    name: "deploy-my-app"
    description: "Deploy my-app to the lab"
    job_type: "run" # run | check
    project: "my-app" # a key from projects/
    playbook: "job-templates/playbooks/deploy.yml" # path relative to the repository
    inventory: "my-inventory" # a key from inventories/
    credentials:
        - "machine-lab" # keys from credentials/
    forks: 5
    timeout: 600
```

__For creating a job template that reads secrets - its own Vault identity:__
```yaml
deploy-with-secrets:
    name: "deploy-with-secrets"
    job_type: "run"
    project: "my-app"
    playbook: "job-templates/playbooks/deploy.yml"
    inventory: "my-inventory"
    vault_identity: # enabled by default; opt out with enabled: false
        secret_paths:
            - "secret/data/my-app/*" # Vault paths the job may read - the platform builds the policy
        secret_id_ttl: 0 # 0 = the durable default; a run_on_commit template must set a positive ttl
```

The platform creates one AppRole and one Vault policy **per job template**, named `aap-<key>` in your namespace. You
never name a policy yourself: naming one could overwrite a policy you do not own, so the module builds the policy
from your `secret_paths` and refuses to reuse an existing policy name. The role_id and SecretID are handed to AAP as
write-only credential inputs - they never enter this workspace's Terraform state.

__For creating a job template that logs in to hosts with a Vault-signed SSH certificate:__
```yaml
configure-hosts:
    name: "configure-hosts"
    job_type: "run"
    project: "my-app"
    playbook: "job-templates/playbooks/configure.yml"
    inventory: "my-inventory"
    vault_identity:
        ssh:
            role: "my-hosts" # a role on your namespace's ssh CA mount (vault tier repo: mounts/ + ssh-roles/)
            username: "ec2-user" # the login user; also the certificate's only principal
```

The platform attaches a `Machine` credential to the template whose certificate is not stored anywhere: at every
launch AAP asks Vault, with the template's own identity, to sign the credential's public key, and the job connects
with that short-lived certificate. The private half of the key sits in AAP and is useless on its own - the hosts
trust only certificates from your Vault SSH CA (`TrustedUserCAKeys` from `<namespace>/ssh/public_key`), and each
certificate lasts the role's `ttl`.

__For creating a run-on-commit job template (per-execution credential):__
```yaml
validate-on-commit:
    name: "validate-on-commit"
    job_type: "run"
    project: "my-app"
    playbook: "job-templates/playbooks/validate.yml"
    run_on_commit: true
    vault_identity:
        secret_paths:
            - "secret/data/my-app/validate/*"
        secret_id_ttl: 600 # required: the credential must die with the run
```

## Required and optional arguments

At the template level:

* `project` - __required__ - a key declared in `projects/`
* `playbook` - __required__ - path to the playbook, relative to the repository root
* `name` - __required__ - the object's name in AAP
* `description` - __optional__
* `job_type` - __optional__, defaults to `run` - must be `run` or `check`
* `inventory` - __optional__ - a key declared in `inventories/`
* `credentials` - __optional__, defaults to `[]` - keys declared in `credentials/`
* `execution_environment` - __optional__ - must be on the platform's allow-list; omit for the platform default
* `limit`, `forks`, `timeout`, `verbosity`, `allow_simultaneous`, `extra_vars` - __optional__ - passed through to AAP
* `survey` - __optional__ - a key declared in `job-templates/surveys/`
* `run_on_commit` - __optional__, defaults to `false` - see the rotation modes below

Within `vault_identity` (all optional, defaults shown):

* `enabled` - defaults to `true` - set `false` to declare a template with no Vault identity
* `backend` - defaults to `approle`
* `secret_paths` - defaults to `[]` - Vault path rules the job may read; required unless `ssh` is set
* `ssh` - __optional__ - `role` (required), `username` (required), `backend` (defaults to `ssh`) - a Vault-signed
  SSH `Machine` credential attached to the template, and `update` on `<backend>/sign/<role>` added to its policy
* `token_ttl` - defaults to `0` (the auth mount's default lease)
* `secret_id_ttl` - defaults to `0` (never expires); a `run_on_commit` template must set a positive value

## Guardrails

* `job_type` must be `run` or `check` - workflow job templates are a v2 concern, and a mislabelled one would silently
  create the wrong object
* `execution_environment` must be on the platform's allow-list - an EE outside the platform's images is not something
  a consumer repository can introduce
* A `project`, `inventory`, `credentials` entry or `survey` that is not declared in the matching folder is refused,
  with the field and the folder named in the error
* `vault_identity.enabled` with neither `secret_paths` nor `ssh` is refused - a role that can authenticate and then do
  nothing fails inside the job rather than at plan time, so the module refuses it before that
* `run_on_commit: true` requires a positive `secret_id_ttl` - a per-execution credential that never expires is a
  contradiction
* There is no `organization` field anywhere in this repository: the organization is injected from the platform's
  onboarding, and a module that accepted one could act on another

## How this folder is consumed

* Every `*.yaml` file under this folder (nested subfolders included) is decoded and merged into the `job_templates`
  input of the TFE-registry-published `aap-platform-user` module (`aap-platform-user/aap`) - except `.yml`, which is
  ignored, so the playbook files beside these declarations are not read as declarations
* The two rotation modes, decided by `run_on_commit`:

  | | `run_on_commit: false` (default) | `run_on_commit: true` |
  |---|---|---|
  | SecretID | durable - lives until rotated | per-execution - expires after `secret_id_ttl` |
  | Launched by | a click, a schedule, the API | the commit that declares it |
  | Runnable later by hand | yes | no - its credential expired minutes after the run |

* Removing an entry destroys the job template on the next run - schedules and notifications referencing it fail
  their own preconditions first, naming the missing key
* Committing to `main` triggers the workspace's run, and auto-apply means the change lands without a manual approval

## FAQ

* _How does this job template get secrets?_
    * List the Vault paths under `vault_identity.secret_paths`. The platform builds the policy, creates the AppRole,
      and hands AAP the credential write-only. The playbook reads the secrets at run time through the job template's
      own identity
* _Why can't I name an existing Vault policy instead?_
    * Naming one could overwrite a policy you do not own. The module builds a dedicated policy per template and
      refuses to reuse an existing policy name - one template, one policy, no shared blast radius
* _What happens if I remove an entry from a yaml file?_
    * The job template is destroyed on the next run, along with its Vault identity and credential. Schedules and
      notifications pointing at it are refused before that, so nothing dangles silently
* _How do I see whether my change applied?_
    * Watch the `aap-platform-user-iim` workspace's run in HCP Terraform - the plan shows exactly what will be
      created, changed, or destroyed
