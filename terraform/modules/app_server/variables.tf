variable "app_name" {
  description = "Name of the application, used for naming resources"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "repository_url" {
  description = "URL of the Git repository to clone during server initialization"
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH into the server"
  type        = string
}

variable "vpc_id" {
  description = "Optional VPC ID. When null, use the default VPC."
  type        = string
  default     = null
}

variable "subnet_id" {
  description = "Optional subnet ID. When null, use the first subnet in the selected VPC."
  type        = string
  default     = null
}
