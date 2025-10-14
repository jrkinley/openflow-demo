#!/usr/bin/env python3
"""
Consume Avro-encoded messages from Kafka and print them to the terminal.
"""

import argparse
import io
import json
import os
import sys
from pathlib import Path
from typing import Dict, Any, Optional

import fastavro
from confluent_kafka import Consumer, KafkaError
from dotenv import load_dotenv


def load_avro_schema(schema_path: Path) -> Dict[str, Any]:
    """Load and parse the Avro schema file."""
    with open(schema_path, 'r') as f:
        return json.load(f)


def deserialize_avro_record(avro_bytes: bytes, schema: Dict[str, Any]) -> Dict[str, Any]:
    """Deserialize Avro bytes back to a record."""
    input_stream = io.BytesIO(avro_bytes)
    return fastavro.schemaless_reader(input_stream, schema)


def create_kafka_consumer() -> Optional[Consumer]:
    """
    Create a Kafka consumer from environment variables.
    Returns None if KAFKA_BOOTSTRAP_SERVERS is not set.
    """
    bootstrap_servers = os.getenv('KAFKA_BOOTSTRAP_SERVERS')
    
    if not bootstrap_servers:
        print("ERROR: KAFKA_BOOTSTRAP_SERVERS not set", file=sys.stderr)
        return None
    
    config = {
        'bootstrap.servers': bootstrap_servers,
        'group.id': 'historical-quotes-consumer',
        'client.id': 'historical-quotes-consumer',
        'auto.offset.reset': 'earliest',  # Start from beginning
        'enable.auto.commit': True,
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
    
    print(f"Creating Kafka consumer with bootstrap servers: {bootstrap_servers}")
    return Consumer(config)


def find_avro_schema(directory: Path = Path('data')) -> Path:
    """Find the Avro schema file (.avsc) in the given directory."""
    avsc_files = list(directory.glob('*.avsc'))
    
    if not avsc_files:
        raise ValueError(f"No Avro schema file (.avsc) found in {directory}")
    
    if len(avsc_files) > 1:
        print(f"Warning: Multiple .avsc files found, using {avsc_files[0].name}", file=sys.stderr)
    
    return avsc_files[0]


def main():
    parser = argparse.ArgumentParser(
        description='Consume Avro-encoded messages from Kafka and print to terminal'
    )
    parser.add_argument(
        '--limit',
        type=int,
        default=None,
        help='Maximum number of messages to consume (default: unlimited)'
    )
    parser.add_argument(
        '--env-file',
        type=str,
        default='.env',
        help='Path to .env file (default: .env)'
    )
    parser.add_argument(
        '--schema-dir',
        type=str,
        default='data',
        help='Directory containing the Avro schema file (default: data)'
    )
    
    args = parser.parse_args()
    
    # Load environment variables from .env file
    env_path = Path(args.env_file)
    if env_path.exists():
        print(f"Loading configuration from {env_path}")
        load_dotenv(env_path)
    else:
        print(f"No .env file found at {env_path}, using environment variables")
    
    # Get Kafka topic
    kafka_topic = os.getenv('KAFKA_TOPIC')
    if not kafka_topic:
        print("ERROR: KAFKA_TOPIC not set in environment", file=sys.stderr)
        sys.exit(1)
    
    # Load Avro schema
    try:
        schema_dir = Path(args.schema_dir)
        schema_path = find_avro_schema(schema_dir)
        print(f"Loading Avro schema from {schema_path}")
        avro_schema = load_avro_schema(schema_path)
        print(f"Schema loaded: {avro_schema['namespace']}.{avro_schema['name']}\n")
    except (ValueError, json.JSONDecodeError) as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)
    
    # Create Kafka consumer
    consumer = create_kafka_consumer()
    if not consumer:
        sys.exit(1)
    
    # Subscribe to topic
    consumer.subscribe([kafka_topic])
    print(f"Subscribed to topic: {kafka_topic}")
    
    if args.limit:
        print(f"Will consume up to {args.limit} messages\n")
    else:
        print("Will consume messages indefinitely (Ctrl+C to stop)\n")
    
    message_count = 0
    
    try:
        while True:
            # Check if we've reached the limit
            if args.limit and message_count >= args.limit:
                print(f"\nReached message limit of {args.limit}")
                break
            
            # Poll for messages
            msg = consumer.poll(timeout=1.0)
            
            if msg is None:
                continue
            
            if msg.error():
                if msg.error().code() == KafkaError._PARTITION_EOF:
                    # End of partition, continue polling
                    print(f"Reached end of partition {msg.partition()}")
                    continue
                else:
                    print(f"Consumer error: {msg.error()}", file=sys.stderr)
                    break
            
            # Deserialize and print the message
            try:
                key = msg.key().decode('utf-8') if msg.key() else None
                avro_record = deserialize_avro_record(msg.value(), avro_schema)
                
                message_count += 1
                print(f"[{message_count}] Topic: {msg.topic()}, Partition: {msg.partition()}, "
                      f"Offset: {msg.offset()}, Key: {key}")
                print(f"    {avro_record}")
                
            except Exception as e:
                print(f"Error deserializing message: {e}", file=sys.stderr)
                continue
    
    except KeyboardInterrupt:
        print("\n\nInterrupted by user")
    
    finally:
        # Close consumer
        print(f"\nConsumed {message_count} messages total")
        print("Closing consumer...")
        consumer.close()


if __name__ == '__main__':
    main()

