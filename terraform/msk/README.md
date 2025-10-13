# AWS MSK Cluster

Deploy an AWS Managed Streaming for Apache Kafka (MSK) cluster with SASL/SCRAM authentication and public access support.

## Quick Start

```bash
# Deploy with new VPC
terraform init
terraform apply -var-file="examples/new-vpc.tfvars" -var="kafka_password=YourPassword"

# Enable public access via AWS Console
# MSK Console → Your Cluster → Edit → Networking → Public Access: Turn On

# Test connection
./test/setup_and_test.sh
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| **Brokers** | 3 × `kafka.t3.small` | Demo-sized instances |
| **Storage** | 100GB per broker | EBS storage |
| **Auth** | SASL/SCRAM + IAM | Dual authentication |
| **Encryption** | TLS | In-transit encryption |

## Public Access Requirements

- **Public subnets** with Internet Gateway routes
- **Authentication enabled** (SASL/SCRAM ✓)
- **TLS encryption** (✓)

Check subnet type:
```bash
aws ec2 describe-subnets --subnet-ids subnet-xxx \
  --query 'Subnets[].{SubnetId:SubnetId,Public:MapPublicIpOnLaunch}'
```

## Connection Details

```bash
terraform output msk_bootstrap_brokers_sasl_scram  # Connection string
terraform output kafka_username                    # Username
terraform output -raw kafka_password               # Password
```

## Testing

The `test/` folder contains automated setup and testing scripts:
- `setup_and_test.sh` - Main test script
- `setup_acls_with_iam.sh` - ACL configuration for public access

## Cleanup

```bash
terraform destroy -var-file="examples/new-vpc.tfvars" -var="kafka_password=YourPassword"
```