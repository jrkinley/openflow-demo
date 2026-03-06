# Phase 0: Prerequisites

## Required Tools

| Tool | Install | Verify |
|------|---------|--------|
| [Cortex Code CLI](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-cli) | `curl -LsS https://ai.snowflake.com/static/cc-scripts/install.sh \| sh` | `cortex --version` |
| [Terraform](https://developer.hashicorp.com/terraform/install) | `brew tap hashicorp/tap && brew install hashicorp/tap/terraform` | `terraform --version` |
| [AWS CLI](https://aws.amazon.com/cli/) | `brew install awscli` | `aws sts get-caller-identity` |
| [Git](https://git-scm.com/) | `brew install git` | `git --version` |

## Additional Tools by Phase 2 Path

**Kafka streaming path:**

| Tool | Install | Verify |
|------|---------|--------|
| [uv](https://github.com/astral-sh/uv) | `brew install uv` | `uv --version` |
| Python 3.11+ | Managed by uv | `uv run python --version` |

**CDC PostgreSQL path:**

| Tool | Install | Verify |
|------|---------|--------|
| [psql](https://www.postgresql.org/download/) | `brew install libpq` | `psql --version` |

## Accounts

- **Snowflake** -- Enterprise edition with Cortex features enabled. Your user must have the `SNOWFLAKE.CORTEX_USER` database role and `ACCOUNTADMIN` access for initial setup.
- **AWS** -- An account with credentials configured (`aws configure`) and permissions to create MSK, RDS, SFTP, and related networking resources.

## Openflow Runtime

An Openflow runtime must be provisioned in your Snowflake account before starting the workshop.

Before provisioning the runtime, create the `OPENFLOW_RUNTIME_ROLE` and assign it to the runtime during setup. The workshop setup script assumes this role already exists and grants it the permissions needed for the workshop -- it does not create the role itself.

## Cortex Code CLI Setup

On first run, `cortex` will guide you through connecting to your Snowflake account. If your Cortex models are not available in your region, you may need to enable cross-region inference:

```sql
ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'AWS_EU';
```

## Clone the Repository

```bash
git clone https://github.com/jrkinley/openflow-demo.git
cd openflow-demo/nasdaq-demo
```

## Snowflake Database Setup

Create the `NASDAQ_DEMO` database, stage, and permissions required by the workshop.

> **Cortex Code CLI**
>
> ```
> Run the SQL setup script at nasdaq-demo/snowflake/nasdaq_demo_setup.sql
> against my Snowflake account to create the NASDAQ_DEMO database,
> the earnings reports stage, and the permissions required by the
> workshop.
> ```

For manual steps, see [snowflake/nasdaq_demo_setup.sql](../snowflake/nasdaq_demo_setup.sql).
