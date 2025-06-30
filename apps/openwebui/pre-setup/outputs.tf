output "namespace" {
  description = "The dynamically generated namespace for this application instance."
  value       = local.namespace
}

output "deployment_suffix" {
  description = "The randomly generated suffix for this deployment instance, used for naming and versioning."
  value       = random_string.ns_suffix.result
}