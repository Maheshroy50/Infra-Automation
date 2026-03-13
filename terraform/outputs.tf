output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = module.app_server.instance_public_ip
}

output "app_url" {
  description = "Base URL of the deployed application"
  value       = "http://${module.app_server.instance_public_ip}"
}

output "generated_private_key_path" {
  description = "Local path to the Terraform-generated private SSH key"
  value       = module.app_server.generated_private_key_path
}

output "ssh_command" {
  description = "Command to SSH into the instance"
  value       = "ssh -i ${module.app_server.generated_private_key_path} ubuntu@${module.app_server.instance_public_ip}"
}
