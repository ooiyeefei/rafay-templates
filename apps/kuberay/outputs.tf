output "kuberay_dashboard_url" {
  description = "The public URL to access the KubeRay dashboard."
  value       = "http://${data.external.shared_alb_info.result.hostname}${local.path}"
}

output "namespace" {
  description = "The unique namespace where this KubeRay instance was deployed."
  value       = local.namespace
}