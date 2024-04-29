variable "create_instances" {
  type        = bool
  default     = false
  description = "whether to create aws_intance type resources or not"
}

variable "create_nat_gtw" {
  type        = bool
  default     = false
  description = "whether to create a NAT gateway in public subnet or not"
}

# VPC creation
resource "aws_vpc" "vpc" {
  enable_dns_hostnames = true
  enable_dns_support   = true
  cidr_block           = "10.0.0.0/24" // 256 IPs
  tags = {
    Name = "vpc"
  }
}

# availablity zones list
variable "availability_zones" {
  type        = list(string)
  description = "availbility zones"
  default     = ["us-east-1a", "us-east-1b"]
}

# 2 public subnets in each AZ
resource "aws_subnet" "public_subnets" {
  count                   = length(var.availability_zones)
  availability_zone       = element(var.availability_zones, count.index)
  cidr_block              = cidrsubnet(aws_vpc.vpc.cidr_block, 2, count.index)
  vpc_id                  = aws_vpc.vpc.id
  map_public_ip_on_launch = true
  tags = {
    Name = "public_subnet_${count.index + 1}"
  }
}

# 2 private subnets in each AZ
resource "aws_subnet" "private_subnets" {
  count             = length(var.availability_zones)
  availability_zone = element(var.availability_zones, count.index)
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = cidrsubnet(aws_vpc.vpc.cidr_block, 2, count.index + 2)
  tags = {
    Name = "private_subnet_${count.index + 1}"
  }
}

# EIP for NAT gateway 
resource "aws_eip" "eip_nat_gtw" {
  count  = var.create_nat_gtw ? 1 : 0
  domain = "vpc"
}

# NAT gateway 
resource "aws_nat_gateway" "nat_gtw" {
  count         = var.create_nat_gtw ? 1 : 0
  allocation_id = aws_eip.eip_nat_gtw[0].id
  subnet_id     = element(aws_subnet.public_subnets[*].id, 0)
  depends_on    = [aws_subnet.public_subnets]
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
  tags = {
    Name = "private_rtb"
  }
}

# network flow of private subnet to NAT gateway 
resource "aws_route" "nat_gtw_route_private_rtb" {
  count                  = var.create_nat_gtw ? 1 : 0
  route_table_id         = aws_route_table.private_rtb.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gtw[0].id
}

# private subnets association with private route table
resource "aws_route_table_association" "private_subnets_private_rtb_assoc" {
  route_table_id = aws_route_table.private_rtb.id
  count          = length(aws_subnet.private_subnets[*].id)
  subnet_id      = element(aws_subnet.private_subnets[*].id, count.index)
}

# internet gateway route table
resource "aws_route_table" "igw_rtb" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "igw_rtb"
  }
}

# network traffic flow to internet gateway
resource "aws_route" "internet_route_igw_rtb" {
  route_table_id         = aws_route_table.igw_rtb.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

# public subnets association with internet gateway route table
resource "aws_route_table_association" "public_subnets_igw_rtb_assoc" {
  route_table_id = aws_route_table.igw_rtb.id
  count          = length(aws_subnet.public_subnets[*].id)
  subnet_id      = element(aws_subnet.public_subnets[*].id, count.index)
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

# public subnet ec2 instances, one in each public subnet
resource "aws_instance" "public_nodejs_ec2" {
  count           = var.create_instances ? length(aws_subnet.public_subnets[*].id) : 0
  subnet_id       = element(aws_subnet.public_subnets[*].id, count.index)
  ami             = "ami-04e5276ebb8451442"
  instance_type   = "t2.micro"
  key_name        = "node-server-key-pair"
  security_groups = [aws_security_group.nodejs_ec2_sg.id]
  user_data       = templatefile("nodejs-ec2-init-script.tpl", {})
  tags = {
    Name = "public_nodejs_ec2_${count.index + 1}"
  }
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

# private subnet ec2 instances, one in each private subnet
resource "aws_instance" "private_ec2" {
  count           = var.create_instances ? length(aws_subnet.private_subnets[*].id) : 0
  subnet_id       = element(aws_subnet.private_subnets[*].id, count.index)
  ami             = "ami-04e5276ebb8451442"
  instance_type   = "t2.micro"
  key_name        = "node-server-key-pair"
  security_groups = [aws_security_group.private_ec2_sg.id]
  tags = {
    Name = "private_ec2_${count.index}"
  }
}
