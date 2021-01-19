terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.22.0"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}

resource "aws_vpc" "vpc_vault" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "VPC Vault"
  }
}

resource "aws_subnet" "public_vault" {
  vpc_id            = aws_vpc.vpc_vault.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-west-2a"

  tags = {
    Name = "Public Vault"
  }
}

resource "aws_internet_gateway" "internet_gateway_vault" {
  vpc_id = aws_vpc.vpc_vault.id

  tags = {
    Name = "Internet Gateway Vault"
  }
}

resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.vpc_vault.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway_vault.id
  }

  tags = {
    Name = "Public Subnet Route Table"
  }
}

resource "aws_route_table_association" "route_table_association" {
  subnet_id      = aws_subnet.public_vault.id
  route_table_id = aws_route_table.route_table.id
}

resource "aws_key_pair" "deployer" {
  key_name   = var.deployer_key_name
  public_key = file(var.public_key_path)
}

resource "aws_security_group" "security_group_vault" {
  name        = "security_group_vault"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.vpc_vault.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Security Group Vault"
  }
}

data "template_file" "user_data_vault" {
  template = file("./modules/install-vault/install-vault.sh")

  vars = {
    VAULT_VERSION    = var.vault_version
  }
}

resource "aws_instance" "vault_testing" {
  ami                         = var.ami_id
  instance_type               = var.type
  key_name                    = var.deployer_key_name
  vpc_security_group_ids      = [aws_security_group.security_group_vault.id]
  subnet_id                   = aws_subnet.public_vault.id
  associate_public_ip_address = true

  user_data = data.template_file.user_data_vault.rendered

  tags = {
    Name = "Vault instance"
  }

  connection {
    type        = "ssh"
    user        = var.ssh_user
    host        = self.public_ip
    private_key = file(var.private_key_path)
  }
}

