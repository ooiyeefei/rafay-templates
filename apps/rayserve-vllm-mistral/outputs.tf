output "namespace" {
  description = "The Kubernetes namespace where the RayService is deployed."
  value       = kubernetes_namespace.this.metadata[0].name
}

output "rayservice_name" {
  description = "The name of the deployed RayService."
  value       = kubernetes_manifest.ray_service.manifest.metadata.name
}

output "hugging_face_secret_name" {
  description = "The name of the Kubernetes secret storing the Hugging Face token."
  value       = kubernetes_secret.hf_token.metadata[0].name
}