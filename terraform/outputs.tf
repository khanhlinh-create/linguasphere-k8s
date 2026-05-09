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
  description = "SSH command to connect to EC2"
  value       = "ssh -i ./linguasphere-k3s-key ubuntu@${module.compute.public_ip}"
}

output "k3s_check_command" {
  description = "Command to verify K3s after SSH"
  value       = "kubectl get nodes -o wide && kubectl get pods -A"
}