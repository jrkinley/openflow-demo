# AWS MSK Cluster - Terraform Configuration

Deploy an AWS Managed Streaming for Apache Kafka (MSK) cluster with SASL/SCRAM authentication.

## Quick Start

```bash
# Initialize and deploy with new VPC
terraform init
terraform apply -var-file="examples/new-vpc.tfvars" -var="kafka_password=YourSecurePassword"

# Or use existing VPC (update VPC/subnet IDs first)
terraform apply -var-file="examples/existing-vpc.tfvars" -var="kafka_password=YourSecurePassword"
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| **Kafka Version** | `3.5.1` | Latest supported version |
| **Broker Nodes** | `3` | `kafka.t3.small` instances |
| **Storage** | `100GB` | EBS per broker |
| **Authentication** | SASL/SCRAM | Username/password auth |
| **Encryption** | TLS | In-transit encryption |
| **Region** | `eu-west-2` | AWS region |

## Outputs

After deployment, get connection details:

```bash
terraform output msk_bootstrap_brokers_sasl_scram  # Connection string
terraform output kafka_username                    # SASL username
terraform output -raw kafka_password               # SASL password
```

## Kafka Client Configuration

```properties
bootstrap.servers=<msk_bootstrap_brokers_sasl_scram>
security.protocol=SASL_SSL
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username="<kafka_username>" password="<kafka_password>";
```

## Features

- ✅ **SASL/SCRAM Authentication** - Secure username/password auth
- ✅ **TLS Encryption** - Data encrypted in transit
- ✅ **CloudWatch Logging** - Broker logs automatically sent
- ✅ **Auto-tagging** - Resources tagged with your username
- ✅ **VPC Flexibility** - Create new VPC or use existing

## Cleanup

```bash
terraform destroy -var-file="examples/new-vpc.tfvars" -var="kafka_password=YourSecurePassword"
```

## Cost Optimization

- Uses `kafka.t3.small` for demo/dev workloads
- 100GB storage per broker (300GB total)
- Consider larger instances for production use