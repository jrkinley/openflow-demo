# AWS MSK Cluster

Deploy an AWS Managed Streaming for Apache Kafka (MSK) cluster with SASL/SCRAM authentication and public access support.

## Quick Start

```bash
# Deploy with existing VPC
export TF_VAR_kafka_password=$(openssl rand -base64 10)
terraform init
terraform apply -var-file="examples/existing-vpc.tfvars"

# Enable public access via AWS Console
# MSK Console → Your Cluster → Properties → Networking Settings → Edit → Public Access: Turn On

# Test connection
cd test
./setup_and_test.sh
```

## Public Access Requirements

- **Public subnets** with Internet Gateway routes
- **Authentication enabled** (SASL/SCRAM ✓)
- **TLS encryption** (✓)

## Connection Details

```bash
terraform output msk_bootstrap_brokers_sasl_scram  # Connection string
terraform output kafka_username                    # Username
terraform output -raw kafka_password               # Password
```

## Using Redpanda's rpk CLI

[rpk](https://docs.redpanda.com/current/get-started/rpk-install/) is Redpanda's CLI tool that works with any Kafka-compatible cluster, including MSK.

### Installation

```bash
# macOS
brew install redpanda-data/tap/redpanda

# Linux (Debian/Ubuntu)
curl -LO https://github.com/redpanda-data/redpanda/releases/latest/download/rpk-linux-amd64.zip
unzip rpk-linux-amd64.zip -d ~/.local/bin/
```

### Configuration

Create an rpk profile for your MSK cluster:

```bash
# Get connection details
CLUSTER_ARN=$(terraform output -raw msk_cluster_arn)
BROKERS=$(aws kafka get-bootstrap-brokers --cluster-arn $CLUSTER_ARN \
  --query 'BootstrapBrokerStringPublicSaslScram' --output text)
USERNAME=$(terraform output -raw kafka_username)
PASSWORD=$(terraform output -raw kafka_password)

# Create rpk profile
rpk profile create msk-demo \
  --set brokers=$BROKERS \
  --set tls.enabled=true \
  --set sasl.mechanism=SCRAM-SHA-512 \
  --set user=$USERNAME \
  --set pass=$PASSWORD
```

### Common Commands

```bash
# List topics
rpk topic list

# Create a topic
rpk topic create my-topic --partitions 3 --replicas 2

# Produce messages
echo "hello world" | rpk topic produce my-topic

# Consume messages
rpk topic consume my-topic --offset start

# Describe topic
rpk topic describe my-topic

# List consumer groups
rpk group list

# Describe consumer group
rpk group describe my-consumer-group
```

## Troubleshooting

### Secret Already Scheduled for Deletion

If you encounter this error:
```
Error: creating Secrets Manager Secret (AmazonMSK_openflow-msk-demo): 
You can't create this secret because a secret with this name is already 
scheduled for deletion.
```

The secret exists but is in the deletion recovery window. Force delete it immediately:

```bash
aws secretsmanager delete-secret \
  --secret-id AmazonMSK_openflow-msk-demo \
  --force-delete-without-recovery
```

Then retry:
```bash
terraform apply -var-file="examples/new-vpc.tfvars" -var="kafka_password=YourPassword"
```

## Cleanup

```bash
terraform destroy -var-file="examples/new-vpc.tfvars" -var="kafka_password=YourPassword"
```