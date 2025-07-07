#---------------------------------------
# Data Sources for Context
#---------------------------------------
data "aws_caller_identity" "current" {}

#---------------------------------------
# Local Variables for Add-on Logic
#---------------------------------------
locals {
  # This logic is preserved directly from the source. It allows enabling/disabling
  # addons via a map and merges in specific configurations for addons that need them.
  base_addons = {
    for name, enabled in var.enable_cluster_addons :
    name => {} if enabled
  }

  addon_overrides = {
    vpc-cni = {
      most_recent    = true
      before_compute = true
    }
    eks-pod-identity-agent = {
      before_compute = true
    }
    aws-ebs-csi-driver = {
      service_account_role_arn = module.ebs_csi_driver_irsa.iam_role_arn
      most_recent              = true
    }
    amazon-cloudwatch-observability = {
      preserve                 = true
      service_account_role_arn = aws_iam_role.cloudwatch_observability_role.arn
    }
  }

  cluster_addons = {
    for name, config in local.base_addons :
    name => merge(config, lookup(local.addon_overrides, name, {}))
  }
}

#---------------------------------------------------------------
# EKS Cluster Module
#---------------------------------------------------------------
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.3" # Pinned to a known compatible version from the source

  cluster_name    = var.cluster_name
  cluster_version = var.eks_cluster_version

  # This is a direct input now, wired from the VPC template in Rafay.
  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids # CRITICAL CHANGE: Using the simplified variable directly

  # Authentication and Access
  authentication_mode                      = "API_AND_CONFIG_MAP"
  enable_cluster_creator_admin_permissions = true
  cluster_endpoint_public_access           = var.cluster_endpoint_public_access

  # Addons Configuration
  cluster_addons = local.cluster_addons

  # KMS Admin roles for the cluster encryption key
  kms_key_administrators = distinct(concat(
    ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"],
    var.kms_key_admin_roles,
    [data.aws_caller_identity.current.arn]
  ))

  # Security Group Rules
  enable_efa_support = true
  cluster_security_group_additional_rules = {
    ingress_nodes_ephemeral_ports_tcp = {
      description                = "Nodes on ephemeral ports"
      protocol                   = "tcp"
      from_port                  = 0
      to_port                    = 65535
      type                       = "ingress"
      source_node_security_group = true
    }
  }
  node_security_group_additional_rules = {
    ingress_cluster_to_node_all_traffic = {
      description                   = "Cluster API to Nodegroup all traffic"
      protocol                      = "-1"
      from_port                     = 0
      to_port                       = 0
      type                          = "ingress"
      source_cluster_security_group = true
    },
    ingress_self_all = {
      description = "Node to node all traffic"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true # This tells the SG to allow traffic from itself
    }
  }

  # Default settings for all managed node groups created by this module
  eks_managed_node_group_defaults = {
    iam_role_additional_policies = {
      AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    }
    ebs_optimized = true
    block_device_mappings = {
      xvda = {
        device_name = "/dev/xvda"
        ebs = {
          volume_size = 100
          volume_type = "gp3"
        }
      }
    }
  }

  # The primary node group for core services
  eks_managed_node_groups = {
    core_node_group = {
      name           = "core-node-group"
      description    = "EKS Core node group for hosting system add-ons"
      subnet_ids     = var.private_subnet_ids # CRITICAL CHANGE: Using the simplified variable
      ami_type       = "AL2023_x86_64_STANDARD"
      min_size       = var.core_node_min_size
      max_size       = var.core_node_max_size
      desired_size   = var.core_node_desired_size
      instance_types = var.core_node_instance_types
      labels = {
        WorkerType    = "ON_DEMAND"
        NodeGroupType = "core"
      }
      taints = [{
        key    = "CriticalAddonsOnly"
        value  = "true"
        effect = "NO_SCHEDULE"
      }]
      tags = var.tags
    }
    # UNTAINTED group for general-purpose pods like Rafay agents or external workload.
    general_purpose_group = {
      name           = "general-purpose-group"
      description    = "Node group for general workloads and third-party agents"
      subnet_ids     = var.private_subnet_ids
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["t3.xlarge"]
      min_size       = 1
      max_size       = 2
      desired_size   = 1
      labels = {
        WorkerType    = "ON_DEMAND"
        NodeGroupType = "general-purpose"
      }
      
      tags = var.tags
    }
  }

  tags = var.tags
}

#---------------------------------------------------------------
# IAM Role for CloudWatch Observability Add-on
#---------------------------------------------------------------
resource "aws_iam_role" "cloudwatch_observability_role" {
  name = "${var.cluster_name}-eks-cw-agent-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRoleWithWebIdentity"
      Effect    = "Allow"
      Principal = { Federated = module.eks.oidc_provider_arn }
      Condition = {
        StringEquals = {
          "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub" : "system:serviceaccount:amazon-cloudwatch:cloudwatch-agent",
          "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud" : "sts.amazonaws.com"
        }
      }
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "cloudwatch_observability_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.cloudwatch_observability_role.name
}

#---------------------------------------------------------------
# IAM Role for Service Account (IRSA) for EBS CSI Driver
#---------------------------------------------------------------
module "ebs_csi_driver_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.39"

  role_name_prefix = format("%s-%s-", var.cluster_name, "ebs-csi")
  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
  tags = var.tags
}

#---------------------------------------------------------------
# IAM Role for Service Account (IRSA) for EFS CSI Driver
#---------------------------------------------------------------
module "efs_csi_driver_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.39" # Use the same version as your other module

  role_name_prefix = format("%s-%s-", var.cluster_name, "efs-csi")
  attach_efs_csi_policy = true # This is the key flag for EFS

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      # The default service account for the EFS CSI controller
      namespace_service_accounts = ["kube-system:efs-csi-controller-sa"]
    }
  }
  tags = var.tags
}