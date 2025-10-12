#!/usr/bin/env python3
"""
Setup Kafka ACLs for SASL/SCRAM user
Uses Confluent Kafka Python client to configure ACLs
"""

import os
import sys
import json
import subprocess
from confluent_kafka.admin import AdminClient, AclBinding, AclBindingFilter
from confluent_kafka import KafkaException

def run_command(cmd):
    """Run shell command and return output"""
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, check=True)
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        print(f"❌ Command failed: {cmd}")
        print(f"   Error: {e.stderr}")
        sys.exit(1)

def get_cluster_info():
    """Get cluster ARN and connection details from AWS"""
    print("🔍 Getting MSK configuration from AWS...")
    
    # Get cluster ARN from Terraform
    cluster_arn = run_command("terraform output -raw msk_cluster_arn 2>/dev/null")
    if not cluster_arn:
        print("❌ Could not get cluster ARN from Terraform")
        sys.exit(1)
    
    # Get bootstrap brokers from AWS
    bootstrap_response = run_command(f"aws kafka get-bootstrap-brokers --cluster-arn '{cluster_arn}'")
    bootstrap_data = json.loads(bootstrap_response)
    bootstrap_servers = (
        bootstrap_data.get('BootstrapBrokerStringPublicSaslScram') or 
        bootstrap_data.get('BootstrapBrokerStringSaslScram')
    )
    
    if not bootstrap_servers:
        print("❌ Could not get bootstrap brokers from AWS")
        sys.exit(1)
    
    # Get secret ARN and credentials
    secret_arns = run_command(f"aws kafka list-scram-secrets --cluster-arn '{cluster_arn}' --query 'SecretArnList[]' --output text")
    if not secret_arns:
        print("❌ No SASL/SCRAM secrets associated with cluster")
        sys.exit(1)
    
    secret_arn = secret_arns.split()[0]  # Use first secret
    secret_value = run_command(f"aws secretsmanager get-secret-value --secret-id '{secret_arn}' --query 'SecretString' --output text")
    secret_data = json.loads(secret_value)
    
    return {
        'bootstrap_servers': bootstrap_servers,
        'username': secret_data['username'],
        'password': secret_data['password']
    }

def create_admin_client(config):
    """Create Kafka admin client"""
    admin_config = {
        'bootstrap.servers': config['bootstrap_servers'],
        'security.protocol': 'SASL_SSL',
        'sasl.mechanisms': 'SCRAM-SHA-512',
        'sasl.username': config['username'],
        'sasl.password': config['password'],
    }
    
    return AdminClient(admin_config)

def setup_acls(admin_client, username):
    """Setup ACLs for the SASL/SCRAM user"""
    print(f"🔧 Setting up ACLs for user: {username}")
    
    from confluent_kafka.admin import ResourceType, ResourcePatternType, AclOperation, AclPermissionType
    
    # Define ACL bindings - focus on essential permissions for basic operations
    acl_bindings = [
        # Topic permissions - allow all operations on all topics
        AclBinding(
            restype=ResourceType.TOPIC,
            name='*',
            resource_pattern_type=ResourcePatternType.LITERAL,
            principal=f'User:{username}',
            host='*',
            operation=AclOperation.ALL,
            permission_type=AclPermissionType.ALLOW
        ),
        # Consumer group permissions - allow all operations on all groups
        AclBinding(
            restype=ResourceType.GROUP,
            name='*',
            resource_pattern_type=ResourcePatternType.LITERAL,
            principal=f'User:{username}',
            host='*',
            operation=AclOperation.ALL,
            permission_type=AclPermissionType.ALLOW
        )
    ]
    
    try:
        print("  📝 Granting topic permissions...")
        print("  👥 Granting consumer group permissions...")
        
        # Create ACLs
        result = admin_client.create_acls(acl_bindings)
        
        # Wait for completion
        for acl, future in result.items():
            try:
                future.result(timeout=10)
            except KafkaException as e:
                if "already exists" in str(e).lower():
                    continue  # ACL already exists, that's fine
                else:
                    print(f"❌ Failed to create ACL: {e}")
                    sys.exit(1)
        
        print("✅ ACLs configured successfully!")
        
    except Exception as e:
        print(f"❌ Failed to setup ACLs: {e}")
        sys.exit(1)

def main():
    """Main function"""
    print("🔐 Setting up Kafka ACLs...")
    
    # Check prerequisites
    try:
        run_command("which aws")
        run_command("which jq")
    except:
        print("❌ Required tools not found. Please install: aws-cli, jq")
        sys.exit(1)
    
    # Get cluster configuration
    config = get_cluster_info()
    
    print(f"✅ Using bootstrap servers: {config['bootstrap_servers']}")
    print(f"✅ Using username: {config['username']}")
    
    # Create admin client
    admin_client = create_admin_client(config)
    
    # Setup ACLs
    setup_acls(admin_client, config['username'])
    
    print("")
    print("🧪 You can now run: ./setup_and_test.sh")

if __name__ == "__main__":
    main()
