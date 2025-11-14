# AWS MSK Cluster

Deploy an AWS Managed Streaming for Apache Kafka (MSK) cluster with SASL/SCRAM authentication and public access support.

## Quick Start

```bash
# Deploy with new VPC
terraform init
terraform apply -var-file="examples/new-vpc.tfvars" -var="kafka_password=YourPassword"

# Enable public access via AWS Console
# MSK Console → Your Cluster → Properties → Networking Settings → Edit → Public Access: Turn On

# Test connection
cd test
.setup_and_test.sh
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