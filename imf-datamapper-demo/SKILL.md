---
name: imf-datamapper-demo
description: "Deploy and run the IMF DataMapper demo using Openflow. Ingests macroeconomic data from the IMF DataMapper API into a Snowflake table, verifies the data, and shows top countries by GDP per capita. Includes full teardown. Triggers: imf api demo, run imf api demo, deploy imf flow, openflow imf demo, clean up imf api demo."
---

## When to use

Use this skill when the user wants to:

- Demo REST API ingestion into Snowflake via Openflow
- Deploy the IMF DataMapper flow to an Openflow runtime
- Verify IMF macroeconomic data loaded into Snowflake
- Tear down a previously deployed IMF DataMapper demo

## What this skill provides

1. **Prerequisites** (Step 1) — Python environment (uv), Snowflake connectivity, Openflow runtime selection
2. **Snowflake setup** (Step 2) — Database, table, external access integration, RBAC grants
3. **Flow deployment** (Step 3) — Parameter context, flow import, start
4. **Polling** (Step 4) — Wait for flow completion
5. **Verification** (Step 5) — Query top 10 countries by GDP per capita
6. **Cleanup** (Step 6) — Stop flow, delete process group and parameter context

## Variables

Track these throughout the skill. Defaults shown in parentheses.

| Variable | Source | Default |
|----------|--------|---------|
| `RUNTIME_NAME` | User input | — |
| `PROJECT_DIR` | Auto-detected | `imf-datamapper-demo/` |
| `VENV_PATH` | Auto-detected | `<PROJECT_DIR>/.venv` |

## Instructions

**EXECUTION GUIDELINES:**

1. **Announce each step clearly** with a header like "**Step X — [Name]**".
2. **Batch commands aggressively** — run independent checks in parallel.
3. **Store all variable values** as you collect them; reference them in later steps.
4. **Always read your Openflow skills first** before any Openflow operation (checking runtimes, deploying flows, managing process groups, teardown). The Openflow skills contain the authoritative guidance for interacting with the runtime and NiPyApi.
5. **Use the project's virtual environment** for nipyapi. The Openflow CLI and nipyapi Python are both fine — mix them as needed. In Python, nipyapi calls typically return dicts (structured objects), not JSON strings; do not `json.loads` unless you truly have a `str`.

---

### Step 0 — Confirm intent

> "This skill deploys the **IMF DataMapper demo** — an Openflow flow that ingests macroeconomic data from the IMF DataMapper API and writes it to a Snowflake table.
>
> The flow fetches World Economic Outlook indicators (GDP, inflation, unemployment, etc.) for 190+ countries and loads them into `API_DEMO.PUBLIC.IMF_DATAMAPPER_INDICATORS`.
>
> Ready to proceed?"

After confirmation, proceed to Step 1.

---

### Step 1 — Prerequisites

#### 1a. Python environment

Check if the project's `.venv` exists and has nipyapi:

```bash
cd "<PROJECT_DIR>"
echo "=== uv ==="; uv --version 2>/dev/null || echo "NOT FOUND"
echo "=== .venv ==="; test -d .venv && echo "FOUND" || echo "NOT FOUND"
```

If `.venv` exists, verify nipyapi:

```bash
source .venv/bin/activate && python -c "import nipyapi; print('nipyapi OK')" 2>/dev/null || echo "nipyapi NOT FOUND"
```

If `.venv` does not exist or nipyapi is missing, create it:

```bash
cd "<PROJECT_DIR>" && uv sync && source .venv/bin/activate && python -c "import nipyapi; print('nipyapi OK')"
```

**Stop if** uv is not found or nipyapi cannot be installed.

#### 1b. Snowflake connectivity

```sql
SELECT CURRENT_USER() AS current_user, CURRENT_ROLE() AS current_role,
       CURRENT_ACCOUNT() AS current_account, CURRENT_REGION() AS current_region;
```

**Stop if** Snowflake connection fails.

#### 1c. Openflow runtime selection

**Read your Openflow skills** and use them to list the active Openflow runtimes. Present the list to the user and ask which runtime they would like to use for the demo. Store the selected name as `RUNTIME_NAME`.

Confirm the runtime is active and reachable via nipyapi.

---

### Step 2 — Snowflake setup

Check whether each prerequisite exists. Create anything that is missing.

#### 2a. Database and table

```sql
CREATE DATABASE IF NOT EXISTS API_DEMO;
USE DATABASE API_DEMO;

CREATE TABLE IF NOT EXISTS API_DEMO.PUBLIC.IMF_DATAMAPPER_INDICATORS (
    INDICATOR VARCHAR,
    COUNTRY_CODE VARCHAR,
    YEAR NUMBER(38,0),
    VALUE FLOAT,
    INGESTION_TIMESTAMP TIMESTAMP_NTZ(9)
);
```

#### 2b. External access integration

Check if the integration already exists:

```sql
SHOW INTEGRATIONS LIKE 'IMF_API_ACCESS';
```

If not found, create it:

```sql
CREATE OR REPLACE NETWORK RULE IMF_API_NETWORK_RULE
    MODE = EGRESS
    TYPE = HOST_PORT
    VALUE_LIST = ('www.imf.org');

CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION IMF_API_ACCESS
    ALLOWED_NETWORK_RULES = (IMF_API_NETWORK_RULE)
    ENABLED = TRUE;
```

Grant usage to the Openflow runtime role:

```sql
GRANT USAGE ON INTEGRATION IMF_API_ACCESS TO ROLE "OPENFLOW_RUNTIME_ROLE";
```

#### 2c. RBAC grants

```sql
GRANT USAGE ON DATABASE API_DEMO TO ROLE OPENFLOW_RUNTIME_ROLE;
GRANT CREATE SCHEMA ON DATABASE API_DEMO TO ROLE OPENFLOW_RUNTIME_ROLE;
GRANT USAGE ON SCHEMA API_DEMO.PUBLIC TO ROLE OPENFLOW_RUNTIME_ROLE;
GRANT CREATE TABLE ON SCHEMA API_DEMO.PUBLIC TO ROLE OPENFLOW_RUNTIME_ROLE;
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, REBUILD, EVOLVE SCHEMA, APPLYBUDGET
    ON TABLE API_DEMO.PUBLIC.IMF_DATAMAPPER_INDICATORS
    TO ROLE OPENFLOW_RUNTIME_ROLE;
```

#### 2d. Verify setup

Run a quick check that the table and EAI both exist:

```sql
SELECT COUNT(*) AS row_count FROM API_DEMO.PUBLIC.IMF_DATAMAPPER_INDICATORS;
SHOW INTEGRATIONS LIKE 'IMF_API_ACCESS';
```

Note: each run of the flow truncates and reloads `IMF_DATAMAPPER_INDICATORS`, so existing row counts from prior runs are expected and not a problem.

---

### Step 3 — Deploy the flow

**Read your Openflow skills before proceeding.**

#### 3a. Parameter context

The flow definition `imf-weo.json` defines a single parameter context named "IMF DataMapper Parameters" with parameter `imf_base_endpoint` (default `https://www.imf.org/external/datamapper/api/v1`).

On the selected runtime, check if that context name already exists:

- If it exists → ask the user whether to **reuse** it or **create a new one**.
- If it does not exist → create it with the default parameter value.

#### 3b. Import and start

1. Import the flow using `import_flow_definition` from `imf-weo.json` in the project directory.
2. Create or attach the parameter context using `nipyapi.parameters` as needed.
3. Start the flow with `ci start_flow`.

---

### Step 4 — Poll until complete

Poll every 10 seconds. The flow usually completes in under two minutes.

Treat it as finished when `queued_flowfiles=0` and `active_threads=0` for **two consecutive polls**.

Once complete, stop the flow with `ci stop_flow`.

If the flow has not completed after 5 minutes, warn the user and ask whether to continue waiting or abort.

---

### Step 5 — Verify

#### 5a. Row count

```sql
SELECT COUNT(*) AS total_rows FROM API_DEMO.PUBLIC.IMF_DATAMAPPER_INDICATORS;
```

Expected: several thousand rows (8 indicators × 190+ countries × multiple years).

#### 5b. Top 10 countries by GDP per capita

```sql
SELECT
    COUNTRY_CODE,
    VALUE AS GDP_PER_CAPITA_USD
FROM API_DEMO.PUBLIC.IMF_DATAMAPPER_INDICATORS
WHERE INDICATOR = 'NGDPDPC'
  AND YEAR = YEAR(CURRENT_DATE())
ORDER BY VALUE DESC
LIMIT 10;
```

Display the results to the user as a summary table.

#### 5c. Additional summary (optional)

```sql
SELECT INDICATOR, COUNT(*) AS records, COUNT(DISTINCT COUNTRY_CODE) AS countries,
       MIN(YEAR) AS min_year, MAX(YEAR) AS max_year
FROM API_DEMO.PUBLIC.IMF_DATAMAPPER_INDICATORS
GROUP BY INDICATOR
ORDER BY INDICATOR;
```

---

### Step 6 — Cleanup

**Pause before cleaning up.** Ask the user:

> "The IMF DataMapper flow has been deployed and verified. Would you like me to clean up the flow instance now, or leave it running?"

Only after user confirms cleanup:

1. Stop the flow if still running.
2. Delete the flow instance with `ci cleanup --delete_parameter_context --force` (adjust flags if your Openflow CLI version differs).
3. Optionally ask if the user also wants to drop the `API_DEMO` database and `IMF_API_ACCESS` integration.

If the user wants full teardown:

```sql
DROP TABLE IF EXISTS API_DEMO.PUBLIC.IMF_DATAMAPPER_INDICATORS;
DROP DATABASE IF EXISTS API_DEMO;
DROP EXTERNAL ACCESS INTEGRATION IF EXISTS IMF_API_ACCESS;
DROP NETWORK RULE IF EXISTS IMF_API_NETWORK_RULE;
```

Present a summary of what was removed.

---

## Examples

**User**: "Run IMF API demo" → Full flow Steps 0–6.

**User**: "deploy imf flow" → Steps 0–5 (skip cleanup prompt).

**User**: "Clean up IMF API demo" → Step 6 only.

**User**: "show me GDP per capita from the IMF demo" → Step 5b only (query existing data).
