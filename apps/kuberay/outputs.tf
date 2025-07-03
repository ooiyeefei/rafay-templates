output "load_balancer_hostname" {
  description = "The publicly accessible hostname of the KubeRay dashboard Load Balancer."
  value       = data.external.load_balancer_info.result.hostname
}

output "kuberay_dashboard_url" {
  description = "The full URL to access the KubeRay dashboard."
  value       = "http://${data.external.load_balancer_info.result.hostname}"
}