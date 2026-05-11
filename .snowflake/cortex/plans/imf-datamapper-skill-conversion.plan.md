# Plan: Convert IMF DataMapper Demo to a Cortex Code CLI Skill

## Context

The `imf-datamapper-demo/` directory currently has a README that serves both as documentation AND as a prompt template users paste into Cortex Code. The goal is to:

1. Extract the operational workflow into a **SKILL.md** file (like `postgres-cdc-demo/SKILL.md`)
2. Replace the README with a short **project overview + install instructions**

## Deliverables

### 1. `imf-datamapper-demo/SKILL.md`

**Frontmatter:**
```yaml
---
name: imf-datamapper-demo
description: "Deploy and run the IMF DataMapper demo using Openflow. Ingests macroeconomic data from the IMF DataMapper API into a Snowflake table, verifies the data, and shows top countries by GDP per capita. Includes full teardown. Triggers: imf datamapper demo, imf demo, deploy imf flow, openflow imf demo, clean up imf demo."
---
```

**Skill structure (following postgres-cdc-demo pattern):**

- **When to use** — user wants to demo IMF API ingestion via Openflow, deploy the imf-weo flow, or tear down a previous run
- **What this skill provides** — prerequisites check, Snowflake setup, flow deployment, verification, teardown
- **Variables** — `RUNTIME_NAME`, `PROJECT_DIR`, `VENV_PATH`
- **Instructions / Execution guidelines** — announce steps, batch parallel ops, read Openflow skills first

**Steps:**

| Step | Description |
|------|-------------|
| 0 | Confirm intent |
| 1 | Prerequisites — check Python env (create with uv if missing), verify Snowflake connection, list active Openflow runtimes (let user select one) |
| 2 | Snowflake setup — check/create `API_DEMO` database, `IMF_DATAMAPPER_INDICATORS` table, `IMF_API_ACCESS` EAI, RBAC grants |
| 3 | Parameter context & flow deployment — create/reuse parameter context, import `imf-weo.json`, start flow |
| 4 | Poll until complete — every 10s, done when queued=0 & active_threads=0 for 2 consecutive polls, then stop flow |
| 5 | Verify — query top 10 countries by GDP per capita (NGDPDPC) for current year, display results |
| 6 | Cleanup — ask user, then `ci cleanup --delete_parameter_context --force` |

**Examples section** at the bottom matching trigger phrases.

### 2. `imf-datamapper-demo/README.md` (rewritten)

Short overview:
- What the demo does (1-2 paragraphs)
- Data source summary (indicators table)
- How it works (3-bullet summary)
- Project structure listing
- **Install the skill** section (`cp -r imf-datamapper-demo ~/.snowflake/cortex/skills/`)
- **Run the demo** section (prompt: `Run the IMF datamapper demo`)
- **Tear down** section (prompt: `Clean up imf demo`)
- References/links

### 3. No changes to other files

`imf-weo.json`, `imf-indicator.groovy`, `pyproject.toml`, `.python-version` remain untouched.

## Key Design Decisions

- The skill's prerequisites step creates the uv venv if it doesn't exist (matching the user's requirement for automated env setup)
- The skill checks Snowflake connectivity and lists runtimes before proceeding (matching the user's requirement)
- The skill checks the EAI exists and creates it if missing (matching the user's requirement)
- The verification step runs the "top 10 countries by GDP per capita" query (matching the user's requirement from the example prompt step 7)
- The README becomes a lightweight entry point pointing users to install and run the skill
