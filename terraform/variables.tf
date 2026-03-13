variable "aws_region" {
  description = "AWS region to deploy the infrastructure in"
  type        = string
  default     = "us-east-1"
}

variable "app_name" {
  description = "Name of the application, used to name AWS resources appropriately"
  type        = string
  default     = "flask-react-app"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "repository_url" {
  description = "URL of your forked Git repository"
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH into the instance"
  type        = string
  default     = "0.0.0.0/0"
}

variable "vpc_id" {
  description = "Optional VPC ID. When omitted, the default VPC is used."
  type        = string
  default     = null
}

variable "subnet_id" {
  description = "Optional subnet ID. When omitted, the first subnet from the selected VPC is used."
  type        = string
  default     = null
}
