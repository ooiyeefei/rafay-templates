output "runai_cluster_url" {
  #value = "https://${var.runai_endpoint}"
  value= "https://${var.runai_cluster}-runai.${var.ingress_domain}"
}

output "runai_realm" {
  value = "https://${var.runai_endpoint}"
}

output "runai_username" {
  value = "${var.username}"
}