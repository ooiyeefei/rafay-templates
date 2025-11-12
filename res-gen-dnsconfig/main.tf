locals {
  create_dns_entry = var.ingress_domain_type == "Rafay" ? true : false
  ingress_cluster = var.host_cluster_name != "" ? var.host_cluster_name : var.cluster_name
}

resource "null_resource" "get_ingress_ip" {

  count = local.create_dns_entry ? 1 : 0
  triggers = {
    always_run = timestamp()
  }
  provisioner "local-exec" {
    command = "chmod +x ${path.module}/scripts/get-ingress-ip.sh && ${path.module}/scripts/get-ingress-ip.sh"
    environment = {
      CLUSTER_NAME = local.ingress_cluster
      PROJECT      = var.project
      CUSTOMER_INGRESS_IP = var.ingress_ip
      INGRESS_NAMESPACE = var.ingress_namespace
    }
  }
}

data "local_file" "ingress_ip" {
  count = local.create_dns_entry ? 1 : 0
  filename = "ingress-ip"
  depends_on = [null_resource.get_ingress_ip]
}

locals {
  ingressips = local.create_dns_entry ? split(",", data.local_file.ingress_ip[0].content) : []
}

resource "aws_route53_record" "jupyter" {
  count = local.create_dns_entry ? 1 : 0
  zone_id = var.route53_zone_id
  name    = "${var.sub_domain}"
  type    = "A"
  ttl     = 300
  records = local.ingressips
}