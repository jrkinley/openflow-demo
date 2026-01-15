#!/usr/bin/env python3
"""Send a message to Amazon MQ ActiveMQ using STOMP protocol.

Usage:
    python send_message.py <queue_name> <message>

Environment variables required:
    MQ_ENDPOINT - The STOMP endpoint (ssl://...)
    MQ_USERNAME - The broker username
    MQ_PASSWORD - The broker password
"""

import os
import ssl
import sys

import stomp


def main():
    if len(sys.argv) < 3:
        print("Usage: python send_message.py <queue_name> <message>")
        sys.exit(1)

    queue_name = sys.argv[1]
    message = " ".join(sys.argv[2:])

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

    try:
        conn.connect(username, password, wait=True)
        conn.send(body=message, destination=queue_name)
        print(f"✅ Sent to '{queue_name}': {message}")
        conn.disconnect()

    except Exception as e:
        print(f"❌ Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
