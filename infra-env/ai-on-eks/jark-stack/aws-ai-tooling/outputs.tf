output "karpenter_helm_release_status" {
  description = "The deployment status of the Karpenter Helm release."
  value       = helm_release.karpenter.status
}

output "kuberay_operator_helm_release_status" {
  description = "The deployment status of the KubeRay Operator Helm release."
  value       = helm_release.kuberay_operator.status
}

output "karpenter_controller_iam_role_arn" {
  description = "The ARN of the IAM role created for the Karpenter controller."
  value       = aws_iam_role.karpenter_controller.arn
}