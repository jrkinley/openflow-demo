---
name: postgres-cdc-demo
description: "Deploy an end-to-end PostgreSQL CDC pipeline using Openflow and Snowflake Postgres. Creates a Snowflake Postgres instance, enables logical replication, loads WHO life-expectancy data, deploys an Openflow CDC connector to stream changes into a Snowflake native table, and verifies the pipeline. Includes full teardown. Triggers: postgres cdc demo, openflow cdc demo, clean up postgres cdc demo."
---

## When to use

Use this skill when the user wants to:

- Demo CDC from PostgreSQL into Snowflake native tables via Openflow
- Create a Snowflake Postgres instance and configure it for CDC
- Deploy an Openflow PostgreSQL CDC connector end-to-end
- Tear down a previously deployed postgres CDC demo

## What this skill provides

1. **Snowflake Postgres instance** (Steps 0-2) — Network policy, instance creation, enable logical replication
2. **Data population** (Step 3) — Load WHO life-expectancy data, create CDC publication
3. **Snowflake target setup** (Step 4) — Target database, RBAC, network rule, EAI
4. **Openflow CDC connector** (Step 5) — Deploy and start the connector
5. **Verification** (Step 6) — Confirm data lands, automated live CDC round-trip (6b), then optional **manual playbook** (6c: psql login, `UPDATE`s, Snowsight `SELECT`s) before teardown
6. **Teardown** (Step 7) — Remove connector, Snowflake objects, drop Postgres instance

## Variables

Track these throughout the skill. Defaults shown in parentheses.

| Variable | Source | Default |
|----------|--------|---------|
| `RUNTIME_NAME` | User input | — |
| `PG_HOST` | DESCRIBE POSTGRES INSTANCE output | — |
| `PG_PASSWORD` | CREATE POSTGRES INSTANCE output | — |
| `SF_TARGET_DB` | — | `PG_CDC_DEMO_DB` |
| `SF_ROLE` | — | `OPENFLOW_CDC_ROLE` |
| `PUBLICATION` | — | `openflow` |
| `SOURCE_TABLE` | — | `who.life_expectancy` |

## Instructions

**EXECUTION GUIDELINES:**

1. **Announce each step clearly** with a header like "**Step X -- [Name]**".
2. **Batch commands aggressively** — run independent checks in parallel.
3. **Store all variable values** as you collect them; reference them in later steps.
4. **Never display passwords** in chat output. Save them silently.
5. **Postgres CSV load (Step 3b) must run in a single psql session.** `CREATE TEMP TABLE` and client `\copy` are session-scoped; do not split them across separate `psql -c` calls or separate tool invocations. Run **one** shell command that `cd`s to the directory containing `RELAY_WHS.csv` and feeds the full Step 3b heredoc to `psql` on stdin (as written in Step 3b), or open **one** interactive `psql` and paste that entire block. Do not rely on an external `.sql` file unless the user chooses to create one locally.
6. **Use a `.pgpass` file for psql connections** to avoid passwords appearing on screen. Create it once at the start, then all psql commands connect without exposing credentials:
   ```bash
   echo "<PG_HOST>:5432:postgres:snowflake_admin:<PG_PASSWORD>" > ~/.pgpass && chmod 600 ~/.pgpass
   ```
   After this, connect with just: `psql "host=<PG_HOST> port=5432 user=snowflake_admin dbname=postgres sslmode=require"`
   Clean up `~/.pgpass` during teardown.
7. **Always read your Openflow skills first** before any Openflow operation (checking runtimes, deploying connectors, managing process groups, teardown). The Openflow skills contain the authoritative guidance for interacting with the runtime and NiPyApi.
8. **Snowsight-friendly Snowflake SQL during CDC checks (Step 6b).** After the Postgres `UPDATE` to **100.00**, **print the Snowsight copy-paste block** (the two `SELECT`s in Step 2) in the chat **before** the wait so the user can run Snowsight in parallel during the pause. When you **verify CDC propagation** in Snowflake (Step 2 after the update, and Step 4 after the revert), **print those same `SELECT`s again in a fenced `sql` block**— easy copy-paste for Snowsight alongside whatever you run from the CLI. Mention that Snowsight is optional but fits live demos (break from the terminal). Use the exact SQL from Step 2 / Step 4, not a paraphrase. **Also print the Postgres `UPDATE` statements** from Step 6b for reference: at minimum, when you start the live CDC test (before or with Step 1), print the **Postgres — copy-paste `UPDATE` reference** block (both `UPDATE`s in one fence); when you run the revert (Step 3), print that revert `UPDATE` again in its own fenced `sql` block so the user can copy into psql without hunting the transcript.
9. **Manual follow-on playbook (Step 6c).** After Step 6b succeeds and you deliver the CDC verified message, **always print the full Step 6c section** (psql login, Postgres `SELECT`/`UPDATE`s, Snowflake `SELECT`s, pointer to Step 7 teardown) in the same user-facing response so the user can **continue the demo manually** — open psql, paste changes in Postgres, flip to Snowsight and re-run the Snowflake queries — **before** any teardown. Substitute `<PG_HOST>` with the real host; never print the password.

---

### Step 0 -- Confirm intent & collect inputs

> "This skill deploys an end-to-end **PostgreSQL CDC pipeline** entirely within Snowflake:
> - Creates a Snowflake Postgres instance
> - Enables logical replication and loads WHO life-expectancy data (~12.9k rows)
> - Deploys an Openflow PostgreSQL CDC connector
> - Streams row-level changes into a Snowflake native table in near-real time
>
> Ready to proceed?"

After confirmation, ask:

1. **"Which Openflow runtime would you like to use?"** — read your Openflow skills and use them to list the active runtimes. Present the list to the user and ask them to pick one. Store the selected name as `RUNTIME_NAME`. Check whether a local nipyapi profile exists for the selected runtime; if not, nipyapi will create one on first use.
2. **"Do you already have a Snowflake Postgres instance you'd like to use, or should I create a new one?"**
   - If **existing** → run `SHOW POSTGRES INSTANCES;` and present the list to the user. Ask them to select which instance to use. Then run `DESCRIBE POSTGRES INSTANCE <selected_instance>;` to capture the `host` value as `PG_HOST`. Ask the user for the password (store as `PG_PASSWORD`). Skip to Step 3.
   - If **new** → proceed to Step 1.

---

### Step 1 -- Prerequisites

**Two parallel tool calls:**

**Bash** (tool check):
```bash
echo "=== psql ==="; psql --version 2>/dev/null || echo "NOT FOUND"
echo "=== Snow CLI ==="; snow --version 2>/dev/null || echo "NOT FOUND"
echo "=== uv ==="; uv --version 2>/dev/null || echo "NOT FOUND"
echo "=== Python venv ==="; test -d .venv && echo "FOUND (.venv)" || echo "NOT FOUND"
```

**SQL** (Snowflake context):
```sql
SELECT CURRENT_USER() AS current_user, CURRENT_ROLE() AS current_role,
       CURRENT_ACCOUNT() AS current_account, CURRENT_REGION() AS current_region;
```

**Stop if:** psql not found, snow CLI not found, uv not found, or Snowflake connection fails.

#### 1b. Python environment

If a `.venv` directory exists in the current working directory, activate it and check for nipyapi:

```bash
source .venv/bin/activate && python -c "import nipyapi; print('nipyapi OK')" 2>/dev/null || echo "nipyapi NOT FOUND"
```

If there is no `.venv` or nipyapi is missing, ask the user:

> "The Openflow skills require a local Python environment with the `nipyapi` package. Can I create one in the current directory using uv?"

On confirmation:

```bash
uv venv .venv && source .venv/bin/activate && uv pip install nipyapi && python -c "import nipyapi; print('nipyapi OK')"
```

**Stop if** nipyapi cannot be installed.

#### 1c. Openflow runtime

The runtime was already selected in Step 0. **Read your Openflow skills now** and use them to confirm the runtime `<RUNTIME_NAME>` is active and reachable via nipyapi. If nipyapi has no local profile for this runtime, it will create one on first connection.

---

### Step 2 -- Create the Snowflake Postgres instance

**Skip if the user is using an existing instance.**

#### 2a. Network policy

The instance needs a network policy to accept inbound connections. For this demo use `0.0.0.0/0` (open to all).

```sql
USE ROLE ACCOUNTADMIN;

CREATE DATABASE IF NOT EXISTS PG_CDC_DEMO_DB;
USE DATABASE PG_CDC_DEMO_DB;

CREATE NETWORK RULE IF NOT EXISTS PG_CDC_DEMO_INGRESS_RULE
    TYPE = IPV4
    VALUE_LIST = ('0.0.0.0/0')
    MODE = POSTGRES_INGRESS;

CREATE NETWORK POLICY IF NOT EXISTS PG_CDC_DEMO_NETWORK_POLICY
    ALLOWED_NETWORK_RULE_LIST = ('PG_CDC_DEMO_DB.PUBLIC.PG_CDC_DEMO_INGRESS_RULE')
    COMMENT = 'Allows inbound connections to the CDC demo Postgres instance.';
```

#### 2b. Create instance

```sql
CREATE POSTGRES INSTANCE IF NOT EXISTS PG_CDC_DEMO
    COMPUTE_FAMILY   = 'BURST_S'
    STORAGE_SIZE_GB  = 10
    AUTHENTICATION_AUTHORITY = POSTGRES
    POSTGRES_VERSION = 17
    NETWORK_POLICY   = 'PG_CDC_DEMO_NETWORK_POLICY'
    COMMENT          = 'Postgres CDC demo instance';
```

**Save the credentials** from the output (`snowflake_admin` password). Store as `PG_PASSWORD`. **Never display the password.**

#### 2c. Wait for the instance to be ready

Poll the instance state every 30 seconds until it shows `READY`. Timeout after 10 minutes if the status is not reached.

```sql
DESCRIBE POSTGRES INSTANCE PG_CDC_DEMO
    ->> SELECT "property", "value"
        FROM $1
        WHERE "property" IN ('name', 'state', 'host');
```

The success state is `READY`. If the state is still `CREATING` or `STARTING` after 10 minutes, stop and tell the user to check the instance status in Snowsight.

Once ready, store the `host` value as `PG_HOST`.

#### 2d. Verify logical replication

Set up `.pgpass` so the password is never shown on screen, then connect:

```bash
echo "<PG_HOST>:5432:postgres:snowflake_admin:<PG_PASSWORD>" > ~/.pgpass && chmod 600 ~/.pgpass
```

```bash
psql "host=<PG_HOST> port=5432 user=snowflake_admin dbname=postgres sslmode=require"
```

Check the current WAL level:

```sql
SHOW wal_level;
```

If the value is already `logical`, no action needed — skip ahead to Step 3.

If the value is `replica`, enable logical replication:

```sql
ALTER SYSTEM SET wal_level = logical;
```

Disconnect and reconnect, then verify with `SHOW wal_level;` again.

---

### Step 3 -- Populate the database

All commands in this step run inside the Postgres instance's `postgres` database via psql (using the `.pgpass` connection set up in Step 2d).

#### 3a. Create schema and table

```sql
CREATE SCHEMA IF NOT EXISTS who;

CREATE TABLE IF NOT EXISTS who.life_expectancy (
    year            SMALLINT       NOT NULL,
    geo_code        SMALLINT       NOT NULL,
    geo_code_type   VARCHAR(50)    NOT NULL,
    geo_name        VARCHAR(150)   NOT NULL,
    sex             VARCHAR(10)    NOT NULL,
    life_expectancy NUMERIC(16,8)  NOT NULL,
    PRIMARY KEY (year, geo_code, sex)
);
```

#### 3b. Load data from CSV

The CSV is `RELAY_WHS.csv` beside this skill (typically `postgres-cdc-demo/RELAY_WHS.csv` when the skill is installed). **Run everything below in one psql process** so the temp table, client `\copy`, and `INSERT` share one session.

`\copy` resolves the CSV path relative to the **shell working directory** at `psql` start — `cd` to that directory first. If `cd` is not possible, keep one `psql` session and paste this block, changing the `\copy` line to an absolute path to `RELAY_WHS.csv`.

Single bash invocation (preferred for agents and automation):

```bash
cd "<path-to-directory-containing-RELAY_WHS.csv>" || exit 1
psql "host=<PG_HOST> port=5432 user=snowflake_admin dbname=postgres sslmode=require" <<'PSQL_LOAD'
\set ON_ERROR_STOP on

CREATE TEMP TABLE _raw_import (
    ind_id TEXT, ind_code TEXT, ind_uuid TEXT, ind_per_code TEXT,
    dim_time TEXT, dim_time_type TEXT, dim_geo_code_m49 TEXT,
    dim_geo_code_type TEXT, dim_publish_state TEXT, ind_name TEXT,
    geo_name_short TEXT, dim_sex TEXT, amount_n TEXT
);

\copy _raw_import FROM 'RELAY_WHS.csv' WITH (FORMAT csv, HEADER true)

INSERT INTO who.life_expectancy (year, geo_code, geo_code_type, geo_name, sex, life_expectancy)
SELECT dim_time::SMALLINT, dim_geo_code_m49::SMALLINT, dim_geo_code_type,
       geo_name_short, dim_sex, amount_n::NUMERIC(16,8)
FROM _raw_import;

DROP TABLE _raw_import;
PSQL_LOAD
```

The quoted heredoc delimiter (`<<'PSQL_LOAD'`) prevents the shell from expanding SQL; only substitute `<PG_HOST>` and the `cd` path in the outer bash lines.

#### 3c. Create CDC publication

```sql
CREATE PUBLICATION openflow FOR TABLE who.life_expectancy;
```

#### 3d. Verify

```sql
SELECT COUNT(*) FROM who.life_expectancy;
SELECT * FROM who.life_expectancy
WHERE geo_name LIKE 'United Kingdom%'
ORDER BY year DESC, sex
LIMIT 10;
```

Expected: 12,936 rows from `COUNT(*)`. The sample `SELECT` uses **United Kingdom** (`LIKE` matches the WHO long place name) so browse queries stay consistent with the **Step 6b** live CDC test on the same geography.

---

### Step 4 -- Snowflake target database & networking

All commands in this step run as Snowflake SQL via snow CLI.

#### 4a. Target database and RBAC

```sql
USE ROLE ACCOUNTADMIN;

CREATE DATABASE IF NOT EXISTS PG_CDC_DEMO_DB;
USE DATABASE PG_CDC_DEMO_DB;

GRANT USAGE ON DATABASE PG_CDC_DEMO_DB TO ROLE OPENFLOW_CDC_ROLE;
GRANT CREATE SCHEMA ON DATABASE PG_CDC_DEMO_DB TO ROLE OPENFLOW_CDC_ROLE;
GRANT USAGE ON SCHEMA PG_CDC_DEMO_DB.PUBLIC TO ROLE OPENFLOW_CDC_ROLE;
GRANT CREATE TABLE ON SCHEMA PG_CDC_DEMO_DB.PUBLIC TO ROLE OPENFLOW_CDC_ROLE;
GRANT USAGE ON FUTURE SCHEMAS IN DATABASE PG_CDC_DEMO_DB TO ROLE OPENFLOW_CDC_ROLE;
GRANT USAGE, OPERATE ON WAREHOUSE OPENFLOW_WH TO ROLE OPENFLOW_CDC_ROLE;

GRANT SELECT ON FUTURE TABLES IN DATABASE PG_CDC_DEMO_DB TO ROLE ACCOUNTADMIN;
GRANT USAGE ON FUTURE SCHEMAS IN DATABASE PG_CDC_DEMO_DB TO ROLE ACCOUNTADMIN;
```

#### 4b. Network rule and EAI

The Openflow runtime needs egress access to reach the Postgres instance.

```sql
CREATE OR REPLACE NETWORK RULE PG_CDC_DEMO_EGRESS_RULE
    MODE = EGRESS
    TYPE = HOST_PORT
    VALUE_LIST = ('<PG_HOST>:5432');

CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION PG_CDC_DEMO_EAI
    ALLOWED_NETWORK_RULES = (PG_CDC_DEMO_DB.PUBLIC.PG_CDC_DEMO_EGRESS_RULE)
    ENABLED = TRUE;

GRANT USAGE ON INTEGRATION PG_CDC_DEMO_EAI TO ROLE OPENFLOW_CDC_ROLE;
```

Replace `<PG_HOST>` with the actual hostname.

#### 4c. Attach EAI to the Openflow runtime

There is no API to attach an EAI to an Openflow runtime programmatically. Prompt the user:

> "The External Access Integration `PG_CDC_DEMO_EAI` has been created.
>
> **You need to attach it to your Openflow runtime manually:**
> 1. Open Snowsight and navigate to **Data Integration > Openflow**.
> 2. Select your runtime: **`<RUNTIME_NAME>`**.
> 3. In the runtime settings, add `PG_CDC_DEMO_EAI` to the External Access Integrations.
> 4. Save the changes.
>
> Let me know once the EAI is attached."

**Wait for user confirmation before proceeding.**

---

### Step 5 -- Deploy the Openflow PostgreSQL CDC connector

**Read your Openflow skills before proceeding** — they contain the exact steps for deploying connectors, uploading assets, setting parameters, and starting process groups. Install or upgrade NiPyApi as directed by the skills.

First, check the runtime for any existing PostgreSQL CDC connector process groups and parameter contexts. If one or more already exist, ask the user:

> "I found an existing PostgreSQL CDC connector in this runtime. Would you like me to **(A) update the existing connector's parameters**, or **(B) create a new connector instance alongside it**?"

- If **A** → update the existing parameter contexts with the values below. Stop and restart the connector after applying changes.
- If **B** → deploy a new PostgreSQL CDC connector from the Snowflake connector repository with its own new parameter context.

If no existing connector is found, deploy a new one.

**PostgreSQL Source Parameters:**

| Parameter | Value |
|-----------|-------|
| PostgreSQL Connection URL | `jdbc:postgresql://<PG_HOST>:5432/postgres?ssl=true&sslmode=require` |
| PostgreSQL JDBC Driver | Upload `postgresql-42.7.8.jar` as a Reference Asset |
| PostgreSQL Username | `snowflake_admin` |
| PostgreSQL Password | `<PG_PASSWORD>` (sensitive — set separately) |
| Publication Name | `openflow` |

**PostgreSQL Destination Parameters:**

| Parameter | Value |
|-----------|-------|
| Destination Database | `PG_CDC_DEMO_DB` |
| Snowflake Authentication Strategy | `SNOWFLAKE_MANAGED` |
| Snowflake Account Identifier | *(leave blank)* |
| Snowflake Username | *(leave blank)* |
| Snowflake Private Key | *(leave blank)* |
| Snowflake Role | `OPENFLOW_CDC_ROLE` |
| Snowflake Warehouse | A warehouse that `OPENFLOW_CDC_ROLE` has USAGE and OPERATE on (e.g. `OPENFLOW_WH`). **This parameter is required** — without it, MERGE statements will fail. |

**PostgreSQL Ingestion Parameters:**

| Parameter | Value |
|-----------|-------|
| Included Table Names | `who.life_expectancy` |
| Merge Task Schedule CRON | `* * * * * ?` (continuous) |
| Object Identifier Resolution | `CASE_INSENSITIVE` (recommended) |

**Parameter notes:**
- Non-sensitive parameters can be set in one call.
- PostgreSQL Password is sensitive and must be set separately.
- PostgreSQL JDBC Driver must be uploaded as a Reference Asset, not set as a parameter value. Download from [jdbc.postgresql.org](https://jdbc.postgresql.org/download/).

**Controller services note:**
When enabling controller services, the **Private Key Service** controller will likely fail validation because we are using `SNOWFLAKE_MANAGED` and have no private key configured. This is expected. Disable or ignore the Private Key Service — it is not needed for managed authentication. All other controller services should enable successfully.

If redeploying after a failed attempt: delete the process group, list and delete any orphan parameter contexts, then redeploy fresh.

Start the connector once deployed.

---

### Step 6 -- Verify

#### 6a. Check data in Snowflake

Wait 30-60 seconds after starting the connector, then:

```sql
SELECT COUNT(*) FROM PG_CDC_DEMO_DB.WHO.LIFE_EXPECTANCY;
```

Retry up to 3 times with 15-second waits if 0.

```sql
SELECT * FROM PG_CDC_DEMO_DB.WHO.LIFE_EXPECTANCY
WHERE GEO_NAME LIKE 'United Kingdom%'
ORDER BY YEAR DESC, SEX
LIMIT 10;
```

Same **United Kingdom** geography as Step **6b** / **6c** (`LIKE` matches the WHO label in the table).

#### 6b. Test live CDC

We will update a specific record, verify it propagates, revert it, and verify again.

**The test record:** UK female life expectancy for **2021**. The table has **`geo_name`** (WHO place label), not a `country` column — in the loaded CSV the UK row uses a long name such as `United Kingdom of Great Britain and Northern Ireland`. Original **`life_expectancy`** is `81.93070945`; the exercise sets it to **`100.00`** then reverts.

**Postgres — copy-paste `UPDATE` reference (print for the user):** Both statements below are what Step 1 and Step 3 run in `postgres` via psql. Echo them in your chat in a fenced `sql` block so the audience can copy into psql or a notes doc in parallel with the demo.

```sql
-- Step 1: CDC test bump (expect Snowflake to follow)
UPDATE who.life_expectancy SET life_expectancy = 100.00
WHERE year = 2021
  AND sex = 'FEMALE'
  AND geo_name LIKE 'United Kingdom%';

-- Step 3: revert to WHO value
UPDATE who.life_expectancy SET life_expectancy = 81.93070945
WHERE year = 2021
  AND sex = 'FEMALE'
  AND geo_name LIKE 'United Kingdom%';
```

**Step 0 — Find the row in Postgres** (optional but recommended; same psql session as the update):

```sql
SELECT year, geo_code, geo_name, sex, life_expectancy
FROM who.life_expectancy
WHERE year = 2021
  AND sex = 'FEMALE'
  AND geo_name LIKE 'United Kingdom%'
ORDER BY geo_name;
```

Expect one female row for the UK country series (`geo_code` **826** if you need the numeric key elsewhere).

**Step 1 — Update in Postgres** (via psql, connected to the `postgres` database using `.pgpass`):

```bash
psql "host=<PG_HOST> port=5432 user=snowflake_admin dbname=postgres sslmode=require"
```

```sql
UPDATE who.life_expectancy SET life_expectancy = 100.00
WHERE year = 2021
  AND sex = 'FEMALE'
  AND geo_name LIKE 'United Kingdom%';
```

Tell the user, then **in this same turn** (before the wait): **print the Postgres `UPDATE` reference block** (both `UPDATE`s above — bump + revert) for copy-paste into psql, and **print the Snowsight copy-paste `sql` block** (the two `SELECT`s under Step 2 — watch by sex, then pinpoint `SELECT *`) so they can run Snowflake checks in parallel while CDC catches up.

> "I've updated the UK Female 2021 life expectancy to **100.00** in PostgreSQL. I'll wait for CDC, then verify in Snowflake. Copy the Snowflake queries from my message into **Snowsight** if you want to watch the row change there in parallel with the CLI— useful during demos."

Wait 30 seconds.

**Step 2 — Verify CDC propagation in Snowflake**

Run the verification query (e.g. `snow sql -q "..."` or your Snowflake path). **In the same response, print the Snowflake SQL below for Snowsight** — users often paste it into a worksheet and refresh while you poll from the CLI, which works well in live demos.

**Copy into Snowsight (parallel check — after update to 100.00):**

```sql
-- UK 2021 rows by sex (watch FEMALE move to 100.00)
SELECT YEAR, GEO_NAME, SEX, LIFE_EXPECTANCY
FROM PG_CDC_DEMO_DB.WHO.LIFE_EXPECTANCY
WHERE YEAR = 2021 AND GEO_NAME LIKE 'United Kingdom%'
ORDER BY SEX;

-- Pinpoint: updated row only
SELECT *
FROM PG_CDC_DEMO_DB.WHO.LIFE_EXPECTANCY
WHERE YEAR = 2021 AND SEX = 'FEMALE' AND GEO_NAME LIKE 'United Kingdom%';
```

Confirm **`LIFE_EXPECTANCY`** shows **`100.00`** on the female row. If it still shows the original value, wait another 15–30 seconds and retry (CLI and/or Snowsight).

Tell the user:

> "The change has propagated. Now I'll revert the value back to the original. If you have Snowsight open, run the same queries again after the revert."

Wait for user confirmation or pause for 10 seconds.

**Step 3 — Revert in Postgres** (same psql session, `postgres` database):

```sql
UPDATE who.life_expectancy SET life_expectancy = 81.93070945
WHERE year = 2021
  AND sex = 'FEMALE'
  AND geo_name LIKE 'United Kingdom%';
```

**Print this revert `UPDATE` verbatim in a fenced `sql` block** in your user-facing message (same SQL as the second statement in the Postgres reference block above) so the user can copy it into psql without scrolling.

Wait 30 seconds.

**Step 4 — Verify CDC propagation after revert in Snowflake**

Run the same checks as Step 2. **Again print the Snowflake SQL for Snowsight** (same queries as Step 2 — copy-paste friendly):

```sql
SELECT YEAR, GEO_NAME, SEX, LIFE_EXPECTANCY
FROM PG_CDC_DEMO_DB.WHO.LIFE_EXPECTANCY
WHERE YEAR = 2021 AND GEO_NAME LIKE 'United Kingdom%'
ORDER BY SEX;

SELECT *
FROM PG_CDC_DEMO_DB.WHO.LIFE_EXPECTANCY
WHERE YEAR = 2021 AND SEX = 'FEMALE' AND GEO_NAME LIKE 'United Kingdom%';
```

Confirm **`LIFE_EXPECTANCY`** is back to **`81.93070945`**.

> "CDC round-trip verified. Changes in Snowflake Postgres propagate to Snowflake native tables in near-real time."

#### 6c. Optional — manual follow-on (before teardown)

Automated verification in **6b** is complete. **Teardown is Step 7** — use it when you are ready to remove resources.

If you want to **keep exploring CDC yourself** (open **psql**, run `UPDATE`s in Postgres, then switch to **Snowsight** and run `SELECT`s to watch rows catch up), the executing agent should **print everything below in full** in the closing message so you can copy-paste without opening the skill file. Keep `<PG_HOST>` as your instance hostname from earlier steps.

**1 — Log in to Postgres (psql)**

With `.pgpass` set up (Step 2d), connect to the `postgres` database:

```bash
psql "host=<PG_HOST> port=5432 user=snowflake_admin dbname=postgres sslmode=require"
```

Without `.pgpass`, use your normal secure method (`PGPASSWORD` in the environment for this session only, or an interactive password prompt). Do not paste passwords into chat or shared notes.

**2 — Postgres: find the test row (optional)**

```sql
SELECT year, geo_code, geo_name, sex, life_expectancy
FROM who.life_expectancy
WHERE year = 2021 AND sex = 'FEMALE' AND geo_name LIKE 'United Kingdom%'
ORDER BY geo_name;
```

**3 — Postgres: example `UPDATE`s (modify, then verify in Snowflake, then revert)**

Run one `UPDATE` at a time in psql. After each change, wait **30–90 seconds** (typical CDC latency), then run the Snowflake queries in **4** in Snowsight until `LIFE_EXPECTANCY` matches.

```sql
-- Set a demo value (Snowflake should show 100.00 for this row after CDC)
UPDATE who.life_expectancy SET life_expectancy = 100.00
WHERE year = 2021 AND sex = 'FEMALE' AND geo_name LIKE 'United Kingdom%';

-- Restore the original WHO value when you are done experimenting
UPDATE who.life_expectancy SET life_expectancy = 81.93070945
WHERE year = 2021 AND sex = 'FEMALE' AND geo_name LIKE 'United Kingdom%';
```

You may use other values for `life_expectancy` if you want ad hoc tests; keep the same `WHERE` clause so you stay on the same primary-key row.

**4 — Snowflake (Snowsight): `SELECT`s to confirm propagation**

Open a **SQL worksheet** in Snowsight (same account where `PG_CDC_DEMO_DB` lives). Re-run after each Postgres `UPDATE` until results match:

```sql
-- UK 2021 by sex (watch FEMALE after your UPDATE)
SELECT YEAR, GEO_NAME, SEX, LIFE_EXPECTANCY
FROM PG_CDC_DEMO_DB.WHO.LIFE_EXPECTANCY
WHERE YEAR = 2021 AND GEO_NAME LIKE 'United Kingdom%'
ORDER BY SEX;

-- Pinpoint row only
SELECT *
FROM PG_CDC_DEMO_DB.WHO.LIFE_EXPECTANCY
WHERE YEAR = 2021 AND SEX = 'FEMALE' AND GEO_NAME LIKE 'United Kingdom%';
```

**5 — When you are finished**

Tear down with **Step 7**, or prompt: *"clean up postgres cdc demo"*.

---

### Step 7 -- Teardown

#### 7.0. Inventory

Before any destructive operations, discover what exists. Run these in parallel:

```sql
USE ROLE ACCOUNTADMIN;
SHOW POSTGRES INSTANCES LIKE 'PG_CDC_DEMO%';
SHOW DATABASES LIKE 'PG_CDC_DEMO%';
SHOW INTEGRATIONS LIKE 'PG_CDC_DEMO%';
SHOW NETWORK POLICIES LIKE 'PG_CDC_DEMO%';
```

Also use your Openflow skills to list process groups on the runtime `<RUNTIME_NAME>` and check for the CDC connector.

Present a summary table to the user showing what was found and what will be removed. Then ask:

> **"What would you like to clean up? (A) Everything, (B) Openflow + Snowflake target only, (C) Postgres instance only"**

If any object is already gone, note it and skip its cleanup step.

#### 7a. Openflow cleanup

**Read your Openflow skills first** for the Complete Connector Removal workflow.

The CDC connector has a hierarchy of parameter contexts (Source, Destination, Ingestion) that can become orphaned if not cleaned up properly. Follow this order:

1. **Before deleting the process group**, get the parameter context hierarchy and note all bound contexts (the parent context and its inherited Source, Destination, and Ingestion child contexts).
2. **Stop the connector** — stop the process group, then disable all controller services.
3. **Delete the process group** using `ci cleanup`.
4. **Delete orphaned parameter contexts** — delete the Ingestion (parent) context first, then Source and Destination. Deleting in the wrong order causes a 409 conflict.

#### 7b. Snowflake target cleanup

**⚠ IMPORTANT — You MUST detach the EAI before dropping it.** If the EAI is still attached to the runtime when dropped, the runtime may enter an error state. Prompt the user:

> "Before I can drop the EAI, you need to remove `PG_CDC_DEMO_EAI` from your runtime's External Access Integrations in Snowsight:
>
> 1. Open Snowsight → **Data Integration → Openflow** → select your runtime
> 2. Remove `PG_CDC_DEMO_EAI` from the External Access Integrations list
> 3. Save
>
> **Do not proceed until this is done.** Let me know once the EAI is detached."

**Wait for user confirmation**, then:

```sql
USE ROLE ACCOUNTADMIN;

DROP EXTERNAL ACCESS INTEGRATION IF EXISTS PG_CDC_DEMO_EAI;
DROP NETWORK RULE IF EXISTS PG_CDC_DEMO_DB.PUBLIC.PG_CDC_DEMO_EGRESS_RULE;
```

Do **not** drop the database yet — the ingress network rule inside it is still referenced by the network policy attached to the Postgres instance.

#### 7c. Postgres instance cleanup

The dependency order matters: instance → network policy → database (which contains the network rules).

```sql
USE ROLE ACCOUNTADMIN;

-- 1. Drop the instance first (unblocks the network policy)
DROP POSTGRES INSTANCE IF EXISTS PG_CDC_DEMO;

-- 2. Drop the network policy (unblocks the network rule inside the database)
DROP NETWORK POLICY IF EXISTS PG_CDC_DEMO_NETWORK_POLICY;

-- 3. Now safe to drop the database (contains both ingress and egress network rules)
DROP DATABASE IF EXISTS PG_CDC_DEMO_DB;
```

#### 7d. Local cleanup

```bash
rm -f ~/.pgpass
```

#### 7e. Summary

Present a summary showing what was removed and what was already gone:

> "Teardown complete. Here's what was cleaned up:
> - Openflow connector: [removed / already gone / skipped]
> - EAI (PG_CDC_DEMO_EAI): [removed / already gone / skipped]
> - Postgres instance (PG_CDC_DEMO): [removed / already gone / skipped]
> - Network policy: [removed / already gone / skipped]
> - Database (PG_CDC_DEMO_DB): [removed / already gone / skipped]
> - Local .pgpass: [removed]"

---

## Examples

**User**: "postgres cdc demo" → Full flow Steps 0-6; after 6b succeeds, print **6c** (manual psql + Snowsight copy-paste) before suggesting Step 7 teardown.

**User**: "I already have a Snowflake Postgres instance, set up CDC to Snowflake" → Step 0 (existing path), collect connection details, skip to Step 3.

**User**: "clean up postgres cdc demo" → Step 7.

**User**: "just drop the Postgres instance" → Step 7c only.
