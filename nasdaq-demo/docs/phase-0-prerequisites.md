# Phase 0: Prerequisites

## Required Tools

| Tool | Install | Verify |
|------|---------|--------|
| [Cortex Code CLI](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-cli) | `curl -LsS https://ai.snowflake.com/static/cc-scripts/install.sh \| sh` | `cortex --version` |
| [Terraform](https://developer.hashicorp.com/terraform/install) | `brew install terraform` | `terraform --version` |
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
