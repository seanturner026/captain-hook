terraform {
  backend "s3" {
    bucket               = "sean-terraform"
    region               = "us-east-1"
    workspace_key_prefix = "aws/lot-rat"
    key                  = "terraform.tfstate"
  }
}

provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = {
      project   = "lot-rat"
      workspace = terraform.workspace
    }
  }
}
