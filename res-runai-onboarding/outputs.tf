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
  value       = try(data.local_sensitive_file.runai_user_password.content, "Check script logs for password or use Run:AI UI to reset")
  description = "Run:AI user password (Run:AI generated temporary password - empty if user already existed)"
  sensitive   = true
}
