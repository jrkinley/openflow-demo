#!/bin/bash
# MSK Connection Test Setup Script

set -e

echo "🚀 Setting up MSK connection test environment..."

# Check if uv is installed
if ! command -v uv &> /dev/null; then
    echo "❌ uv package manager not found. Please install it first:"
    echo "   curl -LsSf https://astral.sh/uv/install.sh | sh"
    exit 1
fi

# Create uv virtual environment in tf-msk folder
echo "🔧 Creating uv virtual environment..."
if [ ! -d ".venv" ]; then
    uv venv .venv
    echo "✅ Created .venv virtual environment"
else
    echo "✅ Using existing .venv virtual environment"
fi

# Activate virtual environment and install dependencies
echo "📦 Installing confluent-kafka library in virtual environment..."
uv pip install confluent-kafka

# Get Terraform outputs if available (we're already in tf-msk directory)
if [ -f "terraform.tfstate" ]; then
    echo "🔧 Getting connection details from Terraform..."
    
    BOOTSTRAP_SERVERS=$(terraform output -raw msk_bootstrap_brokers_sasl_scram 2>/dev/null || echo "")
    KAFKA_USERNAME=$(terraform output -raw kafka_username 2>/dev/null || echo "")
    KAFKA_PASSWORD=$(terraform output -raw kafka_password 2>/dev/null || echo "")
    
    if [ -n "$BOOTSTRAP_SERVERS" ] && [ -n "$KAFKA_USERNAME" ] && [ -n "$KAFKA_PASSWORD" ]; then
        echo "✅ Found Terraform outputs, setting environment variables..."
        export MSK_BOOTSTRAP_SERVERS="$BOOTSTRAP_SERVERS"
        export KAFKA_USERNAME="$KAFKA_USERNAME"
        export KAFKA_PASSWORD="$KAFKA_PASSWORD"
        
        echo "🔧 Configuration:"
        echo "   Bootstrap Servers: $MSK_BOOTSTRAP_SERVERS"
        echo "   Username: $KAFKA_USERNAME"
        echo "   Password: [HIDDEN]"
    else
        echo "⚠️  Could not retrieve all Terraform outputs"
        echo "   Please set environment variables manually or ensure MSK cluster is deployed"
    fi
else
    echo "⚠️  No terraform.tfstate found. Please set environment variables manually:"
    echo "   export MSK_BOOTSTRAP_SERVERS='your-bootstrap-brokers'"
    echo "   export KAFKA_USERNAME='your-username'"
    echo "   export KAFKA_PASSWORD='your-password'"
fi

echo ""
echo "🧪 Running MSK connection test..."
uv run python test_msk_connection.py
