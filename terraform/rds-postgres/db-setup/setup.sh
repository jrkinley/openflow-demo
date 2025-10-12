#!/bin/bash
set -e

# Openflow PostgreSQL CDC Demo - Database Setup Script (Native psql)
# This script sets up the demo database schema and data using local psql

echo "🚀 Setting up Openflow CDC Demo Database..."

# Check if psql is installed
if ! command -v psql &> /dev/null; then
    echo "❌ Error: psql is not installed"
    echo "   Please install PostgreSQL client tools"
    exit 1
fi

# Get RDS connection details from Terraform output
echo "📡 Getting RDS connection details from Terraform..."
cd ..
RDS_HOST=$(terraform output -raw rds_hostname 2>/dev/null)
RDS_USERNAME=$(terraform output -raw rds_username 2>/dev/null)

if [[ -z "$RDS_HOST" ]]; then
    echo "❌ Error: Could not get RDS hostname from Terraform output"
    echo "   Make sure you've run 'terraform apply' successfully"
    exit 1
fi

if [[ -z "$RDS_USERNAME" ]]; then
    echo "❌ Error: Could not get RDS username from Terraform output"
    echo "   Make sure you've run 'terraform apply' successfully"
    exit 1
fi

# Check if password is set
if [[ -z "$TF_VAR_db_password" ]]; then
    echo "❌ Error: Database password not set"
    echo "   Please set: export TF_VAR_db_password='your-password'"
    exit 1
fi

echo "🔗 Connecting to PostgreSQL at: $RDS_HOST"
echo "👤 Using username: $RDS_USERNAME"

# Set PostgreSQL environment variables
export PGHOST="$RDS_HOST"
export PGUSER="$RDS_USERNAME"
export PGPASSWORD="$TF_VAR_db_password"
export PGDATABASE="postgres"

# Run the database setup
echo "📋 Creating schema and tables..."
psql -f db-setup/scripts/01-schema.sql

echo "📊 Loading demo data..."
# Pass SNOW as the stock symbol parameter
psql -f db-setup/scripts/02-seed-data.sql

echo ""
echo "🎉 Demo database setup complete!"
echo "🔗 Connection details:"
echo "   Host: $RDS_HOST"
echo "   Database: postgres"
echo "   Schema: nasdaq"
echo "   Table: stock_quotes"
echo ""
echo "💡 Next steps:"
echo "   1. Connect with: psql -h $RDS_HOST -U $RDS_USERNAME -d postgres"
echo "   2. View data: SELECT * FROM nasdaq.stock_quotes ORDER BY quote_date DESC LIMIT 10;"
echo "   3. Test CDC: UPDATE nasdaq.stock_quotes SET close_price=230.00 WHERE symbol='SNOW' AND quote_date='2025-09-10';"
