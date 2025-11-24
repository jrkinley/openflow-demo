provider "aws" {
  region = var.region
}

data "aws_availability_zones" "available" {}

# Get local username for owner tag
data "external" "local_user" {
  program = ["sh", "-c", "echo '{\"username\":\"'$(id -un)'\"}'"]
}

# Data source for existing VPC (only used when create_vpc = false)
data "aws_vpc" "existing" {
  count = var.create_vpc ? 0 : 1
  id    = var.existing_vpc_id
}

# Data source for existing subnets (only used when create_vpc = false)
data "aws_subnets" "existing" {
  count = var.create_vpc ? 0 : 1
  filter {
    name   = "vpc-id"
    values = [var.existing_vpc_id]
  }
  filter {
    name   = "subnet-id"
    values = var.existing_subnet_ids
  }
}

# Create new VPC (only when create_vpc = true)
module "vpc" {
  count   = var.create_vpc ? 1 : 0
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.21"

  name                 = "${var.name}_vpc"
  cidr                 = var.vpc_cidr
  azs                  = data.aws_availability_zones.available.names
  public_subnets       = var.public_subnets
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = local.common_tags
}

# Local values to handle VPC and subnet references
locals {
  vpc_id     = var.create_vpc ? module.vpc[0].vpc_id : data.aws_vpc.existing[0].id
  subnet_ids = var.create_vpc ? module.vpc[0].public_subnets : var.existing_subnet_ids

  # Common tags for all resources
  common_tags = {
    owner = var.owner != null ? var.owner : data.external.local_user.result.username
  }
}

resource "aws_db_subnet_group" "rds-pg" {
  name       = "${var.name}_subnet_group"
  subnet_ids = local.subnet_ids

  tags = merge(local.common_tags, {
    Name = "${var.name}_subnet_group"
  })
}

resource "aws_security_group" "rds-pg" {
  name   = "${var.name}_sg"
  vpc_id = local.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.name}_sg"
  })
}

resource "aws_db_parameter_group" "rds-pg" {
  name   = var.name
  family = "postgres17"

  parameter {
    name  = "log_connections"
    value = "1"
  }

  # CDC (Change Data Capture) parameters
  parameter {
    name         = "rds.logical_replication"
    value        = "1"
    apply_method = "pending-reboot"
  }

  parameter {
    name  = "max_slot_wal_keep_size"
    value = "51200"  # 50GB limit to prevent WAL buildup
  }

  tags = local.common_tags
}

resource "aws_db_instance" "rds-pg" {
  identifier             = var.name
  instance_class         = var.instance_class
  allocated_storage      = 20
  max_allocated_storage  = 100
  storage_type           = "gp3"
  engine                 = "postgres"
  engine_version         = var.engine_version
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.rds-pg.name
  vpc_security_group_ids = [aws_security_group.rds-pg.id]
  parameter_group_name   = aws_db_parameter_group.rds-pg.name
  publicly_accessible    = true
  skip_final_snapshot    = true

  # CDC (Change Data Capture) requirements
  backup_retention_period = 7

  tags = local.common_tags
}
