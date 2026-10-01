# Project Onboarding

## Introduction

This documentation will provide guidance for how to create SCM-backed projects inside this repository's AAP organization (`IIM-Onboarding`)
using this repository. A project is how AAP gets the playbooks a job template runs; on this install AAP refuses
manual project uploads, so **every job template needs a project here**.

## Prerequisites

* __The repository the project clones already exists, and AAP can authenticate to it__
    * For repositories the platform owns, use `scm_credential: "platform"` - see below
    * For repositories you own, declare a `Source Control` credential in `credentials/` first, and use the SSH form
      of `scm_url` that the credential's key was issued for. The AAP runner does not trust the lab's internal CA, so
      the platform credential is an SSH deploy key - use the SSH form
* __The branch you name exists in that repository__

## Steps to Perform

1. Within this `projects` folder, create a `<project-key>.yaml` file that'll define the
   configuration of the project you want to create
    * The top-level keys from every file in this folder are merged together, so each key must be unique across the
      whole folder

__For a project inside a repository the platform owns (this repository itself):__
```yaml
my-app: # Must match the file name. Only identifies the project - job templates reference this key - its AAP name is `name`
    name: "my-app"
    description: "Playbooks for my-app"
    scm_type: "git"
    scm_url: "git@github.com:zisom-hc/terraform-aap-platform-user-iim.git"
    scm_branch: "main"
    scm_credential: "platform" # the platform-managed credential
```

__For a project in a repository you own:__
```yaml
some-other-repo:
    name: "some-other-repo"
    scm_type: "git"
    scm_url: "git@github.com:my-org/some-other-repo.git"
    scm_branch: "main"
    scm_credential: "vendor-key" # a credential you declared in credentials/
```

## Required and optional arguments

* `scm_url` - __required__ - the clone URL. Use the SSH form; the platform credential is a deploy key, so `https` fails on the
  internal CA
* `name` - __required__ - the object's name in AAP
* `description` - __optional__
* `scm_type` - __optional__, defaults to `git`
* `scm_branch` - __optional__, defaults to `main`
* `scm_update_on_launch` - __optional__, defaults to `true`
* `scm_update_cache_timeout` - __optional__
* `scm_clean` - __optional__, defaults to `false`
* `allow_override` - __optional__, defaults to `false` - allows a launch to override the branch
* `scm_credential` - __optional__ - `"platform"` (the platform-managed credential) or a key from `credentials/`
* `timeout` - __optional__, defaults to `0`

## Guardrails

* `scm_credential: "platform"` is the only way to clone repositories the platform owns. That credential holds the
  read-only deploy key the platform minted on the GitLab project; you cannot declare an equivalent yourself, because
  adding a deploy key needs write access to the repository and a key committed here would be a key in git history.
  The platform hands its credential's id to your workspace as `aap_platform_scm_credential_id` - never set that
  variable by hand
* A project that cannot authenticate does not merely fail to update - AAP refuses every job template declared beside
  it with `Playbook not found for project.`, because the playbook is validated against the project's checkout. If a
  job template will not create, look at the project's sync status first

## How this folder is consumed

* Every `*.yaml` file under this folder (nested subfolders included) is decoded and merged into the `projects` input
  of the TFE-registry-published `aap-platform-user` module (`aap-platform-user/aap`)
* The `platform` credential name is resolved at run time to the id the onboarding tier passed to your workspace - it
  is not a credential declared in `credentials/`, and nothing in `credentials/` can shadow it
* Removing an entry destroys the project on the next run; job templates referencing it are refused first, naming the
  missing key
* Committing to `main` triggers the workspace's run, and auto-apply means the project lands without a manual approval

## FAQ

* _Why does my job template fail with "Playbook not found for project."?_
    * The project could not sync, so its checkout has no playbook. Check the project's last update in AAP - the most
      common cause is an `https://` URL to the internal GitLab, which the runner cannot authenticate to
* _Can I point at a repository outside the lab?_
    * Yes, with a credential you declare in `credentials/` - the same rules apply: declare the credential, use the
      URL form it supports, and never commit the secret itself
* _Which branch do job templates run?_
    * The project's `scm_branch`, unless the project sets `allow_override: true` and the launch overrides it
