provider "aws" {
  region = var.region
}

module "infrastructure" {
  source = "./infrastructure"

  region                   = var.region
  zone                     = var.zone
  n_workers                = var.n_workers
  n_controllers            = var.n_controllers
  worker_instance_type     = var.worker_instance_type
  controller_instance_type = var.controller_instance_type
}

module "configuration" {
  source = "./cluster_configuration"

  cluster_ips               = module.infrastructure.cluster_ips
  ssh_key                   = module.infrastructure.ssh_key
  KUBERNETES_PUBLIC_ADDRESS = module.infrastructure.KUBERNETES_PUBLIC_ADDRESS
}
