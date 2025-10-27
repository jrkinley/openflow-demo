#!/bin/bash

# Script to upload files from a directory to AWS Transfer Family SFTP server
# Usage: ./upload_files.sh <path_to_directory>

set -e

if [ $# -eq 0 ]; then
    echo "Error: No directory path provided"
    echo "Usage: $0 <path_to_directory>"
    exit 1
fi

SOURCE_DIR="$1"

if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: Directory '$SOURCE_DIR' does not exist"
    exit 1
fi

FOLDER_NAME=$(basename "$SOURCE_DIR")
SERVER_ENDPOINT=$(terraform output -raw server_endpoint)

echo "Uploading files from $SOURCE_DIR to $SERVER_ENDPOINT/$FOLDER_NAME"

sftp -i aws_sftp_key openflow-user@"$SERVER_ENDPOINT" <<EOF
-mkdir $FOLDER_NAME
cd $FOLDER_NAME
put $SOURCE_DIR/*
bye
EOF

echo "Upload complete"

