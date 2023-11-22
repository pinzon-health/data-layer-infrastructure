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
    aws_security_group.aurora.id
  ]

  tags = {
    Name = "${local.resource_prefix}-bastion"
  }
}
# Create an Elastic IP address and associate it with the instance
resource "aws_eip" "bastion" {
  domain = "vpc"

  tags = {
    Name = "${local.resource_prefix}-bastion-eip"
  }
}

resource "aws_eip_association" "bastion" {
  instance_id   = aws_instance.bastion.id
  allocation_id = aws_eip.bastion.id
}
########## end of bastion host ##########

########## Aurora ##########
resource "aws_security_group" "aurora" {
  name        = "${local.resource_prefix}-aurora"
  description = "Allow connections to Aurora"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${local.resource_prefix}-aurora"
  }
}
resource "aws_subnet" "private" {
  count = length(local.availability_zones)

  cidr_block = "10.0.${count.index + 101}.0/24"
  vpc_id     = aws_vpc.main.id

  availability_zone = local.availability_zones[count.index]

  tags = {
    Name = "${local.resource_prefix}-private-subnet-${count.index + 1}"
  }
}
resource "aws_db_subnet_group" "subnet_group" {
  name       = "${local.resource_prefix}-subnet-group"
  subnet_ids = aws_subnet.private.*.id

  tags = {
    Name = "${local.resource_prefix}-subnet-group"
  }
}
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "${local.resource_prefix}-private-rt"
  }
}
resource "aws_route_table_association" "private_subnet_association" {
  count          = length(local.availability_zones)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
#### end private subnet
resource "aws_rds_cluster" "aurora" {
  engine         = "aurora-postgresql"
  engine_version = "14.6"
  engine_mode    = "provisioned"

  cluster_identifier        = "${local.resource_prefix}-aurora"
  database_name             = "vitalparams"
  master_password           = var.db_password
  final_snapshot_identifier = "${local.resource_prefix}-aurora-delete-me"

  storage_encrypted      = true
  master_username        = var.master_username
  vpc_security_group_ids = [aws_security_group.aurora.id]

  db_subnet_group_name = aws_db_subnet_group.subnet_group.name

  serverlessv2_scaling_configuration {
    min_capacity = var.min_capacity
    max_capacity = var.max_capacity
  }

  preferred_maintenance_window = "Tue:03:00-Tue:04:00"
  preferred_backup_window      = "02:00-03:00"
  backup_retention_period      = 7

  tags = {
    Name = "${local.resource_prefix}-aurora"
  }
}

resource "aws_rds_cluster_instance" "cluster_instances" {
  cluster_identifier = aws_rds_cluster.aurora.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.aurora.engine
  engine_version     = aws_rds_cluster.aurora.engine_version
}
resource "aws_security_group_rule" "aurora_inbound_from_bastion" {
  security_group_id = aws_security_group.aurora.id

  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bastion.id
}

########## Security group rule for Lambda ##########
resource "aws_security_group" "lambda" {
  name        = "${local.resource_prefix}-lambda"
  description = "Security group for Lambda functions"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.aurora.id]
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
    Name = "${local.resource_prefix}-lambda"
  }
}
resource "aws_security_group_rule" "aurora_inbound_from_lambda" {
  security_group_id        = aws_security_group.aurora.id
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.lambda.id

  description = "Allow inbound traffic from Lambda on port 5432"
}
########## end of Security group rule for Lambda ##########

########## Internet access for Lambda (NAT) ##########
# Elastic IP for NAT Gateway
# Allocate an Elastic IP for the NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${local.resource_prefix}-nat-eip"
  }
}

# # Create a NAT Gateway in the public subnet
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = tolist(aws_subnet.public.*.id)[0] # Using the first public subnet

  tags = {
    Name = "${local.resource_prefix}-nat-gateway"
  }
}

# Update the route table for private subnets to route internet-bound traffic through the NAT Gateway
# Please find under resource "aws_route_table" "private" 

########## end of Internet access for Lambda (NAT) ##########
