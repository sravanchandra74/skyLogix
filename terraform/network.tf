resource "aws_vpc" "main" {
  cidr_block           = "10.161.0.0/24"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "main-vpc"
  }
}

# Public Subnet for NAT Gateway (AZ1)
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.161.0.0/26"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-a"
  }
  depends_on = [aws_vpc.main]
}

# Public Subnet for Bastion Host and ALB (AZ2)
resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.161.0.64/26"
  availability_zone       = "${var.region}b"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-b"
  }
  depends_on = [aws_vpc.main]
}

# Private Subnet for EC2 Instances (AZ1)
resource "aws_subnet" "private_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.161.0.128/26"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = false

  tags = {
    Name = "private-subnet-a"
  }
  depends_on = [aws_vpc.main]
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"
  }
  depends_on = [aws_vpc.main]
}

# Route Table for Public Subnets
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-route-table"
  }
  depends_on = [aws_internet_gateway.igw]
}

# Route Table Association for Public Subnet A
resource "aws_route_table_association" "public_a_rta" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public_rt.id
}

# Route Table Association for Public Subnet B
resource "aws_route_table_association" "public_b_rta" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public_rt.id
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat_eip" {
  domain = "vpc"
  tags = {
    Name = "nat-gateway-eip"
  }
  depends_on = [aws_internet_gateway.igw]
}

# NAT Gateway in Public Subnet A
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_a.id # NAT Gateway in public_a
  tags = {
    Name = "main-nat-gateway"
  }
  depends_on = [aws_eip.nat_eip, aws_subnet.public_a]
}

# Route Table for Private Subnet
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "private-route-table"
  }
  depends_on = [aws_nat_gateway.nat]
}

# Route Table Association for Private Subnet A
resource "aws_route_table_association" "private_a_rta" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private_rt.id
}

# Security group for the private EC2 instances
resource "aws_security_group" "private_sg" {
  name_prefix = "private-sg-"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.bastion_sg.id] # Allow SSH from the bastion SG
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.alb_sg.id] # Allow HTTP from the ALB SG
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Allow all outbound traffic
  }

  tags = {
    Name = "private-instance-sg"
  }
  depends_on = [aws_vpc.main, aws_security_group.bastion_sg, aws_security_group.alb_sg]
}

# Security group for the bastion host
resource "aws_security_group" "bastion_sg" {
  name_prefix = "bastion-sg-"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
    description = "Allow SSH from allowed IPs"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Allow all outbound traffic
  }

  tags = {
    Name = "bastion-sg"
  }
  depends_on = [aws_vpc.main]
}

# Security group for the ALB
resource "aws_security_group" "alb_sg" {
  name_prefix = "alb-sg-"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow traffic from anywhere
    description = "Allow HTTP traffic"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Allow all outbound traffic
  }

  tags = {
    Name = "alb-sg"
  }
  depends_on = [aws_vpc.main]
}

# Generate SSH Key Pair for Bastion Access
resource "tls_private_key" "bastion_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "bastion_private_key" {
  filename        = "/Users/shravanchandraparikipandla/Documents/repo/yolo-test/bastion_access_key.pem"
  content         = tls_private_key.bastion_ssh_key.private_key_pem
  file_permission = "0400"
}

resource "aws_key_pair" "bastion_key_pair" {
  key_name    = "bastion-access-key"
  public_key  = tls_private_key.bastion_ssh_key.public_key_openssh
  depends_on  = [tls_private_key.bastion_ssh_key]
}