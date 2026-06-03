# Snowpark Python: External API to Snowflake

Run arbitrary Python against any external API and stream the results into Snowflake — no SQL pipelines, no orchestration tooling, no intermediate storage. Two deployment options:

1. **Stored Procedure** — runs on a Snowflake warehouse, writes via `write_pandas`
2. **SPCS Container Job** — runs in Snowpark Container Services, streams via Snowpipe Streaming v2

Both examples fetch macroeconomic data from the [IMF DataMapper API](https://www.imf.org/external/datamapper/api/v1/) (World Economic Outlook dataset: GDP, inflation, unemployment across 229 countries).

## Files

| File | Description |
|------|-------------|
| `imf_datamapper_api_proc.py` | Stored procedure version (Snowpark + pandas) |
| `imf_datamapper_api_spcs.py` | SPCS container version (Snowpipe Streaming v2) |
| `Dockerfile` | Container image for SPCS deployment |
| `requirements.txt` | Python dependencies for SPCS container |

## Prerequisites

- Snowflake account with ACCOUNTADMIN privileges
- [Snowflake CLI](https://docs.snowflake.com/en/developer-guide/snowflake-cli/index) (`snow`) installed
- Docker (for SPCS image build/push)

## Option 1: Stored Procedure

Uses `snowflake-snowpark-python` with `write_pandas` to load data into a table. Runs on a warehouse with external access to `www.imf.org`.

### Deploy

```sql
-- Network rule + external access integration
CREATE OR REPLACE NETWORK RULE API_DEMO.PUBLIC.IMF_API_NETWORK_RULE
  MODE = EGRESS
  TYPE = HOST_PORT
  VALUE_LIST = ('www.imf.org');

CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION IMF_API_ACCESS
  ALLOWED_NETWORK_RULES = (API_DEMO.PUBLIC.IMF_API_NETWORK_RULE)
  ENABLED = TRUE;

-- Stage for Python code
CREATE OR REPLACE STAGE API_DEMO.PUBLIC.PYTHON_CODE;
```

```bash
snow stage copy imf_datamapper_api_proc.py @API_DEMO.PUBLIC.PYTHON_CODE --overwrite
```

```sql
CREATE OR REPLACE PROCEDURE API_DEMO.PUBLIC.IMF_DATAMAPPER_REFRESH()
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.12'
PACKAGES = ('snowflake-snowpark-python', 'requests', 'pandas')
IMPORTS = ('@API_DEMO.PUBLIC.PYTHON_CODE/imf_datamapper_api_proc.py')
HANDLER = 'imf_datamapper_api_proc.main'
EXTERNAL_ACCESS_INTEGRATIONS = (IMF_API_ACCESS)
EXECUTE AS CALLER;
```

### Run

```sql
CALL API_DEMO.PUBLIC.IMF_DATAMAPPER_REFRESH();
```

## Option 2: SPCS with Snowpipe Streaming v2

Uses the `snowpipe-streaming` SDK (v1.5.0+) with SPCS workload-identity token authentication. The container authenticates automatically via `/snowflake/session/token` — no keys or secrets needed in the image.

### Setup Snowflake Objects

```sql
-- Target table
CREATE TABLE IF NOT EXISTS API_DEMO.PUBLIC.IMF_DATAMAPPER_INDICATORS_SSV2 (
    INDICATOR STRING,
    COUNTRY_CODE STRING,
    YEAR NUMBER,
    VALUE FLOAT,
    INGESTION_TIMESTAMP STRING
);

-- Streaming pipe
CREATE PIPE IF NOT EXISTS API_DEMO.PUBLIC.IMF_SSV2_PIPE AS
    COPY INTO API_DEMO.PUBLIC.IMF_DATAMAPPER_INDICATORS_SSV2
    FROM TABLE(DATA_SOURCE(TYPE => 'STREAMING'))
    MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

-- Image repository + compute pool (if not already created)
CREATE IMAGE REPOSITORY IF NOT EXISTS API_DEMO.PUBLIC.IMF_IMAGES;
CREATE COMPUTE POOL IF NOT EXISTS IMF_COMPUTE_POOL
  MIN_NODES = 1 MAX_NODES = 1
  INSTANCE_FAMILY = CPU_X64_XS;
```

### Build and Push Container

```bash
docker build --platform linux/amd64 -t imf_datamapper_api_spcs:latest .

# Get your registry URL
snow spcs image-registry url

# Login and push
snow spcs image-registry login
docker tag imf_datamapper_api_spcs:latest <registry_url>/api_demo/public/imf_images/imf_datamapper_api_spcs:latest
docker push <registry_url>/api_demo/public/imf_images/imf_datamapper_api_spcs:latest
```

### Run

```sql
EXECUTE JOB SERVICE
  IN COMPUTE POOL IMF_COMPUTE_POOL
  NAME = API_DEMO.PUBLIC.IMF_SSV2_JOB
  EXTERNAL_ACCESS_INTEGRATIONS = (IMF_API_ACCESS)
  FROM SPECIFICATION $$
  spec:
    containers:
    - name: imf-datamapper-ssv2
      image: /api_demo/public/imf_images/imf_datamapper_api_spcs:latest
      env:
        SNOWFLAKE_DATABASE: API_DEMO
        SNOWFLAKE_SCHEMA: PUBLIC
        TABLE_NAME: IMF_DATAMAPPER_INDICATORS_SSV2
  capabilities:
    securityContext:
      enableCustomCredentials: true
  $$;
```

### Check Status

```sql
CALL SYSTEM$GET_SERVICE_LOGS('API_DEMO.PUBLIC.IMF_SSV2_JOB', '0', 'imf-datamapper-ssv2');
SELECT COUNT(*) FROM API_DEMO.PUBLIC.IMF_DATAMAPPER_INDICATORS_SSV2;
```

## Verify Data

```sql
SELECT COUNTRY_CODE, YEAR, ROUND(VALUE, 2) AS GDP_PER_CAPITA_USD
  FROM API_DEMO.PUBLIC.IMF_DATAMAPPER_INDICATORS_SSV2
 WHERE INDICATOR = 'NGDPDPC'
   AND YEAR = (SELECT MAX(YEAR) FROM API_DEMO.PUBLIC.IMF_DATAMAPPER_INDICATORS_SSV2
               WHERE INDICATOR = 'NGDPDPC' AND VALUE IS NOT NULL)
 ORDER BY VALUE DESC
 LIMIT 10;
```

## Cleanup

```sql
DROP SERVICE IF EXISTS API_DEMO.PUBLIC.IMF_SSV2_JOB;
DROP PIPE IF EXISTS API_DEMO.PUBLIC.IMF_SSV2_PIPE;
DROP TABLE IF EXISTS API_DEMO.PUBLIC.IMF_DATAMAPPER_INDICATORS_SSV2;
DROP PROCEDURE IF EXISTS API_DEMO.PUBLIC.IMF_DATAMAPPER_REFRESH();
DROP STAGE IF EXISTS API_DEMO.PUBLIC.PYTHON_CODE;
DROP EXTERNAL ACCESS INTEGRATION IF EXISTS IMF_API_ACCESS;
DROP NETWORK RULE IF EXISTS API_DEMO.PUBLIC.IMF_API_NETWORK_RULE;
ALTER COMPUTE POOL IMF_COMPUTE_POOL SUSPEND;
```
