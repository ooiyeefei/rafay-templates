#---------------------------------------------------------------
# Provider Configuration
#---------------------------------------------------------------
# To manage resources inside the Kubernetes cluster, we must configure
# the Helm and Kubernetes providers to connect to the EKS cluster
# created in the previous stage.

data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = var.cluster_name
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

#---------------------------------------------------------------
# IRSA for Karpenter
#---------------------------------------------------------------
# Karpenter requires an IAM role to manage EC2 instances. This
# is the most critical part of its setup.

resource "aws_iam_role" "karpenter_controller" {
  name = "${var.cluster_name}-karpenter-controller"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = var.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(var.cluster_oidc_issuer_url, "https://", "")}:sub" : "system:serviceaccount:karpenter:karpenter"
        }
      }
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "karpenter_controller" {
  role       = aws_iam_role.karpenter_controller.name
  policy_arn = "arn:aws:iam::${var.aws_account_id}:policy/KarpenterControllerPolicy-${var.cluster_name}"
}

# The inline policy Karpenter needs to function
resource "aws_iam_policy" "karpenter_controller" {
  name        = "KarpenterControllerPolicy-${var.cluster_name}"
  description = "Policy for the Karpenter controller."
  policy      = data.aws_iam_policy_document.karpenter_controller.json
}

#---------------------------------------------------------------
# Helm Release: Karpenter
#---------------------------------------------------------------
resource "helm_release" "karpenter" {
  namespace        = "karpenter"
  create_namespace = true
  name             = "karpenter"
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  version          = var.karpenter_chart_version

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.karpenter_controller.arn
  }
  set {
    name  = "settings.aws.clusterName"
    value = var.cluster_name
  }
  set {
    name  = "settings.aws.defaultInstanceProfile"
    value = var.karpenter_instance_profile_name
  }
}

#---------------------------------------------------------------
# Helm Release: KubeRay Operator
#---------------------------------------------------------------
# This operator allows us to create RayClusters declaratively.
resource "helm_release" "kuberay_operator" {
  depends_on       = [helm_release.karpenter]
  namespace        = "ray-system"
  create_namespace = true
  name             = "kuberay-operator"
  repository       = "https://ray-project.github.io/kuberay-helm/"
  chart            = "kuberay-operator"
  version          = var.kuberay_chart_version
}

#---------------------------------------------------------------
# Karpenter Custom Resources: NodePool and EC2NodeClass
#---------------------------------------------------------------
# These resources tell Karpenter *how* to provision nodes. This
# is the declarative configuration for your node autoscaling.

resource "kubernetes_manifest" "karpenter_nodepool" {
  depends_on = [helm_release.karpenter]
  manifest = {
    "apiVersion" = "karpenter.sh/v1beta1"
    "kind"       = "NodePool"
    "metadata" = {
      "name" = "default"
    }
    "spec" = {
      "disruption" = {
        "consolidationPolicy" = "WhenUnderutilized"
        "expireAfter"         = "720h" # 30 days
      }
      "template" = {
        "metadata" = {
          "labels" = {
            "type" = "karpenter"
          }
        }
        "spec" = {
          "nodeClassRef" = {
            "name" = "default"
          }
          "requirements" = [
            { "key" = "karpenter.sh/capacity-type", "operator" = "In", "values" = ["on-demand"] },
            { "key" = "karpenter.k8s.aws/instance-category", "operator" = "In", "values" = var.karpenter_instance_category },
            { "key" = "karpenter.k8s.aws/instance-generation", "operator" = "In", "values" = var.karpenter_instance_generation },
          ]
        }
      }
    }
  }
}

resource "kubernetes_manifest" "karpenter_nodeclass" {
  depends_on = [helm_release.karpenter]
  manifest = {
    "apiVersion" = "karpenter.k8s.aws/v1beta1"
    "kind"       = "EC2NodeClass"
    "metadata" = {
      "name" = "default"
    }
    "spec" = {
      "amiFamily" = "AL2"
      "role"      = var.karpenter_instance_profile_name
      "subnetSelectorTerms" = [{
        "tags" = { "karpenter.sh/discovery" = var.cluster_name }
      }]
      "securityGroupSelectorTerms" = [{
        "tags" = { "karpenter.sh/discovery" = var.cluster_name }
      }]
    }
  }
}

# This additional NodePool is specifically for GPU workloads.
resource "kubernetes_manifest" "karpenter_nodepool_gpu" {
  depends_on = [helm_release.karpenter]
  manifest = {
    "apiVersion" = "karpenter.sh/v1beta1"
    "kind"       = "NodePool"
    "metadata" = {
      "name" = "gpu"
    }
    "spec" = {
      "disruption" = {
        "consolidationPolicy" = "WhenUnderutilized"
        "expireAfter"         = "720h"
      }
      "template" = {
        "metadata" = {
          "labels" = {
            "type"                 = "karpenter",
            "node.kubernetes.io/instance-type" = "nvidia-gpu" # A label for easy selection
          }
        }
        "spec" = {
          "nodeClassRef" = {
            "name" = "default" # Can reuse the same node class
          }
          "requirements" = [
            { "key" = "karpenter.sh/capacity-type", "operator" = "In", "values" = ["on-demand"] },
            { "key" = "karpenter.k8s.aws/instance-family", "operator" = "In", "values" = var.karpenter_gpus_instance_family },
            { "key" = "node.kubernetes.io/instance-type", "operator" = "In", "values" = var.karpenter_gpus_instance_types },
            { "key" = "karpenter.sh/provisioner-name", "operator" = "Exists" }, # Standard requirement
          ]
        }
      }
    }
  }
}