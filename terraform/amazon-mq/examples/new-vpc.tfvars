name   = "openflow-mq-demo"
region = "eu-west-2"

# Broker configuration
engine_type        = "ActiveMQ"
engine_version     = "5.18"
host_instance_type = "mq.t3.micro"
deployment_mode    = "SINGLE_INSTANCE"

# Public access for demos
publicly_accessible = true

# Authentication
mq_username = "mqadmin"
# mq_password should be set via environment variable: TF_VAR_mq_password

# Create a new VPC
create_vpc = true
vpc_cidr   = "10.0.0.0/16"
public_subnets = [
  "10.0.4.0/24",
  "10.0.5.0/24",
  "10.0.6.0/24"
]

# Maintenance window
maintenance_day_of_week = "SUNDAY"
maintenance_time_of_day = "03:00"
maintenance_time_zone   = "UTC"

