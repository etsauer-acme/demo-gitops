# Team Onboarding

## Introduction

This documentation will provide guidance for how to create AAP teams, and assign roles to them, inside this repository's
own AAP organization using this repository.

## Prerequisites

* __The objects you want to scope a role to already exist__
    * Declared in this repository's `inventories/`, `projects/` or `credentials/` folders - a role is checked against
      those keys at plan time
* __Role names follow AAP's role-definition names__
    * AAP's role definitions carry full names such as `JobTemplate Execute`, `Inventory Use`, `Project Use`,
      `Credential Admin` and `Organization Execute`. Bare short names (`Execute`, `Use`, `Admin`) do not resolve

## Steps to Perform

1. Within this `teams` folder, create a `<team-key>.yaml` file that'll define the team and the
   roles it holds
    * The top-level keys from every file in this folder are merged together, so each key must be unique across the
      whole folder

__For creating a team with an organization-scoped role:__
```yaml
platform-eng: # Must match the file name. Only identifies the team - its AAP name is `name`
    name: "platform-eng"
    description: "Runs the deployment job templates"
    roles:
        Organization Execute: "organization" # org-scoped execute role
```

__For creating a team with object-scoped roles:__
```yaml
deployers:
    name: "deployers"
    roles:
        JobTemplate Execute: "deploy-my-app" # role name -> a key from the matching folder
        Inventory Use: "my-inventory"
        Project Use: "my-app"
        Credential Admin: "machine-lab"
```

## Required and optional arguments

* `name` - __required__ - the object's name in AAP
* `description` - __optional__
* `roles` - __optional__, defaults to `{}` - map of AAP role-definition name to the object the role is scoped to:
  `"organization"`, or a key from `inventories/`, `projects/` or `credentials/`

## Guardrails

* Roles are scoped **inside your organization only**. A role name that would reach outside it (a platform-wide role,
  or another organization's object) is refused with the name in the error - this module cannot grant what the
  organization itself does not own
* A role scoped to an object key that no folder declares is refused at plan time, naming the key
* Org-scoped and object-scoped role definitions are distinct: `Organization Execute` is the organization-scoped
  execute role, `JobTemplate Execute` is scoped to a job template. Using the wrong one fails the API call with the
  mismatch in the message
* User creation is deliberately out of scope: identities come from the platform's onboarding, and this repository
  assigns roles to teams, not to people

## How this folder is consumed

* Every `*.yaml` file under this folder (nested subfolders included) is decoded and merged into the `teams` input of
  the TFE-registry-published `aap-platform-user` module (`aap-platform-user/aap`)
* Role definitions are looked up by name against the live AAP install at run time - their numeric ids are
  per-install and never hard-coded
* Removing an entry destroys the team on the next run; a role entry removal removes that role assignment only
* Committing to `main` triggers the workspace's run, and auto-apply means the team lands without a manual approval

## FAQ

* _Why did my `Execute: "organization"` role fail?_
    * `Execute` alone does not resolve, and `JobTemplate Execute` is object-scoped - an organization-scoped execute
      role is `Organization Execute`. Check the full role-definition name
* _How do I give a team access to everything in the organization?_
    * Use the `Organization *` role definitions (e.g. `Organization Execute`, `Organization Admin`) scoped to
      `"organization"` - deliberately broad grants are still organization-scoped
* _How do I add people to the team?_
    * Through the platform's identity onboarding, not this repository - user management lives with the platform team
