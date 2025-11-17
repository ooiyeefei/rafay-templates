# ============================================
# Run:AI Cluster Onboarding Automation
# ============================================
#
# This module automates the following steps:
# 1. Parse node information and create DNS-safe hostname
# 2. Create Route53 DNS A record
# 3. Deploy cert-manager ClusterIssuer (via kubectl)
# 4. Create Run:AI cluster in Control Plane (via API)
#    └─ Retrieve cluster UUID and client secret
# 5. Install Run:AI Helm chart (using credentials from step 4)
# 6. Create Run:AI ingress with TLS (via kubectl)
#
# Dependencies are properly sequenced to ensure correct order.
# Uses kubectl for simple YAML deployments (not rafay_workload).
# ============================================

# ============================================
# Data Sources
# ============================================

# Fetch kubeconfig directly from Rafay using the provider
# This uses Rafay API authentication automatically
data "rafay_download_kubeconfig" "cluster" {
  cluster = var.cluster_name
}

# ============================================
# Setup: Download Required Tools
# ============================================

# Download jq and kubectl binaries (similar to runai/ folder pattern)
resource "null_resource" "setup" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "chmod +x ./scripts/setup.sh; ./scripts/setup.sh"
    working_dir = path.module
  }

  triggers = {
    # Run setup on every apply to ensure binaries are always available
    # This is necessary because Rafay Environment Manager may clean up
    # the workspace between runs
    always_run = timestamp()
  }
}

# ============================================
# Local Variables and Data Processing
# ============================================

locals {
  # Extract first node information (assuming single-node or primary node)
  # Access nodes_info field from the wrapper object
  first_node_key = keys(var.nodes_information.nodes_info)[0]
  first_node     = var.nodes_information.nodes_info[local.first_node_key]

  # Sanitize hostname for DNS (remove dashes, lowercase)
  # TRY-63524-gpu01 -> try63524gpu01
  dns_safe_hostname = lower(replace(local.first_node.hostname, "-", ""))

  # Construct FQDN
  # Example: try63524gpu01.runai.langgoose.com
  cluster_fqdn = "${local.dns_safe_hostname}.${var.dns_domain}"

  # Unique TLS secret name per cluster
  tls_secret_name = "runai-tls-${var.cluster_name}"

  # Public IP for DNS record
  public_ip = local.first_node.ip_address

  # Parse kubeconfig YAML to extract authentication data
  # Use the Rafay-fetched kubeconfig content
  kubeconfig_parsed = yamldecode(data.rafay_download_kubeconfig.cluster.kubeconfig)

  # Extract Kubernetes API server endpoint
  # kubeconfig.clusters[0].cluster.server
  host = local.kubeconfig_parsed.clusters[0].cluster.server

  # Extract certificate authority data (base64)
  # kubeconfig.clusters[0].cluster.certificate-authority-data
  certificate_authority_data = local.kubeconfig_parsed.clusters[0].cluster["certificate-authority-data"]

  # Extract client certificate data (base64)
  # kubeconfig.users[0].user.client-certificate-data
  client_certificate_data = local.kubeconfig_parsed.users[0].user["client-certificate-data"]

  # Extract client key data (base64)
  # kubeconfig.users[0].user.client-key-data
  client_key_data = local.kubeconfig_parsed.users[0].user["client-key-data"]

  # Use the Rafay-fetched kubeconfig YAML for kubectl operations
  kubeconfig_content = data.rafay_download_kubeconfig.cluster.kubeconfig
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
  filename = "/tmp/kubeconfig-${var.cluster_name}"
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
  filename        = "${path.module}/cluster-issuer.yaml"
  file_permission = "0644"
}

# Run:AI Ingress
# Creates YAML file for kubectl deployment
resource "local_file" "runai_ingress_yaml" {
  content = templatefile("${path.module}/templates/runai-ingress.yaml.tpl", {
    cluster_fqdn        = local.cluster_fqdn
    tls_secret_name     = local.tls_secret_name
    cluster_issuer_name = var.cluster_issuer_name
    namespace           = var.namespace
  })
  filename        = "${path.module}/runai-ingress.yaml"
  file_permission = "0644"
}

# ============================================
# Step 4: Deploy cert-manager ClusterIssuer
# ============================================

resource "null_resource" "deploy_cluster_issuer" {
  depends_on = [
    null_resource.setup,
    local_file.cluster_issuer_yaml,
    local_sensitive_file.kubeconfig
  ]

  provisioner "local-exec" {
    command     = "./kubectl --kubeconfig ${local_sensitive_file.kubeconfig.filename} apply -f ${local_file.cluster_issuer_yaml.filename}"
    working_dir = path.module
  }

  triggers = {
    yaml_sha = sha256(local_file.cluster_issuer_yaml.content)
  }
}

# ACTIVELY WAIT for ClusterIssuer to be ready
resource "null_resource" "wait_for_issuer_ready" {
  depends_on = [
    null_resource.deploy_cluster_issuer
  ]

  provisioner "local-exec" {
    # This command will poll for up to 2 minutes and only succeed when the issuer is ready.
    # Uses locally downloaded kubectl binary (from setup.sh).
    command     = "./kubectl --kubeconfig ${local_sensitive_file.kubeconfig.filename} wait --for=condition=Ready clusterissuer/${var.cluster_issuer_name} --timeout=120s"
    working_dir = path.module
  }

  triggers = {
    yaml_sha = sha256(local_file.cluster_issuer_yaml.content)
  }
}

# ============================================
# Step 4.5: Create Run:AI Cluster in Control Plane
# ============================================

resource "null_resource" "create_runai_cluster" {
  depends_on = [
    null_resource.setup,
    time_sleep.wait_for_dns
  ]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "chmod +x ./scripts/create-runai-cluster.sh; CLUSTER_NAME='${var.cluster_name}' CLUSTER_FQDN='${local.cluster_fqdn}' ./scripts/create-runai-cluster.sh"
    working_dir = path.module
  }

  triggers = {
    always_run     = timestamp()  # Force re-run on every apply (idempotent API calls)
    cluster_name   = var.cluster_name
    cluster_fqdn   = local.cluster_fqdn
    chart_version  = var.runai_chart_version
    helm_namespace = var.namespace
  }
}

# Read Run:AI Control Plane URL (saved by script from env var)
data "local_file" "runai_control_plane_url" {
  depends_on = [null_resource.create_runai_cluster]
  filename   = "${path.module}/control_plane_url.txt"
}

# Read cluster UUID created by the script via API
data "local_file" "runai_cluster_uuid" {
  depends_on = [null_resource.create_runai_cluster]
  filename   = "${path.module}/cluster_uuid.txt"
}

# Read client secret retrieved by the script via API
data "local_sensitive_file" "runai_client_secret" {
  depends_on = [null_resource.create_runai_cluster]
  filename   = "${path.module}/client_secret.txt"
}

# ============================================
# Step 5: Install Run:AI Cluster (Helm)
# ============================================

resource "helm_release" "runai_cluster" {
  depends_on = [
    null_resource.wait_for_issuer_ready,
    null_resource.create_runai_cluster
  ]

  name       = "runai-cluster"
  repository = var.runai_helm_repo
  chart      = "runai-cluster"
  version    = var.runai_chart_version
  namespace  = var.namespace

  create_namespace = true
  wait             = true   # Native Helm wait for deployments to be ready
  timeout          = 600    # 10 minutes
  verify           = false

  # Disable Run:AI's built-in ingress (we manage our own)
  # Note: Using Helm provider v3.x syntax (list of objects)
  set = [
    {
      name  = "runai-operator.researcherService.ingress.enabled"
      value = "false"
    },
    {
      name  = "runai-operator.clusterApi.ingress.enabled"
      value = "false"
    },
    {
      name  = "controlPlane.url"
      value = "https://${data.local_file.runai_control_plane_url.content}"
    },
    {
      name  = "cluster.uid"
      value = data.local_file.runai_cluster_uuid.content
    },
    {
      name  = "cluster.url"
      value = "https://${local.cluster_fqdn}"
    }
  ]

  # Client secret retrieved from API by create-runai-cluster.sh
  # Note: Using Helm provider v3.x syntax (list of objects)
  set_sensitive = [
    {
      name  = "controlPlane.clientSecret"
      value = data.local_sensitive_file.runai_client_secret.content
    }
  ]

  # Prevent "inconsistent result" errors when values change from placeholder to real
  # The Helm provider tracks metadata changes (revision, values, timestamps)
  # We need to ignore these because our values intentionally change during apply
  lifecycle {
    ignore_changes = [
      metadata[0].revision,
      metadata[0].values,
      metadata[0].last_deployed
    ]
  }
}

# ============================================
# Step 6: Deploy Run:AI Ingress with TLS
# ============================================

resource "null_resource" "deploy_runai_ingress" {
  depends_on = [
    null_resource.setup,
    helm_release.runai_cluster,
    local_file.runai_ingress_yaml,
    local_sensitive_file.kubeconfig
  ]

  provisioner "local-exec" {
    command     = "./kubectl --kubeconfig ${local_sensitive_file.kubeconfig.filename} apply -f ${local_file.runai_ingress_yaml.filename}"
    working_dir = path.module
  }

  triggers = {
    yaml_sha = sha256(local_file.runai_ingress_yaml.content)
  }
}

# ACTIVELY WAIT for Certificate to be issued
resource "null_resource" "wait_for_certificate_ready" {
  depends_on = [
    null_resource.deploy_runai_ingress
  ]

  provisioner "local-exec" {
    # This command polls for up to 5 minutes for the certificate to be issued and ready
    # cert-manager will handle the HTTP-01 challenge and ACME communication
    # Uses locally downloaded kubectl binary (from setup.sh).
    command     = "./kubectl --kubeconfig ${local_sensitive_file.kubeconfig.filename} wait --for=condition=Ready certificate/${local.tls_secret_name} -n ${var.namespace} --timeout=300s"
    working_dir = path.module
  }

  triggers = {
    yaml_sha = sha256(local_file.runai_ingress_yaml.content)
  }
}

# ============================================
# Cleanup: Delete Run:AI Cluster on Destroy
# ============================================
#
# This resource runs a cleanup script during terraform destroy to:
# 1. Authenticate with Run:AI Control Plane
# 2. Delete the cluster registration via API
#
# Environment variables (RUNAI_APP_ID, RUNAI_APP_SECRET, RUNAI_CONTROL_PLANE_URL)
# are automatically inherited from Rafay Config Context.
#
# The script reads cluster UUID from the file created during apply.
# If any values are missing, the script gracefully skips cleanup.

resource "null_resource" "delete_runai_cluster" {
  depends_on = [
    null_resource.create_runai_cluster,
    helm_release.runai_cluster
  ]

  # This provisioner runs ONLY during terraform destroy
  provisioner "local-exec" {
    when        = destroy
    working_dir = path.module
    interpreter = ["/bin/bash", "-c"]

    # Call external script to avoid bash escaping issues
    # Script will read cluster_uuid.txt and control_plane_url.txt
    # Environment variables are passed automatically from Rafay Config Context
    command = <<-EOT
      chmod +x ./scripts/delete-runai-cluster.sh

      # Read values from files (created during apply)
      if [ -f cluster_uuid.txt ]; then
        export CLUSTER_UUID=$(cat cluster_uuid.txt)
      fi

      if [ -f control_plane_url.txt ]; then
        export RUNAI_CONTROL_PLANE_URL=$(cat control_plane_url.txt)
      fi

      # Execute the deletion script
      # RUNAI_APP_ID and RUNAI_APP_SECRET are inherited from environment
      ./scripts/delete-runai-cluster.sh
    EOT

    # Note: RUNAI_APP_ID, RUNAI_APP_SECRET, and RUNAI_CONTROL_PLANE_URL
    # are automatically available from Rafay Config Context
    # We don't need to explicitly set them here
  }

  # No triggers needed - this resource just needs to exist for the destroy provisioner
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
