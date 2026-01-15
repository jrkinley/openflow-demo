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
  enable_nat_gateway   = false
  enable_vpn_gateway   = false
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

# Security group for Amazon MQ broker
resource "aws_security_group" "mq" {
  name_prefix = "${var.name}_mq_"
  description = "Security group for Amazon MQ broker ${var.name}"
  vpc_id      = local.vpc_id

  # AMQP (RabbitMQ)
  ingress {
    from_port   = 5671
    to_port     = 5671
    protocol    = "tcp"
    cidr_blocks = var.publicly_accessible ? ["0.0.0.0/0"] : []
    self        = true
    description = "AMQP with TLS"
  }

  # RabbitMQ Web Console
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.publicly_accessible ? ["0.0.0.0/0"] : []
    self        = true
    description = "RabbitMQ Web Console / ActiveMQ Web Console"
  }

  # ActiveMQ OpenWire
  ingress {
    from_port   = 61617
    to_port     = 61617
    protocol    = "tcp"
    cidr_blocks = var.publicly_accessible ? ["0.0.0.0/0"] : []
    self        = true
    description = "ActiveMQ OpenWire with TLS"
  }

  # ActiveMQ STOMP
  ingress {
    from_port   = 61614
    to_port     = 61614
    protocol    = "tcp"
    cidr_blocks = var.publicly_accessible ? ["0.0.0.0/0"] : []
    self        = true
    description = "ActiveMQ STOMP with TLS"
  }

  # ActiveMQ MQTT
  ingress {
    from_port   = 8883
    to_port     = 8883
    protocol    = "tcp"
    cidr_blocks = var.publicly_accessible ? ["0.0.0.0/0"] : []
    self        = true
    description = "ActiveMQ MQTT with TLS"
  }

  # ActiveMQ WSS
  ingress {
    from_port   = 61619
    to_port     = 61619
    protocol    = "tcp"
    cidr_blocks = var.publicly_accessible ? ["0.0.0.0/0"] : []
    self        = true
    description = "ActiveMQ WSS"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.name}_mq_sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# CloudWatch Log Group for Amazon MQ
resource "aws_cloudwatch_log_group" "mq" {
  name              = "/aws/amazonmq/${var.name}"
  retention_in_days = 7

  tags = local.common_tags
}

# Amazon MQ Broker
resource "aws_mq_broker" "broker" {
  broker_name = var.name

  engine_type         = var.engine_type
  engine_version      = var.engine_version
  host_instance_type  = var.host_instance_type
  deployment_mode     = var.deployment_mode
  publicly_accessible = var.publicly_accessible

  security_groups = [aws_security_group.mq.id]
  subnet_ids      = var.deployment_mode == "SINGLE_INSTANCE" ? [local.subnet_ids[0]] : local.subnet_ids

  auto_minor_version_upgrade = var.auto_minor_version_upgrade

  maintenance_window_start_time {
    day_of_week = var.maintenance_day_of_week
    time_of_day = var.maintenance_time_of_day
    time_zone   = var.maintenance_time_zone
  }

  user {
    username = var.mq_username
    password = var.mq_password
  }

  logs {
    general = true
  }

  tags = merge(local.common_tags, {
    Name = var.name
  })
}

