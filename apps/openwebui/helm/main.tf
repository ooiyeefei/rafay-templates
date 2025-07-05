# --- Template File Rendering ---

locals {
  # Merge the default and additional lists, and remove any duplicates.
  final_model_list = distinct(concat(var.default_ollama_models, var.additional_ollama_models))
}

resource "local_file" "openwebui_values_yaml" {
  content  = templatefile("${path.module}/values.yaml.tpl", {
    s3_bucket_name = var.s3_bucket_name
    region         = var.aws_region
    openwebui_iam_role_arn = var.openwebui_iam_role_arn
    namespace              = var.namespace
    enable_ollama_workload = var.enable_ollama_workload
    external_vllm_endpoint = var.external_vllm_endpoint
  })
  filename = "values.yaml"
}

resource "local_file" "ollama_values_yaml" {
  count = var.enable_ollama_workload ? 1 : 0

  content  = templatefile("${path.module}/ollama-values.yaml.tpl", {
    ollama_models = local.final_model_list,
    ollama_on_gpu = var.ollama_on_gpu 
  })
  filename = "ollama-values.yaml"
}

resource "local_file" "load_balancer_yaml" {
  content = templatefile("${path.module}/lb.yaml.tpl", {
    namespace = var.namespace
  })
  filename = "lb.yaml"
}

# --- Rafay Workload Deployment ---

resource "rafay_workload" "openwebui_helm" {
  depends_on = [
    local_file.openwebui_values_yaml
  ]

  metadata {
    name    = "openwebui-${var.namespace}"
    project = var.project_name
  }

  timeouts {
    create = "10m"
    update = "10m"
    delete = "10m"
  }

  spec {
    namespace = var.namespace
    placement {
      selector = "rafay.dev/clusterName=${var.cluster_name}"
    }
    version = "v-${var.deployment_suffix}-${substr(local_file.openwebui_values_yaml.content_sha256, 0, 8)}"
    artifact {
      type = "Helm"
      artifact {
        repository    = var.openwebui_helm_repo
        chart_name    = var.openwebui_chart_name
        chart_version = var.openwebui_chart_version
        
        values_paths {
          name = "file://values.yaml"
        }
      }
    }
  }
}

resource "rafay_workload" "ollama_helm" {
  count = var.enable_ollama_workload ? 1 : 0

  depends_on = [
    local_file.ollama_values_yaml
  ]

  metadata {
    name    = "ollama-server-${var.namespace}"
    project = var.project_name
  }

  timeouts {
    create = "15m"
    update = "15m"
    delete = "10m"
  }

  spec {
    namespace = var.namespace
    placement {
      selector = "rafay.dev/clusterName=${var.cluster_name}"
    }
    version = "v-${var.deployment_suffix}-${substr(local_file.ollama_values_yaml[0].content_sha256, 0, 8)}"
    artifact {
      type = "Helm"
      artifact {
        repository    = "ollama-official-repo"
        chart_name    = "ollama"
        chart_version = "0.29.0"

        values_paths {
          name = "file://ollama-values.yaml"
        }
      }
    }
  }
}

# Create the AWS EKS Pod Identity Association.
# This is the crucial link between the AWS role and the K8s Service Account.
resource "aws_eks_pod_identity_association" "openwebui" {
  depends_on = [rafay_workload.openwebui_helm]

  cluster_name    = var.cluster_name
  namespace       = var.namespace
  service_account = "open-webui-pia"
  role_arn        = var.openwebui_iam_role_arn
}

resource "rafay_workload" "openwebui_load_balancer" {
  depends_on = [
    rafay_workload.openwebui_helm,
    local_file.load_balancer_yaml
  ]

  metadata {
    name    = "openwebui-lb-${var.namespace}"
    project = var.project_name
  }
  spec {
    namespace = var.namespace
    placement {
      selector = "rafay.dev/clusterName=${var.cluster_name}"
    }
    version = "v-${var.deployment_suffix}"
    artifact {
      type = "Yaml"
      artifact {
        paths {
          name = "file://lb.yaml"
        }
      }
    }
  }
}

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
  filename = "/tmp/kubeconfig-${var.namespace}"
}

resource "time_sleep" "wait_for_lb_provisioning" {
  depends_on      = [rafay_workload.openwebui_load_balancer]
  create_duration = "90s"
}

data "external" "load_balancer_info" {
  depends_on = [
    time_sleep.wait_for_lb_provisioning,
    local_sensitive_file.kubeconfig
  ]

  program = ["bash", "${path.module}/get-lb-hostname.sh"]

  query = {
    # CRITICAL: Pass the path to the unique kubeconfig file.
    kubeconfig_path = local_sensitive_file.kubeconfig.filename
    namespace       = var.namespace
    service_name    = "open-webui-service"
  }
}