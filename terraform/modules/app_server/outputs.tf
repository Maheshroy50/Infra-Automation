output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.web.public_ip
}

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.web.id
}

output "generated_private_key_path" {
  description = "Local path to the generated private SSH key"
  value       = local_sensitive_file.private_key.filename
}
