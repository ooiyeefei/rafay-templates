# ------------------------------------------------------------------------------
# Outputs
# ------------------------------------------------------------------------------
output "instance_id" {
  value       = aws_instance.agent_host_instance.id
  description = "The ID of the EC2 instance."
}

output "instance_public_ip" {
  value       = aws_instance.agent_host_instance.public_ip
  description = "The Public IP address of the EC2 instance."
}

output "get_ssh_key_command" {
  value       = "aws ssm get-parameter --name ${aws_ssm_parameter.ssh_private_key.name} --with-decryption --query Parameter.Value --output text > ${local.key_name}.pem && chmod 400 ${local.key_name}.pem"
  description = "Command to download the SSH private key from SSM Parameter Store."
}

output "ssh_connection_command" {
  value       = "ssh -i ${local.key_name}.pem ${local.ssh_user}@${aws_instance.agent_host_instance.public_ip}"
  description = "Command to SSH into the instance after downloading the key."
}

output "ssm_session_manager_command" {
  value       = "aws ssm start-session --target ${aws_instance.agent_host_instance.id}"
  description = "MORE SECURE: Command to connect using SSM Session Manager (no SSH key or open port needed)."
}