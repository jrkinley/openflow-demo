# AWS MSK Cluster - Terraform Configuration

Deploy an AWS Managed Streaming for Apache Kafka (MSK) cluster with SASL/SCRAM authentication.

## Quick Start

```bash
# Navigate to MSK module
cd terraform/msk

# Initialize and deploy with new VPC
terraform init
terraform apply -var-file="examples/new-vpc.tfvars" -var="kafka_password=YourSecurePassword"

# Enable public access (manual step required)
# See "Enabling Public Access" section below

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

## Enabling Public Access

AWS MSK clusters are created with private access only. To enable public access:

### Step 1: Verify Cluster is Active
```bash
# Check cluster status
aws kafka describe-cluster --cluster-arn $(terraform output -raw msk_cluster_arn)
```

### Step 2: Enable Public Access via AWS Console
1. Go to [AWS MSK Console](https://console.aws.amazon.com/msk/home)
2. Click on your cluster name
3. Click **"Edit"** → **"Networking"**
4. Under **"Public access"**, select **"Turn on"**
5. Click **"Save changes"**
6. Wait 10-15 minutes for the update to complete

### Step 3: Update Terraform Outputs
```bash
# Refresh to get new public bootstrap brokers
terraform refresh -var-file="examples/new-vpc.tfvars" -var="kafka_password=YourPassword"

# Get public connection string
terraform output msk_bootstrap_brokers_sasl_scram
```

### Step 4: Test Connection
```bash
./setup_and_test.sh
```

### Alternative: AWS CLI Method
```bash
# Get cluster ARN
CLUSTER_ARN=$(terraform output -raw msk_cluster_arn)

# Enable public access
aws kafka update-connectivity \
  --cluster-arn "$CLUSTER_ARN" \
  --connectivity-info '{"PublicAccess":{"Type":"SERVICE_PROVIDED_EIPS"}}'

# Monitor progress
aws kafka describe-cluster --cluster-arn "$CLUSTER_ARN" --query 'ClusterInfo.State'
```

## Cleanup

```bash
terraform destroy -var-file="examples/new-vpc.tfvars" -var="kafka_password=YourSecurePassword"
```

## Cost Optimization

- Uses `kafka.t3.small` for demo/dev workloads
- 100GB storage per broker (300GB total)
- Consider larger instances for production use