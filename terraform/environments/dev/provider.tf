terraform {
  required_version = ">= 1.6.0"

backend "s3" {
    bucket = "tradevault-terraform-state-230470759616-us-east-2"
    key = "tradevault/dev/terraform.tfstate"
    region = "us-east-2"
    encrypt = true
    use_lockfile = true
}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}