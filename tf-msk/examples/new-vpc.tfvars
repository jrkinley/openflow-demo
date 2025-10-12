name                   = "kafka-demo"
region                 = "eu-west-2"
create_vpc             = true
kafka_version          = "3.5.1"
number_of_broker_nodes = 3
broker_instance_type   = "kafka.t3.small"
ebs_volume_size        = 100

# Encryption settings
encryption_in_transit_client_broker = "TLS"
encryption_in_transit_in_cluster    = true

# Monitoring
enhanced_monitoring = "DEFAULT"

# SASL/SCRAM Authentication
enable_sasl_scram = true
kafka_username    = "kafka-user"
# kafka_password should be set via environment variable or prompt

# VPC Configuration (only used when create_vpc = true)
vpc_cidr        = "10.0.0.0/16"
private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
public_subnets  = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
