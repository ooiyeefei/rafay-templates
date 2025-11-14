# ============================================
# Output Values
# ============================================

output "cluster_fqdn" {
  value       = local.cluster_fqdn
  description = "Fully Qualified Domain Name for Run:AI cluster"
}

output "cluster_url" {
  value       = "https://${local.cluster_fqdn}"
  description = "Complete Run:AI cluster URL"
}

output "public_ip" {
  value       = local.public_ip
  description = "Public IP address used for DNS record"
}

output "dns_record_fqdn" {
  value       = aws_route53_record.runai_cluster.fqdn
  description = "Created DNS record FQDN"
}

output "tls_secret_name" {
  value       = local.tls_secret_name
  description = "Kubernetes secret name for TLS certificate"
}

output "runai_namespace" {
  value       = var.namespace
  description = "Kubernetes namespace where Run:AI is deployed"
}

output "node_hostname" {
  value       = local.first_node.hostname
  description = "Original hostname from node information"
}

output "dns_safe_hostname" {
  value       = local.dns_safe_hostname
  description = "DNS-safe version of hostname"
}

output "deployment_status" {
  value = {
    dns_created         = aws_route53_record.runai_cluster.fqdn
    cluster_issuer      = "Deployed via ${rafay_workload.cert_manager_issuer.metadata[0].name}"
    runai_cluster       = "Deployed via ${rafay_workload.runai_cluster.metadata[0].name}"
    runai_ingress       = "Deployed via ${rafay_workload.runai_ingress.metadata[0].name}"
    access_url          = "https://${local.cluster_fqdn}"
  }
  description = "Deployment status summary"
}

output "kubeconfig_path" {
  value       = local_sensitive_file.kubeconfig.filename
  description = "Path to generated kubeconfig file"
  sensitive   = true
}
