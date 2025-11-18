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
    cluster_issuer      = "Deployed via kubectl (${var.cluster_issuer_name})"
    runai_cluster       = "Deployed via Helm (${helm_release.runai_cluster.name})"
    runai_ingress       = "Deployed via kubectl (namespace: ${var.namespace})"
    access_url          = "https://${local.cluster_fqdn}"
  }
  description = "Deployment status summary"
}

output "kubeconfig_path" {
  value       = local_sensitive_file.kubeconfig.filename
  description = "Path to generated kubeconfig file"
  sensitive   = true
}

# ============================================
# Outputs for Run:AI Cluster Information
# ============================================

output "runai_cluster_uuid" {
  value       = try(data.local_file.runai_cluster_uuid.content, "")
  description = "Run:AI cluster UUID created in control plane"
}

output "runai_control_plane_url" {
  value       = try(data.local_file.runai_control_plane_url.content, "")
  description = "Run:AI control plane URL"
}

# ============================================
# Outputs for Run:AI User Credentials
# ============================================

output "runai_url" {
  value       = "https://${try(data.local_file.runai_control_plane_url.content, "")}"
  description = "Run:AI SaaS Control Plane login URL"
}

output "runai_project" {
  value       = var.project_name
  description = "Run:AI project name created for this cluster"
}

output "runai_user" {
  value       = try(data.local_file.runai_user_email.content, "")
  description = "Run:AI user email for cluster access"
}

output "runai_password" {
  value       = try(data.local_sensitive_file.runai_user_password.content, "")
  description = "Run:AI user password (temporary password if newly created, or 'existing-user-no-password-available' if user already existed)"
  sensitive   = true
}

output "user_access_info" {
  value = {
    login_url = "https://${try(data.local_file.runai_control_plane_url.content, "")}"
    username  = try(data.local_file.runai_user_email.content, "")
    project   = var.project_name
    scope     = "Project-scoped access (cannot see other clusters/projects)"
  }
  description = "Complete user access information"
}
