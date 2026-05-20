resource "aws_instance" "k3s_server" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  key_name               = aws_key_pair.k3s_key.key_name

  associate_public_ip_address = true
  user_data_replace_on_change = true

  user_data = file("${path.module}/scripts/install_k3s.sh")

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name = "${var.project_name}-k3s-server"
  }
}

resource "aws_eip" "k3s_eip" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-k3s-eip"
  }
}

resource "aws_key_pair" "k3s_key" {
  key_name   = "${var.project_name}-k3s-key"
  public_key = file(var.public_key_path)

  tags = {
    Name = "${var.project_name}-k3s-key"
  }
}

resource "aws_eip_association" "k3s_eip_assoc" {
  instance_id   = aws_instance.k3s_server.id
  allocation_id = aws_eip.k3s_eip.id
}