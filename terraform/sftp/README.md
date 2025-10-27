# AWS Transfer Family SFTP Server

Minimal Terraform configuration for an AWS Transfer Family SFTP server for demonstration purposes.

## Features

- SFTP protocol only, service-managed identity provider
- Publicly accessible IPv4 endpoint with Amazon S3 backend
- CloudWatch logging disabled to minimize costs
- Tagged consistently with `terraform/msk` resources

## Usage

```bash
terraform init
terraform apply
```

Get the server endpoint:
```bash
terraform output server_endpoint
```

## Adding Users

1. Create an S3 bucket and generate SSH keys:
   ```bash
   aws s3 mb s3://openflow-sftp-bucket
   ssh-keygen -t rsa -b 4096 -f aws_sftp_key
   ```

2. Create a user:
   ```bash
   aws transfer create-user \
     --server-id $(terraform output -raw server_id) \
     --user-name openflow-user \
     --role $(terraform output -raw transfer_role_arn) \
     --home-directory-type PATH \
     --home-directory /openflow-sftp-bucket/openflow-user \
     --ssh-public-key-body "$(cat aws_sftp_key.pub)"
   ```

## Using the SFTP Server

### Single File Operations

```bash
# Upload the test file without interactive session
echo "put test.txt" | sftp -i aws_sftp_key openflow-user@$(terraform output -raw server_endpoint)

# Download the test file without interactive session
echo "get test.txt" | sftp -i aws_sftp_key openflow-user@$(terraform output -raw server_endpoint)

# Delete the test file without interactive session
echo "rm test.txt" | sftp -i aws_sftp_key openflow-user@$(terraform output -raw server_endpoint)
```

### Bulk Upload Script

Use the `upload_files.sh` script to upload all files from a directory:

```bash
# Upload all files from a directory
./upload_files.sh /path/to/directory

# Example: Upload historical data files
./upload_files.sh ../historical-quotes/data
```

The script will:
- Validate the directory exists and contains files
- Check for required Terraform outputs and SSH keys
- Upload each file individually to the SFTP server
- Display progress and summary statistics

## Cleanup

Before destroying the Terraform resources, remove the manually created user and S3 bucket:

```bash
# Delete the SFTP user
aws transfer delete-user \
  --server-id $(terraform output -raw server_id) \
  --user-name openflow-user

# Empty and delete the S3 bucket
aws s3 rm s3://openflow-sftp-bucket --recursive
aws s3 rb s3://openflow-sftp-bucket

# Delete local SSH keys (optional)
rm -f aws_sftp_key aws_sftp_key.pub

# Destroy Terraform resources
terraform destroy
```

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `region` | `eu-west-2` | AWS region |
| `name` | `openflow-sftp-demo` | Resource name prefix |
| `owner` | local username | Owner tag |

## Cost Warning

AWS Transfer Family costs approximately **$0.30/hour (~$216/month)** even when idle, plus data transfer and S3 storage costs.

**Destroy when not in use:**
```bash
terraform destroy
```

