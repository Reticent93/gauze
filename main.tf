terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.36.0"
    }
  }

  backend "s3" {
    bucket       = "gauze-tfstate-738959335084"
    key          = "gauze/terraform.tfstate"
    region       = "us-west-2"
    profile      = "gauze"
    use_lockfile = true
  }
}

data "aws_caller_identity" "current" {}