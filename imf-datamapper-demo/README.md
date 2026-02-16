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

## Deploying with Cortex Code CLI

[Cortex Code](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-code) is Snowflake's AI-powered CLI that can deploy and manage Openflow flows using natural language. It uses the [NiPyApi](https://nipyapi.readthedocs.io/) Python library to interact with the NiFi REST API on your Openflow runtime.

Cortex Code requires a local Python environment with the [NiPyApi](https://nipyapi.readthedocs.io/) library installed. This project includes a uv environment with NiPyApi pre-configured:

```bash
uv sync
```

Install Cortex Code following the [installation guide](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-code/install), then use a prompt like this to deploy the flow:

```
First, query the API_DEMO.PUBLIC.IMF_DATAMAPPER_INDICATORS table to get
the current count of distinct indicators, distinct countries, and the
latest ingestion timestamp. Then deploy the imf-weo.json flow to my
Openflow runtime, start it, and wait for it to complete. Once finished,
query the table again and compare the number of indicators and countries
against the original counts — they may differ if the IMF source data
has changed. Validate that the ingestion timestamp has been updated so
we know the data is fresh. Stop and delete the flow instance when done.
```

### Documentation

- [Cortex Code](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-code)
- [Openflow](https://docs.snowflake.com/en/user-guide/data-integration/openflow)
- [NiPyApi](https://nipyapi.readthedocs.io/)
- [Apache NiFi REST API](https://nifi.apache.org/docs/nifi-docs/rest-api/index.html)
