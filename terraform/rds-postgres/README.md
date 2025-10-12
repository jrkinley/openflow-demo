# PostgreSQL RDS with CDC Support

This Terraform module creates a PostgreSQL RDS instance configured for Change Data Capture (CDC) with the flexibility to either create a new VPC or use an existing one.

## Features

- **CDC Ready**: Configured with logical replication for Change Data Capture
- **Flexible VPC Usage**: Create new VPC or use existing infrastructure
- **Demo Database**: Includes setup scripts for NASDAQ stock market data

## Quick Start

### 1. Set Database Password

```bash
# Set the password as an environment variable (required)
export TF_VAR_db_password="your-secure-password"
```

### 2. Deploy Infrastructure

**Option A: Create New VPC**
```bash
terraform init
terraform apply -var-file="examples/new-vpc.tfvars"
```

**Option B: Use Existing VPC**
```bash
terraform init
terraform apply -var-file="examples/existing-vpc.tfvars"
```

### 3. Setup Demo Database

```bash
# Run the database setup script
cd db-setup
./setup.sh
```

### 4. Connect and Test

```bash
# Get connection details
RDS_HOST=$(terraform output -raw rds_hostname)

# Connect with psql
psql -h $RDS_HOST -U postgres -d postgres

# View demo data
SELECT * FROM nasdaq.stock_quotes ORDER BY quote_date DESC LIMIT 10;

# Test CDC
UPDATE nasdaq.stock_quotes SET close_price=230.00 WHERE symbol='SNOW' AND quote_date='2025-09-10';
```

## Configuration Examples

### New VPC Configuration
```hcl
module "postgres_rds" {
  source = "./tf-rds-pg"
  
  name           = "my-app"
  create_vpc     = true
  instance_class = "db.t3.micro"
  engine_version = "17.6"
  db_username    = "postgres"
  db_password    = var.db_password
}
```

### Existing VPC Configuration
```hcl
module "postgres_rds" {
  source = "./tf-rds-pg"
  
  name           = "my-app"
  create_vpc     = false
  instance_class = "db.t3.micro"
  engine_version = "17.6"
  db_username    = "postgres"
  db_password    = var.db_password
  
  existing_vpc_id = "vpc-0eb152610f491cfb3"
  existing_subnet_ids = [
    "subnet-0b7f3513ecc69a242",
    "subnet-097c4f9ae3e0c4052"
  ]
}
```

## CDC Configuration

The RDS instance is automatically configured with:
- **Logical Replication**: Enabled via `rds.logical_replication = 1`
- **Backup Retention**: 7 days (required for CDC)
- **Publication**: `openflow` publication created for CDC consumers
- **Demo Schema**: `nasdaq` schema with stock market data

## Requirements

- Terraform >= 1.0
- AWS Provider ~> 6.0
- PostgreSQL client tools (for database setup)
- When using existing VPC: At least 2 subnets in different availability zones

## Example Files

See the `examples/` directory:
- `new-vpc.tfvars` - Creating a new VPC
- `existing-vpc.tfvars` - Using an existing VPC