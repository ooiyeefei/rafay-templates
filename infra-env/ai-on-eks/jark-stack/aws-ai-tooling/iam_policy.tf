# This file contains the IAM policy document required by the Karpenter controller
# to manage EC2 instances, launch templates, and other AWS resources.

data "aws_iam_policy_document" "karpenter_controller" {
  statement {
    sid    = "Karpenter"
    effect = "Allow"
    actions = [
      "ec2:CreateLaunchTemplate",
      "ec2:CreateFleet",
      "ec2:RunInstances",
      "ec2:CreateTags",
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribeInstances",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeInstanceTypeOfferings",
      "ec2:DescribeAvailabilityZones",
      "ec2:DeleteLaunchTemplate",
      "ec2:TerminateInstances",
      "ec2:DescribeImages",
      "iam:PassRole",
      "ssm:GetParameter",
      "pricing:GetProducts"
    ]
    resources = ["*"]
  }
}