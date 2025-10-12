#!/usr/bin/env python3
"""
MSK Connection Test Script
Tests connection to AWS MSK cluster using SASL/SCRAM authentication.
Produces a message and consumes it back to verify connectivity.

Usage:
    uv pip install confluent-kafka
    python test_msk_connection.py
"""

import os
import sys
import time
import json
from datetime import datetime
from confluent_kafka import Producer, Consumer, KafkaException, KafkaError
from confluent_kafka.admin import AdminClient, NewTopic

# Configuration - Update these values from your Terraform outputs
BOOTSTRAP_SERVERS = os.getenv('MSK_BOOTSTRAP_SERVERS', 'your-msk-brokers:9096')
SASL_USERNAME = os.getenv('KAFKA_USERNAME', 'kafka-user')
SASL_PASSWORD = os.getenv('KAFKA_PASSWORD', 'your-password')
TOPIC_NAME = 'msk-test-topic'
CONSUMER_GROUP = 'msk-test-group'

def get_kafka_config():
    """Get base Kafka configuration for SASL/SCRAM authentication."""
    return {
        'bootstrap.servers': BOOTSTRAP_SERVERS,
        'security.protocol': 'SASL_SSL',
        'sasl.mechanisms': 'SCRAM-SHA-512',
        'sasl.username': SASL_USERNAME,
        'sasl.password': SASL_PASSWORD,
    }

def test_connection():
    """Test basic connection to MSK cluster."""
    print("🔗 Testing MSK cluster connection...")
    
    try:
        admin_client = AdminClient(get_kafka_config())
        metadata = admin_client.list_topics(timeout=10)
        
        print(f"✅ Successfully connected to MSK cluster!")
        print(f"📊 Found {len(metadata.topics)} topics")
        print(f"🖥️  Cluster has {len(metadata.brokers)} brokers")
        return True
        
    except Exception as e:
        print(f"❌ Connection failed: {e}")
        return False

def create_topic_if_not_exists():
    """Create test topic if it doesn't exist."""
    print(f"📝 Checking/creating topic: {TOPIC_NAME}")
    
    try:
        admin_client = AdminClient(get_kafka_config())
        metadata = admin_client.list_topics(timeout=10)
        
        if TOPIC_NAME not in metadata.topics:
            print(f"🆕 Creating topic: {TOPIC_NAME}")
            topic = NewTopic(TOPIC_NAME, num_partitions=1, replication_factor=3)
            futures = admin_client.create_topics([topic])
            
            # Wait for topic creation
            for topic, future in futures.items():
                try:
                    future.result(timeout=10)
                    print(f"✅ Topic '{topic}' created successfully")
                except Exception as e:
                    print(f"❌ Failed to create topic '{topic}': {e}")
                    return False
        else:
            print(f"✅ Topic '{TOPIC_NAME}' already exists")
        
        return True
        
    except Exception as e:
        print(f"❌ Topic creation failed: {e}")
        return False

def delivery_report(err, msg):
    """Callback for message delivery reports."""
    if err is not None:
        print(f"❌ Message delivery failed: {err}")
    else:
        print(f"✅ Message delivered to {msg.topic()}[{msg.partition()}] at offset {msg.offset()}")

def produce_message():
    """Produce a test message to the Kafka topic."""
    print("📤 Producing test message...")
    
    try:
        producer_config = get_kafka_config()
        producer_config.update({
            'acks': 'all',
            'retries': 3,
            'batch.size': 16384,
            'linger.ms': 10,
        })
        
        producer = Producer(producer_config)
        
        # Create test message
        test_message = {
            'timestamp': datetime.now().isoformat(),
            'message': 'Hello from MSK test script!',
            'test_id': int(time.time())
        }
        
        message_json = json.dumps(test_message)
        
        # Produce message
        producer.produce(
            topic=TOPIC_NAME,
            value=message_json.encode('utf-8'),
            key=f"test-key-{test_message['test_id']}".encode('utf-8'),
            callback=delivery_report
        )
        
        # Wait for message delivery
        producer.flush(timeout=10)
        print("📤 Message production completed")
        return test_message['test_id']
        
    except Exception as e:
        print(f"❌ Message production failed: {e}")
        return None

def consume_message(expected_test_id):
    """Consume the test message from the Kafka topic."""
    print("📥 Consuming test message...")
    
    try:
        consumer_config = get_kafka_config()
        consumer_config.update({
            'group.id': CONSUMER_GROUP,
            'auto.offset.reset': 'earliest',
            'enable.auto.commit': True,
            'session.timeout.ms': 6000,
            'heartbeat.interval.ms': 2000,
        })
        
        consumer = Consumer(consumer_config)
        consumer.subscribe([TOPIC_NAME])
        
        message_found = False
        timeout = time.time() + 30  # 30 second timeout
        
        while time.time() < timeout and not message_found:
            msg = consumer.poll(timeout=1.0)
            
            if msg is None:
                continue
                
            if msg.error():
                if msg.error().code() == KafkaError._PARTITION_EOF:
                    continue
                else:
                    print(f"❌ Consumer error: {msg.error()}")
                    break
            
            try:
                # Decode message
                message_data = json.loads(msg.value().decode('utf-8'))
                key = msg.key().decode('utf-8') if msg.key() else None
                
                print(f"📥 Received message:")
                print(f"   Key: {key}")
                print(f"   Partition: {msg.partition()}")
                print(f"   Offset: {msg.offset()}")
                print(f"   Timestamp: {message_data.get('timestamp')}")
                print(f"   Message: {message_data.get('message')}")
                print(f"   Test ID: {message_data.get('test_id')}")
                
                # Check if this is our test message
                if message_data.get('test_id') == expected_test_id:
                    print("✅ Successfully consumed our test message!")
                    message_found = True
                
            except json.JSONDecodeError:
                print(f"📥 Received non-JSON message: {msg.value().decode('utf-8')}")
        
        consumer.close()
        
        if not message_found:
            print("⚠️  Test message not found within timeout period")
            return False
            
        return True
        
    except Exception as e:
        print(f"❌ Message consumption failed: {e}")
        return False

def main():
    """Main test function."""
    print("🚀 Starting MSK Connection Test")
    print("=" * 50)
    
    # Check environment variables
    if BOOTSTRAP_SERVERS == 'your-msk-brokers:9096':
        print("⚠️  Please set environment variables:")
        print("   export MSK_BOOTSTRAP_SERVERS='your-bootstrap-brokers'")
        print("   export KAFKA_USERNAME='your-username'")
        print("   export KAFKA_PASSWORD='your-password'")
        print("\nOr get them from Terraform outputs:")
        print("   terraform output msk_bootstrap_brokers_sasl_scram")
        print("   terraform output kafka_username")
        print("   terraform output -raw kafka_password")
        sys.exit(1)
    
    print(f"🔧 Configuration:")
    print(f"   Bootstrap Servers: {BOOTSTRAP_SERVERS}")
    print(f"   Username: {SASL_USERNAME}")
    print(f"   Topic: {TOPIC_NAME}")
    print(f"   Consumer Group: {CONSUMER_GROUP}")
    print()
    
    # Test connection
    if not test_connection():
        sys.exit(1)
    
    # Create topic
    if not create_topic_if_not_exists():
        sys.exit(1)
    
    # Produce message
    test_id = produce_message()
    if test_id is None:
        sys.exit(1)
    
    # Wait a moment for message to be available
    print("⏳ Waiting for message to be available...")
    time.sleep(2)
    
    # Consume message
    if not consume_message(test_id):
        sys.exit(1)
    
    print()
    print("🎉 MSK connection test completed successfully!")
    print("✅ Connection, production, and consumption all working!")

if __name__ == '__main__':
    main()
