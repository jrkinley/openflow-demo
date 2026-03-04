# Phase 2A: Structured Data -- Kafka Streaming

Load historical NASDAQ stock quotes into Snowflake via Kafka streaming from MSK.

This path results in a `HISTORICAL_STOCK_QUOTES` table in `NASDAQ_DEMO.PUBLIC`.

## Data Source

The historical stock quote CSVs in `data/` are downloaded from the NASDAQ website. Each stock has its own historical market activity page, for example:

> https://www.nasdaq.com/market-activity/stocks/tsla/historical

To download data, select the **Max** tab to get the full history, then click **Download**. The CSV format is the same for all stocks.

If you want to use fresher data or a different stock, download the CSV from the NASDAQ website and place it in the `data/` directory following the naming convention `HistoricalData_<SYMBOL>.csv`. The Kafka and PostgreSQL setup scripts both read from this shared directory.

---

### 2A.1 Configure the Kafka Producer

Populate the `.env` file in `kafka/` with your MSK connection details from the Terraform outputs.

> **Cortex Code CLI**
>
> ```
> Read the .env.example file in nasdaq-demo/kafka/ and the Terraform
> outputs from terraform/msk/ to create a .env file with the correct
> MSK bootstrap servers, SASL credentials, and topic name.
> ```

Alternatively, do it manually:

```bash
cd nasdaq-demo/kafka
cp .env.example .env
```

Edit `.env` with the values from `terraform output`:

```bash
cd ../../terraform/msk
terraform output msk_bootstrap_brokers_sasl_scram  # KAFKA_BOOTSTRAP_SERVERS
terraform output kafka_username                    # KAFKA_SASL_USERNAME
terraform output -raw kafka_password               # KAFKA_SASL_PASSWORD
```

### 2A.2 Set Up rpk for Kafka Interaction

[rpk](https://docs.redpanda.com/current/get-started/rpk-install/) is Redpanda's CLI tool that works with any Kafka-compatible cluster, including MSK. It's the easiest way to interact with topics, consumer groups, and ACLs from the terminal.

> **Cortex Code CLI**
>
> ```
> Read the README at terraform/msk/README.md for the rpk installation
> and setup instructions. Check if an existing rpk profile already
> exists for the MSK cluster brokers and credentials. If so, use it.
> If not, create a new profile called "nasdaq-msk-demo" using the
> Terraform outputs from terraform/msk/ with the public SASL/SCRAM
> broker endpoints and credentials.
> ```

For full details on rpk installation and MSK profile configuration, see [terraform/msk/README.md](../../terraform/msk/README.md).

Verify rpk can connect to the cluster:

```bash
rpk topic list
```

### 2A.3 Produce Data to Kafka and Verify

> **Cortex Code CLI**
>
> ```
> In nasdaq-demo/kafka/, run uv sync then run produce.py against
> the ../data directory with --recreate-topic. The script must load
> its connection settings from the .env file only -- ignore any
> Kafka variables already in the environment. After producing,
> verify the data using rpk.
> ```

For manual steps:

```bash
cd nasdaq-demo/kafka
uv sync
uv run python produce.py ../data --recreate-topic
rpk topic consume HISTORICAL_STOCK_QUOTES --offset start --num 5
```

### 2A.4 Configure Network Access and Permissions

The Openflow runtime needs network access to reach the MSK cluster, and the runtime role needs permissions on the NASDAQ_DEMO database.

> **Cortex Code CLI**
>
> ```
> Using the rpk profile or the .env file in nasdaq-demo/kafka/,
> get the MSK public broker hostnames and configure the following:
>
> 1. Create a network rule with the MSK public broker endpoints
>    (port 9196)
> 2. Create or update an external access integration (EAI) that
>    references the network rule
> 3. Grant USAGE on the EAI to OPENFLOW_RUNTIME_ROLE
> 4. Attach the EAI to the Openflow runtime service
> 5. Grant OPENFLOW_RUNTIME_ROLE USAGE on the NASDAQ_DEMO database
>    and USAGE + CREATE TABLE on the NASDAQ_DEMO.PUBLIC schema
> ```

For manual reference:

```sql
USE ROLE ACCOUNTADMIN;
USE DATABASE NASDAQ_DEMO;

-- Network rule for MSK public broker endpoints
CREATE OR REPLACE NETWORK RULE MSK_NETWORK_RULE
    MODE = EGRESS
    TYPE = HOST_PORT
    VALUE_LIST = ('<broker-1>:9196', '<broker-2>:9196', '<broker-3>:9196');

-- External access integration
CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION MSK_EAI
    ALLOWED_NETWORK_RULES = (MSK_NETWORK_RULE)
    ENABLED = TRUE;

GRANT USAGE ON INTEGRATION MSK_EAI TO ROLE OPENFLOW_RUNTIME_ROLE;

-- Attach EAI to the runtime
ALTER SERVICE <runtime-service-name>
    SET EXTERNAL_ACCESS_INTEGRATIONS = (MSK_EAI);

-- Permissions for the runtime role
GRANT USAGE ON DATABASE NASDAQ_DEMO TO ROLE OPENFLOW_RUNTIME_ROLE;
GRANT USAGE ON SCHEMA NASDAQ_DEMO.PUBLIC TO ROLE OPENFLOW_RUNTIME_ROLE;
GRANT CREATE TABLE ON SCHEMA NASDAQ_DEMO.PUBLIC TO ROLE OPENFLOW_RUNTIME_ROLE;
```

Replace `<broker-*>` with your MSK public broker hostnames and `<runtime-service-name>` with the Openflow runtime service name.

### 2A.5 Deploy the Openflow Kafka Connector

Deploy the Kafka connector from the Snowflake connector repository to the Openflow runtime.

> **Cortex Code CLI**
>
> ```
> Check your skills for Openflow. Install or upgrade the NiPyApi
> Python library using uv and update pyproject.toml. Verify that
> the Openflow runtime exists -- it should have "nasdaq" in the
> name. The Openflow runtime role is OPENFLOW_RUNTIME_ROLE.
>
> Do not modify or remove any existing connectors or parameter
> contexts in the runtime. Deploy a new Kafka connector from the
> Snowflake connector repository with its own new parameter context.
>
> Source configuration (from rpk profile or nasdaq-demo/kafka/.env):
> - Bootstrap servers, SASL/SCRAM credentials, topic name
>
> Destination configuration:
> - Database: NASDAQ_DEMO
> - Schema: PUBLIC
> - Table: HISTORICAL_STOCK_QUOTES
> - Auth: SNOWFLAKE_SESSION_TOKEN (leave account identifier,
>   username, and private key empty -- SPCS resolves these
>   from the session)
> ```

### 2A.6 Checkpoint

> **Cortex Code CLI**
>
> ```
> Verify that data has landed in the HISTORICAL_STOCK_QUOTES table
> in NASDAQ_DEMO.PUBLIC. Show the total row count and a sample of
> 10 rows.
> ```

```sql
SELECT COUNT(*) FROM NASDAQ_DEMO.PUBLIC.HISTORICAL_STOCK_QUOTES;

SELECT * FROM NASDAQ_DEMO.PUBLIC.HISTORICAL_STOCK_QUOTES LIMIT 10;
```

