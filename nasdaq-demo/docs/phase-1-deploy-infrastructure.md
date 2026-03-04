# Phase 1: Deploy Infrastructure

Deploy the external data sources on AWS using Terraform. All services are deployed into the same existing VPC.

You will always deploy the **SFTP server** (needed for unstructured data in Phase 4). Then choose either **MSK** (Kafka) or **RDS-Postgres** (CDC) depending on your Phase 2 path.

## VPC Configuration

The Terraform modules require a VPC ID and subnet IDs. Use the default VPC in your AWS account.

Start Cortex Code CLI from your terminal:

```bash
cortex
```

> **Cortex Code CLI**
>
> ```
> Using my configured AWS credentials, find the default VPC ID and its
> public subnet IDs. Update the existing-vpc.tfvars example files in
> terraform/msk/ and terraform/rds-postgres/ with these values.
> ```

Alternatively, find them manually:

```bash
aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query "Vpcs[0].VpcId" --output text
aws ec2 describe-subnets --filters "Name=vpc-id,Values=<vpc-id>" --query "Subnets[*].SubnetId" --output text
```

## 1.1 Deploy SFTP Server

The SFTP server hosts the earnings report PDFs that Openflow will pick up and deliver to a Snowflake stage.

> **Cortex Code CLI**
>
> ```
> Read the README at terraform/sftp/README.md then deploy the SFTP
> terraform module using the default variables and the existing default
> VPC. After deployment, verify the SFTP server is reachable by
> connecting and listing the root directory.
> ```

For manual steps, see [terraform/sftp/README.md](../../terraform/sftp/README.md).

## 1.2 Deploy Structured Data Source (choose one)

### Option A: Kafka (MSK)

Deploys an AWS Managed Streaming for Apache Kafka cluster with SASL/SCRAM authentication and public access.

> **Important**: MSK provisioning takes approximately **45 minutes or more** end-to-end. The cluster itself takes 20+ minutes to create, then enabling public access triggers another 20+ minute reconfiguration. Plan accordingly -- you can move ahead to [Phase 4](phase-4-unstructured-data.md) while waiting.

> **Cortex Code CLI**
>
> ```
> Read the README at terraform/msk/README.md then deploy the MSK
> terraform module using the default variables and the existing
> default VPC. Generate a secure password for the Kafka user.
> After terraform apply completes, enable public access on the
> cluster using the AWS CLI. Monitor the cluster state until it
> returns to Active. Once Active, run the setup and test script
> to create the public Kafka user, then verify the connection
> using the rpk instructions in the README. This process
> takes 45+ minutes end-to-end so be patient and allow
> plenty of time for each step. Print progress updates at
> each stage so I always know what step we are at and what
> is happening while waiting.
> ```

For full details, see [terraform/msk/README.md](../../terraform/msk/README.md).

### Option B: PostgreSQL (CDC)

Deploys an RDS PostgreSQL instance configured for Change Data Capture with logical replication.

> **Cortex Code CLI**
>
> ```
> Read the README at terraform/rds-postgres/README.md then deploy
> the RDS PostgreSQL terraform module using the default variables
> and the existing default VPC. Generate a secure password for the
> database user. After deployment, verify the instance is available
> by connecting with psql.
> ```

For full details, see [terraform/rds-postgres/README.md](../../terraform/rds-postgres/README.md).
