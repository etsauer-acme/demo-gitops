# Credential Onboarding

## Introduction

This documentation will provide guidance for how to create credential *objects* inside this repository's AAP organization (`IIM-Onboarding`)
using this repository. A credential object is the metadata and the wiring - **never a secret value**. The secret
itself is resolved from your Vault namespace at job-run time, or supplied per launch as a survey answer.

## Prerequisites

* __The credential type you intend to use is one the platform sanctions__
    * The sanctioned types today are `Source Control`, `Machine`, `HashiCorp Vault Secret Lookup` and
      `HashiCorp Vault Signed SSH`. A type outside that list is refused by name rather than created silently
* __Any secret the credential needs lives in your Vault namespace__
    * Committed values would be in git history forever, and this stack deliberately gives you a path that does not
      need them

## Steps to Perform

1. Within this `credentials` folder, create a `<credential-key>.yaml` file that'll define the
   configuration of the credential you want to create
    * The top-level keys from every file in this folder are merged together, so each key must be unique across the
      whole folder

__For creating a Vault lookup credential:__
```yaml
vault-lookup: # Must match the file name. Only identifies the credential - job templates reference this key - its AAP name is `name`
    name: "vault-lookup"
    description: "Reads secrets out of Vault"
    credential_type: "HashiCorp Vault Secret Lookup"
    inputs:
        url: "https://vault.example.com:8200"
```

__For creating a machine credential:__
```yaml
machine-lab:
    name: "machine-lab"
    credential_type: "Machine"
    inputs:
        username: "ansible"
```

## Required and optional arguments

* `credential_type` - __required__ - one of the sanctioned names above
* `name` - __required__ - the object's name in AAP
* `description` - __optional__
* `credential_type_kind` - __optional__, override only - the platform records the correct kind for each sanctioned
  name; supplying one by hand is how you get a lookup that finds nothing
* `credential_type_id` - __optional__, override only
* `inputs` - __optional__, defaults to `{}` - the credential's non-secret wiring, stored write-only

## Guardrails

* No secret values in this repository, ever. A value committed here is a value in git history forever; the secret
  comes from Vault at run time or from a survey answer at launch
* `credential_type` must be on the platform's allow-list - the refusal names the permitted types
* `inputs` are stored write-only: they are sent to AAP and do not enter this workspace's Terraform state. Changing
  them without changing the platform's `credential_version_seed` is a silent no-op - that is the one trap in the
  write-only mechanism, and the platform owns the seed
* You do not declare a Source Control credential to clone this repository: the platform creates one
  (`platform-scm`) holding the read-only deploy key AAP clones with - see `projects/`

## How this folder is consumed

* Every `*.yaml` file under this folder (nested subfolders included) is decoded and merged into the `credentials`
  input of the TFE-registry-published `aap-platform-user` module (`aap-platform-user/aap`)
* A job template references a credential by its key in its `credentials` list; the reference is checked at plan time
  and a missing key is refused by name
* Removing an entry destroys the credential on the next run; job templates referencing it are refused first
* Committing to `main` triggers the workspace's run, and auto-apply means the credential lands without a manual
  approval

## FAQ

* _Where do I put the password / key / token?_
    * Nowhere in this repository. Design the job to read it from Vault at run time through its own Vault identity,
      or take it as a survey answer at launch
* _What is the difference between the two Vault credential types?_
    * `HashiCorp Vault Secret Lookup` (kind `external`) reads secrets from Vault during a job; the type named plain
      `Vault` (kind `vault`) is a different AAP credential kind. The allow-list resolves the kind for you
* _Why did my credential change do nothing?_
    * Write-only inputs only re-send when the platform's `credential_version_seed` changes - the write-only
      mechanism cannot notice a content change on its own
