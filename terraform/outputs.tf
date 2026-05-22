output "instance_id" {
  description = "EC2 instance ID"
  value       = module.compute.instance_id
}

output "instance_public_ip" {
  description = "Elastic public IP of EC2 instance"
  value       = module.compute.public_ip
}

output "instance_private_ip" {
  description = "Private IP of EC2 instance"
  value       = module.compute.private_ip
}

output "ssh_command" {
  description = "Command to connect to EC2"
  value       = "ssh -i ${pathexpand(var.private_key_path)} ubuntu@${module.compute.public_ip}"
}

output "k3s_check_command" {
  description = "Command to verify K3s using a local kubeconfig"
  value       = "kubectl get nodes -o wide && kubectl get pods -A"
}

output "kubeconfig_ssm_parameter_name" {
  description = "SSM Parameter Store name where the EC2 instance publishes kubeconfig (SecureString)"
  value       = module.compute.kubeconfig_ssm_parameter_name
}

output "kubeconfig_fetch_instructions" {
  description = "How to fetch kubeconfig from AWS SSM Parameter Store"
  value = <<-EOT
    Fetch kubeconfig from SSM (PowerShell example):
      aws ssm get-parameter --region ${var.aws_region} --name "${module.compute.kubeconfig_ssm_parameter_name}" --with-decryption --query Parameter.Value --output text | Out-File -Encoding ascii $HOME\.kube\linguasphere.yaml

    Fetch kubeconfig from SSM (WSL/Linux/macOS bash example):
      mkdir -p ~/.kube
      aws ssm get-parameter --region ${var.aws_region} --name "${module.compute.kubeconfig_ssm_parameter_name}" --with-decryption --query Parameter.Value --output text > ~/.kube/linguasphere.yaml

    Then use it locally:
      PowerShell:
        $env:KUBECONFIG="$HOME\.kube\linguasphere.yaml"
        kubectl get nodes -o wide

      bash:
        export KUBECONFIG=~/.kube/linguasphere.yaml
        kubectl get nodes -o wide

    To enable monitoring via Helm (Terraform), run:
      terraform apply -var="deploy_monitoring=true"
  EOT
}

# Monitoring module outputs (re-exported for workspace users)
output "monitoring_namespace" {
  description = "Namespace where monitoring stack is installed (module.monitoring)"
  value       = try(module.monitoring[0].namespace, null)
}

output "grafana_info" {
  description = "Grafana service info from monitoring module"
  value       = null
}

output "prometheus_info" {
  description = "Prometheus service info from monitoring module"
  value       = null
}

output "monitoring_access_instructions" {
  description = "Quick access commands for Grafana and Prometheus"
  value = var.deploy_monitoring ? (
  <<-EOT
    With KUBECONFIG set locally, port-forward Grafana:
      kubectl -n ${module.monitoring[0].namespace} port-forward svc/${var.monitoring_release_name}-grafana 3000:80
      Visit http://localhost:3000 (user: admin, password = value of variable `grafana_admin_password`)

    Find Prometheus service name:
      PowerShell:
        kubectl -n ${module.monitoring[0].namespace} get svc | findstr /i prometheus
      bash:
        kubectl -n ${module.monitoring[0].namespace} get svc | grep -i prometheus
  EOT
  ) : "Monitoring is disabled (set deploy_monitoring=true after kubeconfig is available)."
}

output "monitoring_port_forward_commands" {
  description = "Port-forward commands re-exported from module.monitoring"
  value       = try(module.monitoring[0].port_forward_commands, null)
}