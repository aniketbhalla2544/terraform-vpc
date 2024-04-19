resource "aws_vpc" "vpc_1" {
  enable_dns_hostnames = true
  enable_dns_support   = true
  cidr_block           = "10.0.0.0/17"

  tags = {
    Name = "vpc_1"
  }
}

resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.vpc_1.id
  cidr_block              = "10.0.0.0/18"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public_subnet_1"
  }
}

resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.vpc_1.id
  cidr_block        = "10.0.64.0/18"
  availability_zone = "us-east-1a"

  tags = {
    Name = "private_subnet_1"
  }
}

resource "aws_eip" "eip_nat_gtw_vpc_1" {
  domain = "vpc"
}

resource "aws_nat_gateway" "private_subnet_natgtw" {
  subnet_id     = aws_subnet.public_subnet_1.id
  allocation_id = aws_eip.eip_nat_gtw_vpc_1.id

  tags = {
    Name = "nat_gtw_public_subnet_vpc_1g h"
  }
  depends_on = [aws_subnet.public_subnet_1]
}

resource "aws_internet_gateway" "igw_vpc_1" {
  vpc_id = aws_vpc.vpc_1.id

  tags = {
    Name = "igw_vpc_1"
  }
}

resource "aws_route_table" "private_rtb_vpc_1" {
  vpc_id = aws_vpc.vpc_1.id
  tags = {
    Name = "private_rtb_vpc_1"
  }
}

resource "aws_route" "nat_gtw_route" {
  route_table_id         = aws_route_table.private_rtb_vpc_1.id
  nat_gateway_id         = aws_nat_gateway.private_subnet_natgtw.id
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route_table_association" "private_subnet_private_rtb_assoc" {
  route_table_id = aws_route_table.private_rtb_vpc_1.id
  subnet_id      = aws_subnet.private_subnet_1.id
}

resource "aws_route_table" "igw_rtb_vpc_1" {
  vpc_id = aws_vpc.vpc_1.id

  tags = {
    Name = "igw_rtb_vpc_1"
  }
}

resource "aws_route" "igw_route" {
  route_table_id         = aws_route_table.igw_rtb_vpc_1.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw_vpc_1.id
}

resource "aws_route_table_association" "igw_rtb__vpc_1_assoc" {
  route_table_id = aws_route_table.igw_rtb_vpc_1.id
  subnet_id      = aws_subnet.public_subnet_1.id
}

resource "aws_security_group" "nodejs_ec2_sg" {
  vpc_id      = aws_vpc.vpc_1.id
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
  vpc_id      = aws_vpc.vpc_1.id
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
