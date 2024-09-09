# Variable declarations
variable "ec2_count" {
  description = "Number of EC2 instances to create"
  type        = number
  default     = 1
}

variable "rds_count" {
  description = "Number of RDS instances to create"
  type        = number
  default     = 1
}

provider "aws" {
  region = "eu-central-1"
}

# Data source for Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# VPC
resource "aws_vpc" "demo_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
}

# Subnets
resource "aws_subnet" "demo_subnet_1" {
  vpc_id     = aws_vpc.demo_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "eu-central-1a"
}

resource "aws_subnet" "demo_subnet_2" {
  vpc_id     = aws_vpc.demo_vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "eu-central-1b"
}

# Internet Gateway
resource "aws_internet_gateway" "demo_igw" {
  vpc_id = aws_vpc.demo_vpc.id
}

# Route Table
resource "aws_route_table" "demo_rt" {
  vpc_id = aws_vpc.demo_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.demo_igw.id
  }
}

# Route Table Association
resource "aws_route_table_association" "demo_rta_subnet1" {
  subnet_id      = aws_subnet.demo_subnet_1.id
  route_table_id = aws_route_table.demo_rt.id
}

resource "aws_route_table_association" "demo_rta_subnet2" {
  subnet_id      = aws_subnet.demo_subnet_2.id
  route_table_id = aws_route_table.demo_rt.id
}

# Security Group
resource "aws_security_group" "demo_sg" {
  vpc_id = aws_vpc.demo_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 Instance
resource "aws_instance" "demo_instance" {
  count         = var.ec2_count
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.demo_subnet_1.id
  vpc_security_group_ids = [aws_security_group.demo_sg.id]
  associate_public_ip_address = true

  root_block_device {
    volume_type = "gp2"
    volume_size = 8
  }

  tags = {
    Name = "demo-instance-${count.index + 1}"
  }
}

# RDS MySQL Instance
resource "aws_db_subnet_group" "demo_subnet_group" {
  name       = "demo-subnet-group-${random_id.suffix.hex}"
  subnet_ids = [aws_subnet.demo_subnet_1.id, aws_subnet.demo_subnet_2.id]
}

# Add this resource to generate a random suffix
resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_db_instance" "demo_db" {
  count                = var.rds_count
  allocated_storage    = 20
  engine               = "mysql"
  instance_class       = "db.t3.micro"
  db_name              = "mydb${count.index + 1}"
  username             = "admin"
  password             = "password"
  vpc_security_group_ids = [aws_security_group.demo_sg.id]
  skip_final_snapshot   = true
  publicly_accessible   = true
  multi_az              = false
  db_subnet_group_name  = aws_db_subnet_group.demo_subnet_group.name
  identifier            = "demo-db-${count.index + 1}-${random_id.suffix.hex}"
}

# Add outputs for EC2 and RDS instances
output "ec2_instance_ids" {
  description = "IDs of created EC2 instances"
  value       = aws_instance.demo_instance[*].id
}

output "rds_endpoints" {
  description = "Endpoints of created RDS instances"
  value       = aws_db_instance.demo_db[*].endpoint
}