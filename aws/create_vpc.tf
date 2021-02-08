provider "aws" {
  region = "us-west-1"
  profile = "default"

}

# Create VPC
resource "aws_vpc" "vpc_terraform" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "VPC-Terraform"
    Group = "ICO"
    Owner = "erpost"
  }
}
# Create Private Subnet
resource "aws_subnet" "subnet1_private" {
  vpc_id     = aws_vpc.vpc_terraform.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "Sub1Private-Terraform"
    Group = "ICO"
    Owner = "erpost"
  }
}
# Create Public Subnet
resource "aws_subnet" "subnet2_public" {
  vpc_id     = aws_vpc.vpc_terraform.id
  cidr_block = "10.0.2.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "Sub2Public-Terraform"
    Group = "ICO"
    Owner = "erpost"
  }
}
# Remove Default Security Group Rules (No access)
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.vpc_terraform.id

  ingress {
    protocol  = -1
    self      = false
    from_port = 0
    to_port   = 0
  }
}
# Create Security Group
resource "aws_security_group" "allow_https" {
  name        = "allow_https"
  description = "Allow HTTPS inbound traffic"
  vpc_id      = aws_vpc.vpc_terraform.id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vpc_terraform.cidr_block, "172.16.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Group = "ICO"
    Owner = "erpost"
  }
}
# Create Internet Gateway

# Create Public Route Table
