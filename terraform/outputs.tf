output "instance_public_ip" {
  description = "Public IP of EC2 instance"
  value       = aws_eip.k3s_eip.public_ip
}