name           = "nifi-postgres"
region         = "eu-west-2"
create_vpc     = false
instance_class = "db.m7g.large"
engine_version = "17.6"
db_username    = "postgres"

# Existing VPC Configuration (required when create_vpc = false)
existing_vpc_id = "vpc-0eb152610f491cfb3"
existing_subnet_ids = [
  "subnet-0b7f3513ecc69a242",
  "subnet-097c4f9ae3e0c4052",
  "subnet-02e0b74dfe9d9a4a6"
]
