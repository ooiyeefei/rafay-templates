provider "aws" {
  region = var.aws_region
}

provider "aws" {
  alias  = "ecr"
  region = "us-east-1"
}