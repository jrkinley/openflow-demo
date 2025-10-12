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
  private_subnets      = var.private_subnets
  public_subnets       = var.public_subnets
  enable_nat_gateway   = true
  enable_vpn_gateway   = false
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = local.common_tags
}

# Local values to handle VPC and subnet references
locals {
  vpc_id     = var.create_vpc ? module.vpc[0].vpc_id : data.aws_vpc.existing[0].id
  subnet_ids = var.create_vpc ? module.vpc[0].private_subnets : var.existing_subnet_ids

  # Common tags for all resources
  common_tags = {
    owner = var.owner != null ? var.owner : data.external.local_user.result.username
  }
}

# Security group for MSK cluster
resource "aws_security_group" "msk" {
  name_prefix = "${var.name}_msk_"
  vpc_id      = local.vpc_id

  # Kafka broker communication (9092 for PLAINTEXT, 9094 for TLS, 9096 for SASL_SCRAM)
  ingress {
    from_port = 9092
    to_port   = 9092
    protocol  = "tcp"
    self      = true
  }

  ingress {
    from_port = 9094
    to_port   = 9094
    protocol  = "tcp"
    self      = true
  }

  ingress {
    from_port = 9096
    to_port   = 9096
    protocol  = "tcp"
    self      = true
  }

  # Allow public access to SASL_SCRAM port for demo purposes
  ingress {
    from_port   = 9096
    to_port     = 9096
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Public access to SASL_SCRAM port"
  }

  # Zookeeper communication
  ingress {
    from_port = 2181
    to_port   = 2181
    protocol  = "tcp"
    self      = true
  }

  # JMX monitoring
  ingress {
    from_port = 11001
    to_port   = 11002
    protocol  = "tcp"
    self      = true
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.name}_msk_sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Security group for MSK clients (if using public subnets)
resource "aws_security_group" "msk_client" {
  count       = var.create_vpc ? 1 : 0
  name_prefix = "${var.name}_msk_client_"
  vpc_id      = local.vpc_id

  # Allow outbound to MSK brokers
  egress {
    from_port       = 9092
    to_port         = 9092
    protocol        = "tcp"
    security_groups = [aws_security_group.msk.id]
  }

  egress {
    from_port       = 9094
    to_port         = 9094
    protocol        = "tcp"
    security_groups = [aws_security_group.msk.id]
  }

  # Allow outbound to Zookeeper
  egress {
    from_port       = 2181
    to_port         = 2181
    protocol        = "tcp"
    security_groups = [aws_security_group.msk.id]
  }

  # Allow all other outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.name}_msk_client_sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Update MSK security group to allow traffic from client security group
resource "aws_security_group_rule" "msk_from_client_9092" {
  count                    = var.create_vpc ? 1 : 0
  type                     = "ingress"
  from_port                = 9092
  to_port                  = 9092
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.msk_client[0].id
  security_group_id        = aws_security_group.msk.id
}

resource "aws_security_group_rule" "msk_from_client_9094" {
  count                    = var.create_vpc ? 1 : 0
  type                     = "ingress"
  from_port                = 9094
  to_port                  = 9094
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.msk_client[0].id
  security_group_id        = aws_security_group.msk.id
}

resource "aws_security_group_rule" "msk_from_client_2181" {
  count                    = var.create_vpc ? 1 : 0
  type                     = "ingress"
  from_port                = 2181
  to_port                  = 2181
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.msk_client[0].id
  security_group_id        = aws_security_group.msk.id
}

# CloudWatch Log Group for MSK
resource "aws_cloudwatch_log_group" "msk" {
  name              = "/aws/msk/${var.name}"
  retention_in_days = 7

  tags = local.common_tags
}

# MSK Configuration
resource "aws_msk_configuration" "msk" {
  kafka_versions = [var.kafka_version]
  name           = "${var.name}-config"

  server_properties = <<PROPERTIES
auto.create.topics.enable = true
default.replication.factor = 3
min.insync.replicas = 2
num.partitions = 3
log.retention.hours = 168
allow.everyone.if.no.acl.found = false
PROPERTIES
}

# MSK Cluster
resource "aws_msk_cluster" "msk" {
  cluster_name           = var.name
  kafka_version          = var.kafka_version
  number_of_broker_nodes = var.number_of_broker_nodes
  configuration_info {
    arn      = aws_msk_configuration.msk.arn
    revision = aws_msk_configuration.msk.latest_revision
  }

  broker_node_group_info {
    instance_type   = var.broker_instance_type
    client_subnets  = local.subnet_ids
    security_groups = [aws_security_group.msk.id]
    connectivity_info {
      public_access {
        type = "SERVICE_PROVIDED_EIPS"
      }
    }

    storage_info {
      ebs_storage_info {
        volume_size = var.ebs_volume_size
      }
    }
  }

  encryption_info {
    encryption_in_transit {
      client_broker = var.encryption_in_transit_client_broker
      in_cluster    = var.encryption_in_transit_in_cluster
    }
  }

  open_monitoring {
    prometheus {
      jmx_exporter {
        enabled_in_broker = true
      }
      node_exporter {
        enabled_in_broker = true
      }
    }
  }

  logging_info {
    broker_logs {
      cloudwatch_logs {
        enabled   = true
        log_group = aws_cloudwatch_log_group.msk.name
      }
    }
  }

  enhanced_monitoring = var.enhanced_monitoring

  client_authentication {
    sasl {
      scram = var.enable_sasl_scram
    }
  }

  tags = merge(local.common_tags, {
    Name = var.name
  })
}

# Simple SASL/SCRAM Authentication (AWS requires Secrets Manager)
resource "aws_secretsmanager_secret" "msk_scram_secret" {
  count = var.enable_sasl_scram ? 1 : 0
  name  = "${var.name}-msk-scram-secret"

  tags = merge(local.common_tags, {
    Name = "${var.name}_msk_scram_secret"
  })
}

resource "aws_secretsmanager_secret_version" "msk_scram_secret_version" {
  count     = var.enable_sasl_scram ? 1 : 0
  secret_id = aws_secretsmanager_secret.msk_scram_secret[0].id
  secret_string = jsonencode({
    username = var.kafka_username
    password = var.kafka_password
  })
}

resource "aws_msk_scram_secret_association" "msk_scram_association" {
  count           = var.enable_sasl_scram ? 1 : 0
  cluster_arn     = aws_msk_cluster.msk.arn
  secret_arn_list = [aws_secretsmanager_secret.msk_scram_secret[0].arn]
}
