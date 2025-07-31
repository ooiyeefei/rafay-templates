# -----------------------------------------------------------------------------
# PROVIDER AND DATA SOURCE CONFIGURATION
# -----------------------------------------------------------------------------
# These are still required for Terraform to connect to the cluster and AWS.

provider "kubernetes" {
  host                   = var.cluster_endpoint
  cluster_ca_certificate = base64decode(var.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = var.cluster_endpoint
    cluster_ca_certificate = base64decode(var.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

data "aws_eks_cluster_auth" "cluster" {
  name = var.cluster_name
}

data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.ecr
}

# -----------------------------------------------------------------------------
# FOUNDATIONAL ADD-ONS (from EKS Blueprints)
# This module installs core services like networking, scheduling, and observability.
# -----------------------------------------------------------------------------

module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.20"

  # --- Core Cluster Inputs ---
  cluster_name      = var.cluster_name
  cluster_endpoint  = var.cluster_endpoint
  cluster_version   = var.eks_cluster_version
  oidc_provider_arn = var.oidc_provider_arn

  # --- Add-on Configurations ---
  enable_aws_load_balancer_controller = true
  aws_load_balancer_controller = {
    values = [
      yamlencode({
        # This gives the LBC pods the toleration they need to run on the core nodes
        tolerations = [{
          key      = "CriticalAddonsOnly"
          operator = "Exists"
          effect   = "NoSchedule"
        }]
      })
    ]
  }

  enable_aws_efs_csi_driver           = true

  # --- NGINX CONFIGURATION ---
  enable_ingress_nginx = true
  ingress_nginx = {
    values = [
      yamlencode({
        # Add tolerations for BOTH the controller and the admission job webhook
        controller: {
          tolerations: [{ key: "CriticalAddonsOnly", operator: "Exists", effect: "NoSchedule" }]
        },
        admissionWebhooks: {
          patch: {
            tolerations: [{ key: "CriticalAddonsOnly", operator: "Exists", effect: "NoSchedule" }]
          }
        }
      })
    ]
  }

  # --- KUBE-PROMETHEUS-STACK CONFIGURATION ---
  enable_kube_prometheus_stack = true
  kube_prometheus_stack = {
    values = [
      yamlencode({
        # Give tolerations to all the key components of the stack
        grafana = {
          adminPassword = "prom-operator"
          tolerations = [{
            key      = "CriticalAddonsOnly"
            operator = "Exists"
            effect   = "NoSchedule"
          }]
        }
        prometheus = {
          prometheusSpec = {
            tolerations = [{
              key      = "CriticalAddonsOnly"
              operator = "Exists"
              effect   = "NoSchedule"
            }]
          }
        }
        alertmanager = {
          alertmanagerSpec = {
            tolerations = [{
              key      = "CriticalAddonsOnly"
              operator = "Exists"
              effect   = "NoSchedule"
            }]
          }
        }
      })
    ]
  }

  # Karpenter Controller Installation
  enable_karpenter = true
  karpenter = {
    chart_version           = "1.4.0" # The blueprint module uses versions without "v"
    repository_username     = data.aws_ecrpublic_authorization_token.token.user_name
    repository_password     = data.aws_ecrpublic_authorization_token.token.password
    source_policy_documents = [data.aws_iam_policy_document.karpenter_controller_policy.json]
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# DATA & AI ADD-ONS (from EKS Blueprints Data Addons)
# This module installs AI/ML specific tools and the Karpenter CRDs.
# -----------------------------------------------------------------------------

module "data_addons" {
  source  = "aws-ia/eks-data-addons/aws"
  version = "~> 1.37"

  # This module also needs the OIDC provider ARN
  oidc_provider_arn = var.oidc_provider_arn

  # --- Add-on Configurations ---

  # Volcano for batch scheduling
  enable_volcano = true

  # KubeRay Operator, configured to use Volcano
  enable_kuberay_operator = true
  kuberay_operator_helm_config = {
    version = "1.1.1"
    values = [
      yamlencode({
        batchScheduler = {
          enabled = true
        }
      })
    ]
  }

  # Kubecost for cost monitoring
  enable_kubecost = true
  kubecost_helm_config = {
    version             = "2.2.2"
    repository_username = data.aws_ecrpublic_authorization_token.token.user_name
    repository_password = data.aws_ecrpublic_authorization_token.token.password
    # This points Kubecost to the Prometheus installed by the *other* blueprint module
    values = [
      yamlencode({
        # This block tells Kubecost to use an external Prometheus and to disable its own.
        prometheus = {
          enabled = false # Disables the entire embedded Prometheus sub-chart
          external = {
            server = "http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090"
          }
        }
      })
    ]
  }

  enable_karpenter_resources = true
  karpenter_resources_helm_config = {
    x86-cpu-karpenter = {
      values = [
        <<-EOT
      name: default
      clusterName: ${var.cluster_name}
      ec2NodeClass:
        amiFamily: Bottlerocket
        karpenterRole: ${split("/", module.eks_blueprints_addons.karpenter.node_iam_role_arn)[1]}
        subnetSelectorTerms:
          tags:
            karpenter.sh/discovery: ${var.cluster_name}
        securityGroupSelectorTerms:
          tags:
            Name: ${var.cluster_name}-node
        blockDeviceMappings:
          # Root device
          - deviceName: /dev/xvda
            ebs:
              volumeSize: 100Gi
              volumeType: gp3
              encrypted: true
          # Data device: Container resources such as images and logs
          - deviceName: /dev/xvdb
            ebs:
              volumeSize: 300Gi
              volumeType: gp3
              encrypted: true
      nodePool:
        labels:
          - type: karpenter
          - NodeGroupType: x86-cpu-karpenter
        requirements:
          - key: "karpenter.k8s.aws/instance-category"
            operator: In
            values: ["c", "m", "r"]
          - key: "karpenter.k8s.aws/instance-generation"
            operator: Gt
            values: ["4"]
          - key: "kubernetes.io/arch"
            operator: In
            values: ["amd64"]
          - key: "karpenter.sh/capacity-type"
            operator: In
            values: ["spot", "on-demand"]
        limits:
          cpu: 1000
        disruption:
          consolidationPolicy: WhenEmpty
      EOT
      ]
    }
    g5-gpu-karpenter = {
      values = [
        <<-EOT
      name: g5-gpu-karpenter
      clusterName: ${var.cluster_name}
      ec2NodeClass:
        amiFamily: Bottlerocket
        amiSelectorTerms:
          - name: "*bottlerocket-aws-*-nvidia*"
        karpenterRole: ${split("/", module.eks_blueprints_addons.karpenter.node_iam_role_arn)[1]}
        subnetSelectorTerms:
          tags:
            karpenter.sh/discovery: ${var.cluster_name}
        securityGroupSelectorTerms:
          tags:
            Name: ${var.cluster_name}-node
        blockDeviceMappings:
          # Root device
          - deviceName: /dev/xvda
            ebs:
              volumeSize: 100Gi
              volumeType: gp3
              encrypted: true
          # Data device: Container resources such as images and logs
          - deviceName: /dev/xvdb
            ebs:
              volumeSize: 300Gi
              volumeType: gp3
              encrypted: true
      nodePool:
        labels:
          - type: karpenter
          - NodeGroupType: g5-gpu-karpenter
        taints:
          - key: nvidia.com/gpu
            value: "true"
            effect: "NoSchedule"
        requirements:
          - key: "karpenter.k8s.aws/instance-family"
            operator: In
            values: ["g5", "g4dn"]
          - key: "node.kubernetes.io/instance-type"
            operator: In
            values: ["g4dn.xlarge", "g4dn.2xlarge", "g5.xlarge", "g5.2xlarge", "g5.4xlarge", "g5.8xlarge"]
          - key: "kubernetes.io/arch"
            operator: In
            values: ["amd64"]
          - key: "karpenter.sh/capacity-type"
            operator: In
            values: ["on-demand"]
        limits:
          cpu: 1000
        disruption:
          consolidationPolicy: WhenEmpty
      EOT
      ]
    }
  }
  
  depends_on = [module.eks_blueprints_addons]
}

# -----------------------------------------------------------------------------
# FOUNDATIONAL STORAGE CONFIGURATION (Best Practice)
# These are still good to manage manually for full control.
# -----------------------------------------------------------------------------

resource "kubernetes_annotations" "disable_gp2" {
  api_version = "storage.k8s.io/v1"
  kind        = "StorageClass"
  metadata { name = "gp2" }
  annotations = { "storageclass.kubernetes.io/is-default-class" = "false" }
  force       = true

  # Ensure this happens only after the cluster is fully up
  depends_on = [module.eks_blueprints_addons]
}

resource "kubernetes_storage_class" "default_gp3" {
  metadata {
    name        = "gp3"
    annotations = { "storageclass.kubernetes.io/is-default-class" = "true" }
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
  depends_on = [kubernetes_annotations.disable_gp2]
}

# -----------------------------------------------------------------------------
# AWS-AUTH CONFIGMAP DATA MANAGEMENT FOR KARPENTER
# -----------------------------------------------------------------------------
# This is the correct, idempotent method for adding the Karpenter node role
# to the aws-auth ConfigMap when it's managed by a separate EKS stack.
# This pattern is adapted from community best practices to be robust and safe.

# 1. A local variable to define the new role mapping we want to add.
locals {
  karpenter_node_role_map = [
    {
      rolearn  = module.eks_blueprints_addons.karpenter.node_iam_role_arn
      username = "system:node:{{EC2PrivateDNSName}}"
      groups   = [
        "system:bootstrappers",
        "system:nodes",
      ]
    }
  ]
}

# 2. A data source to read the current aws-auth ConfigMap managed by the EKS module.
data "kubernetes_config_map_v1" "aws_auth" {
  provider = kubernetes
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }
  depends_on = [module.eks_blueprints_addons]
}

# 3. The resource that takes ownership of ONLY the 'data' field of the ConfigMap.
resource "kubernetes_config_map_v1_data" "aws_auth" {
  provider = kubernetes
  force    = true # This is required to let our resource overwrite the 'data' field.

  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    # This logic safely merges the existing roles with our new Karpenter role.
    "mapRoles" = yamlencode(distinct(concat(
      # Safely decode the existing roles. If the key is missing or the value is null/empty, default to an empty list.
      yamldecode(lookup(data.kubernetes_config_map_v1.aws_auth.data, "mapRoles", "[]")),
      # Add our new Karpenter role.
      local.karpenter_node_role_map
    )))

    # We must also include the mapUsers key, even if it's empty, to avoid drift.
    # We use the same safe lookup pattern.
    "mapUsers" = lookup(data.kubernetes_config_map_v1.aws_auth.data, "mapUsers", "[]")
  }

  # This ensures we don't accidentally delete the ConfigMap.
  lifecycle {
    prevent_destroy = true
  }
}