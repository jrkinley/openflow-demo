provider "aws" {
  region = var.region
}

# Get local username for owner tag
data "external" "local_user" {
  program = ["sh", "-c", "echo '{\"username\":\"'$(id -un)'\"}'"]
}

# Local values for common tags
locals {
  common_tags = {
    owner = var.owner != null ? var.owner : data.external.local_user.result.username
  }
}

# IAM role for AWS Transfer Family to access S3
resource "aws_iam_role" "transfer_role" {
  name = "${var.name}-transfer-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "transfer.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${var.name}-transfer-role"
  })
}

# IAM policy for S3 access
resource "aws_iam_role_policy" "transfer_s3_policy" {
  name = "${var.name}-transfer-s3-policy"
  role = aws_iam_role.transfer_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowListingOfUserFolder"
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = "arn:aws:s3:::*"
      },
      {
        Sid    = "HomeDirObjectAccess"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:GetObjectVersion"
        ]
        Resource = "arn:aws:s3:::*/*"
      }
    ]
  })
}

# AWS Transfer Family SFTP Server
# Note: CloudWatch logging is disabled to minimize costs
resource "aws_transfer_server" "sftp" {
  identity_provider_type = "SERVICE_MANAGED"
  endpoint_type          = "PUBLIC"
  protocols              = ["SFTP"]
  domain                 = "S3"

  tags = merge(local.common_tags, {
    Name = var.name
  })
}

