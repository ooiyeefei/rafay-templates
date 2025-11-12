variable "runai_endpoint" {}
variable "runai_client_secret" {}
variable "runai_cluster_uid" {}
variable "cluster" {}
variable "runai_cluster" {}

variable "ingress_domain" {
  default = "dev.rafay-edge.net"
}
variable "username" {}
variable "rafay_rest_endpoint" {
    default = "nvidia.rafay.dev"
}
variable "project" {}
variable "route53_zone_id" {
  default = "Z1OM749F0P8E4R"
}
variable "location" {}
variable "google_project" {}