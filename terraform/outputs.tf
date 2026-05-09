output "instance_public_ip" {
  description = "Public IP of EC2 instance"
  value       = module.compute.public_ip
}

output "instance_private_ip" {
  description = "Private IP of EC2 instance"
  value       = module.compute.private_ip
}