# AWS Amazon MQ Broker

Deploy an AWS Amazon MQ broker (RabbitMQ or ActiveMQ) with public access support for demos.

## Quick Start

```bash
# Deploy with existing VPC
export TF_VAR_mq_password=$(openssl rand -base64 12)
terraform init
terraform apply -var-file="examples/existing-vpc.tfvars"

# Test connection
cd test
./setup_and_test.sh
```

## Public Access Requirements

- **Public subnets** with Internet Gateway routes
- **publicly_accessible** set to `true`
- Security group allows inbound traffic on broker ports

## Connection Details

```bash
terraform output console_url         # Web console URL
terraform output rabbitmq_endpoint   # AMQP endpoint (for RabbitMQ)
terraform output mq_username         # Username
terraform output -raw mq_password    # Password
```

## Supported Engines

### ActiveMQ (Default)

- **Engine**: ActiveMQ 5.18
- **Protocols**: OpenWire, AMQP, STOMP, MQTT, WSS
- **Console**: HTTPS (port 443)

### RabbitMQ

- **Engine**: RabbitMQ 3.13
- **Protocol**: AMQP 0-9-1 over TLS (port 5671)
- **Console**: HTTPS (port 443)

To use RabbitMQ, set `engine_type = "RabbitMQ"` and `engine_version = "3.13"` in your tfvars file.

## Test Scripts

The `test/` directory includes Python scripts for testing connectivity using the STOMP protocol:

```bash
cd test

# Setup environment and run connection test
./setup_and_test.sh

# Send a message (set environment variables first - uses STOMP port 61614)
export MQ_ENDPOINT=$(cd .. && terraform output -json activemq_endpoints | jq -r '.[] | select(startswith("stomp+ssl://"))' | head -1 | sed 's/stomp+ssl:/ssl:/')
export MQ_USERNAME=$(cd .. && terraform output -raw mq_username)
export MQ_PASSWORD=$(cd .. && terraform output -raw mq_password)

uv run python send_message.py openflow-queue 'Hello, World!'

# Receive a message (single)
uv run python receive_message.py openflow-queue

# Receive messages continuously
uv run python receive_message.py openflow-queue --continuous
```

## Using the ActiveMQ Web Console

1. Get the console URL:
   ```bash
   terraform output console_url
   ```

2. Open the URL in your browser

3. Login with credentials:
   ```bash
   terraform output mq_username
   terraform output -raw mq_password
   ```

4. From the console you can:
   - View queues and topics
   - Browse and send test messages
   - Monitor connections and subscribers

## OpenFlow / NiFi Integration

### Required JAR Files

To connect OpenFlow's JMS processors (`PublishJMS`, `ConsumeJMS`) to Amazon MQ ActiveMQ, you must upload the ActiveMQ client libraries. These JARs are **not bundled** with NiFi/OpenFlow by default because:

1. **Licensing** - ActiveMQ client libraries are distributed separately
2. **Version flexibility** - Allows matching the client version to your broker version
3. **Reduced footprint** - NiFi ships lean; you add only what you need

The following JAR files are included in this directory:

| JAR File | Purpose |
|----------|---------|
| `activemq-client-jakarta-5.18.7.jar` | ActiveMQ client for JMS connectivity |
| `jakarta.jms-api-3.1.0.jar` | Jakarta JMS API (required by ActiveMQ client) |
| `geronimo-j2ee-management_1.1_spec-1.0.1.jar` | J2EE management interfaces |
| `hawtbuf-1.11.jar` | High-performance buffer library for ActiveMQ |

## Configuration Options

| Variable | Default | Description |
|----------|---------|-------------|
| `engine_type` | `ActiveMQ` | Broker engine: `ActiveMQ` or `RabbitMQ` |
| `engine_version` | `5.18` | Engine version (5.18 for ActiveMQ, 3.13 for RabbitMQ) |
| `host_instance_type` | `mq.t3.micro` | Instance type |
| `deployment_mode` | `SINGLE_INSTANCE` | Deployment mode |
| `publicly_accessible` | `true` | Enable public access |
| `mq_username` | `mqadmin` | Admin username |
| `mq_password` | - | Admin password (required) |

## Cleanup

```bash
terraform destroy -var-file="examples/existing-vpc.tfvars"
```

## Troubleshooting

### Connection Timeout

If you can't connect to the broker:

1. Verify the broker is publicly accessible:
   ```bash
   terraform output -json | jq '.publicly_accessible'
   ```

2. Check security group allows your IP:
   ```bash
   aws ec2 describe-security-groups --group-ids $(terraform output -raw security_group_id)
   ```

3. Ensure you're using TLS (amqps://, not amqp://)

### Broker Still Creating

Amazon MQ brokers can take 10-15 minutes to create. Check status:

```bash
aws mq describe-broker --broker-id $(terraform output -raw broker_id) \
  --query 'BrokerState' --output text
```

Wait for `RUNNING` state before testing connectivity.

