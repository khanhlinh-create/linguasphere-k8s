output "namespace" {
  description = "Namespace where monitoring stack is installed"
  value       = var.namespace
}

output "port_forward_commands" {
  description = "Local kubectl port-forward commands (run on your machine with KUBECONFIG set)"
  value = {
    grafana    = "kubectl -n ${var.namespace} port-forward svc/${var.release_name}-grafana 3000:80"
    prometheus = "kubectl -n ${var.namespace} port-forward svc/${var.release_name}-kube-prometheus-stack-prometheus 9090:9090"
  }
}
