# Schedule Onboarding

## Introduction

This documentation will provide guidance for how to create scheduled launches of job templates inside this repository's own
AAP organization using this repository.

## Prerequisites

* __The job template you intend to schedule already exists__
    * Declared in this repository's `job-templates/` folder - a schedule for a job template the module does not own
      would outlive its own deletion, so the reference is refused at plan time
* __A valid RRULE for the recurrence you want__
    * AAP schedules use the iCalendar RRULE format, with a `DTSTART` and a recurrence rule

## Steps to Perform

1. Within this `job-templates/schedules` folder, create a `<schedule-key>.yaml` file that'll define
   the schedule you want to create
    * The top-level keys from every file in this folder are merged together, so each key must be unique across the
      whole folder

__For creating a daily launch:__
```yaml
nightly-deploy: # Must match the file name. Only identifies the schedule - its AAP name is `name`
    name: "nightly-deploy"
    description: "Nightly deploy of my-app"
    unified_job_template: "deploy-my-app" # a key from job-templates/
    rrule: "DTSTART:20260101T020000Z RRULE:FREQ=DAILY;INTERVAL=1"
    enabled: true
    inventory: "my-inventory" # optional; overrides the job template's own
    limit: "app-01" # optional
    extra_data:
        app_version: "latest"
```

## Required and optional arguments

* `unified_job_template` - __required__ - a key declared in `job-templates/`
* `rrule` - __required__ - the iCalendar recurrence rule
* `name` - __required__ - the object's name in AAP
* `description` - __optional__
* `enabled` - __optional__, defaults to `true`
* `inventory` - __optional__ - a key from `inventories/`, overriding the job template's own for this schedule
* `limit` - __optional__ - host limit for the launch
* `extra_data` - __optional__, defaults to `{}` - launch-time variables

## Guardrails

* A schedule cannot launch a job template this module does not own - it would outlive its own deletion
* A `run_on_commit` job template is startable from a schedule only while its credential is alive - which, by design,
  is not the case for a schedule that fires hours after the last commit. Scheduled work and run-on-commit are
  different intents; pick one per job template
* A referenced inventory key that no folder declares is refused at plan time

## How this folder is consumed

* Every `*.yaml` file under this folder (nested subfolders included) is decoded and merged into the `schedules`
  input of the TFE-registry-published `aap-platform-user` module (`aap-platform-user/aap`)
* The referenced job template key is resolved to its AAP id at run time; the job template's creation is ordered
  before the schedule that points at it
* Removing an entry destroys the schedule on the next run - the job template it launched is untouched
* Committing to `main` triggers the workspace's run, and auto-apply means the schedule lands without a manual
  approval

## FAQ

* _Where do I get an RRULE from?_
    * AAP's own schedule editor shows the RRULE it builds - copy it from there. The format is iCalendar's
      `DTSTART` + `RRULE`
* _Can a schedule pass survey answers?_
    * Through `extra_data`, keyed by the survey's variable names
* _Why does my schedule reference a `run_on_commit` template and fail to launch later?_
    * That template's credential expired by design. Scheduled work should use a durable (default) job template
