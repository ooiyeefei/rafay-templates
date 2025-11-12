output "clusterUUID" {
  value = data.local_file.cluster-uuid.content
}

output "tempPassword" {
  value = data.local_file.user-password.content
}
