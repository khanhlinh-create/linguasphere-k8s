variable "namespace" {
  type    = string
  default = "monitoring"
}

variable "release_name" {
  type    = string
  default = "kube-prometheus-stack"
}

variable "chart_version" {
  type    = string
  default = "57.2.0"
}

variable "grafana_admin_password" {
  type      = string
  sensitive = true
  default   = "admin"
}

variable "grafana_service_type" {
  type    = string
  default = "ClusterIP"
}

variable "prometheus_service_type" {
  type    = string
  default = "ClusterIP"
}

variable "helm_values" {
  description = "Optional extra Helm values YAML (merged after defaults)."
  type        = string
  default     = null
}

variable "wait" {
  type    = bool
  default = true
}

variable "timeout" {
  type    = number
  default = 600
}
