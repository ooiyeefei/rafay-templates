locals {
  first_node_key = keys(var.nodes_info)[0]
  first_node     = var.nodes_info[local.first_node_key]

  # Sanitize hostname for DNS (remove dashes, lowercase)
  # TRY-63524-gpu01 -> try63524gpu01
  dns_safe_hostname = lower(replace(local.first_node.hostname, "-", ""))

  # Construct FQDN
  # Example: try63524gpu01.runai.langgoose.com
  cluster_fqdn = "${local.dns_safe_hostname}.${var.dns_domain}"

  # Unique TLS secret name per environment
  tls_secret_name = "runai-tls-${var.environment_name}"

  # Public IP for DNS record
  public_ip = local.first_node.ip_address

  # Kubeconfig content for kubectl operations
  kubeconfig_content = yamlencode({
    apiVersion      = "v1"
    kind            = "Config"
    current-context = "default"
    clusters = [{
      name = var.cluster_name
      cluster = {
        server                     = var.host
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
}

# ============================================
# Step 1: Create Route53 DNS A Record
# ============================================

resource "aws_route53_record" "runai_cluster" {
  zone_id = var.route53_zone_id
  name    = local.cluster_fqdn
  type    = "A"
  ttl     = 300
  records = [local.public_ip]
}

# Pragmatic wait for DNS propagation (no kubectl alternative)
resource "time_sleep" "wait_for_dns" {
  depends_on      = [aws_route53_record.runai_cluster]
  create_duration = "60s"  # Be generous for global DNS propagation
}

# ============================================
# Step 2: Create Kubeconfig File
# ============================================

resource "local_sensitive_file" "kubeconfig" {
  content  = local.kubeconfig_content
  filename = "/tmp/kubeconfig-runai-${var.environment_name}"
}

# ============================================
# Step 3: Template Files for Kubernetes Resources
# ============================================

# ClusterIssuer for cert-manager
resource "local_file" "cluster_issuer_yaml" {
  content = templatefile("${path.module}/templates/cluster-issuer.yaml.tpl", {
    cluster_issuer_name = var.cluster_issuer_name
    letsencrypt_email   = var.letsencrypt_email
  })
  filename = "${path.module}/cluster-issuer.yaml"
}

# Run:AI Ingress
resource "local_file" "runai_ingress_yaml" {
  depends_on = [
    time_sleep.wait_for_dns
  ]

  content = templatefile("${path.module}/templates/runai-ingress.yaml.tpl", {
    cluster_fqdn        = local.cluster_fqdn
    tls_secret_name     = local.tls_secret_name
    cluster_issuer_name = var.cluster_issuer_name
    namespace           = var.namespace
  })
  filename = "${path.module}/runai-ingress.yaml"
}

# ============================================
# Step 4: Deploy cert-manager ClusterIssuer
# ============================================

resource "rafay_workload" "cert_manager_issuer" {
  depends_on = [
    local_file.cluster_issuer_yaml,
    local_sensitive_file.kubeconfig
  ]

  metadata {
    name    = "cert-manager-issuer-${var.environment_name}"
    project = var.project_name
  }

  timeouts {
    create = "5m"
    update = "5m"
    delete = "5m"
  }

  spec {
    namespace = "cert-manager"
    placement {
      selector = "rafay.dev/clusterName=${var.cluster_name}"
    }
    version = "v-${var.deployment_suffix}"
    artifact {
      type = "Yaml"
      artifact {
        paths {
          name = "file://cluster-issuer.yaml"
        }
      }
    }
  }
}

# ACTIVELY WAIT for ClusterIssuer to be ready
resource "null_resource" "wait_for_issuer_ready" {
  depends_on = [rafay_workload.cert_manager_issuer]

  provisioner "local-exec" {
    # This command will poll for up to 2 minutes and only succeed when the issuer is ready.
    # It requires kubectl to be installed on the Terraform agent.
    command = "kubectl --kubeconfig ${local_sensitive_file.kubeconfig.filename} wait --for=condition=Ready clusterissuer/${var.cluster_issuer_name} --timeout=120s"
  }

  triggers = {
    issuer_version = rafay_workload.cert_manager_issuer.spec[0].version
  }
}

# ============================================
# Step 5: Install Run:AI Cluster (Helm)
# ============================================

resource "rafay_workload" "runai_cluster" {
  depends_on = [
    null_resource.wait_for_issuer_ready,
    time_sleep.wait_for_dns
  ]

  metadata {
    name    = "runai-cluster-${var.environment_name}"
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
    version = "v-${var.deployment_suffix}-runai"
    artifact {
      type = "Helm"
      artifact {
        repository    = var.runai_helm_repo
        chart_name    = "runai-cluster"
        chart_version = var.runai_chart_version

        # Helm values configuration
        values = <<-EOT
          # Disable Run:AI's built-in ingress (we manage our own)
          runai-operator:
            researcherService:
              ingress:
                enabled: false
            clusterApi:
              ingress:
                enabled: false

          controlPlane:
            url: ${var.runai_control_plane_url}
            clientSecret: ${var.runai_client_secret}

          cluster:
            uid: ${var.runai_cluster_uid}
            url: https://${local.cluster_fqdn}
        EOT
      }
    }
  }
}

# ACTIVELY WAIT for Run:AI Deployments to be available
resource "null_resource" "wait_for_runai_ready" {
  depends_on = [rafay_workload.runai_cluster]

  provisioner "local-exec" {
    # Wait for Run:AI deployments to be Available (all replicas ready)
    # This ensures backend services are available when ingress routes traffic
    command = <<-EOT
      kubectl --kubeconfig ${local_sensitive_file.kubeconfig.filename} \
        wait --for=condition=Available deployment \
        -l app.kubernetes.io/instance=runai-cluster \
        -n ${var.namespace} \
        --timeout=300s
    EOT
  }

  triggers = {
    workload_version = rafay_workload.runai_cluster.spec[0].version
  }
}

# ============================================
# Step 6: Deploy Run:AI Ingress with TLS
# ============================================

resource "rafay_workload" "runai_ingress" {
  depends_on = [
    null_resource.wait_for_runai_ready,
    local_file.runai_ingress_yaml
  ]

  metadata {
    name    = "runai-ingress-${var.environment_name}"
    project = var.project_name
  }

  timeouts {
    create = "10m"
    update = "10m"
    delete = "5m"
  }

  spec {
    namespace = var.namespace
    placement {
      selector = "rafay.dev/clusterName=${var.cluster_name}"
    }
    version = "v-${var.deployment_suffix}-ingress"
    artifact {
      type = "Yaml"
      artifact {
        paths {
          name = "file://runai-ingress.yaml"
        }
      }
    }
  }
}

# ACTIVELY WAIT for Certificate to be issued
resource "null_resource" "wait_for_certificate_ready" {
  depends_on = [rafay_workload.runai_ingress]

  provisioner "local-exec" {
    # This command polls for up to 5 minutes for the certificate to be issued and ready
    # cert-manager will handle the HTTP-01 challenge and ACME communication
    command = "kubectl --kubeconfig ${local_sensitive_file.kubeconfig.filename} wait --for=condition=Ready certificate/${local.tls_secret_name} -n ${var.namespace} --timeout=300s"
  }

  triggers = {
    ingress_version = rafay_workload.runai_ingress.spec[0].version
  }
}

# ============================================
# Verification Script (Optional)
# ============================================

# This can be used to verify the deployment
resource "null_resource" "verify_deployment" {
  depends_on = [
    null_resource.wait_for_certificate_ready
  ]

  provisioner "local-exec" {
    command = <<-EOT
      echo "==================================="
      echo "Run:AI Cluster Onboarding Complete"
      echo "==================================="
      echo "Cluster FQDN: ${local.cluster_fqdn}"
      echo "Public IP: ${local.public_ip}"
      echo "DNS Record: ${aws_route53_record.runai_cluster.fqdn}"
      echo "TLS Secret: ${local.tls_secret_name}"
      echo ""
      echo "Access Run:AI at: https://${local.cluster_fqdn}"
      echo "==================================="
    EOT
  }
}
