variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "ap-southeast-2"
}

variable "project_name" {
  description = "Project name for tagging"
  type        = string
  default     = "linguasphere"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.medium"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.10.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet"
  type        = string
  default     = "10.10.1.0/24"
}

variable "admin_cidr" {
  description = "Public IP in CIDR format. If omitted, Terraform auto-detects it via checkip.amazonaws.com."
  type        = string
  default     = null
}

variable "public_key_path" {
  description = "Path to SSH public key"
  type        = string
  default     = "./linguasphere-k3s-key.pub"
}

variable "private_key_path" {
  description = "Path to SSH private key used to connect to the EC2 instance"
  type        = string
  default     = "~/.ssh/linguasphere-k3s-key"
}

variable "deploy_monitoring" {
  description = "Whether to deploy monitoring via Helm (requires local kubeconfig access to the cluster)."
  type        = bool
  default     = false
}

variable "monitoring_namespace" {
  description = "Kubernetes namespace for monitoring stack"
  type        = string
  default     = "monitoring"
}

variable "monitoring_release_name" {
  description = "Helm release name for kube-prometheus-stack"
  type        = string
  default     = "kube-prometheus-stack"
}

variable "monitoring_chart_version" {
  description = "Helm chart version for kube-prometheus-stack"
  type        = string
  default     = "57.2.0"
}


variable "grafana_service_type" {
  description = "Grafana service type (ClusterIP/NodePort/LoadBalancer)"
  type        = string
  default     = "ClusterIP"
}

variable "prometheus_service_type" {
  description = "Prometheus service type (ClusterIP/NodePort/LoadBalancer)"
  type        = string
  default     = "ClusterIP"
}

variable "monitoring_helm_values" {
  description = "Optional extra Helm values YAML for monitoring"
  type        = string
  default     = null
}

variable "monitoring_wait" {
  description = "Wait for all resources to be ready when installing monitoring"
  type        = bool
  default     = true
}

variable "monitoring_timeout" {
  description = "Timeout (seconds) for Helm install/upgrade of monitoring"
  type        = number
  default     = 600
}