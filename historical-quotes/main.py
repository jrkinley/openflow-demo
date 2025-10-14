#!/usr/bin/env python3
"""
Process historical stock quote CSV files and produce to Kafka in JSON format.
"""

import argparse
import csv
import json
import os
import sys
import threading
import time
from pathlib import Path
from typing import List, Dict, Any, Optional

from confluent_kafka import Producer
from confluent_kafka.admin import AdminClient, NewTopic, KafkaException
from dotenv import load_dotenv


def get_kafka_config() -> Optional[Dict[str, Any]]:
    """
    Get base Kafka configuration from environment variables.
    Returns None if KAFKA_BOOTSTRAP_SERVERS is not set.
    """
    bootstrap_servers = os.getenv('KAFKA_BOOTSTRAP_SERVERS')
    
    if not bootstrap_servers:
        return None
    
    config = {
        'bootstrap.servers': bootstrap_servers,
        'security.protocol': os.getenv('KAFKA_SECURITY_PROTOCOL', 'SASL_SSL'),
        'sasl.mechanisms': os.getenv('KAFKA_SASL_MECHANISM', 'SCRAM-SHA-512'),
        'sasl.username': os.getenv('KAFKA_SASL_USERNAME'),
        'sasl.password': os.getenv('KAFKA_SASL_PASSWORD'),
    }
    
    return config


def create_kafka_producer() -> Optional[Producer]:
    """
    Create a Kafka producer from environment variables.
    Returns None if KAFKA_BOOTSTRAP_SERVERS is not set (for testing without Kafka).
    """
    config = get_kafka_config()
    
    if not config:
        print("KAFKA_BOOTSTRAP_SERVERS not set. Running in print-only mode.")
        return None
    
    # Add producer-specific configuration
    config['client.id'] = 'historical-quotes-producer'
    
    print(f"Creating Kafka producer with bootstrap servers: {config['bootstrap.servers']}")
    return Producer(config)


def create_kafka_admin_client() -> Optional[AdminClient]:
    """
    Create a Kafka admin client from environment variables.
    Returns None if KAFKA_BOOTSTRAP_SERVERS is not set.
    """
    config = get_kafka_config()
    
    if not config:
        print("ERROR: KAFKA_BOOTSTRAP_SERVERS not set in environment", file=sys.stderr)
        return None
    
    print(f"Creating Kafka admin client with bootstrap servers: {config['bootstrap.servers']}")
    return AdminClient(config)


def recreate_topic(topic_name: str):
    """
    Delete and recreate a Kafka topic using cluster defaults.
    Waits 10 seconds between deletion and creation.
    """
    try:
        admin_client = create_kafka_admin_client()
        
        print(f"\n{'='*60}")
        print(f"Recreating topic: {topic_name}")
        print(f"{'='*60}\n")
        
        # Delete the topic if it exists
        try:
            print(f"Deleting topic '{topic_name}'...")
            fs = admin_client.delete_topics([topic_name], operation_timeout=30)
            
            # Wait for operation to complete
            for topic, f in fs.items():
                try:
                    f.result()  # The result itself is None
                    print(f"Topic '{topic}' deleted successfully")
                except KafkaException as e:
                    if e.args[0].code() == KafkaException._UNKNOWN_TOPIC_OR_PART:
                        print(f"Topic '{topic}' does not exist (will create new)")
                    else:
                        error_msg = str(e)
                        print(f"Failed to delete topic '{topic}': {error_msg}", file=sys.stderr)
                        if "TOPIC_AUTHORIZATION_FAILED" in error_msg or "authorization" in error_msg.lower():
                            print("HINT: Your credentials may not have admin permissions for topic management", file=sys.stderr)
                        return False
        except Exception as e:
            print(f"Error during topic deletion: {e}", file=sys.stderr)
            print("HINT: Ensure your user has permissions for Kafka admin operations", file=sys.stderr)
            return False
        
        # Wait for Kafka to cleanup resources
        print(f"\nWaiting 10 seconds for Kafka to cleanup resources...")
        for i in range(10, 0, -1):
            print(f"{i}...", end=" ", flush=True)
            time.sleep(1)
        print("\n")
        
        # Create the topic using cluster defaults
        try:
            print(f"Creating topic '{topic_name}' with cluster defaults...")
            new_topic = NewTopic(
                topic=topic_name,
                num_partitions=-1,  # Use broker default
                replication_factor=-1  # Use broker default
            )
            
            fs = admin_client.create_topics([new_topic], operation_timeout=30)
            
            # Wait for operation to complete
            for topic, f in fs.items():
                try:
                    f.result()  # The result itself is None
                    print(f"Topic '{topic}' created successfully")
                except KafkaException as e:
                    error_msg = str(e)
                    print(f"Failed to create topic '{topic}': {error_msg}", file=sys.stderr)
                    if "TOPIC_AUTHORIZATION_FAILED" in error_msg or "authorization" in error_msg.lower():
                        print("HINT: Your credentials may not have admin permissions for topic management", file=sys.stderr)
                    return False
        except Exception as e:
            print(f"Error during topic creation: {e}", file=sys.stderr)
            return False
        
        print(f"\n{'='*60}")
        print(f"Topic '{topic_name}' is ready")
        print(f"{'='*60}\n")
        
        return True
        
    except Exception as e:
        print(f"Unexpected error during topic recreation: {e}", file=sys.stderr)
        return False


def serialize_json_record(record: Dict[str, Any]) -> bytes:
    """Serialize a record to JSON bytes."""
    return json.dumps(record).encode('utf-8')


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


def csv_row_to_record(row: Dict[str, str], symbol: str) -> Dict[str, Any]:
    """
    Convert a CSV row to a record dictionary.
    
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
    thread_id: int,
    producer: Optional[Producer],
    kafka_topic: Optional[str]
):
    """
    Process a single CSV file in a thread.
    Read each row, convert to JSON format, and produce to Kafka (or print if no producer).
    """
    symbol = extract_symbol_from_filename(csv_path.name)
    
    print(f"[Thread {thread_id}] Processing {csv_path.name} (Symbol: {symbol})")
    
    try:
        with open(csv_path, 'r') as f:
            reader = csv.DictReader(f)
            record_count = 0
            
            for row in reader:
                # Convert CSV row to record
                record = csv_row_to_record(row, symbol)
                
                if producer and kafka_topic:
                    # Serialize and produce to Kafka
                    json_bytes = serialize_json_record(record)
                    
                    # Use the stock symbol as the key for partitioning
                    key = symbol.encode('utf-8')
                    
                    # Produce the message
                    producer.produce(
                        topic=kafka_topic,
                        key=key,
                        value=json_bytes,
                        callback=delivery_callback
                    )
                    
                    # Poll to handle delivery callbacks
                    producer.poll(0)
                else:
                    # Print mode (no Kafka connection)
                    print(f"[Thread {thread_id}] {record}")
                
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


def main():
    parser = argparse.ArgumentParser(
        description='Process historical stock quote CSV files and produce to Kafka in JSON format'
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
    parser.add_argument(
        '--recreate-topic',
        action='store_true',
        help='Delete and recreate the Kafka topic before producing messages'
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
        print(f"Found {len(csv_files)} CSV file(s) to process\n")
    except ValueError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)
    
    # Get Kafka topic
    kafka_topic = os.getenv('KAFKA_TOPIC')
    
    # Recreate topic if requested
    if args.recreate_topic:
        if not kafka_topic:
            print("ERROR: KAFKA_TOPIC not set in environment", file=sys.stderr)
            sys.exit(1)
        
        if not recreate_topic(kafka_topic):
            print("ERROR: Failed to recreate topic", file=sys.stderr)
            sys.exit(1)
    
    # Create Kafka producer
    producer = create_kafka_producer()
    
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
            args=(csv_file, idx, producer, kafka_topic),
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
