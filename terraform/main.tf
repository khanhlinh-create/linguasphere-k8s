data "http" "current_ip" {
  count = var.admin_cidr == null ? 1 : 0

  url = "https://checkip.amazonaws.com"

  request_headers = {
    Accept = "text/plain"
  }
}

locals {
  admin_cidr = var.admin_cidr != null ? var.admin_cidr : "${chomp(data.http.current_ip[0].response_body)}/32"
  kubeconfig_ssm_parameter_name = "/${var.project_name}/${var.environment}/kubeconfig"
}

resource "aws_ssm_parameter" "kubeconfig" {
  name      = local.kubeconfig_ssm_parameter_name
  type      = "SecureString"
  value     = "PENDING_KUBECONFIG_FROM_EC2"
  overwrite = true

  lifecycle {
    ignore_changes = [value]
  }
}

module "network" {
  source = "./modules/network"

  project_name       = var.project_name
  vpc_cidr           = var.vpc_cidr
  public_subnet_cidr = var.public_subnet_cidr
  admin_cidr         = local.admin_cidr
}

module "compute" {
  source = "./modules/compute"

  subnet_id         = module.network.public_subnet_id
  security_group_id = module.network.security_group_id

  instance_type   = var.instance_type
  project_name    = var.project_name
  public_key_path = var.public_key_path

  aws_region                   = var.aws_region
  kubeconfig_ssm_parameter_name = local.kubeconfig_ssm_parameter_name

  depends_on = [aws_ssm_parameter.kubeconfig]
}

module "monitoring" {
  source = "./modules/monitoring"

  count = var.deploy_monitoring ? 1 : 0

  providers = {
    kubernetes = kubernetes.monitoring
    helm       = helm.monitoring
  }

  namespace                = var.monitoring_namespace
  release_name             = var.monitoring_release_name
  chart_version            = var.monitoring_chart_version
  grafana_admin_password = data.aws_secretsmanager_secret_version.grafana_password.secret_string
  grafana_service_type     = var.grafana_service_type
  prometheus_service_type  = var.prometheus_service_type
  helm_values              = var.monitoring_helm_values
  wait                     = var.monitoring_wait
  timeout                  = var.monitoring_timeout

  depends_on = [module.compute]
}

data "aws_secretsmanager_secret" "grafana_password" {
  name = "/${var.project_name}/${var.environment}/grafana-admin"
}

data "aws_secretsmanager_secret_version" "grafana_password" {
  secret_id = data.aws_secretsmanager_secret.grafana_password.id
}