# Phase 7: Teardown & Cleanup

Destroy all resources to avoid ongoing costs. Follow this order to handle dependencies correctly.

> **Important**: AWS Transfer Family (SFTP) costs ~$0.30/hour even when idle. MSK and RDS also incur hourly charges. Tear down promptly after the workshop.

## 7.1 Snowflake Objects

> **Cortex Code CLI**
>
> ```
> Read the teardown script at nasdaq-demo/snowflake/05_teardown.sql
> and run it to drop all workshop objects from the NASDAQ_DEMO database.
> ```

Manual SQL:

```sql
USE ROLE ACCOUNTADMIN;
USE DATABASE NASDAQ_DEMO;

-- Cortex Agent
DROP AGENT IF EXISTS NASDAQ_AGENT;

-- Cortex Search
DROP CORTEX SEARCH SERVICE IF EXISTS EARNINGS_REPORTS_SEARCH;

-- Semantic View
DROP SEMANTIC VIEW IF EXISTS HISTORICAL_QUOTES_SEMANTIC_VIEW;

-- Unstructured data objects
DROP TABLE IF EXISTS EARNINGS_REPORTS_CHUNKS;
DROP TABLE IF EXISTS EARNINGS_REPORTS_PARSED;
REMOVE @EARNINGS_REPORTS_STAGE;
DROP STAGE IF EXISTS EARNINGS_REPORTS_STAGE;

-- Structured data objects
DROP DYNAMIC TABLE IF EXISTS HISTORICAL_QUOTES_TYPED;
DROP VIEW IF EXISTS HISTORICAL_QUOTES_TIMESERIES;
DROP TABLE IF EXISTS HISTORICAL_QUOTES_FORECAST;

-- Raw data from Openflow connector
TRUNCATE TABLE IF EXISTS HISTORICAL_STOCK_QUOTES;
-- DROP TABLE IF EXISTS HISTORICAL_STOCK_QUOTES;
```

## 7.2 AWS Infrastructure

Destroy in any order -- the Terraform modules are independent.

**SFTP Server:**

> **Cortex Code CLI**
>
> ```
> Read the README at terraform/sftp/README.md for the cleanup
> instructions. Delete the SFTP user, empty and remove the S3 bucket,
> then run terraform destroy.
> ```

Manual steps:

```bash
cd terraform/sftp

# Delete the SFTP user
aws transfer delete-user \
  --server-id $(terraform output -raw server_id) \
  --user-name openflow-user

# Empty and delete the S3 bucket
aws s3 rm s3://openflow-sftp-bucket --recursive
aws s3 rb s3://openflow-sftp-bucket

# Delete SSH keys
rm -f aws_sftp_key aws_sftp_key.pub

# Destroy Terraform resources
terraform destroy
```

**MSK Cluster (if deployed):**

```bash
cd terraform/msk
terraform destroy -var-file="examples/existing-vpc.tfvars" -var="kafka_password=unused"
```

**RDS PostgreSQL (if deployed):**

```bash
cd terraform/rds-postgres
terraform destroy -var-file="examples/existing-vpc.tfvars" -var="db_password=unused"
```

## 7.3 Local Cleanup (optional)

```bash
# Remove rpk profile (if created)
rpk profile delete msk-demo

# Remove .env file
rm -f nasdaq-demo/.env
```

## 7.4 Checkpoint

Verify everything is gone:

```bash
# Check no Terraform state remains
ls terraform/*/terraform.tfstate 2>/dev/null && echo "WARNING: Terraform state files still exist" || echo "All clean"

# Check Snowflake
snow sql -q "SELECT TABLE_NAME FROM NASDAQ_DEMO.INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'PUBLIC';" --format json
```
