output "vpc_id" {
  description = "The ID of the created VPC"
  value       = aws_vpc.public_vpc.id
}

output "subnet_id" {
  description = "The ID of the created subnet"
  value       = aws_subnet.public_subnet.id
}

output "instance_id" {
  description = "The ID of the EC2 instance"
  value       = aws_instance.public_instance.id
}

output "instance_public_ip" {
  description = "The public IP address of the EC2 instance"
  value       = aws_instance.public_instance.public_ip
}

output "key_path" {
  description = "The private key for the EC2 instance"
  value       = local_file.private_key.filename
  sensitive   = true
}
