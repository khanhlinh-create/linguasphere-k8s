resource "aws_instance" "k3s_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  key_name               = aws_key_pair.k3s_key.key_name

  iam_instance_profile = aws_iam_instance_profile.k3s_profile.name

  associate_public_ip_address = true
  user_data_replace_on_change = true

  user_data = <<-EOF
#!/usr/bin/env bash
set -euo pipefail

export AWS_REGION="${var.aws_region}"
export KUBECONFIG_SSM_PARAMETER_NAME="${var.kubeconfig_ssm_parameter_name}"
export EXPECTED_PUBLIC_IP="${aws_eip.k3s_eip.public_ip}"

${file("${path.module}/scripts/install_k3s.sh")}
EOF

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

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

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  owners = ["099720109477"]
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "k3s_role" {
  name               = "${var.project_name}-k3s-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.k3s_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "k3s_put_kubeconfig" {
  name = "${var.project_name}-k3s-put-kubeconfig"
  role = aws_iam_role.k3s_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:PutParameter",
          "ssm:AddTagsToResource"
        ]
        Resource = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${trim(var.kubeconfig_ssm_parameter_name, "/") }"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "k3s_profile" {
  name = "${var.project_name}-k3s-profile"
  role = aws_iam_role.k3s_role.name
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

resource "aws_iam_role_policy" "k3s_read_secrets" {
  name = "${var.project_name}-k3s-read-secrets"
  role = aws_iam_role.k3s_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:/linguasphere/*"
      }
    ]
  })
}