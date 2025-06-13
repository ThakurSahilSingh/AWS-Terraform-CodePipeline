terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>4.0"
    }
  }
}
 
provider "aws" {
  region = "us-east-1"
}
 
# Create a VPC
resource "aws_vpc" "TF_VPC" {
  cidr_block = "192.168.0.0/24"
  tags = {
    Name = "TF_VPC-tag"
  }
}
 
#Internet Gateway
resource "aws_internet_gateway" "TF_IGW" {
  vpc_id = aws_vpc.TF_VPC.id
  tags = {
    Name = "TF_IGW-tag"
  }
}
 
# Create a public subnet
resource "aws_subnet" "TF_Pub_Sub" {
  vpc_id                  = aws_vpc.TF_VPC.id
  cidr_block              = "192.168.0.0/25"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "TF_Pub_Sub-tag"
  }
}
 
#create a private subnet
resource "aws_subnet" "TF_Priv_Sub" {
  vpc_id            = aws_vpc.TF_VPC.id
  cidr_block        = "192.168.0.128/25"
  availability_zone = "us-east-1a"
  tags = {
    Name = "TF_Priv_Sub-tag"
  }
}
 
# Create a route table for the public subnet
resource "aws_route_table" "TF_Pub_RT" {
  vpc_id = aws_vpc.TF_VPC.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.TF_IGW.id
  }
  tags = {
    Name = "TF_Pub_RT-tag"
  }
}
 
# Create a route table for private subnet
resource "aws_route_table" "TF_Priv_RT" {
  vpc_id = aws_vpc.TF_VPC.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.TF_NAT_GW.id
  }
  tags = {
    Name = "TF_Priv_RT-tag"
  }
}
 
# PubSub Route table association
resource "aws_route_table_association" "PubSub_RT_Assoc" {
  subnet_id      = aws_subnet.TF_Pub_Sub.id
  route_table_id = aws_route_table.TF_Pub_RT.id
}
 
# PrivSub Route table association
resource "aws_route_table_association" "PrivSub_RT_Assoc" {
  subnet_id      = aws_subnet.TF_Priv_Sub.id
  route_table_id = aws_route_table.TF_Priv_RT.id
}
 
# Create a Elastic IP for NAT Gateway
resource "aws_eip" "eip-NAT-GW" {
  #domain = "vpc"
}
 
# Create a NAT Gateway
resource "aws_nat_gateway" "TF_NAT_GW" {
  allocation_id = aws_eip.eip-NAT-GW.id
  subnet_id     = aws_subnet.TF_Pub_Sub.id
  tags = {
    Name = "TF_NAT_GW-tag"
  }
}
 
# Create a security group
resource "aws_security_group" "TF_SG" {
  name        = "TF_SG"
  description = "Allow SSH and HTTP traffic"
  vpc_id      = aws_vpc.TF_VPC.id
 
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
 
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # -1 indicates all protocols and all traffic
    cidr_blocks = ["0.0.0.0/0"]
  }
}
 
# NACL
resource "aws_network_acl" "TF_NACL" {
  vpc_id = aws_vpc.TF_VPC.id
 
  ingress {
    protocol    = "-1"
    rule_no = 100
    from_port   = 0
    to_port     = 0
    action      = "allow"
    cidr_block  = "0.0.0.0/0"
  }
 
  egress {
    protocol    = "-1"
    rule_no = 100
    from_port   = 0
    to_port     = 0
    action      = "allow"
    cidr_block  = "0.0.0.0/0"
  }
}
 
#NACL association with pubsub
resource "aws_network_acl_association" "NACL_PubSub" {
  subnet_id      = aws_subnet.TF_Pub_Sub.id
  network_acl_id = aws_network_acl.TF_NACL.id
}
 
#NACL association with privsub
resource "aws_network_acl_association" "NACL_PrivSub" {
  subnet_id      = aws_subnet.TF_Priv_Sub.id
  network_acl_id = aws_network_acl.TF_NACL.id
}
 
# Create a public EC2 instance
resource "aws_instance" "TF_Pub_EC2" {
  ami                         = "ami-0e449927258d45bc4"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.TF_Pub_Sub.id
  vpc_security_group_ids          = [aws_security_group.TF_SG.id]
  associate_public_ip_address = true
  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install -y httpd
              sudo systemctl start httpd
              sudo systemctl enable httpd
              sudo chown -R apache:apache /var/www/html
              sudo chmod -R 755 /var/www/html
              echo "<h1> Hi Welcome to Terraform! </h1>" | sudo tee /var/www/html/index.html
            EOF
  tags = {
    Name = "TF_Pub_EC2_tag"
  }
}
 
#EC2 instance in private subnet
resource "aws_instance" "TF_Priv_EC2" {
  ami           = "ami-0e449927258d45bc4"
  instance_type = "t2.micro"
  # No public IP address required as it's in a private subnet
  subnet_id          = aws_subnet.TF_Priv_Sub.id
  vpc_security_group_ids = [aws_security_group.TF_SG.id]
  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install -y httpd
              sudo systemctl start httpd
              sudo systemctl enable httpd
              sudo chown -R apache:apache /var/www/html
              sudo chmod -R 755 /var/www/html
              echo "<h1> Hello, Welcome to Sahil's to Webpage </h1>" | sudo tee /var/www/html/index.html
            EOF
  tags = {
    Name = "TF_Priv_EC2_tag"
  }
}
