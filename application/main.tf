locals {
  common_tags = {
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}

resource "aws_vpc" "public_vpc" {
  cidr_block = var.vpc_cidr
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

resource "aws_security_group" "web" {
  name        = "app-web-sg"
  description = "Allow inbound HTTP/HTTPS and SSH"
  vpc_id      = aws_vpc.public_vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "app-web-sg"
  })
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-resolute-26.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
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

resource "aws_instance" "public_instance" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public_subnet.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.web.id]
  key_name                    = aws_key_pair.deployer_key.key_name
  provisioner "remote-exec" {
    inline = [
      "mkdir -p /home/ubuntu/scripts",
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.rsa_key_4096.private_key_pem
      host        = self.public_ip
    }
  }

  provisioner "file" {
    source      = "${path.module}/scripts/install_k8s_tools.sh"
    destination = "/home/ubuntu/scripts/install_k8s_tools.sh"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.rsa_key_4096.private_key_pem
      host        = self.public_ip
    }
  }
  provisioner "remote-exec" {
    inline = [
      "sudo /bin/bash /home/ubuntu/scripts/install_k8s_tools.sh",
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.rsa_key_4096.private_key_pem
      host        = self.public_ip
    }
  }

  tags = merge(local.common_tags, {
    Name = "app-public-instance"
  })
}

resource "aws_ami_from_instance" "k8s_ami" {
  name               = "k8s_ami"
  source_instance_id = aws_instance.public_instance.id
}

resource "aws_instance" "app-k8s-control-plane" {
  ami                         = aws_ami_from_instance.k8s_ami.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public_subnet.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.web.id]
  key_name                    = aws_key_pair.deployer_key.key_name

  tags = merge(local.common_tags, {
    Name = "app-k8s-control-plane"
  })
}
resource "aws_instance" "app-k8s-worker-1" {
  ami                         = aws_ami_from_instance.k8s_ami.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public_subnet.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.web.id]
  key_name                    = aws_key_pair.deployer_key.key_name

  tags = merge(local.common_tags, {
    Name = "app-k8s-worker-1"
  })
}
resource "aws_instance" "app-k8s-worker-2" {
  ami                         = aws_ami_from_instance.k8s_ami.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public_subnet.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.web.id]
  key_name                    = aws_key_pair.deployer_key.key_name

  tags = merge(local.common_tags, {
    Name = "app-k8s-worker-2"
  })
}