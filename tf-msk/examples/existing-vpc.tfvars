name                   = "kafka-demo"
region                 = "eu-west-2"
create_vpc             = false
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

# Existing VPC Configuration (required when create_vpc = false)
# Replace these with your actual VPC and subnet IDs
existing_vpc_id = "vpc-0eb152610f491cfb3"
existing_subnet_ids = [
  "subnet-0b7f3513ecc69a242",
  "subnet-097c4f9ae3e0c4052",
  "subnet-02e0b74dfe9d9a4a6"
]
