# Survey Onboarding

## Introduction

This documentation will provide guidance for how to create job-template survey specs inside this repository's own AAP
organization using this repository. A survey prompts the launcher for variables at launch time.

## Prerequisites

* __The job template that will carry the survey already exists__
    * Declared in this repository's `job-templates/` folder, referencing this survey by file name

## Steps to Perform

1. Within this `job-templates/surveys` folder, create a `<survey-key>.json` file that'll define the
   survey spec
    * The file name (without `.json`) is the key a job template references in its `survey` field
2. Reference it from a job template:
    * In a `job-templates/*.yaml` file, set `survey: "<the file name without .json>"`

__For creating a survey with two questions:__
```json
{
  "name": "Deploy my-app",
  "description": "Choose what to deploy",
  "spec": [
    {
      "question_name": "Target version",
      "variable": "app_version",
      "type": "text",
      "question_description": "The application version to deploy",
      "required": true
    },
    {
      "question_name": "Deploy to production?",
      "variable": "production",
      "type": "multiplechoice",
      "choices": ["no", "yes"],
      "default": "no",
      "required": true
    }
  ]
}
```

## Required and optional arguments

At the survey level:

* `spec` - __required__ - the list of questions; AAP keeps only one survey per job template, and changing the
  questions replaces the whole spec
* `name` - __required__ - the survey's name in AAP
* `description` - __optional__

Within each question in `spec`:

* `question_name` - __required__ - the label shown to the launcher
* `variable` - __required__ - the variable the answer is assigned to
* `type` - __required__ - e.g. `text`, `multiplechoice`, `integer`
* `question_description` - __optional__, defaults to `""` - the AAP API requires the attribute, so the module
  supplies an empty default rather than failing the plan
* `choices` - __optional__ - for `multiplechoice` / `multiselect` types
* `default` - __optional__
* `min` / `max` - __optional__ - for numeric types
* `required` - __optional__, defaults to `false`

## Guardrails

* A job template's `survey` field must name a file in this folder - an unmatched reference is refused at plan time,
  naming the survey
* JSON rather than YAML, because that is the shape the AAP API and its own survey documentation use - a spec copied
  out of the AAP UI pastes in here unchanged
* Secrets as survey answers are the one sanctioned way a launch supplies a secret value directly - it lives only in
  the launch, not in this repository

## How this folder is consumed

* Every `*.json` file under this folder (nested subfolders included) is read into the `job_template_surveys` input
  of the TFE-registry-published `aap-platform-user` module (`aap-platform-user/aap`), keyed by file name
* The survey spec is applied to the job template in the same run that creates the template - a survey without its
  job template cannot exist here
* Removing a file destroys the survey on the next run; the job template referencing it is refused first, naming the
  missing survey
* Committing to `main` triggers the workspace's run, and auto-apply means the survey lands without a manual approval

## FAQ

* _Where do I find the valid question types?_
    * AAP's survey documentation - the `type` strings pass through unchanged, so anything AAP's own editor offers
      works here
* _Why is `question_description` required?_
    * It is required by the AAP provider's schema, not by you - the module defaults it to an empty string so a
      question without a description plans cleanly
* _Can two job templates share one survey?_
    * Yes - both reference the same file name; each gets its own copy of the spec applied
