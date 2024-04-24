# availablity zones list
variable "availability_zones" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
}

# VPC creation
resource "aws_vpc" "vpc" {
  enable_dns_hostnames = true
  enable_dns_support   = true
  cidr_block           = "10.0.0.0/17"
  tags = {
    Name = "vpc"
  }
}

# public subnet
resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.0.0/18"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "public_subnet_1"
  }
}

# private subnet
resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.64.0/18"
  availability_zone = "us-east-1a"
  tags = {
    Name = "private_subnet_1"
  }
}

# EIP for NAT gateway 
resource "aws_eip" "eip_nat_gtw" {
  domain = "vpc"
}

# NAT gateway 
resource "aws_nat_gateway" "nat_gtw" {
  allocation_id = aws_eip.eip_nat_gtw.id
  subnet_id     = aws_subnet.public_subnet_1.id
  depends_on    = [aws_subnet.public_subnet_1]
  tags = {
    Name = "nat_gtw"
  }
}

# VPC internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "igw"
  }
}

# private subnet route table
resource "aws_route_table" "private_rtb" {
  vpc_id = aws_vpc.vpc.id

  # network flow of private subnet to NAT gateway 
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gtw.id
  }

  tags = {
    Name = "private_rtb"
  }
}

# private subnet association with private route table
resource "aws_route_table_association" "private_subnet_private_rtb_assoc" {
  route_table_id = aws_route_table.private_rtb.id
  subnet_id      = aws_subnet.private_subnet_1.id
}

# internet gateway route table
resource "aws_route_table" "igw_rtb" {
  vpc_id = aws_vpc.vpc.id

  # network traffic flow to internet gateway
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "igw_rtb"
  }
}

# public subnet association with internet gateway route table
resource "aws_route_table_association" "public_subnet_igw_rtb_assoc" {
  route_table_id = aws_route_table.igw_rtb.id
  subnet_id      = aws_subnet.public_subnet_1.id
}


# security group for node container instances in public subnet
resource "aws_security_group" "nodejs_ec2_sg" {
  vpc_id      = aws_vpc.vpc.id
  name        = "nodejs_ec2_sg"
  description = "allows SSH and opens port 3004 for nodejs docker container server"

  tags = {
    Name = "nodejs_ec2_sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allows_ssh_nodejs_ec2" {
  security_group_id = aws_security_group.nodejs_ec2_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  description       = "allows SSH to nodejs ec2 instances"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_ingress_rule" "opens_port_3004_nodejs_ec2" {
  security_group_id = aws_security_group.nodejs_ec2_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  description       = "allows outside traffic to reach instance at port 3004"
  ip_protocol       = "tcp"
  from_port         = 3004
  to_port           = 3004
}

resource "aws_vpc_security_group_egress_rule" "allows_outbound_traffic" {
  security_group_id = aws_security_group.nodejs_ec2_sg.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# public subnet ec2 instance
resource "aws_instance" "public_ec2_1" {
  ami             = "ami-04e5276ebb8451442"
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.public_subnet_1.id
  key_name        = "node-server-key-pair"
  security_groups = [aws_security_group.nodejs_ec2_sg.id]

  tags = {
    Name = "public_ec2_1"
  }

  user_data = templatefile("nodejs-ec2-init-script.tpl", {})
}

resource "aws_security_group" "private_ec2_sg" {
  vpc_id      = aws_vpc.vpc.id
  description = "security group of private ec2 isntances"
  tags = {
    Name = "private_ec2_sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "private_inbound" {
  security_group_id = aws_security_group.private_ec2_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_egress_rule" "private_outbound" {
  security_group_id = aws_security_group.private_ec2_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# private subnet ec2 instance
resource "aws_instance" "private_ec2_1" {
  ami             = "ami-04e5276ebb8451442"
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.private_subnet_1.id
  key_name        = "node-server-key-pair"
  security_groups = [aws_security_group.private_ec2_sg.id]

  tags = {
    Name = "private_ec2_1"
  }
}
