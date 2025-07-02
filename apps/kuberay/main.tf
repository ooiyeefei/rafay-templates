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

resource "helm_release" "apply-volcano" {
  count = var.enable_volcano == "true" ? 1 : 0

  name       = "volcano"
  repository = "https://volcano-sh.github.io/helm-charts/"
  chart      = "volcano"
  version    = var.volcano_version
  namespace  = "volcano-system"
  create_namespace = true
}

resource "helm_release" "kuberay-operator" {
  depends_on = [
    kubernetes_namespace.app_namespace,
    helm_release.apply-volcano
  ]
  
  name       = "kuberay-operator"
  repository = "https://ray-project.github.io/kuberay-helm/"
  chart      = "kuberay-operator"
  version    = var.kuberay_version
  namespace  = local.namespace
  create_namespace = false

  values = [
    <<-EOF
    batchScheduler:
      enabled: ${var.enable_volcano}
    EOF
  ]
}

resource "helm_release" "ray-cluster" {
  depends_on = [helm_release.kuberay-operator]
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
    kubernetes_namespace.app_namespace,
    helm_release.ray-cluster
  ]

  metadata {
    name      = "kuberay-dashboard-ingress"
    namespace = local.namespace
    annotations = {
      "kubernetes.io/ingress.class"          = "alb"
      "alb.ingress.kubernetes.io/group.name" = "shared-apps-group"
      "alb.ingress.kubernetes.io/scheme" = "internet-facing"
      "alb.ingress.kubernetes.io/target-type" = "ip"
      "alb.ingress.kubernetes.io/rewrite-target" = "/"
      "alb.ingress.kubernetes.io/group.order"    = "10"
    }
  }

  spec {
    rule {
      http {
        path {
          # Route traffic based on the unique, dynamic path.
          path      = local.path
          path_type = "Prefix"
          backend {
            service {
              # This is the default service name from the KubeRay Helm chart.
              name = "ray-cluster-head-svc"
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