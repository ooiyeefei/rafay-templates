# File: main.tf (Corrected)

# --- Dynamic Namespace Creation for the Application ---
resource "random_string" "instance_suffix" {
  length  = 5
  special = false
  upper   = false
}

locals {
  # This is the unique namespace for THIS KubeRay application instance.
  namespace = "kuberay-${random_string.instance_suffix.result}"
}

resource "kubernetes_namespace" "app_namespace" {
  metadata {
    name = local.namespace
  }
}

# --- Cluster-Level Dependency: Volcano Scheduler ---
# It's best practice for a cluster-wide scheduler to have its own static namespace.
resource "kubernetes_namespace" "volcano_system" {
  metadata {
    name = "volcano-system"
  }
}

resource "helm_release" "apply-volcano" {
  count = var.enable_volcano == "true" ? 1 : 0

  name       = "volcano"
  repository = "https://volcano-sh.github.io/helm-charts/"
  chart      = "volcano"
  version    = var.volcano_version
  # Install into its own dedicated namespace.
  namespace  = "volcano-system"

  # Explicitly depend on its namespace being created first.
  depends_on = [kubernetes_namespace.volcano_system]
}


# --- Core Application Deployment via Helm ---

resource "helm_release" "kuberay-operator" {
  # This now depends on both the application namespace AND the volcano release.
  depends_on = [
    kubernetes_namespace.app_namespace,
    helm_release.apply-volcano
  ]
  name       = "kuberay-operator"
  repository = "https://ray-project.github.io/kuberay-helm/"
  chart      = "kuberay-operator"
  version    = var.kuberay_version
  # This component will be installed in the dynamic application namespace.
  namespace  = local.namespace

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
  depends_on = [helm_release.ray-cluster]

  metadata {
    name      = "kuberay-dashboard-ingress"
    namespace = local.namespace
    annotations = {
      "kubernetes.io/ingress.class"            = "alb"
      "alb.ingress.kubernetes.io/rewrite-target" = "/"
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