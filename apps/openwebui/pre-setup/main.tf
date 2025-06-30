# --- Namespace and Identity Setup ---
resource "random_string" "ns_suffix" {
  length  = 5
  special = false
  upper   = false
}

locals {
  namespace = "openwebui-${random_string.ns_suffix.result}"
}

# 1. Create the namespace directly using the authenticated kubernetes provider.
resource "kubernetes_namespace" "app_namespace" {
  metadata {
    name = local.namespace
  }
}

# 2. Create the Kubernetes Service Account inside the new namespace.
resource "kubernetes_service_account" "openwebui" {
  depends_on = [kubernetes_namespace.app_namespace]

  metadata {
    name      = "open-webui-pia"
    namespace = kubernetes_namespace.app_namespace.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = var.openwebui_iam_role_arn
    }
  }
}

# 3. Create the AWS EKS Pod Identity Association.
# This is the crucial link between the AWS role and the K8s Service Account.
resource "aws_eks_pod_identity_association" "openwebui" {
  depends_on = [kubernetes_service_account.openwebui]

  cluster_name    = var.cluster_name
  namespace       = kubernetes_namespace.app_namespace.metadata[0].name
  service_account = kubernetes_service_account.openwebui.metadata[0].name
  role_arn        = var.openwebui_iam_role_arn
}

# --- Render all YAML files to disk using the simple filename pattern ---

resource "local_file" "storage_class" {
  content  = templatefile("${path.module}/storage-class.yaml.tpl", {})
  filename = "storage-class.yaml"
}

resource "local_file" "cluster_secret_store" {
  content  = templatefile("${path.module}/cluster-secret-store.yaml.tpl", {
    aws_region = var.aws_region
  })
  filename = "cluster-secret-store.yaml"
}

resource "local_file" "external_secret" {
  content  = templatefile("${path.module}/external-secret.yaml.tpl", {
    namespace      = local.namespace,
    db_secret_name = var.db_secret_name
  })
  filename = "external-secret.yaml"
}

resource "local_file" "pgvector_job" {
  content  = templatefile("${path.module}/pgvector-job.yaml.tpl", {
    namespace = local.namespace
  })
  filename = "pgvector-job.yaml"
}

resource "rafay_workload" "openwebui_secrets_setup" {
  depends_on = [
    aws_eks_pod_identity_association.openwebui,
    local_file.storage_class,
    local_file.cluster_secret_store,
    local_file.external_secret
  ]

  metadata {  
    name    = "openwebui-secrets-setup-${random_string.ns_suffix.result}"
    project = var.project_name
  }
  spec {
    namespace = local.namespace
    placement {
      selector = "rafay.dev/clusterName=${var.cluster_name}"
    }
    version = "v-${random_string.ns_suffix.result}"
    artifact {
      type = "Yaml"
      artifact {
        paths {
          name = "file://storage-class.yaml"
        }
        paths {
          name = "file://cluster-secret-store.yaml"
        }
        paths {
          name = "file://external-secret.yaml"
        }
      }
    }
  }
}

resource "rafay_workload" "openwebui_pgvector_job" {
  depends_on = [
    rafay_workload.openwebui_secrets_setup,
    local_file.pgvector_job
  ]

  metadata {
    name    = "openwebui-pgvector-job-${random_string.ns_suffix.result}"
    project = var.project_name
  }
  spec {
    namespace = local.namespace
    placement {
      selector = "rafay.dev/clusterName=${var.cluster_name}"
    }
    version = "v-${random_string.ns_suffix.result}"
    artifact {
      type = "Yaml"
      artifact {
        paths {
          name = "file://pgvector-job.yaml"
        }
      }
    }
  }
}