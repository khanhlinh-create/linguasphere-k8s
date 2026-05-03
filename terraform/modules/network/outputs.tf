output "public_subnet_id" { value = aws_subnet.public_subnet_id}
output "security_group_id" {value = aws_security_group.k3s_sg.id}