output "public_ip" {
  value = aws_eip.k3s_eip.public_ip
}

output "private_ip" {
  value = aws_instance.k3s_server.private_ip
}

output "instance_id" {
  value = aws_instance.k3s_server.id
}

output "kubeconfig_ssm_parameter_name" {
  description = "SSM Parameter Store name where the instance publishes kubeconfig"
  value       = var.kubeconfig_ssm_parameter_name
}