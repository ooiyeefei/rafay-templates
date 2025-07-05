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
  kubernetes = {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
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
  policy_arn = aws_iam_policy.karpenter_controller.arn
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
resource "helm_release" "volcano" {
  name       = "volcano"
  repository = "https://volcano-sh.github.io/helm-charts"
  chart      = "volcano"
  namespace  = "volcano-system"
  create_namespace = true
  version    = "1.12.1"
}

# This operator allows us to create RayClusters declaratively.
resource "helm_release" "kuberay_operator" {
  depends_on       = [helm_release.karpenter]
  namespace        = "ray-system"
  create_namespace = true
  name             = "kuberay-operator"
  repository       = "https://ray-project.github.io/kuberay-helm/"
  chart            = "kuberay-operator"
  version          = var.kuberay_chart_version

  set {
    name  = "batchScheduler.enabled"
    value = "true"
  }
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

# Disable the old gp2 storage class
resource "kubernetes_annotations" "disable_gp2" {
  api_version = "storage.k8s.io/v1"
  kind        = "StorageClass"
  metadata {
    name = "gp2"
  }
  annotations = {
    "storageclass.kubernetes.io/is-default-class" = "false"
  }
  force = true
}

# Create a new default gp3 storage class
resource "kubernetes_storage_class" "default_gp3" {
  depends_on = [kubernetes_annotations.disable_gp2]
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }
  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  allow_volume_expansion = true
  volume_binding_mode    = "WaitForFirstConsumer"
  parameters = {
    fsType    = "ext4"
    encrypted = "true"
    type      = "gp3"
  }
}

resource "helm_release" "aws_efs_csi_driver" {
  name       = "aws-efs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-efs-csi-driver/"
  chart      = "aws-efs-csi-driver"
  namespace  = "kube-system"
  version    = "2.8.1" # Pin to a specific, tested version

  set {
    name  = "controller.serviceAccount.create"
    value = "false" # We don't need the chart to create the SA
  }
  set {
    name  = "controller.serviceAccount.name"
    value = "efs-csi-controller-sa"
  }
  set {
    # This is where you annotate the Service Account with the role from the EKS module
    name  = "controller.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = var.efs_csi_driver_role_arn
  }
}

# ==============================================================================
# AWS Load Balancer Controller (LBC)
# This section follows the proven manual install pattern.
# ==============================================================================

# Step 1: Create the Kubernetes Service Account and annotate it with the IAM Role.
resource "kubernetes_service_account" "aws_load_balancer_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = var.aws_load_balancer_controller_irsa_role_arn
    }
  }
}

# Step 2: Install the LBC Helm chart.
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.8.0" # Pinning to a specific recent version

  # This ensures the SA exists before the chart tries to use it.
  depends_on = [kubernetes_service_account.aws_load_balancer_controller]

  set {
    name  = "serviceAccount.create"
    value = "false" # We manage the SA ourselves.
  }
  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller" # Tell the chart which SA to use.
  }
  set {
    name  = "clusterName"
    value = var.cluster_name
  }
}

# ==============================================================================
# Ingress and Observability Applications
# These are installed after the LBC is ready.
# ==============================================================================

#---------------------------------------------------------------
# Helm Release: Ingress NGINX Controller
#---------------------------------------------------------------
resource "helm_release" "ingress_nginx" {
  depends_on = [helm_release.aws_load_balancer_controller]

  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = "ingress-nginx"
  create_namespace = true
  version    = "4.10.1"

  values = [
    yamlencode({
      controller = {
        # This tells the AWS LBC to provision a high-performance Network Load Balancer
        # to feed traffic to the NGINX pods. This is the best-practice setup.
        service = {
          type = "LoadBalancer"
          annotations = {
            "service.beta.kubernetes.io/aws-load-balancer-type" = "nlb"
          }
        }
      }
    })
  ]
}

#---------------------------------------------------------------
# Helm Release: Kube Prometheus Stack (Prometheus + Grafana)
#---------------------------------------------------------------
resource "helm_release" "kube_prometheus_stack" {
  depends_on = [helm_release.ingress_nginx]

  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = "monitoring"
  create_namespace = true
  version    = "58.1.0"
  timeout    = 600
}

#---------------------------------------------------------------
# Helm Release: Kubecost
#---------------------------------------------------------------
resource "helm_release" "kubecost" {
  depends_on = [helm_release.kube_prometheus_stack]

  name       = "kubecost"
  repository = "https://kubecost.github.io/cost-analyzer/"
  chart      = "cost-analyzer"
  namespace  = "kubecost"
  create_namespace = true
  version    = "2.2.2"
  
  values = [
    yamlencode({
      kubecostProductConfigs = {
        clusterName = var.cluster_name
      }
      # This is critical. It tells Kubecost to use the Prometheus we just installed,
      # rather than installing its own, preventing conflicts.
      prometheus = {
        server = "http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090"
      }
    })
  ]
}