################################################################################
# Self-Managed Security Groups
# We create these ourselves to have full, reliable control over their rules.
################################################################################

resource "aws_security_group" "eks_cluster_sg" {
  name        = "${var.name}-cluster"
  description = "EKS cluster security group"
  vpc_id      = module.vpc.vpc_id

  tags = merge(
    local.tags,
    {
      Name = "${var.name}-cluster"
    },
  )
}

resource "aws_security_group" "eks_node_sg" {
  name        = "${var.name}-nodes"
  description = "EKS node shared security group"
  vpc_id      = module.vpc.vpc_id

  tags = merge(
    local.tags,
    {
      "Name"                                   = "${var.name}-nodes"
      "kubernetes.io/cluster/${var.name}" = "owned"
    },
  )
}

################################################################################
# Essential Communication Rules
# Step 2: Create the minimum rules needed for nodes to join the cluster.
# These are created BEFORE the EKS module is called.
################################################################################

# Rule 1: Allow all outbound traffic from nodes to the internet.
# NECESSARY for nodes to pull container images and talk to AWS APIs.
resource "aws_security_group_rule" "nodes_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.eks_node_sg.id
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]
  description       = "Essential: Node all egress to internet"
}

# Rule 2: Allow the cluster control plane to communicate with the nodes.
# NECESSARY for the control plane to manage kubelets and webhooks.
resource "aws_security_group_rule" "cluster_ingress_to_nodes" {
  type                     = "ingress"
  from_port                = 0 # Allow all ports for simplicity, can be locked down further if needed.
  to_port                  = 0
  protocol                 = "-1" # Allow all protocols
  security_group_id        = aws_security_group.eks_node_sg.id
  source_security_group_id = aws_security_group.eks_cluster_sg.id
  description              = "Essential: Allow cluster control plane to talk to nodes"
}

# Rule 3: Allow nodes to communicate with the cluster control plane API.
# NECESSARY for nodes to register and get workloads.
resource "aws_security_group_rule" "nodes_ingress_from_cluster" {
  type                     = "ingress"
  from_port                = 443 # HTTPS port for the API server
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_cluster_sg.id
  source_security_group_id = aws_security_group.eks_node_sg.id
  description              = "Essential: Allow nodes to talk to cluster API"
}

################################################################################
# Cluster
################################################################################
locals {
  # 1. User-defined settings remain the same.
  gpu_user_settings = {
    enabled      = true
    desired_size = var.gpu_node_count
    min_size     = var.gpu_node_count > 0 ? 1 : 0
  }

  spot_user_settings = {
    enabled      = true
    desired_size = var.spot_node_count
    min_size     = var.spot_node_count > 0 ? 1 : 0
  }

  # 2. Build the final configurations by conditionally merging.
  #    This version solves the type consistency error.
  final_configs = {
    for key, base_config in var.node_group_configurations :
    key => merge(
      base_config,

      # GPU Override:
      # This expression now does two things:
      # a) It uses a null map in the 'false' case to satisfy Terraform's type checker.
      # b) It then filters out any keys with 'null' values, resulting in an empty map ({})
      #    if the condition is false. This prevents accidental overwrites on other node groups.
      {
        for k, v in (key == "gpu" && var.enable_gpu_nodes ? local.gpu_user_settings : { enabled = null, desired_size = null, min_size = null }) : k => v if v != null
      },

      # SPOT Override (same pattern):
      {
        for k, v in (key == "spot" && var.enable_spot_nodes ? local.spot_user_settings : { enabled = null, desired_size = null, min_size = null }) : k => v if v != null
      }
    )
  }

  # 3. This final block remains UNCHANGED. It takes the correctly-built 'final_configs'
  #    map from above and prepares it for the EKS module by filtering out disabled groups.
  enabled_node_groups = {
    for key, config in local.final_configs : key => {
      name                         = key
      min_size                     = config.min_size
      max_size                     = config.max_size
      desired_size                 = config.desired_size
      instance_types               = config.instance_types
      capacity_type                = config.capacity_type
      disk_size                    = config.disk_size
      disk_type                    = config.disk_type
      labels                       = merge({ Environment = var.name }, config.labels)
      taints                       = config.taints
      subnet_ids                   = module.vpc.private_subnets
      enable_monitoring            = true
      iam_role_additional_policies = {
        AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      }
      tags = {
        "Name"     = "${var.name}-${key}-node-group"
        "ExtraTag" = "${key}-node-group"
      }
    } if config.enabled
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.24"

  cluster_name    = var.name
  cluster_version = var.eks_cluster_version

  # Give the Terraform identity admin access to the cluster
  # which will allow it to deploy resources into the cluster
  enable_cluster_creator_admin_permissions = true
  cluster_endpoint_public_access           = true

  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  create_cluster_security_group = false
  cluster_security_group_id   = aws_security_group.eks_cluster_sg.id

  create_node_security_group = false
  node_security_group_id   = aws_security_group.eks_node_sg.id

  # Add managed node groups
  eks_managed_node_groups = local.enabled_node_groups

  # Cluster add-ons
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent = true
    }
    eks-pod-identity-agent = {
      most_recent = true
    }
  }
  tags = local.tags
} 

# --- Rules for the Node Security Group ---

resource "aws_security_group_rule" "nodes_ingress_self" {
  depends_on = [module.eks]

  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.eks_node_sg.id
  self              = true
  description       = "Node to node all ports/protocols"
}

resource "aws_security_group_rule" "nodes_ingress_from_vpc_on_8080" {
  depends_on = [module.eks]

  type              = "ingress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  security_group_id = aws_security_group.eks_node_sg.id
  cidr_blocks       = [module.vpc.vpc_cidr_block]
  description       = "Allow NLB traffic to nodes on application port 8080"
}

resource "aws_security_group_rule" "nodes_allow_internet_to_openwebui" {
  depends_on = [module.eks]

  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.eks_node_sg.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow internet traffic to OpenWebUI pods via NLB"
}

################################################################################
# Create the Kubernetes Service Account
################################################################################

module "aws_load_balancer_controller_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.39"

  role_name_prefix = "${var.name}-LBCRole"

  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = local.tags
}

resource "kubernetes_service_account" "alb_sa" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/name"      = "aws-load-balancer-controller"
      "app.kubernetes.io/component" = "controller"
    }
    annotations = {
      # Links the Service Account to the IAM Role we created.
      "eks.amazonaws.com/role-arn" = module.aws_load_balancer_controller_irsa_role.iam_role_arn
      
      # Best-practice annotation for STS endpoints.
      "eks.amazonaws.com/sts-regional-endpoints" = "true"
    }
  }
  depends_on = [module.eks]
}

################################################################################
# Install the AWS Load Balancer Controller using the Helm provider
################################################################################

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  depends_on = [
    kubernetes_service_account.alb_sa
  ]

  set = [
    {
      name  = "serviceAccount.create"
      value = "false"
    },
    {
      name  = "serviceAccount.name"
      value = "aws-load-balancer-controller"
    },
    {
      name  = "clusterName"
      value = var.name
    },
    {
      name  = "region"
      value = var.region
    },
    {
      name  = "vpcId"
      value = module.vpc.vpc_id
    }
  ]
}

################################################################################
# Install KubeRay Operator (Shared, Cluster-Wide Platform Component)
################################################################################

resource "helm_release" "kuberay_operator" {
  name             = "kuberay-operator"
  repository       = "https://ray-project.github.io/kuberay-helm/"
  chart            = "kuberay-operator"
  version          = "1.4.0"
  namespace        = "kuberay-system"
  create_namespace = true

  depends_on = [
    helm_release.aws_load_balancer_controller,
    helm_release.apply-volcano
  ]
}

resource "helm_release" "apply-volcano" {
  name             = "volcano"
  repository       = "https://volcano-sh.github.io/helm-charts/"
  chart            = "volcano"
  version          = "1.12.1"
  namespace        = "volcano-system"
  create_namespace = true

  depends_on = [helm_release.aws_load_balancer_controller]
}