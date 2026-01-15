#!/usr/bin/env python3
"""Receive messages from Amazon MQ ActiveMQ using STOMP protocol.

Usage:
    python receive_message.py <queue_name> [--continuous]

Environment variables required:
    MQ_ENDPOINT - The STOMP endpoint (ssl://...)
    MQ_USERNAME - The broker username
    MQ_PASSWORD - The broker password
"""

import os
import ssl
import sys
import time
import uuid

import stomp


class MessageListener(stomp.ConnectionListener):
    """Listener to receive and print messages."""

    def __init__(self, continuous=False):
        self.continuous = continuous
        self.received = False

    def on_message(self, frame):
        print(f"📨 Received: {frame.body}")
        self.received = True

    def on_error(self, frame):
        print(f"❌ Error: {frame.body}")


def main():
    if len(sys.argv) < 2:
        print("Usage: python receive_message.py <queue_name> [--continuous]")
        sys.exit(1)

    queue_name = sys.argv[1]
    continuous = "--continuous" in sys.argv

    # Ensure queue name has proper prefix
    if not queue_name.startswith("/queue/"):
        queue_name = f"/queue/{queue_name}"

    # Get configuration from environment
    endpoint = os.environ.get("MQ_ENDPOINT", "")
    username = os.environ.get("MQ_USERNAME", "")
    password = os.environ.get("MQ_PASSWORD", "")

    if not all([endpoint, username, password]):
        print("Error: MQ_ENDPOINT, MQ_USERNAME, and MQ_PASSWORD must be set")
        sys.exit(1)

    # Parse endpoint
    host = endpoint.replace("ssl://", "").split(":")[0]
    port = 61614  # ActiveMQ STOMP+SSL port

    # Setup SSL connection
    conn = stomp.Connection(
        [(host, port)],
        heartbeats=(10000, 10000),
    )
    conn.set_ssl(for_hosts=[(host, port)])

    listener = MessageListener(continuous)
    conn.set_listener("receiver", listener)

    try:
        conn.connect(username, password, wait=True)
        subscription_id = str(uuid.uuid4())
        conn.subscribe(destination=queue_name, id=subscription_id, ack="auto")

        if continuous:
            print(f"Listening for messages on '{queue_name}'... (Ctrl+C to stop)")
            while True:
                time.sleep(1)
        else:
            # Wait briefly for a single message
            timeout = 3
            start = time.time()
            while not listener.received and (time.time() - start) < timeout:
                time.sleep(0.1)

            if not listener.received:
                print(f"No messages in queue '{queue_name}'")

            conn.disconnect()

    except KeyboardInterrupt:
        print("\nStopped listening.")
        conn.disconnect()
    except Exception as e:
        print(f"❌ Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
