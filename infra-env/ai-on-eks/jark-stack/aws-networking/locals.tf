locals {
  # Select a slice of the available AZs based on the user's desired number.
  azs = slice(data.aws_availability_zones.available.names, 0, var.num_azs)

  # --- IP Address Calculation using a consistent /24 block size ---
  # newbits = 8 creates /24 subnets, which provides 256 addresses per subnet.

  # Private subnets are allocated first, one per AZ.
  private_subnets = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k)]

  # Public subnets start after a large reserved block for future private subnets.
  # We reserve 128 blocks (0-127) for private subnets, so public starts at 128.
  # This avoids magic numbers and is clear about the intended separation.
  public_subnets = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 128)]
  
  # Merge user-provided tags with a mandatory tag needed for EKS.
  tags = merge(
    var.tags,
    {
      "kubernetes.io/cluster/${var.vpc_name}" = "shared"
    }
  )
}