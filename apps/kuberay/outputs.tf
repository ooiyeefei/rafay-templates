output "kuberay_dashboard_url" {
  description = "The public URL to access the KubeRay dashboard."
  # Combines the shared ALB's hostname with the unique path for this deployment.
  value       = "http://${var.shared_alb_hostname}${local.path}"
}

output "namespace" {
  description = "The unique namespace where this KubeRay instance was deployed."
  value       = local.namespace
}