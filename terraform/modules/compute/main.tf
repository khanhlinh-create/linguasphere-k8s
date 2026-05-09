resource "aws_instance" "k3s_server" {
  ami           = "ami-0df7a207adb9748c7"
  instance_type = var.instance_type

  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]

  associate_public_ip_address = true

  user_data = file("${path.module}/scripts/install_k3s.sh")

  tags = {
    Name = "${var.project_name}-server"
  }
}

resource "aws_eip" "k3s_eip" {
  instance = aws_instance.k3s_server.id

  tags = {
    Name = "${var.project_name}-eip"
  }
}