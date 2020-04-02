provider "aws" {
  region = var.region
}

module "networking" {
  source = "./vpc"

  region = var.region
  zone   = var.zone
}

module "security_group" {
  source = "./security_group"

  vpc_id = module.networking.vpc_id
}

resource "aws_lb" "lb" {
  name               = "kubernetes-the-hard-way-${terraform.workspace}"
  internal           = false
  load_balancer_type = "network"
  ip_address_type    = "ipv4"

  tags = {
    Name        = "kubernetes-the-hard-way-${terraform.workspace}"
    ManagedBy   = "Terraform"
    Environment = terraform.workspace
  }

  subnet_mapping {
    subnet_id     = module.networking.subnet_id
    allocation_id = aws_eip.lb.id
  }
}

resource "aws_lb_target_group" "cluster" {
  name     = "kubernetes-the-hard-way-${terraform.workspace}"
  port     = 6443
  protocol = "TCP"
  vpc_id   = module.networking.vpc_id

  tags = {
    Name        = "kubernetes-the-hard-way-${terraform.workspace}"
    ManagedBy   = "Terraform"
    Environment = terraform.workspace
  }

  health_check {
    protocol            = "HTTPS"
    path                = "/healthz"
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.lb.arn
  port              = 6443
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.cluster.arn
  }
}

resource "aws_eip" "lb" {
  tags = {
    Name        = "kubernetes-the-hard-way-${terraform.workspace}"
    ManagedBy   = "Terraform"
    Environment = terraform.workspace
  }
}

resource "aws_lb_target_group_attachment" "controller" {
  count = length(module.nodes.controller_ids)

  target_group_arn = aws_lb_target_group.cluster.arn
  target_id        = module.nodes.controller_ids[count.index]
  port             = 6443
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

module "configuration" {
  source = "./cluster_configuration"

  cluster_ips               = module.nodes.cluster_ips
  ssh_key                   = module.nodes.ssh_key
  KUBERNETES_PUBLIC_ADDRESS = aws_eip.lb.public_ip
}
