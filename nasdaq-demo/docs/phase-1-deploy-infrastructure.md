# Phase 1: Deploy Infrastructure

Deploy the external data sources on AWS using Terraform. All services are deployed into the same existing VPC.

You will always deploy the **SFTP server** (needed for unstructured data in Phase 3). Then choose either **MSK** (Kafka) or **RDS-Postgres** (CDC) depending on your Phase 2 path.

## VPC Configuration

The Terraform modules require a VPC ID and subnet IDs. Use the default VPC in your AWS account.

> **Cortex Code CLI**
>
> ```
> Using my configured AWS credentials, find the default VPC ID and its
> public subnet IDs in eu-west-2. Update the existing-vpc.tfvars
> example files in terraform/msk/ and terraform/rds-postgres/ with
> these values.
> ```

Alternatively, find them manually:

```bash
aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query "Vpcs[0].VpcId" --output text --region eu-west-2
aws ec2 describe-subnets --filters "Name=vpc-id,Values=<vpc-id>" --query "Subnets[*].SubnetId" --output text --region eu-west-2
```

## 1.1 Deploy SFTP Server

The SFTP server hosts the earnings report PDFs that Openflow will pick up and deliver to a Snowflake stage.

> **Cortex Code CLI**
>
> ```
> Read the README at terraform/sftp/README.md then deploy the SFTP
> terraform module using the default variables.
> ```

For manual steps, see [terraform/sftp/README.md](../../terraform/sftp/README.md).

**Checkpoint** -- verify the server is running:

```bash
cd terraform/sftp
terraform output server_endpoint
```

## 1.2 Deploy Structured Data Source (choose one)

### Option A: Kafka (MSK)

Deploys an AWS Managed Streaming for Apache Kafka cluster with SASL/SCRAM authentication and public access.

> **Important**: MSK provisioning takes approximately **45 minutes** end-to-end. The cluster itself takes 15-20 minutes to create, followed by a manual step in the AWS Console to enable public access, which triggers another 15-20 minute reconfiguration. Plan accordingly -- you can move ahead to [Phase 3](phase-3-unstructured-data.md) while waiting.

> **Cortex Code CLI**
>
> ```
> Read the README at terraform/msk/README.md then deploy the MSK
> terraform module using the existing VPC example tfvars. Generate a
> secure password for the Kafka user.
> ```

After `terraform apply` completes, enable public access via the AWS Console:

1. Open **MSK Console** -> Your Cluster -> **Properties**
2. **Networking Settings** -> **Edit** -> **Public Access: Turn On**
3. Wait for the cluster to return to **Active** state (~15-20 min)

For full details, see [terraform/msk/README.md](../../terraform/msk/README.md).

**Checkpoint** -- verify the cluster and note the connection details:

```bash
cd terraform/msk
terraform output msk_bootstrap_brokers_sasl_scram
terraform output kafka_username
terraform output -raw kafka_password
```

### Option B: PostgreSQL (CDC)

Deploys an RDS PostgreSQL instance configured for Change Data Capture with logical replication.

> **Cortex Code CLI**
>
> ```
> Read the README at terraform/rds-postgres/README.md then deploy the
> RDS PostgreSQL terraform module using the existing VPC example tfvars.
> Generate a secure password for the database user.
> ```

After the instance is available, set up the demo database:

> **Cortex Code CLI**
>
> ```
> Read the README at terraform/rds-postgres/README.md then run the
> database setup script in terraform/rds-postgres/db-setup/ to create
> the schema and load the sample data.
> ```

For full details, see [terraform/rds-postgres/README.md](../../terraform/rds-postgres/README.md).

**Checkpoint** -- verify the database and data:

```bash
cd terraform/rds-postgres
RDS_HOST=$(terraform output -raw rds_hostname)
psql -h $RDS_HOST -U postgres -d postgres -c \
  "SELECT symbol, COUNT(*) FROM nasdaq.stock_quotes GROUP BY symbol;"
```
