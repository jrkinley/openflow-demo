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

# VPC Configuration (required when create_vpc = false)
create_vpc = false

# IMPORTANT: For public access, these MUST be public subnets with Internet Gateway routes
# Replace these with your actual VPC and PUBLIC subnet IDs
existing_vpc_id = "vpc-0eb152610f491cfb3"
existing_subnet_ids = [
  "subnet-0b7f3513ecc69a242" # Must be public subnet (only 1 needed for SINGLE_INSTANCE)
]

# Maintenance window
maintenance_day_of_week = "SUNDAY"
maintenance_time_of_day = "03:00"
maintenance_time_zone   = "UTC"

# To find your public subnets, use:
# aws ec2 describe-subnets --filters "Name=vpc-id,Values=YOUR_VPC_ID" \
#   --query 'Subnets[?MapPublicIpOnLaunch==`true`].{SubnetId:SubnetId,AZ:AvailabilityZone,CIDR:CidrBlock}'

