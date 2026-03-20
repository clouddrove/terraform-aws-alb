# Terraform version
terraform {
  required_version = ">= 1.6.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.31.0"
    }
  }

  provider_meta "aws" {
    module_name = "clouddrove/terraform-aws-alb"
  }
}
