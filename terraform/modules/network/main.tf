data "http" "my_public_ip" {
    url = "https://checkip.amazonaws.com"
}

resource "aws_vpc" "main" {
    cidr_block  = var.vpc_cidr
    enable_dns_hostnames = true
    tags = {Name = "${var.project_name}-vpc"}
}

resource "aws_internet_gateway" "gw" {
    vpc_id = aws_vpc.main.id
}

resource "aws_subnet" "public" {
    vpc_id = aws_vpc.main.id
    cidr_block = var.public_subnet_cidr
    tags = {Name = "${var.project_name}-public-subnet"}
}

resource "aws_route_table" "rt" {
    vpc_id = aws_vpc.main.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.gw.id
    }
}

resource "aws_route_table_association" "a" {
    subnet_id = aws_subnet.public.id
    route_table_id = aws_route_table.rt.id
}

resource "aws_security_group" "k3s_sg" {
    name = "${var.project_name}-sg"
    vpc_id = aws_vpc.main.id

    # SSH, HTTP, K3s API (6443), NodePort (30000-32767 - Argo/Grafana)
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_block = ["${chomp(data.http.my_public_ip.response_body)}/32"]
    }

    ingress {
        from_port = 6443
        to_port = 6443
        protocol = "tcp"
        cidr_block = ["${chomp(data.http.my_public_ip.response_body)}/32"]
    }

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_block = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_block = ["0.0.0.0/0"]
    }
}