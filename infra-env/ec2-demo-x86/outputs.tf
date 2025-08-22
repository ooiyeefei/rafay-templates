# ------------------------------------------------------------------------------
# Outputs
# ------------------------------------------------------------------------------

output "instance_ids" {
  value       = aws_instance.main[*].id
  description = "A list of the IDs of the created EC2 instances."
}

output "instance_public_ips" {
  value       = aws_instance.main[*].public_ip
  description = "A list of the Public IP addresses of the EC2 instances."
}

output "ssh_private_key_filename" {
  value       = local_file.private_key.filename
  description = "The filename of the generated SSH private key ('cpu-host-keypair.pem')."
}

output "ssh_connection_command_first_instance" {
  value       = "ssh -i ${local_file.private_key.filename} ubuntu@${aws_instance.main[0].public_ip}"
  description = "Command to SSH into the first instance using the generated private key."
}

output "ssm_session_manager_command_first_instance" {
  value       = "aws ssm start-session --target ${aws_instance.main[0].id}"
  description = "MORE SECURE: Command to connect to the first instance using SSM Session Manager (no SSH key or open port needed)."
}