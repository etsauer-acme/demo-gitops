# Notification Onboarding

## Introduction

This documentation will provide guidance for how to create notification templates, and wire them to job-template
events, inside this repository's AAP organization (`IIM-Onboarding`) using this repository.

## Prerequisites

* __The job templates whose events you want to wire already exist__
    * Declared in this repository's `job-templates/` folder - the event wiring references those keys and is refused
      at plan time if nothing declares them
* __The endpoint the notification posts to exists and is reachable from AAP__

## Steps to Perform

1. Within this `job-templates/notifications` folder, create a `<notification-key>.yaml` file that'll
   define the notification template and the events it fires on
    * The top-level keys from every file in this folder are merged together, so each key must be unique across the
      whole folder

__For creating a webhook notification wired to a job template:__
```yaml
deploy-webhook: # Must match the file name. Only identifies the notification template - its AAP name is `name`
    name: "deploy-webhook"
    description: "Posts deploy outcomes to the lab hooks endpoint"
    notification_type: "webhook"
    url: "https://hooks.example.com/aap"
    configuration:
        http_method: "POST"
    events:
        deploy-my-app: # a key from job-templates/
            started: false
            success: true
            error: true
```

## Required and optional arguments

* `notification_type` - __required__ - e.g. `webhook`
* `url` - __optional__ - lifted to the top level because nearly every type needs it; the rest goes in
  `configuration`
* `name` - __required__ - the object's name in AAP
* `description` - __optional__
* `configuration` - __optional__, defaults to `{}` - the type-specific configuration. For a `webhook`, the platform
  supplies an empty `headers` object automatically if you do not bring your own (the AAP API requires it)
* `events` - __optional__, defaults to `{}` - map of job-template key to the events it fires on

Within an event entry:

* `started`, `success`, `error` - __optional__, each defaults to `false`

## Guardrails

* The event wiring is part of this declaration rather than a second step in the UI: a notification template that
  nothing is attached to notifies nobody, and that is a silent failure worth designing out
* An `events` entry naming a job template that `job-templates/` does not declare is refused at plan time, naming the
  key
* Anything secret in `configuration` - a token, an authorization header - comes from your Vault namespace at run
  time, not from this file. AAP never returns those values, so a value written here would be unverifiable as well
  as exposed

## How this folder is consumed

* Every `*.yaml` file under this folder (nested subfolders included) is decoded and merged into the `notifications`
  input of the TFE-registry-published `aap-platform-user` module (`aap-platform-user/aap`)
* The event links are created as part of the same run as the notification template - a link needs both a
  notification template id and a job template id, and only the module holds both
* Removing an entry destroys the notification template and its event wiring on the next run; the job templates it
  referenced are untouched
* Committing to `main` triggers the workspace's run, and auto-apply means the notification lands without a manual
  approval

## FAQ

* _Why did my webhook fail with "Configuration field 'headers' incorrect type"?_
    * The AAP API requires a `headers` object in webhook configuration. The platform supplies an empty one when your
      declaration does not bring its own - if you set `headers` yourself, it must be an object, not a string
* _Can one notification serve several job templates?_
    * Yes - add more keys under `events`, one per job template
* _Where does the webhook's auth token go?_
    * In Vault, read by the receiving endpoint or injected by the platform - not in this file
