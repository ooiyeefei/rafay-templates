output "cluster_name" {
  description = "The name of the EKS cluster."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "The endpoint for the EKS cluster's API server."
  value       = module.eks.cluster_endpoint
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

output "configure_kubectl" {
  description = "A command to configure kubectl to connect to the new EKS cluster."
  value       = module.eks.configure_kubectl
}