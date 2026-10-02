terraform {
  required_version = ">= 1.5.0"

  required_providers {
  aws = {
    source = "hashicorp/aws"
    version = "~> 5.0"
   }
  }
  # Configure Terraform to store state remotely in AWS S3
  backend "s3" {
    bucket =             "mgumto-tf-state-cross-cloud"
    key    =             "aws-azure-cross-cloud-network/terraform.tfstate"
    region =             "us-east-1"

    # Enable state locking via DynamoDB
    dynamodb_table = "terraform-locks-cross-cloud"
    encrypt            = true
  }
}

provider "aws" {
    region = "us-east-1"
}