# AWS Authentication Configuration
data "external" "aws_auth" {
  program = ["bash", "-c", <<-EOF
    cat <<JSON
    {
      "access_key": "$AWS_ACCESS_KEY_ID",
      "secret_key": "$AWS_SECRET_ACCESS_KEY",
      "role_arn": "$AWS_ROLE_ARN",
      "profile": "$AWS_PROFILE",
      "web_identity_token_file": "$AWS_WEB_IDENTITY_TOKEN_FILE",
      "shared_config_file": "$AWS_CONFIG_FILE",
      "shared_credentials_file": "$AWS_SHARED_CREDENTIALS_FILE"
    }
JSON
  EOF
  ]
}

# AWS Provider Configuration
provider "aws" {
  region                   = var.region
  access_key              = try(data.external.aws_auth.result.access_key, null)
  secret_key              = try(data.external.aws_auth.result.secret_key, null)
  profile                 = try(data.external.aws_auth.result.profile, null)
  shared_config_files     = try(coalesce(data.external.aws_auth.result.shared_config_file), "") != "" ? [data.external.aws_auth.result.shared_config_file] : null
  shared_credentials_files = try(coalesce(data.external.aws_auth.result.shared_credentials_file), "") != "" ? [data.external.aws_auth.result.shared_credentials_file] : null

  dynamic "assume_role" {
    for_each = try(coalesce(data.external.aws_auth.result.role_arn), "") != "" ? [1] : []
    content {
      role_arn = data.external.aws_auth.result.role_arn
    }
  }

  dynamic "assume_role_with_web_identity" {
    for_each = try(coalesce(data.external.aws_auth.result.web_identity_token_file), "") != "" ? [1] : []
    content {
      role_arn                = data.external.aws_auth.result.role_arn
      web_identity_token_file = data.external.aws_auth.result.web_identity_token_file
    }
  }
}

data "aws_eks_cluster" "cluster" {
    name = var.cluster_name
}
data "aws_eks_cluster_auth" "ephemeral" {
  name = var.cluster_name
}

locals {
  loc = join("",["aws/",var.region])
}

resource "rafay_import_cluster" "rafay_cluster" {
  clustername           = var.cluster_name
  projectname           = var.project_name
  blueprint             = var.blueprint
  blueprint_version     = var.blueprint_version
  kubernetes_provider   = "EKS"
  location              = local.loc
  provision_environment = "CLOUD"
  values_path           = "values.yaml"
  labels = merge({"rafay.dev/envRun" = ""},{"rafay.dev/k8sVersion" = data.aws_eks_cluster.cluster.version},var.cluster_labels)
  lifecycle {
    ignore_changes = [
      bootstrap_path,
      values_path
    ]
  }
}


provider kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
    token                  = data.aws_eks_cluster_auth.ephemeral.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
    token                  = data.aws_eks_cluster_auth.ephemeral.token
  }
}

data "external" "env" {
  program = ["bash", "-c", <<-EOF
    cat <<JSON
    {
     "RCTL_REST_ENDPOINT": "$RCTL_REST_ENDPOINT",
    "RCTL_API_KEY": "$RCTL_API_KEY"
    }
JSON
  EOF
  ]
}

locals {
  rest_endpoint = sensitive(data.external.env.result["RCTL_REST_ENDPOINT"])
  api_key       = sensitive(data.external.env.result["RCTL_API_KEY"])
}

resource "null_resource" "fetch_cluster_info" {
  depends_on = [helm_release.v2-infra,local.api_key,local.rest_endpoint]
  triggers = {
    blueprint = var.blueprint
   }

  provisioner "local-exec" {
    command = "chmod +x  ./fetch_cluster_info.sh && ./fetch_cluster_info.sh ${local.rest_endpoint} ${var.project_name} ${var.cluster_name} ${local.api_key}"
  }
}

resource "helm_release" "v2-infra" {
  depends_on = [rafay_import_cluster.rafay_cluster]

  name             = "v2-infra"
  namespace        = "rafay-system"
  create_namespace = true
  repository       = "https://rafaysystems.github.io/rafay-helm-charts/"
  chart            = "v2-infra"
  values           = [rafay_import_cluster.rafay_cluster.values_data]
  version          = "1.1.3"

  lifecycle {
    ignore_changes = [
      # Avoid reapplying helm release
      values,
      # Prevent reapplying if version changes
      version
    ]
  }
}

resource "null_resource" "delete-webhook" {
  triggers = {
    cluster_name = var.cluster_name
    project_name = var.project_name
  }

  provisioner "local-exec" {
    when    = destroy
    command = "chmod +x ./delete-webhook.sh && ./delete-webhook.sh"
    environment = {
      CLUSTER_NAME = "${self.triggers.cluster_name}"
      PROJECT      = "${self.triggers.project_name}"
    }
  }

  depends_on = [helm_release.v2-infra]
}