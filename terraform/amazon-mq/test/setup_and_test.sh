#!/bin/bash
# Amazon MQ Connection Test Setup Script
set -e

echo "Setting up Amazon MQ connection test..."

# Check prerequisites
for cmd in uv jq; do
    command -v "$cmd" >/dev/null || { echo "Error: $cmd not found"; exit 1; }
done

# Setup Python environment
[ ! -d ".venv" ] && uv venv .venv
uv pip install "stomp.py" >/dev/null

# Get broker configuration from Terraform
BROKER_ID=$(cd .. && terraform output -raw broker_id 2>/dev/null)
[ -z "$BROKER_ID" ] && { echo "Error: Could not get broker ID from Terraform"; exit 1; }

ENGINE_TYPE=$(cd .. && terraform output -raw broker_engine_type 2>/dev/null)
CONSOLE_URL=$(cd .. && terraform output -raw console_url 2>/dev/null)
MQ_USERNAME=$(cd .. && terraform output -raw mq_username 2>/dev/null)
MQ_PASSWORD=$(cd .. && terraform output -raw mq_password 2>/dev/null)

if [ "$ENGINE_TYPE" = "ActiveMQ" ]; then
    # Get ActiveMQ STOMP endpoint
    ENDPOINTS=$(cd .. && terraform output -json activemq_endpoints 2>/dev/null)
    ENDPOINT=$(echo "$ENDPOINTS" | jq -r '.[] | select(startswith("stomp+ssl://"))' | head -1)
    
    # Convert stomp+ssl:// to ssl:// for stomp.py compatibility
    ENDPOINT=$(echo "$ENDPOINT" | sed 's/stomp+ssl:/ssl:/')
    
    echo "✅ ActiveMQ Configuration ready"
    echo "   STOMP Endpoint: $ENDPOINT"
    echo "   Console:        $CONSOLE_URL"
    echo "   Username:       $MQ_USERNAME"
    
    # Export for test script
    export MQ_ENDPOINT="$ENDPOINT"
    export MQ_USERNAME="$MQ_USERNAME"
    export MQ_PASSWORD="$MQ_PASSWORD"
    
    echo ""
    echo "Running ActiveMQ connection test..."
    uv run python test_activemq_connection.py
else
    ENDPOINT=$(cd .. && terraform output -raw rabbitmq_endpoint 2>/dev/null)
    echo "✅ RabbitMQ Configuration ready"
    echo "   Endpoint: $ENDPOINT"
    echo "   Console:  $CONSOLE_URL"
    echo "   Username: $MQ_USERNAME"
    echo ""
    echo "RabbitMQ test not implemented. Use the web console to test connectivity."
fi
