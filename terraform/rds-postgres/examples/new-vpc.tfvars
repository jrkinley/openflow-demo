name           = "nifi-pg-cdc"
region         = "eu-west-2"
create_vpc     = true
instance_class = "db.m7g.large"
engine_version = "17.6"
db_username    = "postgres"

# VPC Configuration (only used when create_vpc = true)
vpc_cidr       = "10.0.0.0/16"
public_subnets = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
