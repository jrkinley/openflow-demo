# IMF DataMapper Demo

An Openflow demo that ingests macroeconomic data from the [IMF DataMapper API](https://www.imf.org/external/datamapper/api/v1/) and writes it to a Snowflake table.

## Data Source

The [IMF DataMapper API](https://www.imf.org/external/datamapper/api/v1/) provides free, public access to the International Monetary Fund's World Economic Outlook (WEO) dataset. The API returns time-series data for a wide range of macroeconomic indicators across all IMF member countries.

### Indicators

| Indicator Code | Description |
|----------------|-------------|
| NGDPDPC | GDP per capita (current prices, USD) |
| NGDPD | GDP (current prices, USD billions) |
| NGDP_RPCH | GDP growth (annual % change) |
| PCPIPCH | Inflation (average consumer prices, annual % change) |
| LUR | Unemployment rate (% of total labor force) |
| GGXWDG_NGDP | Government gross debt (% of GDP) |
| BCA_NGDPD | Current account balance (% of GDP) |
| LP | Population (millions) |

Data is available for **190+ countries** with historical values and IMF projections.

## Snowflake Setup

Before deploying the Openflow flow, create the target table and grant the necessary permissions to the Openflow runtime role.

### Create the database and table

```sql
CREATE DATABASE IF NOT EXISTS API_DEMO;
USE DATABASE API_DEMO;

CREATE OR REPLACE TABLE API_DEMO.PUBLIC.IMF_DATAMAPPER_INDICATORS (
    INDICATOR VARCHAR,
    COUNTRY_CODE VARCHAR,
    YEAR NUMBER(38,0),
    VALUE FLOAT,
    INGESTION_TIMESTAMP TIMESTAMP_NTZ(9)
);
```

### Create external access integration

```sql
CREATE OR REPLACE NETWORK RULE IMF_API_NETWORK_RULE
    MODE = EGRESS
    TYPE = HOST_PORT
    VALUE_LIST = ('www.imf.org');

CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION IMF_API_ACCESS
    ALLOWED_NETWORK_RULES = (IMF_API_NETWORK_RULE)
    ENABLED = TRUE;

GRANT USAGE ON INTEGRATION IMF_API_ACCESS TO ROLE "OPENFLOW_RUNTIME_ROLE";
```

### Grant permissions to the Openflow runtime role

The `OPENFLOW_RUNTIME_ROLE` requires USAGE on the database and schema, CREATE TABLE on the schema, and read/write privileges on the table:

```sql
-- Database grants
GRANT USAGE ON DATABASE API_DEMO TO ROLE OPENFLOW_RUNTIME_ROLE;
GRANT CREATE SCHEMA ON DATABASE API_DEMO TO ROLE OPENFLOW_RUNTIME_ROLE;

-- Schema grants
GRANT USAGE ON SCHEMA API_DEMO.PUBLIC TO ROLE OPENFLOW_RUNTIME_ROLE;
GRANT CREATE TABLE ON SCHEMA API_DEMO.PUBLIC TO ROLE OPENFLOW_RUNTIME_ROLE;

-- Table grants
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, REBUILD, EVOLVE SCHEMA, APPLYBUDGET
    ON TABLE API_DEMO.PUBLIC.IMF_DATAMAPPER_INDICATORS
    TO ROLE OPENFLOW_RUNTIME_ROLE;
```

## How It Works

1. The flow calls the IMF DataMapper API to fetch WEO indicator data for all available countries and years.
2. The response is parsed and flattened into rows of `(indicator, country_code, year, value)`.
3. The data is written to a Snowflake table using the Openflow Snowpipe Streaming processor.

## Getting Started with Cortex Code CLI

The [Cortex Code CLI](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-cli) is required to deploy this demo. The CLI has built-in Openflow skills that know how to deploy flows, manage the Openflow runtime, and interact with the NiFi REST API via [NiPyApi](https://nipyapi.readthedocs.io/).

### Prerequisites

1. Install the Cortex Code CLI following the [installation guide](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-cli).
2. An Openflow runtime must already be provisioned and active in your Snowflake account.
3. Complete the [Snowflake Setup](#snowflake-setup) steps above to create the database, table, external access integration, and role grants.
4. This project includes a uv environment with NiPyApi pre-configured. Install the dependencies:

```bash
uv sync
```

### Deploy and run

Open the Cortex Code CLI from this project directory and use the following prompt to validate your setup and deploy the flow:

```
Deploy and run the IMF DataMapper demo:

1. Read your Openflow skills so you know how to interact
   with flows and the Openflow runtime.
2. Verify that my Openflow runtime exists and is active.
3. Check that the following all exist: the API_DEMO
   database, the IMF_DATAMAPPER_INDICATORS table, and
   the IMF_API_ACCESS external access integration. If
   anything is missing, follow the Snowflake Setup section
   in the README to create it. If you are unable to
   complete any prerequisite, state what failed and stop.
4. Use the project's Python virtual environment (.venv)
   for all nipyapi operations via Python, not the CLI.
5. Deploy the imf-weo.json flow to my Openflow runtime
   and start it.
6. Wait for the flow to finish. Poll every 10 seconds
   and wait until the process group has processed data.
   Only then stop the flow.
7. Verify the data loaded by querying the table to list
   the top 10 countries by GDP per capita for the
   current year.
8. Delete the flow instance when done.
```

### Documentation

- [Cortex Code CLI](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-cli)
- [Openflow](https://docs.snowflake.com/en/user-guide/data-integration/openflow)
- [NiPyApi](https://nipyapi.readthedocs.io/)
- [Apache NiFi REST API](https://nifi.apache.org/docs/nifi-docs/rest-api/index.html)
