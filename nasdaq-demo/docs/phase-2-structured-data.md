# Phase 2: Structured Data

Load historical NASDAQ stock quotes into Snowflake. Choose the path that matches the infrastructure you deployed in Phase 1.

Both options result in a `HISTORICAL_STOCK_QUOTES` table in Snowflake.

---

## Option A: Kafka Streaming

### 2A.1 Configure the Kafka Producer

Populate the `.env` file with your MSK connection details from the Terraform outputs.

> **Cortex Code CLI**
>
> ```
> Read the .env.example file in nasdaq-demo/ and the Terraform outputs
> from terraform/msk/ to create a .env file with the correct MSK
> bootstrap servers, SASL credentials, and topic name.
> ```

Alternatively, do it manually:

```bash
cd nasdaq-demo
cp .env.example .env
```

Edit `.env` with the values from `terraform output`:

```bash
cd ../terraform/msk
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
> and setup instructions. Using the Terraform outputs from terraform/msk/,
> install rpk and create an rpk profile called "msk-demo" with the
> public SASL/SCRAM broker endpoints and credentials.
> ```

For full details on rpk installation and MSK profile configuration, see [terraform/msk/README.md](../../terraform/msk/README.md).

Verify rpk can connect to the cluster:

```bash
rpk topic list
```

### 2A.3 Produce Data to Kafka

Run the producer to push the historical stock quote CSVs into the Kafka topic:

```bash
cd nasdaq-demo
uv sync
uv run python produce.py ./data --recreate-topic
```

### 2A.4 Verify Data in Kafka

Confirm the data landed in the topic before connecting Openflow.

**Using rpk:**

```bash
rpk topic describe historical-stock-quotes
rpk topic consume historical-stock-quotes --offset start --num 5
```

**Using the Python consumer:**

```bash
cd nasdaq-demo
uv run python consume.py --limit 10
```

### 2A.5 Deploy the Openflow Kafka Connector

Deploy the Kafka connector flow to Openflow so it consumes from the MSK topic and writes to a Snowflake table.

> **Cortex Code CLI**
>
> ```
> Check your skills for Openflow. Deploy the Kafka connector flow
> defined in nasdaq-demo/openflow/default/nasdaq-demo-kafka.json to
> the Openflow runtime. The connector should consume from the
> historical-stock-quotes topic on my MSK cluster and write to the
> HISTORICAL_STOCK_QUOTES table in the NASDAQ_DEMO database.
> ```

For details on the flow definition, see [openflow/default/nasdaq-demo-kafka.json](../openflow/default/nasdaq-demo-kafka.json).

### 2A.6 Checkpoint

Verify data has landed in Snowflake:

```sql
SELECT COUNT(*) FROM NASDAQ_DEMO.PUBLIC.HISTORICAL_STOCK_QUOTES;

SELECT * FROM NASDAQ_DEMO.PUBLIC.HISTORICAL_STOCK_QUOTES LIMIT 10;
```

---

## Option B: PostgreSQL CDC

The demo database was seeded during [Phase 1](phase-1-deploy-infrastructure.md#option-b-postgresql-cdc). Now deploy the Openflow CDC connector to replicate the data into Snowflake.

### 2B.1 Deploy the Openflow CDC Connector

> **Cortex Code CLI**
>
> ```
> Check your skills for Openflow. Deploy the CDC connector flow defined
> in nasdaq-demo/openflow/default/nasdaq-demo-cdc.json to the Openflow
> runtime. The connector should replicate from the nasdaq.stock_quotes
> table in my RDS PostgreSQL instance and write to the
> HISTORICAL_STOCK_QUOTES table in the NASDAQ_DEMO database.
> ```

For details on the flow definition, see [openflow/default/nasdaq-demo-cdc.json](../openflow/default/nasdaq-demo-cdc.json).

### 2B.2 Checkpoint

Verify data has landed in Snowflake:

```sql
SELECT COUNT(*) FROM NASDAQ_DEMO.PUBLIC.HISTORICAL_STOCK_QUOTES;

SELECT * FROM NASDAQ_DEMO.PUBLIC.HISTORICAL_STOCK_QUOTES LIMIT 10;
```

### 2B.3 Test CDC (optional)

Demonstrate live Change Data Capture by updating a row in PostgreSQL and watching it appear in Snowflake:

```bash
RDS_HOST=$(cd terraform/rds-postgres && terraform output -raw rds_hostname)
psql -h $RDS_HOST -U postgres -d postgres -c \
  "UPDATE nasdaq.stock_quotes SET close_price=0.0 WHERE symbol='TSLA' AND quote_date='2025-11-06';"
```

Wait a few moments, then check in Snowflake:

```sql
SELECT * FROM NASDAQ_DEMO.PUBLIC.HISTORICAL_STOCK_QUOTES
WHERE SYMBOL = 'TSLA' AND DATE = '2025-11-06';
```

Revert the change:

```bash
psql -h $RDS_HOST -U postgres -d postgres -c \
  "UPDATE nasdaq.stock_quotes SET close_price=445.91 WHERE symbol='TSLA' AND quote_date='2025-11-06';"
```

---

## Create the Dynamic Table

Regardless of which path you chose, create a dynamic table that cleans and types the raw data. This gives downstream phases a consistent, well-typed view of the stock quote data.

> **Cortex Code CLI**
>
> ```
> In the NASDAQ_DEMO database, create a dynamic table called
> HISTORICAL_QUOTES_TYPED that selects from HISTORICAL_STOCK_QUOTES
> and converts the date column to DATE, strips the $ prefix from the
> price columns and casts them to DOUBLE, and keeps symbol and volume
> as-is. Set the target lag to 1 minute and use the COMPUTE_WH warehouse.
> ```

Manual SQL:

```sql
CREATE OR REPLACE DYNAMIC TABLE NASDAQ_DEMO.PUBLIC.HISTORICAL_QUOTES_TYPED
    TARGET_LAG = '1 minute'
    WAREHOUSE = 'COMPUTE_WH'
    AS
        SELECT
            SYMBOL,
            TO_DATE(DATE) AS QUOTE_DATE,
            TO_DOUBLE(LTRIM(CLOSE_LAST, '$')) AS CLOSE_LAST_USD,
            VOLUME,
            TO_DOUBLE(LTRIM(OPEN, '$')) AS OPEN_USD,
            TO_DOUBLE(LTRIM(HIGH, '$')) AS HIGH_USD,
            TO_DOUBLE(LTRIM(LOW, '$')) AS LOW_USD
        FROM HISTORICAL_STOCK_QUOTES;
```

**Checkpoint** -- verify the typed data:

```sql
SELECT
    SYMBOL,
    COUNT(QUOTE_DATE) AS NUM_QUOTES,
    MIN(QUOTE_DATE) AS EARLIEST,
    MAX(QUOTE_DATE) AS LATEST,
    MAX(CLOSE_LAST_USD) AS MAX_CLOSE
FROM NASDAQ_DEMO.PUBLIC.HISTORICAL_QUOTES_TYPED
GROUP BY SYMBOL
ORDER BY SYMBOL;
```
