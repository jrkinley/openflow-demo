# Historical Quotes

Process historical stock quote CSV files and produce to Kafka in JSON format.

## Setup

Install [uv](https://github.com/astral-sh/uv) and sync dependencies:

```bash
uv sync
```

## Configuration

Copy `.env.example` to `.env` and configure for your Kafka cluster:

```bash
cp .env.example .env
```

Edit `.env` with your AWS MSK broker endpoints and credentials:
- `KAFKA_BOOTSTRAP_SERVERS`
- `KAFKA_SASL_USERNAME` / `KAFKA_SASL_PASSWORD`
- `KAFKA_TOPIC`

## Usage

### Producer

Process CSV files and produce to Kafka:

```bash
# Process all CSV files in a directory
uv run python main.py ./data

# Process a single CSV file
uv run python main.py ./data/HistoricalData_SNOW.csv

# Recreate (truncate) the topic before producing
uv run python main.py ./data --recreate-topic
```

**Print-only mode**: If `KAFKA_BOOTSTRAP_SERVERS` is not set, records are printed instead of sent to Kafka.

**Topic recreation**: The `--recreate-topic` flag deletes and recreates the topic using cluster defaults, waiting 10 seconds between operations for Kafka cleanup. Note: This requires your SCRAM credentials to have admin permissions for topic management. If you get authorization errors, you can skip this flag and manually create/manage the topic.

### Consumer

Consume messages from Kafka:

```bash
# Consume up to 10 messages
uv run python consume.py --limit 10

# Consume all messages (Ctrl+C to stop)
uv run python consume.py
```

The consumer starts from the beginning of the topic by default.

## Features

- Multi-threaded CSV processing (one thread per file)
- JSON serialization
- AWS MSK support (SASL_SSL with SCRAM-SHA-512)
- Partitioning by stock symbol

