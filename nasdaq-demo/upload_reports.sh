#!/bin/bash

# Upload earnings report PDFs to the AWS Transfer Family SFTP server.
# Defaults to uploading all reports from data/reports/ but accepts an
# optional directory argument.
#
# Usage:
#   ./upload_reports.sh                  # upload all reports
#   ./upload_reports.sh data/reports/TSLA # upload TSLA reports only

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform/sftp"
SOURCE_DIR="${1:-$SCRIPT_DIR/data/reports}"

if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: Directory '$SOURCE_DIR' does not exist"
    exit 1
fi

if [ ! -f "$TERRAFORM_DIR/aws_sftp_key" ]; then
    echo "Error: SSH key not found at $TERRAFORM_DIR/aws_sftp_key"
    echo "See terraform/sftp/README.md for setup instructions"
    exit 1
fi

SERVER_ENDPOINT=$(cd "$TERRAFORM_DIR" && terraform output -raw server_endpoint)

echo "Uploading reports from $SOURCE_DIR to $SERVER_ENDPOINT"

# Upload each subdirectory (MSFT, TSLA) preserving folder structure
for dir in "$SOURCE_DIR"/*/; do
    if [ -d "$dir" ]; then
        FOLDER_NAME=$(basename "$dir")
        echo "  Uploading $FOLDER_NAME reports..."
        sftp -i "$TERRAFORM_DIR/aws_sftp_key" openflow-user@"$SERVER_ENDPOINT" <<EOF
-mkdir $FOLDER_NAME
cd $FOLDER_NAME
put $dir*
bye
EOF
    fi
done

# Also upload any files directly in the source directory
FILES=$(find "$SOURCE_DIR" -maxdepth 1 -type f -name "*.pdf" 2>/dev/null)
if [ -n "$FILES" ]; then
    echo "  Uploading top-level reports..."
    sftp -i "$TERRAFORM_DIR/aws_sftp_key" openflow-user@"$SERVER_ENDPOINT" <<EOF
put $SOURCE_DIR/*.pdf
bye
EOF
fi

echo "Upload complete"
