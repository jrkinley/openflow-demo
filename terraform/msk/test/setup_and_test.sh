#!/bin/bash
# MSK Connection Test Setup Script
set -e

echo "Setting up MSK connection test..."

# Check prerequisites
for cmd in uv aws jq kafka-acls; do
    command -v "$cmd" >/dev/null || { echo "Error: $cmd not found"; exit 1; }
done

# Setup Python environment
[ ! -d ".venv" ] && uv venv .venv
uv pip install confluent-kafka >/dev/null

# Download AWS MSK IAM Auth JAR
IAM_JAR_FILE="aws-msk-iam-auth-1.1.1-all.jar"
if [ ! -f "$IAM_JAR_FILE" ]; then
    echo "Downloading IAM authentication JAR..."
    curl -sL -o "$IAM_JAR_FILE" "https://github.com/aws/aws-msk-iam-auth/releases/download/v1.1.1/aws-msk-iam-auth-1.1.1-all.jar"
fi
export CLASSPATH="$(pwd)/$IAM_JAR_FILE:$CLASSPATH"

# Get cluster configuration from AWS
CLUSTER_ARN=$(cd .. && terraform output -raw msk_cluster_arn 2>/dev/null)
[ -z "$CLUSTER_ARN" ] && { echo "Error: Could not get cluster ARN from Terraform"; exit 1; }

BOOTSTRAP_RESPONSE=$(aws kafka get-bootstrap-brokers --cluster-arn "$CLUSTER_ARN")
PUBLIC_BROKERS_SCRAM=$(echo "$BOOTSTRAP_RESPONSE" | jq -r '.BootstrapBrokerStringPublicSaslScram')
PUBLIC_BROKERS_IAM=$(echo "$BOOTSTRAP_RESPONSE" | jq -r '.BootstrapBrokerStringPublicSaslIam')

[ "$PUBLIC_BROKERS_SCRAM" = "null" ] && { echo "Error: Public SCRAM brokers not available. Enable public access."; exit 1; }
[ "$PUBLIC_BROKERS_IAM" = "null" ] && { echo "Error: Public IAM brokers not available"; exit 1; }

# Get SCRAM credentials
SECRET_ARN=$(aws kafka list-scram-secrets --cluster-arn "$CLUSTER_ARN" --query 'SecretArnList[0]' --output text)
SECRET_VALUE=$(aws secretsmanager get-secret-value --secret-id "$SECRET_ARN" --query 'SecretString' --output text)
KAFKA_USERNAME=$(echo "$SECRET_VALUE" | jq -r '.username')
KAFKA_PASSWORD=$(echo "$SECRET_VALUE" | jq -r '.password')

# Export for test script
export MSK_BOOTSTRAP_SERVERS="$PUBLIC_BROKERS_SCRAM"
export KAFKA_USERNAME="$KAFKA_USERNAME"
export KAFKA_PASSWORD="$KAFKA_PASSWORD"

echo "✅ Configuration ready"
echo "   SCRAM Servers: $PUBLIC_BROKERS_SCRAM"
echo "   Username: $KAFKA_USERNAME"

# Setup ACLs and run tests
echo ""
echo "Setting up ACLs..."
./setup_acls_with_iam.sh "$PUBLIC_BROKERS_IAM" "$KAFKA_USERNAME"

echo ""
echo "Running connection tests..."
uv run python test_msk_connection.py