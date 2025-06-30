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
# Cluster
################################################################################

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
  eks_managed_node_groups = {
    # General purpose node group for basic workloads
    general = {
      name = "general"

      subnet_ids = module.vpc.private_subnets

      min_size     = 1
      max_size     = 5
      desired_size = 2

      instance_types = ["t3.medium", "t3.large"]
      capacity_type  = "ON_DEMAND"

      iam_role_additional_policies = {
        AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      }

      # Enable detailed monitoring
      enable_monitoring = true

      # Disk configuration
      disk_size = 20
      disk_type = "gp3"

      # Labels and taints
      labels = {
        Environment = var.name
        NodeGroup   = "general"
      }

      # Tags
      tags = {
        ExtraTag = "general-node-group"
      }
    }

    # GPU node group for ML workloads
    gpu = {
      name = "gpu"

      subnet_ids = module.vpc.private_subnets

      min_size     = 0
      max_size     = 3
      desired_size = 0  # Start with 0, scale up as needed

      instance_types = ["g5.xlarge", "g5.2xlarge", "g5.4xlarge"]
      capacity_type  = "ON_DEMAND"

      iam_role_additional_policies = {
        AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      }

      # Enable detailed monitoring
      enable_monitoring = true

      # Disk configuration
      disk_size = 50
      disk_type = "gp3"

      # Labels and taints for GPU workloads
      labels = {
        Environment = var.name
        NodeGroup   = "gpu"
        accelerator = "nvidia"
      }

      taints = [{
        key    = "nvidia.com/gpu"
        value  = "true"
        effect = "NO_SCHEDULE"
      }]

      # Tags
      tags = {
        ExtraTag = "gpu-node-group"
      }
    }

    # Spot node group for cost optimization
    spot = {
      name = "spot"

      subnet_ids = module.vpc.private_subnets

      min_size     = 0
      max_size     = 5
      desired_size = 0  # Start with 0, scale up as needed

      instance_types = ["t3.medium", "t3.large", "c6i.large", "m6i.large"]
      capacity_type  = "SPOT"

      iam_role_additional_policies = {
        AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      }

      # Enable detailed monitoring
      enable_monitoring = true

      # Disk configuration
      disk_size = 20
      disk_type = "gp3"

      # Labels and taints for spot instances
      labels = {
        Environment = var.name
        NodeGroup   = "spot"
      }

      taints = [{
        key    = "spot"
        value  = "true"
        effect = "NO_SCHEDULE"
      }]

      # Tags
      tags = {
        ExtraTag = "spot-node-group"
      }
    }
  }

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
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.eks_node_sg.id
  self              = true
  description       = "Node to node all ports/protocols"
}

resource "aws_security_group_rule" "nodes_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.eks_node_sg.id
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]
  description       = "Node all egress"
}

resource "aws_security_group_rule" "nodes_ingress_from_vpc_on_8080" {
  type              = "ingress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  security_group_id = aws_security_group.eks_node_sg.id
  cidr_blocks       = [module.vpc.vpc_cidr_block]
  description       = "Allow NLB traffic to nodes on application port 8080"
}

resource "aws_security_group_rule" "nodes_allow_internet_to_openwebui" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.eks_node_sg.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow internet traffic to OpenWebUI pods via NLB"
}

# --- Rules for the Cluster Security Group ---

resource "aws_security_group_rule" "cluster_ingress_from_nodes" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_cluster_sg.id # <-- Use our SG ID
  source_security_group_id = aws_security_group.eks_node_sg.id # <-- Use our SG ID
  description              = "Node groups to cluster API"
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