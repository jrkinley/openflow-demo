#!/usr/bin/env python3
"""
Process historical stock quote CSV files and produce to Kafka in Avro format.
"""

import argparse
import csv
import io
import json
import os
import sys
import threading
from pathlib import Path
from typing import List, Dict, Any, Optional

import fastavro
from confluent_kafka import Producer
from dotenv import load_dotenv


def load_avro_schema(schema_path: Path) -> Dict[str, Any]:
    """Load and parse the Avro schema file."""
    with open(schema_path, 'r') as f:
        return json.load(f)


def create_kafka_producer() -> Optional[Producer]:
    """
    Create a Kafka producer from environment variables.
    Returns None if KAFKA_BOOTSTRAP_SERVERS is not set (for testing without Kafka).
    """
    bootstrap_servers = os.getenv('KAFKA_BOOTSTRAP_SERVERS')
    
    if not bootstrap_servers:
        print("KAFKA_BOOTSTRAP_SERVERS not set. Running in print-only mode.")
        return None
    
    config = {
        'bootstrap.servers': bootstrap_servers,
        'client.id': 'historical-quotes-producer',
    }
    
    # Add SASL/SSL configuration
    security_protocol = os.getenv('KAFKA_SECURITY_PROTOCOL')
    if security_protocol:
        config['security.protocol'] = security_protocol
    
    sasl_mechanism = os.getenv('KAFKA_SASL_MECHANISM')
    if sasl_mechanism:
        config['sasl.mechanism'] = sasl_mechanism
    
    sasl_username = os.getenv('KAFKA_SASL_USERNAME')
    if sasl_username:
        config['sasl.username'] = sasl_username
    
    sasl_password = os.getenv('KAFKA_SASL_PASSWORD')
    if sasl_password:
        config['sasl.password'] = sasl_password
    
    print(f"Creating Kafka producer with bootstrap servers: {bootstrap_servers}")
    return Producer(config)


def serialize_avro_record(record: Dict[str, Any], schema: Dict[str, Any]) -> bytes:
    """Serialize a record using Avro schema to bytes."""
    output = io.BytesIO()
    fastavro.schemaless_writer(output, schema, record)
    return output.getvalue()


def delivery_callback(err, msg):
    """Callback for Kafka message delivery reports."""
    if err is not None:
        print(f'Message delivery failed: {err}', file=sys.stderr)
    else:
        print(f'Message delivered to {msg.topic()} [{msg.partition()}] at offset {msg.offset()}')


def extract_symbol_from_filename(filename: str) -> str:
    """
    Extract stock symbol from filename.
    Example: HistoricalData_AAPL.csv -> AAPL
    """
    # Remove extension
    name = Path(filename).stem
    # Handle format: HistoricalData_SYMBOL
    if '_' in name:
        return name.split('_')[-1]
    return name


def csv_row_to_avro(row: Dict[str, str], symbol: str) -> Dict[str, Any]:
    """
    Convert a CSV row to an Avro record.
    
    CSV columns: Date, Close/Last, Volume, Open, High, Low
    """
    return {
        'symbol': symbol,
        'date': row['Date'],
        'close_last': row['Close/Last'],
        'volume': int(row['Volume'].replace(',', '')),  # Remove comma separators
        'open': row['Open'],
        'high': row['High'],
        'low': row['Low']
    }


def process_csv_file(
    csv_path: Path,
    schema: Dict[str, Any],
    thread_id: int,
    producer: Optional[Producer],
    kafka_topic: Optional[str]
):
    """
    Process a single CSV file in a thread.
    Read each row, convert to Avro format, and produce to Kafka (or print if no producer).
    """
    symbol = extract_symbol_from_filename(csv_path.name)
    
    print(f"[Thread {thread_id}] Processing {csv_path.name} (Symbol: {symbol})")
    
    try:
        with open(csv_path, 'r') as f:
            reader = csv.DictReader(f)
            record_count = 0
            
            for row in reader:
                # Convert CSV row to Avro record
                avro_record = csv_row_to_avro(row, symbol)
                
                # Validate against schema (fastavro will raise if invalid)
                fastavro.validate(avro_record, schema)
                
                if producer and kafka_topic:
                    # Serialize and produce to Kafka
                    avro_bytes = serialize_avro_record(avro_record, schema)
                    
                    # Use the stock symbol as the key for partitioning
                    key = symbol.encode('utf-8')
                    
                    # Produce the message
                    producer.produce(
                        topic=kafka_topic,
                        key=key,
                        value=avro_bytes,
                        callback=delivery_callback
                    )
                    
                    # Poll to handle delivery callbacks
                    producer.poll(0)
                else:
                    # Print mode (no Kafka connection)
                    print(f"[Thread {thread_id}] {avro_record}")
                
                record_count += 1
        
        # Flush any remaining messages for this thread
        if producer:
            producer.flush()
        
        print(f"[Thread {thread_id}] Completed {csv_path.name}: {record_count} records processed")
    
    except Exception as e:
        print(f"[Thread {thread_id}] ERROR processing {csv_path.name}: {e}", file=sys.stderr)


def find_csv_files(path: Path) -> List[Path]:
    """
    Find all CSV files in the given path.
    If path is a file, return it as a single-item list.
    If path is a directory, return all CSV files in it.
    """
    if path.is_file():
        if path.suffix.lower() == '.csv':
            return [path]
        else:
            raise ValueError(f"File {path} is not a CSV file")
    elif path.is_dir():
        csv_files = list(path.glob('*.csv'))
        if not csv_files:
            raise ValueError(f"No CSV files found in directory {path}")
        return sorted(csv_files)
    else:
        raise ValueError(f"Path {path} does not exist")


def find_avro_schema(directory: Path) -> Path:
    """Find the Avro schema file (.avsc) in the given directory."""
    avsc_files = list(directory.glob('*.avsc'))
    
    if not avsc_files:
        raise ValueError(f"No Avro schema file (.avsc) found in {directory}")
    
    if len(avsc_files) > 1:
        print(f"Warning: Multiple .avsc files found, using {avsc_files[0].name}", file=sys.stderr)
    
    return avsc_files[0]


def main():
    parser = argparse.ArgumentParser(
        description='Process historical stock quote CSV files and produce to Kafka in Avro format'
    )
    parser.add_argument(
        'path',
        type=str,
        help='Path to a CSV file or directory containing CSV files'
    )
    parser.add_argument(
        '--env-file',
        type=str,
        default='.env',
        help='Path to .env file (default: .env)'
    )
    
    args = parser.parse_args()
    
    # Load environment variables from .env file
    env_path = Path(args.env_file)
    if env_path.exists():
        print(f"Loading configuration from {env_path}")
        load_dotenv(env_path)
    else:
        print(f"No .env file found at {env_path}, using environment variables")
    
    # Convert to Path object
    input_path = Path(args.path)
    
    # Find CSV files
    try:
        csv_files = find_csv_files(input_path)
        print(f"Found {len(csv_files)} CSV file(s) to process")
    except ValueError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)
    
    # Determine directory for schema lookup
    schema_dir = csv_files[0].parent
    
    # Load Avro schema
    try:
        schema_path = find_avro_schema(schema_dir)
        print(f"Loading Avro schema from {schema_path.name}")
        avro_schema = load_avro_schema(schema_path)
        print(f"Schema loaded: {avro_schema['namespace']}.{avro_schema['name']}\n")
    except (ValueError, json.JSONDecodeError) as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)
    
    # Create Kafka producer
    producer = create_kafka_producer()
    kafka_topic = os.getenv('KAFKA_TOPIC')
    
    if producer and not kafka_topic:
        print("ERROR: KAFKA_TOPIC not set in environment", file=sys.stderr)
        sys.exit(1)
    
    if producer and kafka_topic:
        print(f"Will produce messages to topic: {kafka_topic}\n")
    
    # Create a thread for each CSV file
    threads = []
    
    for idx, csv_file in enumerate(csv_files, start=1):
        thread = threading.Thread(
            target=process_csv_file,
            args=(csv_file, avro_schema, idx, producer, kafka_topic),
            name=f"CSVProcessor-{idx}"
        )
        threads.append(thread)
        thread.start()
    
    # Wait for all threads to complete
    print(f"Started {len(threads)} processing thread(s)\n")
    
    for thread in threads:
        thread.join()
    
    # Final flush to ensure all messages are sent
    if producer:
        print("\nFlushing remaining messages...")
        producer.flush()
    
    print("\nAll threads completed. Exiting.")


if __name__ == '__main__':
    main()
