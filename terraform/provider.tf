terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

data "aws_ssm_parameter" "kubeconfig" {
  count           = var.deploy_monitoring ? 1 : 0
  name            = local.kubeconfig_ssm_parameter_name
  with_decryption = true
}

locals {
  kubeconfig_raw = var.deploy_monitoring ? data.aws_ssm_parameter.kubeconfig[0].value : ""
  kubeconfig_obj = var.deploy_monitoring ? try(yamldecode(local.kubeconfig_raw), null) : null

  kubeconfig_current_context = local.kubeconfig_obj != null ? try(local.kubeconfig_obj["current-context"], null) : null

  kubeconfig_context = local.kubeconfig_obj != null && local.kubeconfig_current_context != null ? (
    try(
      [for c in local.kubeconfig_obj.contexts : c.context if c.name == local.kubeconfig_current_context][0],
      null
    )
  ) : null

  kubeconfig_cluster_name = local.kubeconfig_context != null ? try(local.kubeconfig_context.cluster, null) : null
  kubeconfig_user_name    = local.kubeconfig_context != null ? try(local.kubeconfig_context.user, null) : null

  kubeconfig_cluster = local.kubeconfig_obj != null && local.kubeconfig_cluster_name != null ? (
    try(
      [for c in local.kubeconfig_obj.clusters : c.cluster if c.name == local.kubeconfig_cluster_name][0],
      null
    )
  ) : null

  kubeconfig_user = local.kubeconfig_obj != null && local.kubeconfig_user_name != null ? (
    try(
      [for u in local.kubeconfig_obj.users : u.user if u.name == local.kubeconfig_user_name][0],
      null
    )
  ) : null

  monitoring_host                   = var.deploy_monitoring ? try(local.kubeconfig_cluster.server, null) : null
  monitoring_cluster_ca_certificate = var.deploy_monitoring ? try(base64decode(local.kubeconfig_cluster["certificate-authority-data"]), null) : null
  monitoring_client_certificate     = var.deploy_monitoring ? try(base64decode(local.kubeconfig_user["client-certificate-data"]), null) : null
  monitoring_client_key             = var.deploy_monitoring ? try(base64decode(local.kubeconfig_user["client-key-data"]), null) : null
}

check "monitoring_kubeconfig_ready" {
  assert {
    condition = !var.deploy_monitoring || (
      local.kubeconfig_obj != null &&
      local.monitoring_host != null &&
      local.monitoring_client_certificate != null &&
      local.monitoring_client_key != null
    )
    error_message = "deploy_monitoring=true but kubeconfig in SSM is not ready/valid yet. Fetch it and verify it starts with 'apiVersion: v1', or wait for EC2 bootstrap to publish it."
  }
}

provider "kubernetes" {
  alias = "monitoring"

  host                   = local.monitoring_host
  cluster_ca_certificate = local.monitoring_cluster_ca_certificate
  client_certificate     = local.monitoring_client_certificate
  client_key             = local.monitoring_client_key
}

provider "helm" {
  alias = "monitoring"

  kubernetes = {
    host                   = local.monitoring_host
    cluster_ca_certificate = local.monitoring_cluster_ca_certificate
    client_certificate     = local.monitoring_client_certificate
    client_key             = local.monitoring_client_key
  }
}