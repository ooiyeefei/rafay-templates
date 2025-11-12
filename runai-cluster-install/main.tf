resource "local_file" "ingress_spec" {
  content = templatefile("${path.module}/templates/test-ingress.tftpl", {
    cluster_name   = "${var.runai_cluster}"
    ingress_domain         = "${var.ingress_domain}"
  })
  filename        = "test-ingress.yaml"
  file_permission = "0644"
}

resource "rafay_access_apikey" "sampleuser" {
  user_name = var.username
}

resource "null_resource" "get_ingress_ip" {
  triggers = {
    always_run = "${timestamp()}"
  }
  provisioner "local-exec" {
    command     = "./get-ingress-ip.sh"
    environment = {
      CLUSTER_NAME= var.cluster
      RAFAY_REST_ENDPOINT= "${var.rafay_rest_endpoint}"
      RAFAY_API_KEY="${rafay_access_apikey.sampleuser.apikey}"
      PROJECT="${var.project}"
    }
  }
}

data "local_file" "ingress_ip" {
  filename = "ingress-ip"
  depends_on = [null_resource.get_ingress_ip]
}

provider "aws" {
  region  = "us-west-2"
}

resource "aws_route53_record" "ingress" {
  zone_id = var.route53_zone_id
  name    = "${var.runai_cluster}-runai.${var.ingress_domain}"
  type    = "A"
  ttl     = 300
  records = [data.local_file.ingress_ip.content]
}

resource "null_resource" "apply_dummy_ingress" {
  /*triggers = {
    always_run = "${timestamp()}"
  }*/
  provisioner "local-exec" {
    command     = "./apply-ingress.sh"
    environment = {
      CLUSTER_NAME= var.cluster
      RAFAY_REST_ENDPOINT= "${var.rafay_rest_endpoint}"
      RAFAY_API_KEY="${rafay_access_apikey.sampleuser.apikey}"
      PROJECT="${var.project}"
    }
  }
  depends_on = [aws_route53_record.ingress]
}

/*provider "helm" {
  kubernetes {
    //config_path = "/home/terraform/app/scratch/job/terraform/runai-cluster-install/ztka-user-kubeconfig"
    config_paths = [
        app/scratch/job/terraform/runai-cluster-install/ztka-user-kubeconfig
      ]
  }
}*/

data "google_client_config" "current" {}

data "google_container_cluster" "gke" {
  name     = var.cluster
  location = var.location
  project = var.google_project
}

provider "helm" {
  kubernetes {
    host                   = "https://${data.google_container_cluster.gke.endpoint}"
    cluster_ca_certificate = base64decode("${data.google_container_cluster.gke.master_auth.0.cluster_ca_certificate}")
    token                  = data.google_client_config.current.access_token
    /*exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command = "gke-gcloud-auth-plugin"
    }*/
  }
}

resource "helm_release" "runai" {
  name       = "runai-cluster"
  repository = "https://runai.jfrog.io/artifactory/api/helm/op-charts-prod"
  chart      = "runai-cluster"
  version    = "2.17.50"
  create_namespace = false
  namespace  = "runai"
  wait       = true

  set {
    name  = "controlPlane.url"
    value = "${var.runai_endpoint}"
  }
  set {
    name  = "controlPlane.clientSecret"
    value = var.runai_client_secret
  }

  set {
    name  = "cluster.uid"
    value = var.runai_cluster_uid
  }
  set {
    name  = "cluster.url"
    value = "https://${var.runai_cluster}-runai.${var.ingress_domain}"
  }
  depends_on = [null_resource.get_ingress_ip,null_resource.apply_dummy_ingress]
}