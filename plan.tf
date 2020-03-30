provider "aws" {
  region = var.region
}

module "networking" {
  source = "./vpc"

  region    = var.region
  zone      = var.zone
  stub_zone = var.stub_zone
}

module "security_group" {
  source = "./security_group"

  vpc_id = module.networking.vpc_id
}

resource "aws_lb" "lb" {
  name               = "kubernetes-the-hard-way-${terraform.workspace}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [module.security_group.id]
  subnets            = [module.networking.subnet_id, module.networking.stub_id]
  ip_address_type    = "ipv4"

  tags = {
    Name        = "kubernetes-the-hard-way-${terraform.workspace}"
    ManagedBy   = "Terraform"
    Environment = terraform.workspace
  }
}

module "nodes" {
  source = "./nodes"

  zone                     = var.zone
  n_workers                = var.n_workers
  n_controllers            = var.n_controllers
  worker_instance_type     = var.worker_instance_type
  controller_instance_type = var.controller_instance_type
  subnet_id                = module.networking.subnet_id
  security_group_id        = module.security_group.id
}
