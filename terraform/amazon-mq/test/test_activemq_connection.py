#!/usr/bin/env python3
"""Test script for Amazon MQ ActiveMQ connection using STOMP protocol."""

import os
import ssl
import sys
import time
import uuid

import stomp

# Get configuration from environment
ENDPOINT = os.environ.get("MQ_ENDPOINT", "")
USERNAME = os.environ.get("MQ_USERNAME", "")
PASSWORD = os.environ.get("MQ_PASSWORD", "")

TEST_QUEUE = "/queue/openflow-test-queue"
TEST_MESSAGE = "Hello from OpenFlow Amazon MQ test!"


class TestListener(stomp.ConnectionListener):
    """Listener to receive messages."""

    def __init__(self):
        self.received_message = None
        self.error = None

    def on_message(self, frame):
        self.received_message = frame.body

    def on_error(self, frame):
        self.error = frame.body


def main():
    if not all([ENDPOINT, USERNAME, PASSWORD]):
        print("Error: MQ_ENDPOINT, MQ_USERNAME, and MQ_PASSWORD must be set")
        sys.exit(1)

    # Parse endpoint - format: ssl://b-xxxx.mq.region.amazonaws.com:61614
    host = ENDPOINT.replace("ssl://", "").split(":")[0]
    port = 61614  # ActiveMQ STOMP+SSL port

    print(f"Connecting to ActiveMQ at {host}:{port}...")

    # Setup SSL connection
    conn = stomp.Connection(
        [(host, port)],
        heartbeats=(10000, 10000),
    )
    conn.set_ssl(for_hosts=[(host, port)])

    listener = TestListener()
    conn.set_listener("test", listener)

    try:
        # Connect to ActiveMQ
        conn.connect(USERNAME, PASSWORD, wait=True)
        print("✅ Connected to ActiveMQ")

        # Subscribe to test queue
        subscription_id = str(uuid.uuid4())
        conn.subscribe(destination=TEST_QUEUE, id=subscription_id, ack="auto")
        print(f"✅ Subscribed to queue: {TEST_QUEUE}")

        # Send a test message
        conn.send(body=TEST_MESSAGE, destination=TEST_QUEUE)
        print(f"✅ Sent message: {TEST_MESSAGE}")

        # Wait for message to be received
        timeout = 5
        start = time.time()
        while listener.received_message is None and (time.time() - start) < timeout:
            time.sleep(0.1)

        if listener.received_message:
            print(f"✅ Received message: {listener.received_message}")
        else:
            print("❌ No message received within timeout")
            sys.exit(1)

        if listener.error:
            print(f"❌ Error: {listener.error}")
            sys.exit(1)

        # Disconnect
        conn.disconnect()
        print("\n🎉 All tests passed! Amazon MQ ActiveMQ is working correctly.")

    except stomp.exception.ConnectFailedException as e:
        print(f"❌ Connection failed: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()

