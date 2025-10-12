#!/bin/bash
# MSK Connection Test Setup Script

set -e

echo "🚀 Setting up MSK connection test environment..."

# Check prerequisites
if ! command -v uv &> /dev/null; then
    echo "❌ uv package manager not found. Please install it first:"
    echo "   curl -LsSf https://astral.sh/uv/install.sh | sh"
    exit 1
fi

if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI not found. Please install it first"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "❌ jq not found. Please install it first"
    exit 1
fi

# Setup Python environment
echo "📦 Setting up Python environment..."
if [ ! -d ".venv" ]; then
    uv venv .venv
fi
uv pip install confluent-kafka

# Get cluster ARN from Terraform (only thing we need from Terraform)
if [ ! -f "terraform.tfstate" ]; then
    echo "❌ No terraform.tfstate found. Please deploy the cluster first."
    exit 1
fi

CLUSTER_ARN=$(terraform output -raw msk_cluster_arn 2>/dev/null)
if [ -z "$CLUSTER_ARN" ]; then
    echo "❌ Could not get cluster ARN from Terraform"
    exit 1
fi

echo "🔍 Getting MSK configuration from AWS..."

# Get bootstrap brokers from AWS
BOOTSTRAP_RESPONSE=$(aws kafka get-bootstrap-brokers --cluster-arn "$CLUSTER_ARN")
PUBLIC_BROKERS=$(echo "$BOOTSTRAP_RESPONSE" | jq -r '.BootstrapBrokerStringPublicSaslScram // .BootstrapBrokerStringSaslScram')

if [ -z "$PUBLIC_BROKERS" ] || [ "$PUBLIC_BROKERS" = "null" ]; then
    echo "❌ Could not get bootstrap brokers from AWS"
    exit 1
fi

# Get secret ARN from AWS (find the AmazonMSK_ secret associated with this cluster)
SECRET_ARNS=$(aws kafka list-scram-secrets --cluster-arn "$CLUSTER_ARN" --query 'SecretArnList[]' --output text)
if [ -z "$SECRET_ARNS" ]; then
    echo "❌ No SASL/SCRAM secrets associated with cluster"
    exit 1
fi

# Use the first secret (should only be one)
SECRET_ARN=$(echo "$SECRET_ARNS" | head -n1)

# Get credentials from secret
SECRET_VALUE=$(aws secretsmanager get-secret-value --secret-id "$SECRET_ARN" --query 'SecretString' --output text)
KAFKA_USERNAME=$(echo "$SECRET_VALUE" | jq -r '.username')
KAFKA_PASSWORD=$(echo "$SECRET_VALUE" | jq -r '.password')

# Export environment variables
export MSK_BOOTSTRAP_SERVERS="$PUBLIC_BROKERS"
export KAFKA_USERNAME="$KAFKA_USERNAME"
export KAFKA_PASSWORD="$KAFKA_PASSWORD"

echo "✅ Configuration ready:"
echo "   Bootstrap Servers: $MSK_BOOTSTRAP_SERVERS"
echo "   Username: $KAFKA_USERNAME"
echo "   Password: [HIDDEN]"

echo ""
echo "🔧 Setting up Kafka ACLs (if needed)..."
uv run python setup_kafka_acls.py

echo ""
echo "🧪 Running MSK connection test..."
uv run python test_msk_connection.py