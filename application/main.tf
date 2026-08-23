locals {
  common_tags = {
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}

resource "aws_vpc" "public_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = merge(local.common_tags, {
    Name = "public-vpc"
  })
}

resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.public_vpc.id
  cidr_block = var.subnet_cidr
  tags = merge(local.common_tags, {
    Name = "app-public-subnet"
  })
}

resource "aws_internet_gateway" "public_igw" {
  vpc_id = aws_vpc.public_vpc.id
  tags = merge(local.common_tags, {
    Name = "app-igw"
  })
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.public_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.public_igw.id
  }

  tags = merge(local.common_tags, {
    Name = "app-public-route-table"
  })
}

resource "aws_route_table_association" "public_route_table_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_security_group" "cp_sg" {
  name        = "app-k8s-control-plane-sg"
  description = "Control plane security group"
  vpc_id      = aws_vpc.public_vpc.id
  tags = merge(local.common_tags, {
    Name = "app-k8s-control-plane-sg"
  })
}
resource "aws_security_group" "worker_node_sg" {
  name        = "app-k8s-worker-sg"
  description = "Worker nodes security group"
  vpc_id      = aws_vpc.public_vpc.id
  tags = merge(local.common_tags, {
    Name = "app-k8s-worker-sg"
  })
}
resource "aws_security_group" "allow_ssh" {
  name        = "allow ssh"
  description = "Allow inbound HTTP/HTTPS and SSH"
  vpc_id      = aws_vpc.public_vpc.id
  tags = merge(local.common_tags, {
    Name = "app-ssh-sg"
  })
}

resource "aws_vpc_security_group_ingress_rule" "ssh_rule" {
  security_group_id = aws_security_group.allow_ssh.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}


resource "aws_vpc_security_group_ingress_rule" "cp-api-server-rule" {
  security_group_id            = aws_security_group.cp_sg.id
  referenced_security_group_id = aws_security_group.cp_sg.id
  from_port                    = 6443
  to_port                      = 6443
  ip_protocol                  = "tcp"
}
resource "aws_vpc_security_group_ingress_rule" "worker_api_server" {
  security_group_id            = aws_security_group.cp_sg.id
  referenced_security_group_id = aws_security_group.worker_node_sg.id
  from_port                    = 6443
  to_port                      = 6443
  ip_protocol                  = "tcp"
}
resource "aws_vpc_security_group_ingress_rule" "cp-kubelet-rule" {
  security_group_id            = aws_security_group.cp_sg.id
  referenced_security_group_id = aws_security_group.worker_node_sg.id
  from_port                    = 10250
  to_port                      = 10250
  ip_protocol                  = "tcp"
}
resource "aws_vpc_security_group_ingress_rule" "cp-etcd-rule" {
  security_group_id            = aws_security_group.cp_sg.id
  referenced_security_group_id = aws_security_group.cp_sg.id
  from_port                    = 2379
  to_port                      = 2379
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "worker-kubelet-rule" {
  security_group_id            = aws_security_group.worker_node_sg.id
  referenced_security_group_id = aws_security_group.cp_sg.id
  from_port                    = 10250
  to_port                      = 10250
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "cp_cilium_vxlan" {
  security_group_id            = aws_security_group.cp_sg.id
  referenced_security_group_id = aws_security_group.worker_node_sg.id
  from_port                    = 8472
  to_port                      = 8472
  ip_protocol                  = "udp"
}

resource "aws_vpc_security_group_ingress_rule" "worker_cilium_vxlan" {
  security_group_id            = aws_security_group.worker_node_sg.id
  referenced_security_group_id = aws_security_group.cp_sg.id
  from_port                    = 8472
  to_port                      = 8472
  ip_protocol                  = "udp"
}
resource "aws_vpc_security_group_ingress_rule" "worker_cilium_vxlan_self" {
  security_group_id            = aws_security_group.worker_node_sg.id
  referenced_security_group_id = aws_security_group.worker_node_sg.id
  from_port                    = 8472
  to_port                      = 8472
  ip_protocol                  = "udp"
}
resource "aws_vpc_security_group_ingress_rule" "worker_cilium_health" {
  security_group_id            = aws_security_group.worker_node_sg.id
  referenced_security_group_id = aws_security_group.worker_node_sg.id
  from_port                    = 4240
  to_port                      = 4240
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "cp_egress" {
  security_group_id = aws_security_group.cp_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_egress_rule" "worker_egress" {
  security_group_id = aws_security_group.worker_node_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

data "aws_ami" "k8s_tools" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["k8s-tools-ubuntu-24-04-*"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "tls_private_key" "rsa_key_4096" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "deployer_key" {
  key_name   = "deployer-key"
  public_key = tls_private_key.rsa_key_4096.public_key_openssh
}

resource "local_file" "private_key" {
  content         = tls_private_key.rsa_key_4096.private_key_pem
  filename        = "${path.root}/deployer-key.pem"
  file_permission = "0600"
}

resource "aws_instance" "app-k8s-control-plane" {
  ami                         = data.aws_ami.k8s_tools.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public_subnet.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.cp_sg.id, aws_security_group.allow_ssh.id]
  key_name                    = aws_key_pair.deployer_key.key_name

  tags = merge(local.common_tags, {
    Name = "app-k8s-control-plane"
  })
}
resource "aws_instance" "app-k8s-worker-1" {
  ami                         = data.aws_ami.k8s_tools.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public_subnet.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.worker_node_sg.id, aws_security_group.allow_ssh.id]
  key_name                    = aws_key_pair.deployer_key.key_name

  tags = merge(local.common_tags, {
    Name = "app-k8s-worker-1"
  })
}
resource "aws_instance" "app-k8s-worker-2" {
  ami                         = data.aws_ami.k8s_tools.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public_subnet.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.worker_node_sg.id, aws_security_group.allow_ssh.id]
  key_name                    = aws_key_pair.deployer_key.key_name

  tags = merge(local.common_tags, {
    Name = "app-k8s-worker-2"
  })
}