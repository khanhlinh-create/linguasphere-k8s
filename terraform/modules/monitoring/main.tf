locals {
  default_values_yaml = <<-YAML
grafana:
  adminPassword: "${var.grafana_admin_password}"
  service:
    type: ${var.grafana_service_type}

prometheus:
  service:
    type: ${var.prometheus_service_type}
YAML

  # Only include extra values when non-empty
  extra_values_yaml = var.helm_values != null && trim(var.helm_values, " \t\n") != "" ? var.helm_values : null
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = var.namespace
  }
}

resource "helm_release" "kube_prometheus_stack" {
  name       = var.release_name
  namespace  = var.namespace
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.chart_version

  create_namespace = false

  values = compact([
    local.default_values_yaml,
    local.extra_values_yaml,
  ])

  wait    = var.wait
  timeout = var.timeout

  depends_on = [kubernetes_namespace.monitoring]
}
