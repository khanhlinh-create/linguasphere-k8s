variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "Project name for tagging"
  type        = string
  default     = "linguasphere"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.medium"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.10.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet"
  type        = string
  default     = "10.10.1.0/24"
}

variable "admin_cidr" {
  description = "Your public IP in CIDR format, example: 1.2.3.4/32"
  type        = string
}

variable "public_key_path" {
  description = "Path to SSH public key"
  type        = string
  default     = "./linguasphere-k3s-key.pub"
}