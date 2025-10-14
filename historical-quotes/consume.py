#!/usr/bin/env python3
"""
Consume JSON-encoded messages from Kafka and print them to the terminal.
"""

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Dict, Any, Optional

from confluent_kafka import Consumer, KafkaError
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


def deserialize_json_record(json_bytes: bytes) -> Dict[str, Any]:
    """Deserialize JSON bytes back to a record."""
    return json.loads(json_bytes.decode('utf-8'))


def create_kafka_consumer() -> Optional[Consumer]:
    """
    Create a Kafka consumer from environment variables.
    Returns None if KAFKA_BOOTSTRAP_SERVERS is not set.
    """
    config = get_kafka_config()
    
    if not config:
        print("ERROR: KAFKA_BOOTSTRAP_SERVERS not set", file=sys.stderr)
        return None
    
    # Add consumer-specific configuration
    config['group.id'] = 'historical-quotes-consumer'
    config['client.id'] = 'historical-quotes-consumer'
    config['auto.offset.reset'] = 'earliest'  # Start from beginning
    config['enable.auto.commit'] = True
    
    print(f"Creating Kafka consumer with bootstrap servers: {config['bootstrap.servers']}")
    return Consumer(config)


def main():
    parser = argparse.ArgumentParser(
        description='Consume JSON-encoded messages from Kafka and print to terminal'
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
                record = deserialize_json_record(msg.value())
                
                message_count += 1
                print(f"[{message_count}] Topic: {msg.topic()}, Partition: {msg.partition()}, "
                      f"Offset: {msg.offset()}, Key: {key}")
                print(f"    {record}")
                
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

