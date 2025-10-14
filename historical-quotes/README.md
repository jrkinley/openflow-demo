# Historical Quotes

Process historical stock quote CSV files and produce to Kafka in Avro format.

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
```

**Print-only mode**: If `KAFKA_BOOTSTRAP_SERVERS` is not set, records are printed instead of sent to Kafka.

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
- Avro serialization with schema validation
- AWS MSK support (SASL_SSL with SCRAM-SHA-512)
- Partitioning by stock symbol

