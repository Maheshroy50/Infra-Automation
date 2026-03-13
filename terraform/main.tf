terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
  required_version = ">= 1.2.0"
}

provider "aws" {
  region = var.aws_region
}

module "app_server" {
  source = "./modules/app_server"

  app_name         = var.app_name
  instance_type    = var.instance_type
  repository_url   = var.repository_url
  allowed_ssh_cidr = var.allowed_ssh_cidr
  vpc_id           = var.vpc_id
  subnet_id        = var.subnet_id
}
