#!/bin/bash
# Setup Kafka ACLs using IAM authentication for MSK public access
set -e

if [ $# -ne 2 ]; then
    echo "Usage: $0 <bootstrap_servers_iam> <scram_username>"
    exit 1
fi

BOOTSTRAP_SERVERS="$1"
SCRAM_USERNAME="$2"
PRINCIPAL="User:$SCRAM_USERNAME"

echo "Setting up Kafka ACLs for public access..."

# Check prerequisites
command -v kafka-acls >/dev/null || { echo "Error: kafka-acls not found. Install with: brew install kafka"; exit 1; }
command -v aws >/dev/null || { echo "Error: AWS CLI not found"; exit 1; }
command -v jq >/dev/null || { echo "Error: jq not found"; exit 1; }

# Get MSK admin user name from Terraform (most reliable)
MSK_ADMIN_USER_NAME=$(cd .. && terraform output -raw msk_admin_user_name 2>/dev/null)
if [ -z "$MSK_ADMIN_USER_NAME" ]; then
    echo "Error: Could not get MSK admin user name from Terraform"
    exit 1
fi

# Get MSK admin credentials from AWS
MSK_ADMIN_ACCESS_KEY=$(aws iam list-access-keys --user-name "$MSK_ADMIN_USER_NAME" --query 'AccessKeyMetadata[0].AccessKeyId' --output text 2>/dev/null)
if [ "$MSK_ADMIN_ACCESS_KEY" = "None" ] || [ -z "$MSK_ADMIN_ACCESS_KEY" ]; then
    echo "Error: MSK admin user '$MSK_ADMIN_USER_NAME' not found or has no access keys"
    exit 1
fi

# Get secret key from Terraform (only place it's stored)
MSK_ADMIN_SECRET_KEY=$(cd .. && terraform output -raw msk_admin_secret_access_key 2>/dev/null)
if [ -z "$MSK_ADMIN_SECRET_KEY" ]; then
    echo "Error: Could not get secret access key from Terraform"
    exit 1
fi

# Create temporary AWS profile
TEMP_PROFILE="msk-temp-$$"
aws configure set aws_access_key_id "$MSK_ADMIN_ACCESS_KEY" --profile "$TEMP_PROFILE" >/dev/null
aws configure set aws_secret_access_key "$MSK_ADMIN_SECRET_KEY" --profile "$TEMP_PROFILE" >/dev/null
aws configure set region "${AWS_DEFAULT_REGION:-eu-west-2}" --profile "$TEMP_PROFILE" >/dev/null
export AWS_PROFILE="$TEMP_PROFILE"

# Create IAM client properties and run ACLs
PROPERTIES_FILE=$(mktemp /tmp/iam-client.XXXXXX.properties)
cat > "$PROPERTIES_FILE" << EOF
security.protocol=SASL_SSL
sasl.mechanism=AWS_MSK_IAM
sasl.jaas.config=software.amazon.msk.auth.iam.IAMLoginModule required awsProfileName="$TEMP_PROFILE";
sasl.client.callback.handler.class=software.amazon.msk.auth.iam.IAMClientCallbackHandler
EOF

KAFKA_BIN_PATH=$(dirname "$(which kafka-acls)")

# Cleanup function
cleanup() {
    [ -f "$PROPERTIES_FILE" ] && rm -f "$PROPERTIES_FILE"
    [ -n "$TEMP_PROFILE" ] && aws configure --profile "$TEMP_PROFILE" --remove-section >/dev/null 2>&1 || true
}
trap cleanup EXIT

# Test AWS credentials first
echo "Testing IAM credentials..."
if ! aws sts get-caller-identity --profile "$TEMP_PROFILE" >/dev/null 2>&1; then
    echo "Error: IAM credentials test failed"
    exit 1
fi

# Grant comprehensive permissions
echo "Granting cluster permissions..."
for operation in Create Describe; do
    if ! "$KAFKA_BIN_PATH/kafka-acls" --bootstrap-server "$BOOTSTRAP_SERVERS" --command-config "$PROPERTIES_FILE" \
        --add --allow-principal "$PRINCIPAL" --operation "$operation" --cluster >/dev/null 2>&1; then
        echo "Warning: Failed to grant cluster $operation permission (may already exist)"
    fi
done

echo "Granting topic permissions..."
for operation in Read Write Create Describe Delete; do
    if ! "$KAFKA_BIN_PATH/kafka-acls" --bootstrap-server "$BOOTSTRAP_SERVERS" --command-config "$PROPERTIES_FILE" \
        --add --allow-principal "$PRINCIPAL" --operation "$operation" --topic "*" >/dev/null 2>&1; then
        echo "Warning: Failed to grant topic $operation permission (may already exist)"
    fi
done

echo "Granting consumer group permissions..."
for operation in Read Describe; do
    if ! "$KAFKA_BIN_PATH/kafka-acls" --bootstrap-server "$BOOTSTRAP_SERVERS" --command-config "$PROPERTIES_FILE" \
        --add --allow-principal "$PRINCIPAL" --operation "$operation" --group "*" >/dev/null 2>&1; then
        echo "Warning: Failed to grant group $operation permission (may already exist)"
    fi
done

echo "✅ ACLs configured for user: $SCRAM_USERNAME"