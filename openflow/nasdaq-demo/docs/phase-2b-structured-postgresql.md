# Phase 2B: Structured Data -- PostgreSQL CDC

Load historical NASDAQ stock quotes into Snowflake via Change Data Capture from PostgreSQL RDS.

This path results in a `HISTORICAL_STOCK_QUOTES` table in `NASDAQ_DEMO.NASDAQ`.

## Data Source

The historical stock quote CSVs in `data/` are downloaded from the NASDAQ website. Each stock has its own historical market activity page, for example:

> https://www.nasdaq.com/market-activity/stocks/tsla/historical

To download data, select the **Max** tab to get the full history, then click **Download**. The CSV format is the same for all stocks.

If you want to use fresher data or a different stock, download the CSV from the NASDAQ website and place it in the `data/` directory following the naming convention `HistoricalData_<SYMBOL>.csv`. The Kafka and PostgreSQL setup scripts both read from this shared directory.

---

### 2B.1 Set Up the Demo Database

The PostgreSQL RDS instance is already up and running from Phase 1. Now create the demo schema and load the sample stock quote data.

> **Cortex Code CLI**
>
> ```
> Read the setup script at nasdaq-demo/postgres/setup.sh and the
> SQL scripts in the same directory. Note: if the Kafka path was
> followed previously, the nasdaq.historical_stock_quotes table may already
> exist -- if so, ask me whether to drop and recreate it before
> proceeding. Run the setup script to create the nasdaq schema,
> tables, and load the historical stock quote CSV data into the
> PostgreSQL RDS instance. Once complete, use psql to query the
> nasdaq.historical_stock_quotes table and confirm the row count and date
> range of the loaded data.
> ```

For manual steps, see [postgres/setup.sh](../postgres/setup.sh).

### 2B.2 Configure Network Access

The Openflow runtime needs network access to reach the PostgreSQL RDS instance. Find the Openflow runtime service name and attach the EAI.

> **Cortex Code CLI**
>
> ```
> Using the terraform/rds-postgres/ outputs, get the PostgreSQL
> RDS hostname and configure the following:
>
> 1. Create a network rule with the PostgreSQL RDS endpoint
>    (port 5432)
> 2. Create or update an external access integration (EAI) that
>    references the network rule
> 3. Grant USAGE on the EAI to OPENFLOW_RUNTIME_ROLE
> 4. Find the Openflow runtime service name (SHOW SERVICES LIKE
>    'OPENFLOW%') and attach the EAI to the service
> ```

For manual reference:

```sql
USE ROLE ACCOUNTADMIN;
USE DATABASE NASDAQ_DEMO;

CREATE OR REPLACE NETWORK RULE RDS_NETWORK_RULE
    MODE = EGRESS
    TYPE = HOST_PORT
    VALUE_LIST = ('<rds-hostname>:5432');

CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION RDS_EAI
    ALLOWED_NETWORK_RULES = (RDS_NETWORK_RULE)
    ENABLED = TRUE;

GRANT USAGE ON INTEGRATION RDS_EAI TO ROLE OPENFLOW_RUNTIME_ROLE;

-- Find the Openflow runtime service name
SHOW SERVICES LIKE 'OPENFLOW%' IN SCHEMA <database>.<schema>;

ALTER SERVICE <database>.<schema>.OPENFLOW$<runtime_name>
    SET EXTERNAL_ACCESS_INTEGRATIONS = (RDS_EAI);
```

Replace `<rds-hostname>` with your PostgreSQL RDS endpoint.

### 2B.3 Deploy the Openflow CDC Connector

Deploy the PostgreSQL CDC connector from the Snowflake connector repository to the Openflow runtime.

> **Note**: CDC mirrors the source schema structure into Snowflake. The `nasdaq.historical_stock_quotes` table in PostgreSQL will appear as `NASDAQ_DEMO.NASDAQ.HISTORICAL_STOCK_QUOTES` in Snowflake (source schema name becomes the destination schema).

> **Cortex Code CLI**
>
> ```
> Check your skills for Openflow. Install or upgrade the NiPyApi
> Python library using uv and update pyproject.toml. Verify that
> the Openflow runtime exists -- it should have "nasdaq" in the
> name. The Openflow runtime role is OPENFLOW_RUNTIME_ROLE.
>
> Do not modify or remove any existing connectors or parameter
> contexts in the runtime. Deploy a new PostgreSQL CDC connector
> from the Snowflake connector repository with its own new
> parameter context.
>
> Source configuration (from terraform/rds-postgres/ outputs):
> - JDBC URL: jdbc:postgresql://<hostname>:5432/postgres
> - Username: postgres
> - Password: from TF_VAR_db_password (sensitive -- set separately)
> - Publication: openflow
> - Table: nasdaq.historical_stock_quotes
>
> Destination configuration:
> - Database: NASDAQ_DEMO
> - Schema: auto-created from source schema name (NASDAQ)
> - Table: auto-created from source table name (HISTORICAL_STOCK_QUOTES)
> - Auth: SNOWFLAKE_SESSION_TOKEN (leave account identifier,
>   username, and private key empty -- SPCS resolves these
>   from the session)
>
> Parameter notes:
> - Non-sensitive parameters can be set in one call
> - Password is sensitive and must be set separately
> - JDBC driver must be uploaded as an asset, not set as a
>   parameter value
>
> If redeploying after a failed attempt: delete the process
> group, list and delete any orphan parameter contexts, then
> redeploy fresh.
> ```

### 2B.4 Checkpoint

> **Cortex Code CLI**
>
> ```
> Verify that data has landed in the NASDAQ_DEMO.NASDAQ.HISTORICAL_STOCK_QUOTES
> table. Show the total row count and a sample of 10 rows.
> ```

```sql
SELECT COUNT(*) FROM NASDAQ_DEMO.NASDAQ.HISTORICAL_STOCK_QUOTES;

SELECT * FROM NASDAQ_DEMO.NASDAQ.HISTORICAL_STOCK_QUOTES LIMIT 10;
```

### 2B.5 Test CDC (optional)

Demonstrate live Change Data Capture by updating a row in PostgreSQL and watching it appear in Snowflake:

```bash
RDS_HOST=$(cd terraform/rds-postgres && terraform output -raw rds_hostname)
psql -h $RDS_HOST -U postgres -d postgres -c \
  "UPDATE nasdaq.historical_stock_quotes SET close_price=0.0 WHERE symbol='TSLA' AND quote_date='2025-11-06';"
```

Wait a few moments, then check in Snowflake:

```sql
SELECT * FROM NASDAQ_DEMO.NASDAQ.HISTORICAL_STOCK_QUOTES
WHERE SYMBOL = 'TSLA' AND QUOTE_DATE = '2025-11-06';
```

Revert the change:

```bash
psql -h $RDS_HOST -U postgres -d postgres -c \
  "UPDATE nasdaq.historical_stock_quotes SET close_price=445.91 WHERE symbol='TSLA' AND quote_date='2025-11-06';"
```
