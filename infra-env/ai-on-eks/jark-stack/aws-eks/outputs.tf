output "cluster_name" {
  description = "The name of the EKS cluster."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "The endpoint for your EKS cluster's API server."
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster."
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_oidc_issuer_url" {
  description = "The OIDC issuer URL for the EKS cluster, used for IAM Roles for Service Accounts (IRSA)."
  value       = module.eks.cluster_oidc_issuer_url
}

output "oidc_provider_arn" {
  description = "The ARN of the OIDC provider for the EKS cluster."
  value       = module.eks.oidc_provider_arn
}

output "cluster_security_group_id" {
  description = "The ID of the EKS cluster's primary security group."
  value       = module.eks.cluster_security_group_id
}

output "cluster_exec_config" {
  description = "Configuration block for exec-based authentication. Used for generating a kubeconfig that uses the AWS IAM Authenticator."
  value = {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      module.eks.cluster_name
    ]
  }
  sensitive = true
}

output "configure_kubectl_command" {
  description = "Run this command to configure kubectl to connect to the new EKS cluster. Make sure you are logged in with the correct AWS profile."
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "eks_managed_node_group_instance_profile_name" {
  description = "The name of the IAM instance profile for the core node group."
  # The instance profile name is the same as the role name for managed node groups.
  value       = module.eks.eks_managed_node_groups["core_node_group"].iam_role_name
}

output "efs_csi_driver_irsa_role_arn" {
  description = "The ARN of the IAM role for the EFS CSI driver."
  value       = module.efs_csi_driver_irsa.iam_role_arn
}

output "aws_load_balancer_controller_irsa_role_arn" {
  description = "The ARN of the IAM role for the AWS Load Balancer Controller."
  value       = module.aws_load_balancer_controller_irsa.iam_role_arn
}