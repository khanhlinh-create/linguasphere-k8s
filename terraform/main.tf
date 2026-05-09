module "network" {
  source = "./modules/network"

  project_name = var.project_name
}

module "compute" {
  source = "./modules/compute"

  subnet_id         = module.network.public_subnet_id
  security_group_id = module.network.security_group_id

  instance_type = var.instance_type
  project_name  = var.project_name
}