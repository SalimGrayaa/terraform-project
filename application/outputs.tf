output "vpc_id" {
  description = "The ID of the created VPC"
  value       = aws_vpc.public_vpc.id
}

output "subnet_id" {
  description = "The ID of the created subnet"
  value       = aws_subnet.public_subnet.id
}

output "key_path" {
  description = "The private key for the EC2 instance"
  value       = local_file.private_key.filename
  sensitive   = true
}
output "k8s_control_plane_instance_hostname" {
  description = "The hostname of the Kubernetes control plane instance"
  value       = aws_instance.app-k8s-control-plane.private_dns
}

output "k8s_control_plane_instance_public_ip" {
  description = "The public IP address of the Kubernetes control plane instance"
  value       = aws_instance.app-k8s-control-plane.public_ip
}

output "k8s_worker_1_instance_public_ip" {
  description = "The public IP address of Kubernetes worker 1"
  value       = aws_instance.app-k8s-worker-1.public_ip
}

output "k8s_worker_2_instance_public_ip" {
  description = "The public IP address of Kubernetes worker 2"
  value       = aws_instance.app-k8s-worker-2.public_ip
}
