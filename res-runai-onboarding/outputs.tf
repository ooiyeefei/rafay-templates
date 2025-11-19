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

output "password_note" {
  value       = "Temporary password is displayed in the script output logs. User can also reset password via Run:AI UI."
  description = "Password retrieval instructions"
}
