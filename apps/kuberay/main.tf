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

# Create a Routable Service for the ALB ---
# The default service created by the Helm chart is "headless" (ClusterIP: None),
# which the AWS LBC cannot use as a backend. We create a new, standard ClusterIP
# service that targets the same Ray head pod.

resource "kubernetes_service" "ray_head_routable_svc" {
  depends_on = [helm_release.ray-cluster]

  metadata {
    name      = "ray-cluster-head-routable-svc"
    namespace = local.namespace
  }
  spec {
    # This selector is copied from the headless service to ensure it targets the same pod.
    selector = {
      "ray.io/cluster"    = "ray-cluster-kuberay"
      "ray.io/node-type"  = "head"
    }
    type = "ClusterIP"
    port {
      name        = "dashboard"
      port        = 8265
      target_port = 8265
      protocol    = "TCP"
    }
  }
}

# --- Create an Ingress to Route Traffic via the Shared ALB ---
resource "kubernetes_ingress_v1" "kuberay_ingress" {
  depends_on = [kubernetes_service.ray_head_routable_svc]

  metadata {
    name      = "kuberay-dashboard-ingress"
    namespace = local.namespace
    annotations = {
      "alb.ingress.kubernetes.io/group.name" = "shared-apps-group"
      "alb.ingress.kubernetes.io/scheme"     = "internet-facing"
      "alb.ingress.kubernetes.io/target-type" = "ip"
      "alb.ingress.kubernetes.io/rewrite-target" = "/"
      "alb.ingress.kubernetes.io/group.order"    = "10"
    }
  }

  spec {
    ingress_class_name = "alb"

    rule {
      http {
        path {
          path      = local.path
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.ray_head_routable_svc.metadata[0].name
              port { number = 8265 }
            }
          }
        }
      }
    }
  }
}