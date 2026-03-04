# Phase 8: Teardown & Cleanup

Destroy all resources to avoid ongoing costs. Follow this order to handle dependencies correctly.

> **Important**: AWS Transfer Family (SFTP) costs ~$0.30/hour even when idle. MSK and RDS also incur hourly charges. Tear down promptly after the workshop.

## 8.1 Snowflake Objects

> **Cortex Code CLI**
>
> ```
> Read the teardown script at nasdaq-demo/snowflake/nasdaq_demo_teardown.sql
> and run it to drop all workshop objects from the NASDAQ_DEMO database.
> ```

See [`snowflake/nasdaq_demo_teardown.sql`](../snowflake/nasdaq_demo_teardown.sql) for the full list of objects dropped.

## 8.2 AWS Infrastructure

Destroy in any order -- the Terraform modules are independent.

**SFTP Server:**

> **Cortex Code CLI**
>
> ```
> Read the README at terraform/sftp/README.md for the cleanup
> instructions. Delete the SFTP user, empty and remove the S3 bucket,
> then run terraform destroy.
> ```

See the [SFTP Terraform README](../../terraform/sftp/README.md) for detailed teardown instructions.

**MSK Cluster (if deployed):**

> **Cortex Code CLI**
>
> ```
> Read the README at terraform/msk/README.md and destroy the MSK
> Terraform resources.
> ```

See the [MSK Terraform README](../../terraform/msk/README.md) for manual teardown steps.

**RDS PostgreSQL (if deployed):**

> **Cortex Code CLI**
>
> ```
> Read the README at terraform/rds-postgres/README.md and destroy the
> RDS PostgreSQL Terraform resources.
> ```

See the [RDS PostgreSQL Terraform README](../../terraform/rds-postgres/README.md) for manual teardown steps.

## 8.3 Local Cleanup (optional)

> **Cortex Code CLI**
>
> ```
> Clean up any local workshop artifacts: delete the rpk profile if one
> was created for the MSK cluster.
> ```

Manual steps:

```bash
rpk profile delete nasdaq-msk
```

## 8.4 Checkpoint

> **Cortex Code CLI**
>
> ```
> Verify the workshop teardown is complete. Check that no Terraform
> state files remain in the terraform directories, and query the
> NASDAQ_DEMO database to confirm all tables and objects have been
> dropped.
> ```
