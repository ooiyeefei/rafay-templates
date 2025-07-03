# --- Dynamic Namespace Creation for the Application ---
resource "random_string" "instance_suffix" {
  length  = 5
  special = false
  upper   = false
}

locals {
  # Unique namespace for THIS KubeRay application instance.
  namespace = "kuberay-${random_string.instance_suffix.result}"
}

resource "kubernetes_namespace" "app_namespace" {
  metadata {
    name = local.namespace
  }
}

# --- Core Application Deployment via Helm ---
resource "helm_release" "ray-cluster" {
  depends_on = [kubernetes_namespace.app_namespace]
  name       = "ray-cluster"
  repository = "https://ray-project.github.io/kuberay-helm/"
  chart      = "ray-cluster"
  version    = var.kuberay_version
  namespace  = local.namespace

  values = [templatefile("${path.module}/templates/raycluster-values.yaml.tftpl", {
    head_config          = var.kuberay_head_config
    worker_config        = var.kuberay_worker_config
    worker_tolerations   = var.kuberay_worker_tolerations
    worker_node_selector = var.kuberay_worker_node_selector
  })]
}

# --- Template File Rendering for Load Balancer ---
resource "local_file" "load_balancer_yaml" {
  content = templatefile("${path.module}/lb.yaml.tpl", {
    namespace = local.namespace
  })
  filename = "${path.module}/kuberay-lb-${local.namespace}.yaml"
}

# --- Deploy the Load Balancer Service using Rafay Workload ---
resource "rafay_workload" "kuberay_load_balancer" {
  depends_on = [
    helm_release.ray-cluster,
    local_file.load_balancer_yaml
  ]

  metadata {
    name    = "kuberay-lb-${local.namespace}"
    project = var.project_name
  }
  spec {
    namespace = local.namespace
    placement {
      selector = "rafay.dev/clusterName=${var.cluster_name}"
    }
    version = "v-${random_string.instance_suffix.result}"
    artifact {
      type = "Yaml"
      artifact {
        paths {
          name = "file://${local_file.load_balancer_yaml.filename}"
        }
      }
    }
  }
}

# --- Kubeconfig and Hostname Retrieval (mirrored from openwebui) ---
resource "local_sensitive_file" "kubeconfig" {
  content = yamlencode({
    apiVersion      = "v1"
    kind            = "Config"
    current-context = "default"
    clusters = [{
      name = var.cluster_name
      cluster = {
        server                    = var.host
        certificate-authority-data = var.certificateauthoritydata
      }
    }]
    contexts = [{
      name = "default"
      context = {
        cluster = var.cluster_name
        user    = "default"
      }
    }]
    users = [{
      name = "default"
      user = {
        client-certificate-data = var.clientcertificatedata
        client-key-data         = var.clientkeydata
      }
    }]
  })
  filename = "/tmp/kubeconfig-${local.namespace}"
}

resource "time_sleep" "wait_for_lb_provisioning" {
  depends_on      = [rafay_workload.kuberay_load_balancer]
  create_duration = "90s"
}

data "external" "load_balancer_info" {
  depends_on = [
    time_sleep.wait_for_lb_provisioning,
    local_sensitive_file.kubeconfig
  ]

  program = ["bash", "${path.module}/get-lb-hostname.sh"]

  query = {
    kubeconfig_path = local_sensitive_file.kubeconfig.filename
    namespace       = local.namespace
    service_name    = "kuberay-dashboard-service"
  }
}