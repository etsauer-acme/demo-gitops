output "organization" {
  value = { name = aap_organization.this.name, id = aap_organization.this.id }
}

output "inventory_ids" {
  value = module.aap_platform_user.inventory_ids
}

output "job_template_ids" {
  value = module.aap_platform_user.job_template_ids
}
