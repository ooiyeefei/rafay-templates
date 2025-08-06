# ------------------------------------------------------------------------------
# Local Variables
#
# Creates a standardized naming prefix and other local values from the input
# variables to ensure resource uniqueness and consistency.
# ------------------------------------------------------------------------------
locals {
  # Prepends resource names with the first 5 chars of the env name for uniqueness
  name_prefix = substr(var.environment_name, 0, 5)
  ssh_user    = "ubuntu"
  # Creates a dynamic key pair name from the full environment name
  key_name    = "${var.environment_name}-keypair"
}

# ------------------------------------------------------------------------------
# Key Pair
#
# Creates a new RSA key pair for SSH access and stores the private key
# securely in AWS SSM Parameter Store. The key name is dynamic based on the
# injected environment name.
# ------------------------------------------------------------------------------
resource "tls_private_key" "agent_host_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "agent_host_key_pair" {
  key_name   = local.key_name
  public_key = tls_private_key.agent_host_key.public_key_openssh
}

resource "aws_ssm_parameter" "ssh_private_key" {
  name        = "/ec2/keypair/${aws_key_pair.agent_host_key_pair.id}"
  description = "Private key for the agent host instance. Do not expose."
  type        = "SecureString"
  value       = tls_private_key.agent_host_key.private_key_pem
  tags = {
    Name = "${local.name_prefix}-ssh-key"
  }
}

# ------------------------------------------------------------------------------
# Networking
#
# Sets up the VPC and related networking resources. The 'Name' tags are all
# prepended with the 5-character prefix from the environment name for uniqueness.
# ------------------------------------------------------------------------------
resource "aws_vpc" "agent_host_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "${local.name_prefix}-AgentHostVPC"
  }
}

resource "aws_subnet" "agent_host_public_subnet" {
  vpc_id                  = aws_vpc.agent_host_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]
  tags = {
    Name = "${local.name_prefix}-PublicSubnet"
  }
}

resource "aws_internet_gateway" "agent_host_igw" {
  vpc_id = aws_vpc.agent_host_vpc.id
  tags = {
    Name = "${local.name_prefix}-AgentHostIGW"
  }
}

resource "aws_route_table" "agent_host_public_rt" {
  vpc_id = aws_vpc.agent_host_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.agent_host_igw.id
  }
  tags = {
    Name = "${local.name_prefix}-PublicRouteTable"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.agent_host_public_subnet.id
  route_table_id = aws_route_table.agent_host_public_rt.id
}

resource "aws_security_group" "agent_host_sg" {
  name        = "${local.name_prefix}-agent-host-sg"
  description = "Allow SSH and enable SSM for the agent host"
  vpc_id      = aws_vpc.agent_host_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow SSH access from anywhere"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-agent-host-sg"
  }
}

# ------------------------------------------------------------------------------
# IAM Role and Policies
#
# The IAM Role name is prepended with the 5-character prefix to ensure it is
# unique within the AWS account.
# ------------------------------------------------------------------------------
resource "aws_iam_role" "agent_host_role" {
  name = "${local.name_prefix}-AgentHostComputeRole"
  path = "/"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
  tags = {
    Name = "${local.name_prefix}-AgentHostComputeRole"
  }
}

# This policy attachment is critical for allowing SSM / Instance Connect.
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.agent_host_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "eks_worker_policy" {
  role       = aws_iam_role.agent_host_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_policy" "ebs_csi_policy" {
  name        = "${local.name_prefix}-EbsCsiDriverPolicy"
  description = "Policy required by the AWS EBS CSI driver."
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "ec2:CreateSnapshot",
          "ec2:AttachVolume",
          "ec2:DetachVolume",
          "ec2:ModifyVolume",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeInstances",
          "ec2:DescribeSnapshots",
          "ec2:DescribeTags",
          "ec2:DescribeVolumes",
          "ec2:DescribeVolumesModifications"
        ],
        "Resource" : "*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "ec2:CreateTags"
        ],
        "Resource" : [
          "arn:aws:ec2:*:*:volume/*",
          "arn:aws:ec2:*:*:snapshot/*"
        ],
        "Condition" : {
          "StringEquals" : {
            "ec2:CreateAction" : [
              "CreateVolume",
              "CreateSnapshot"
            ]
          }
        }
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "ec2:DeleteSnapshot"
        ],
        "Resource" : "*",
        "Condition" : {
          "StringLike" : {
            "ec2:ResourceTag/ebs.csi.aws.com/cluster" : "true"
          }
        }
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "ec2:DeleteTags"
        ],
        "Resource" : [
          "arn:aws:ec2:*:*:volume/*",
          "arn:aws:ec2:*:*:snapshot/*"
        ],
        "Condition" : {
          "Null" : {
            "ec2:CreateAction" : "false"
          }
        }
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "ec2:DeleteVolume"
        ],
        "Resource" : "*",
        "Condition" : {
          "StringLike" : {
            "ec2:ResourceTag/csi.volume.kubernetes.io/clusterid" : "*"
          }
        }
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "ec2:CreateVolume"
        ],
        "Resource" : "*",
        "Condition" : {
          "StringLike" : {
            "aws:RequestTag/ebs.csi.aws.com/cluster" : "true"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ebs_csi_policy_attachment" {
  role       = aws_iam_role.agent_host_role.name
  policy_arn = aws_iam_policy.ebs_csi_policy.arn
}

resource "aws_iam_instance_profile" "agent_host_profile" {
  name = "${local.name_prefix}-AgentHostInstanceProfile"
  role = aws_iam_role.agent_host_role.name
}


# ------------------------------------------------------------------------------
# Data Sources
# ------------------------------------------------------------------------------
data "aws_availability_zones" "available" {
  state = "available"
}

# CHANGED: This data source now looks for a non-Graviton (x86_64) AMI.
data "aws_ami" "ubuntu_x86" {
  most_recent = true
  owners      = ["099720109477"] # Canonical's AWS account ID

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# ------------------------------------------------------------------------------
# EC2 Instance
#
# This is the main compute resource. It uses the variables and resources
# defined above to launch a configured EC2 instance.
# ------------------------------------------------------------------------------
resource "aws_instance" "agent_host_instance" {
  instance_type          = var.instance_type
  # CHANGED: Use the x86_64 AMI found above
  ami                    = data.aws_ami.ubuntu_x86.id
  subnet_id              = aws_subnet.agent_host_public_subnet.id
  vpc_security_group_ids = [aws_security_group.agent_host_sg.id]
  key_name               = aws_key_pair.agent_host_key_pair.key_name
  iam_instance_profile   = aws_iam_instance_profile.agent_host_profile.name

  root_block_device {
    volume_size           = var.root_volume_size_gib
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required" # Enforces IMDSv2
  }

  # CHANGED: User data now installs the x86_64 version of the AWS CLI.
  user_data = <<-EOF
    #!/bin/bash
    set -e -x

    # Update system and install basic packages including bzip2
    apt-get update -y
    apt-get upgrade -y
    apt-get install -y curl wget unzip git htop bzip2

    # Install AWS CLI v2 for x86_64
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    ./aws/install
    rm -rf awscliv2.zip aws

    # Install Docker
    apt-get install -y docker.io
    systemctl enable --now docker
    usermod -aG docker ${local.ssh_user}

    # Ensure SSM Agent is running for Session Manager / Instance Connect
    systemctl enable --now snap.amazon-ssm-agent.amazon-ssm-agent.service || true

    # Setup complete
    echo "Agent host setup complete"
  EOF

  tags = {
    Name = "${var.environment_name}-AgentHost"
  }
}