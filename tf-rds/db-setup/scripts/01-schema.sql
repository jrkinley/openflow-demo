-- PostgreSQL Schema Setup for Openflow CDC Demo
-- This script creates stock market data tables for demonstrating Change Data Capture

\echo 'Creating demo schema and tables...'

-- Create a demo schema (optional, but good practice)
CREATE SCHEMA IF NOT EXISTS nasdaq;

-- Set search path to include our demo schema
SET search_path TO nasdaq, public;

-- Create a stock quotes table for historical market data
CREATE TABLE IF NOT EXISTS stock_quotes (
    id SERIAL PRIMARY KEY,
    symbol VARCHAR(10) NOT NULL,
    quote_date DATE NOT NULL,
    close_price DECIMAL(10,4) NOT NULL,
    volume BIGINT NOT NULL,
    open_price DECIMAL(10,4) NOT NULL,
    high_price DECIMAL(10,4) NOT NULL,
    low_price DECIMAL(10,4) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(symbol, quote_date)
);

-- Create indexes for stock quotes table
CREATE INDEX IF NOT EXISTS idx_stock_quotes_symbol ON stock_quotes(symbol);
CREATE INDEX IF NOT EXISTS idx_stock_quotes_date ON stock_quotes(quote_date);
CREATE INDEX IF NOT EXISTS idx_stock_quotes_symbol_date ON stock_quotes(symbol, quote_date);

-- Set REPLICA IDENTITY to DEFAULT for CDC (ensures primary keys are in WAL)
ALTER TABLE stock_quotes REPLICA IDENTITY DEFAULT;

-- Create publication for Openflow CDC connector
CREATE PUBLICATION openflow;

-- Add the stock_quotes table to the publication
ALTER PUBLICATION openflow ADD TABLE stock_quotes;

\echo 'Schema setup completed successfully!'
\echo 'Publication "openflow" created for CDC with stock_quotes table'
