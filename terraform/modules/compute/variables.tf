variable "subnet_id" {
  type = string
}

variable "security_group_id" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "project_name" {
  type = string
}

variable "aws_region" {
  description = "AWS region (used by user_data to publish kubeconfig to SSM)"
  type        = string
}

variable "public_key_path" {
  type = string
}

variable "kubeconfig_ssm_parameter_name" {
  description = "SSM Parameter Store name to publish kubeconfig (SecureString). Example: /project/dev/kubeconfig"
  type        = string
}