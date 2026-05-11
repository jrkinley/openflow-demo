# Snowflake Demos

A collection of demos and examples for Snowflake, organised by product area.

## Structure

```
snowflake-demos/
├── terraform/          Shared infrastructure modules (AWS)
├── openflow/           Openflow integration demos
│   ├── imf-datamapper-demo/
│   ├── nasdaq-demo/
│   ├── postgres-cdc-demo/
│   └── versioning/
└── snowpark/           Snowpark & SPCS demos
    └── spcs-python/
```

## Demos

### Openflow

| Demo | Description |
|------|-------------|
| [IMF DataMapper](openflow/imf-datamapper-demo/) | Ingest macroeconomic data from the IMF DataMapper API using Openflow |
| [NASDAQ Workshop](openflow/nasdaq-demo/) | End-to-end financial services workshop: Kafka/CDC ingestion, Cortex AI, and Snowflake Intelligence |
| [PostgreSQL CDC](openflow/postgres-cdc-demo/) | Change Data Capture from PostgreSQL to Snowflake via Openflow |
| [Versioning](openflow/versioning/) | Openflow flow definition version control |

### Snowpark

| Demo | Description |
|------|-------------|
| [SPCS Python](snowpark/spcs-python/) | Snowpark Container Services and Stored Procedure examples for consuming external APIs |

### Terraform

Shared infrastructure modules used by the Openflow demos:

| Module | Description |
|--------|-------------|
| [Amazon MQ](terraform/amazon-mq/) | ActiveMQ broker deployment |
| [MSK](terraform/msk/) | AWS Managed Streaming for Apache Kafka |
| [RDS PostgreSQL](terraform/rds-postgres/) | PostgreSQL instance with logical replication |
| [SFTP](terraform/sftp/) | AWS Transfer Family SFTP server |
