locals {
  project_files    = fileset(path.module, "projects/**/*.yaml")
  inventory_files  = fileset(path.module, "inventories/**/*.yaml")
  credential_files = fileset(path.module, "credentials/**/*.yaml")
  team_files       = fileset(path.module, "teams/**/*.yaml")
  job_template_files = setsubtract(
    fileset(path.module, "job-templates/**/*.yaml"),
    setunion(
      fileset(path.module, "job-templates/schedules/**/*.yaml"),
      fileset(path.module, "job-templates/notifications/**/*.yaml"),
    )
  )
  survey_files       = fileset(path.module, "job-templates/surveys/**/*.json")
  schedule_files     = fileset(path.module, "job-templates/schedules/**/*.yaml")
  notification_files = fileset(path.module, "job-templates/notifications/**/*.yaml")

  misnamed_files = [
    for f in setunion(local.project_files, local.inventory_files, local.credential_files, local.team_files, local.job_template_files, local.schedule_files, local.notification_files) :
    f if join(",", try(keys(yamldecode(file(f))), [])) != trimsuffix(basename(f), ".yaml")
  ]
}

module "aap_platform_user" {
  source  = "app.terraform.io/team-rts-fiserv/aap-platform-user/aap"
  version = "0.4.0"

  organization_name = aap_organization.this.name
  organization = {
    id         = aap_organization.this.id
    gateway_id = aap_organization.this.gateway_id
  }
  platform_scm_credential_id = tonumber(aap_credential.scm.id)

  projects      = merge([for f in local.project_files : yamldecode(file(f))]...)
  inventories   = merge([for f in local.inventory_files : yamldecode(file(f))]...)
  credentials   = merge([for f in local.credential_files : yamldecode(file(f))]...)
  teams         = merge([for f in local.team_files : yamldecode(file(f))]...)
  job_templates = merge([for f in local.job_template_files : yamldecode(file(f))]...)
  job_template_surveys = {
    for f in local.survey_files : trimsuffix(basename(f), ".json") => jsondecode(file(f))
  }
  schedules     = merge([for f in local.schedule_files : yamldecode(file(f))]...)
  notifications = merge([for f in local.notification_files : yamldecode(file(f))]...)
}

# The yaml key only identifies an entry and is never used as a name; it must match the file name so entries stay findable.
output "entry_keys_match_file_names" {
  value = true

  precondition {
    condition     = length(local.misnamed_files) == 0
    error_message = "Each yaml file must hold one entry whose key matches the file name. Mismatched: ${join(", ", local.misnamed_files)}."
  }
}
