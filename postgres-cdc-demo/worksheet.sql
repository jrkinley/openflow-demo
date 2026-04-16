-- =======================================================================
-- PostgreSQL CDC Demo — Manual Worksheet
-- =======================================================================
--
-- This worksheet walks you through deploying an end-to-end PostgreSQL CDC
-- pipeline using Openflow and Snowflake Postgres. Import it into a
-- Snowsight SQL worksheet and run each section in order.
--
-- Steps that require psql or the Openflow UI are marked with ACTION
-- blocks — follow those instructions outside of Snowsight, then return
-- here and continue.
--
-- Reference: https://docs.snowflake.com/en/user-guide/data-integration/openflow/connectors/postgres/setup
-- =======================================================================


-- =====================================================================
-- STEP 1: Create the Snowflake Postgres instance
-- =====================================================================

USE ROLE ACCOUNTADMIN;

-- 1a. Target database (also holds network rules)
CREATE DATABASE IF NOT EXISTS PG_CDC_DEMO_DB;
USE DATABASE PG_CDC_DEMO_DB;

-- 1b. Network rule & policy (open to all for demo purposes)
CREATE NETWORK RULE IF NOT EXISTS PG_CDC_DEMO_INGRESS_RULE
    TYPE = IPV4
    VALUE_LIST = ('0.0.0.0/0')
    MODE = POSTGRES_INGRESS;

CREATE NETWORK POLICY IF NOT EXISTS PG_CDC_DEMO_NETWORK_POLICY
    ALLOWED_NETWORK_RULE_LIST = ('PG_CDC_DEMO_DB.PUBLIC.PG_CDC_DEMO_INGRESS_RULE')
    COMMENT = 'Allows inbound connections to the CDC demo Postgres instance.';

-- 1c. Create the Postgres instance
--     IMPORTANT: Save the credentials from the output! You will need the
--     snowflake_admin password for psql connections later.
CREATE POSTGRES INSTANCE IF NOT EXISTS PG_CDC_DEMO
    COMPUTE_FAMILY   = 'BURST_S'
    STORAGE_SIZE_GB  = 10
    AUTHENTICATION_AUTHORITY = POSTGRES
    POSTGRES_VERSION = 17
    NETWORK_POLICY   = 'PG_CDC_DEMO_NETWORK_POLICY'
    COMMENT          = 'Postgres CDC demo instance';

-- 1d. Poll until the instance state is READY
--     Wait 30 seconds between checks. Typically takes 2-5 minutes.
CALL SYSTEM$WAIT(30);

DESCRIBE POSTGRES INSTANCE PG_CDC_DEMO
    ->> SELECT "property", "value"
        FROM $1
        WHERE "property" IN ('name', 'state', 'host');

-- Re-run the CALL + DESCRIBE above until state = READY.
-- Once READY, note the 'host' value — you'll need it for the rest of
-- the tutorial. We'll refer to it as <PG_HOST> below.


-- =====================================================================
-- STEP 2: Connect via psql and prepare the database for CDC
-- =====================================================================

-- ACTION: Open a terminal and run the following commands.
--
-- Set up .pgpass so the password isn't displayed on screen:
--
--   echo "<PG_HOST>:5432:postgres:snowflake_admin:<PASSWORD>" > ~/.pgpass && chmod 600 ~/.pgpass
--
-- Connect to the Postgres instance:
--
--   psql "host=<PG_HOST> port=5432 user=snowflake_admin dbname=postgres sslmode=require"
--
-- 2a. Check if logical replication is already enabled:
--
--   SHOW wal_level;
--
-- If it shows 'logical', skip ahead to Step 2b.
-- If it shows 'replica', run:
--
--   ALTER SYSTEM SET wal_level = logical;
--
-- Then disconnect (\q), reconnect, and verify with SHOW wal_level;
--
-- 2b. Create the schema and table:
--
--   CREATE SCHEMA IF NOT EXISTS who;
--
--   CREATE TABLE IF NOT EXISTS who.life_expectancy (
--       year            SMALLINT       NOT NULL,
--       geo_code        SMALLINT       NOT NULL,
--       geo_code_type   VARCHAR(50)    NOT NULL,
--       geo_name        VARCHAR(150)   NOT NULL,
--       sex             VARCHAR(10)    NOT NULL,
--       life_expectancy NUMERIC(16,8)  NOT NULL,
--       PRIMARY KEY (year, geo_code, sex)
--   );
--
-- 2c. Load the CSV data via a temp staging table.
--     The RELAY_WHS.csv file is in the demo repo (postgres-cdc-demo/).
--     Start psql from that directory, or use the full path in the \copy command.
--
--   CREATE TEMP TABLE _raw_import (
--       ind_id TEXT, ind_code TEXT, ind_uuid TEXT, ind_per_code TEXT,
--       dim_time TEXT, dim_time_type TEXT, dim_geo_code_m49 TEXT,
--       dim_geo_code_type TEXT, dim_publish_state TEXT, ind_name TEXT,
--       geo_name_short TEXT, dim_sex TEXT, amount_n TEXT
--   );
--
--   \copy _raw_import FROM 'RELAY_WHS.csv' WITH (FORMAT csv, HEADER true)
--
--   INSERT INTO who.life_expectancy (year, geo_code, geo_code_type, geo_name, sex, life_expectancy)
--   SELECT dim_time::SMALLINT, dim_geo_code_m49::SMALLINT, dim_geo_code_type,
--          geo_name_short, dim_sex, amount_n::NUMERIC(16,8)
--   FROM _raw_import;
--
--   DROP TABLE _raw_import;
--
-- 2d. Create the CDC publication:
--
--   CREATE PUBLICATION openflow FOR TABLE who.life_expectancy;
--
-- 2e. Verify the data loaded:
--
--   SELECT COUNT(*) FROM who.life_expectancy;
--   -- Expected: 12,936 rows
--
--   SELECT * FROM who.life_expectancy
--   WHERE geo_name = 'Switzerland'
--   ORDER BY year DESC, sex LIMIT 10;
--
-- Once verified, return to this worksheet.


-- =====================================================================
-- STEP 3: Snowflake target database & networking
-- =====================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE PG_CDC_DEMO_DB;

-- 3a. RBAC grants for the Openflow CDC role
GRANT USAGE ON DATABASE PG_CDC_DEMO_DB TO ROLE OPENFLOW_CDC_ROLE;
GRANT CREATE SCHEMA ON DATABASE PG_CDC_DEMO_DB TO ROLE OPENFLOW_CDC_ROLE;
GRANT USAGE ON SCHEMA PG_CDC_DEMO_DB.PUBLIC TO ROLE OPENFLOW_CDC_ROLE;
GRANT CREATE TABLE ON SCHEMA PG_CDC_DEMO_DB.PUBLIC TO ROLE OPENFLOW_CDC_ROLE;
GRANT USAGE ON FUTURE SCHEMAS IN DATABASE PG_CDC_DEMO_DB TO ROLE OPENFLOW_CDC_ROLE;
GRANT USAGE, OPERATE ON WAREHOUSE OPENFLOW_WH TO ROLE OPENFLOW_CDC_ROLE;

GRANT SELECT ON FUTURE TABLES IN DATABASE PG_CDC_DEMO_DB TO ROLE ACCOUNTADMIN;
GRANT USAGE ON FUTURE SCHEMAS IN DATABASE PG_CDC_DEMO_DB TO ROLE ACCOUNTADMIN;

-- 3b. Egress network rule & EAI so Openflow can reach the Postgres instance
--     Replace <PG_HOST> with your actual Postgres hostname from Step 1d
--     (run DESCRIBE POSTGRES INSTANCE PG_CDC_DEMO if you need to look it up).
CREATE OR REPLACE NETWORK RULE PG_CDC_DEMO_EGRESS_RULE
    MODE = EGRESS
    TYPE = HOST_PORT
    VALUE_LIST = ('<PG_HOST>:5432');

CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION PG_CDC_DEMO_EAI
    ALLOWED_NETWORK_RULES = (PG_CDC_DEMO_DB.PUBLIC.PG_CDC_DEMO_EGRESS_RULE)
    ENABLED = TRUE;

GRANT USAGE ON INTEGRATION PG_CDC_DEMO_EAI TO ROLE OPENFLOW_CDC_ROLE;

-- ACTION: Attach the EAI to your Openflow runtime manually:
--
--   1. Open Snowsight → Data Integration → Openflow
--   2. Select your runtime
--   3. In runtime settings, add PG_CDC_DEMO_EAI to External Access Integrations
--   4. Save the changes
--
-- Continue once the EAI is attached.


-- =====================================================================
-- STEP 4: Install and configure the PostgreSQL CDC connector
-- =====================================================================

-- ACTION: This step is performed entirely in the Openflow UI.
--
-- 4a. Install the connector:
--   1. Navigate to the Openflow overview page
--   2. Select "View more connectors"
--   3. Find "PostgreSQL" and select "Add to runtime"
--   4. Select your runtime and click Add
--   5. Authenticate when prompted
--
-- 4b. Configure Source Parameters:
--   Right-click the connector process group → Parameters → Source Parameters
--
--   PostgreSQL Connection URL:  jdbc:postgresql://<PG_HOST>:5432/postgres?ssl=true&sslmode=require
--   PostgreSQL JDBC Driver:    Upload postgresql-42.7.8.jar as a Reference Asset
--                              (download from https://jdbc.postgresql.org/download/)
--   PostgreSQL Username:       snowflake_admin
--   PostgreSQL Password:       <your password> (set this as a sensitive parameter)
--   Publication Name:          openflow
--                              (must match the CREATE PUBLICATION name from Step 2d)
--
-- 4c. Configure Destination Parameters:
--
--   Destination Database:              PG_CDC_DEMO_DB
--   Snowflake Authentication Strategy: SNOWFLAKE_MANAGED_TOKEN
--   Snowflake Account Identifier:      (leave blank)
--   Snowflake Username:                (leave blank)
--   Snowflake Private Key:             (leave blank)
--   Snowflake Role:                    OPENFLOW_CDC_ROLE
--   Snowflake Warehouse:               OPENFLOW_WH   ← REQUIRED, MERGE will fail without this
--   Object Identifier Resolution:      CASE_INSENSITIVE
--
-- 4d. Configure Ingestion Parameters:
--
--   Included Table Names:      who.life_expectancy
--   Merge Task Schedule CRON:  * * * * * ?    (continuous)
--
-- 4e. Enable and start:
--   1. Right-click on the canvas → Enable all Controller Services
--      NOTE: The "Private Key Service" will fail — this is expected when
--      using SNOWFLAKE_MANAGED_TOKEN. Disable or ignore it.
--   2. Right-click the process group → Start
--
-- Continue once the connector is running.


-- =====================================================================
-- STEP 5: Verify initial data load
-- =====================================================================

-- Wait 30-60 seconds after starting the connector, then run:
SELECT COUNT(*) FROM PG_CDC_DEMO_DB.WHO.LIFE_EXPECTANCY;
-- If 0, wait another 30 seconds and retry.

SELECT * FROM PG_CDC_DEMO_DB.WHO.LIFE_EXPECTANCY
WHERE GEO_NAME = 'Switzerland'
ORDER BY YEAR DESC, SEX
LIMIT 10;


-- =====================================================================
-- STEP 6: Test live CDC
-- =====================================================================

-- Use this query in Snowsight to watch the change arrive in real time.
-- Run it before and after each update below:
SELECT YEAR, GEO_NAME, SEX, LIFE_EXPECTANCY
FROM PG_CDC_DEMO_DB.WHO.LIFE_EXPECTANCY
WHERE GEO_CODE = 826 AND YEAR = 2021
ORDER BY SEX;

-- ACTION: Connect to the Postgres instance's "postgres" database using
-- the .pgpass file you set up in Step 2:
--
--   psql "host=<PG_HOST> port=5432 user=snowflake_admin dbname=postgres sslmode=require"
--
-- Then run this update:
--
--   UPDATE who.life_expectancy SET life_expectancy = 100.00
--   WHERE geo_code = 826 AND year = 2021 AND sex = 'FEMALE';
--
-- Wait 30-90 seconds for the change to propagate (typically ~60 seconds
-- for the first CDC change), then re-run the SELECT above in this worksheet.
-- The UK Female 2021 value should now show 100.00.

-- ACTION: In the same psql session, revert the change:
--
--   UPDATE who.life_expectancy SET life_expectancy = 81.93070945
--   WHERE geo_code = 826 AND year = 2021 AND sex = 'FEMALE';
--
-- Wait 30-90 seconds, then re-run the SELECT above.
-- The value should be back to 81.93070945.
--
-- CDC round-trip verified!


-- =====================================================================
-- STEP 7: Teardown
-- =====================================================================

-- 7a. Inventory — check what exists before dropping anything
USE ROLE ACCOUNTADMIN;
SHOW POSTGRES INSTANCES LIKE 'PG_CDC_DEMO%';
SHOW DATABASES LIKE 'PG_CDC_DEMO%';
SHOW INTEGRATIONS LIKE 'PG_CDC_DEMO%';
SHOW NETWORK POLICIES LIKE 'PG_CDC_DEMO%';

-- ACTION: Openflow cleanup (do this first, in the Openflow UI):
--
--   1. Right-click the PostgreSQL process group → Stop
--   2. Disable all Controller Services
--   3. Delete the process group
--   4. Delete the orphaned parameter contexts from the Parameter Contexts
--      panel. Delete the Ingestion (parent) context first, then Source
--      and Destination. Deleting in the wrong order causes a 409 conflict.

-- !! IMPORTANT: Before dropping the EAI you MUST detach it from the runtime.
-- If the EAI is still attached when dropped, the runtime may enter an error state.
--
-- ACTION: Open Snowsight → Data Integration → Openflow → select your runtime →
-- remove PG_CDC_DEMO_EAI from the External Access Integrations list → Save.
-- Do NOT proceed until this is done.

-- 7b. Drop the EAI and egress network rule
DROP EXTERNAL ACCESS INTEGRATION IF EXISTS PG_CDC_DEMO_EAI;
DROP NETWORK RULE IF EXISTS PG_CDC_DEMO_DB.PUBLIC.PG_CDC_DEMO_EGRESS_RULE;

-- 7c. Drop in dependency order: instance → network policy → database
DROP POSTGRES INSTANCE IF EXISTS PG_CDC_DEMO;
DROP NETWORK POLICY IF EXISTS PG_CDC_DEMO_NETWORK_POLICY;
DROP DATABASE IF EXISTS PG_CDC_DEMO_DB;

-- 7d. Local cleanup (run in your terminal):
--
--   rm -f ~/.pgpass

-- Teardown complete!
