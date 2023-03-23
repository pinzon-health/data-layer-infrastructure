terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.15.0"
    }
  }
}

provider "aws" {
  region  = "eu-central-1"
  profile = var.profile
}

locals {
  project_name       = "data-layer"
  resource_prefix    = "${local.project_name}-${var.environment}"
  availability_zones = ["eu-central-1a", "eu-central-1b"]
}

########## VPC ##########
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "${local.resource_prefix}-vpc"
  }
}

# create an internet gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.resource_prefix}-igw"
  }
}

resource "aws_subnet" "public" {
  count = length(local.availability_zones)

  cidr_block = "10.0.${count.index + 1}.0/24"
  vpc_id     = aws_vpc.main.id

  availability_zone = local.availability_zones[count.index]

  tags = {
    Name = "${local.resource_prefix}-public-subnet-${count.index + 1}"
  }
}

# Route Table: create a route table and associate it with your subnet. Make sure to add a route that directs internet-bound traffic (0.0.0.0/0) to the internet gateway.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }


  tags = {
    Name = "${local.resource_prefix}-public-rt"
  }
}

# Route Table Association: associate the route table with your subnet.
resource "aws_route_table_association" "subnet-association" {
  count          = length(local.availability_zones)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
########## end VPC ##########

########## Key Pair ##########
resource "aws_key_pair" "generated_key" {
  key_name   = "${local.resource_prefix}-key"
  public_key = tls_private_key.generated_key.public_key_openssh
}
resource "tls_private_key" "generated_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}
resource "local_file" "private_key" {
  content  = tls_private_key.generated_key.private_key_pem
  filename = "keys/${var.environment}/${local.resource_prefix}-key.pem"
}

########## bastion host ##########
resource "aws_security_group" "bastion" {
  name        = "${local.resource_prefix}-bastion"
  description = "Allow SSH connections to the bastion host"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.bastion_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "bastion" {
  ami           = var.bastion_ami_id
  instance_type = var.bastion_instance_type
  #key_name      = "new-data-layer-temp-key"
  key_name = aws_key_pair.generated_key.key_name

  subnet_id = tolist(aws_subnet.public.*.id)[0]

  vpc_security_group_ids = [
    aws_security_group.bastion.id,
  ]

  tags = {
    Name = "${local.resource_prefix}-bastion"
  }
}
# Create an Elastic IP address and associate it with the instance
resource "aws_eip" "bastion" {
  vpc = true

  tags = {
    Name = "${local.resource_prefix}-bastion-eip"
  }
}

resource "aws_eip_association" "bastion" {
  instance_id   = aws_instance.bastion.id
  allocation_id = aws_eip.bastion.id
}
########## end of bastion host ##########
