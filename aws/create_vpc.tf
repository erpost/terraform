provider "aws" {
  region = "us-west-1"
  profile = "default"

}

#Create VPC
resource "aws_vpc" "vpc" {
  cidr_block = "10.1.0.0/16"

  tags = {
    Name = "VPC-Terraform"
    Group = "ICO"
    Owner = "erpost"
  }
}