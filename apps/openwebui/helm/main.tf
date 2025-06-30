# --- Template File Rendering ---

resource "local_file" "openwebui_values_yaml" {
  content  = templatefile("${path.module}/values.yaml.tpl", {
    s3_bucket_name = var.s3_bucket_name
    region         = var.aws_region
    openwebui_iam_role_arn = var.openwebui_iam_role_arn
  })
  filename = "values.yaml"
}

resource "local_file" "load_balancer_yaml" {
  content = templatefile("${path.module}/lb.yaml.tpl", {
    namespace = var.namespace
    node_security_group_id = var.node_security_group_id
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
  spec {
    namespace = var.namespace
    placement {
      selector = "rafay.dev/clusterName=${var.cluster_name}"
    }
    version = "v-${var.deployment_suffix}"
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
    aws_eks_pod_identity_association.openwebui,
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