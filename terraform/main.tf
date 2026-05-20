module "network" {
  source = "./modules/network"

  project_name       = var.project_name
  vpc_cidr           = var.vpc_cidr
  public_subnet_cidr = var.public_subnet_cidr
  admin_cidr         = var.admin_cidr
}

module "compute" {
  source = "./modules/compute"

  subnet_id         = module.network.public_subnet_id
  security_group_id = module.network.security_group_id

  instance_type   = var.instance_type
  project_name    = var.project_name
  public_key_path = var.public_key_path
  ami_id          = var.ami_id
}