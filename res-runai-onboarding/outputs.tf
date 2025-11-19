# ============================================
# Run:AI Access Outputs
# ============================================

output "runai_control_plane_url" {
  value       = "https://${try(data.local_file.runai_control_plane_url.content, "")}"
  description = "Run:AI Control Plane login URL"
}

output "user_email" {
  value       = var.user_email
  description = "Run:AI user email (cluster-scoped Administrator)"
}

output "password" {
  value       = local.runai_user_password
  description = "Run:AI user password"
  sensitive   = true
}
