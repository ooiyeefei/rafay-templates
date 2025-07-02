# --- Dynamic Namespace Creation for the Application ---
resource "random_string" "instance_suffix" {
  length  = 5
  special = false
  upper   = false
}

locals {
  # Unique namespace for THIS KubeRay application instance.
  namespace = "kuberay-${random_string.instance_suffix.result}"
  path      = "/kuberay-${random_string.instance_suffix.result}"
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

# --- Create an Ingress to Route Traffic via the Shared ALB ---
resource "kubernetes_ingress_v1" "kuberay_ingress" {
  depends_on = [
    helm_release.ray-cluster
  ]

  metadata {
    name      = "kuberay-dashboard-ingress"
    namespace = local.namespace
    annotations = {
      "kubernetes.io.ingress.class" = "alb"
      "alb.ingress.kubernetes.io/group.name" = "shared-apps-group"
      "alb.ingress.kubernetes.io/scheme" = "internet-facing"
      "alb.ingress.kubernetes.io/target-type" = "ip"
      "alb.ingress.kubernetes.io/rewrite-target" = "/"
      "alb.ingress.kubernetes.io/group.order" = "10"
    }
  }

  spec {
    rule {
      http {
        path {
          path      = local.path
          path_type = "Prefix"
          backend {
            service {
              name = "ray-cluster-kuberay-head-svc"
              port {
                number = 8265
              }
            }
          }
        }
      }
    }
  }
}