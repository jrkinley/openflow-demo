# PostgreSQL CDC Demo

A self-contained demo that creates a Snowflake Postgres instance, populates it with WHO life-expectancy data, and uses an Openflow PostgreSQL CDC connector to capture changes in real time and land them in a Snowflake native table. Everything runs within the Snowflake platform.

## Overview

This demo connects an Openflow PostgreSQL CDC connector to a Snowflake Postgres instance via a logical replication slot. Row-level changes (inserts, updates, deletes) are captured from the source database and streamed into a Snowflake native table in near-real time.

## Cortex Code CLI Skill

This demo is driven by a [Cortex Code CLI](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-cli) skill that walks you through each step interactively.

### Install the skill

```bash
cp -r postgres-cdc-demo ~/.snowflake/cortex/skills/
```

### Run the demo

Open the Cortex Code CLI and prompt:

```
Run the postgres cdc demo
```

The skill guides you through instance creation, data loading, connector deployment, and verification. If you already have a Snowflake Postgres instance you can skip ahead -- the skill will ask.

### Tear down

```
Clean up postgres cdc demo
```

## What the skill covers

1. **Snowflake Postgres instance** -- Network policy, instance creation, enable logical replication via `ALTER SYSTEM SET wal_level = logical`.
2. **Data population** -- Load ~12.9k rows of WHO life-expectancy data (190+ countries, 2000--2021) and create a CDC publication.
3. **Snowflake target setup** -- Target database, RBAC grants for `OPENFLOW_CDC_ROLE`, network rule, and External Access Integration.
4. **Openflow CDC connector** -- Deploy and configure the connector against your Openflow runtime.
5. **Verification** -- Confirm data lands in Snowflake and test live CDC with an update round-trip.
6. **Teardown** -- Remove the connector, Snowflake objects, and drop the Postgres instance.

## Project structure

```
postgres-cdc-demo/
├── README.md
├── SKILL.md                   # Cortex Code CLI skill
└── RELAY_WHS.csv              # WHO life-expectancy data
```

## References

- [Snowflake Postgres](https://docs.snowflake.com/en/user-guide/snowflake-postgres/about)
- [Openflow PostgreSQL CDC Connector](https://docs.snowflake.com/en/user-guide/data-integration/openflow/connectors/postgres/setup)
- [Syncing Snowflake Postgres to Native Tables with Openflow](https://medium.com/@johnkangw/syncing-snowflake-postgres-to-native-tables-with-openflow-a-step-by-step-guide-8e8f13b56872)
