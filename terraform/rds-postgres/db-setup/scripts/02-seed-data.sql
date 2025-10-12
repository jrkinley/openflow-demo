-- Sample Data for Nasdaq CDC Demo
-- This script bulk loads stock market data from CSV
-- Usage: psql -f 02-seed-data.sql

-- Set search path to include our demo schema
SET search_path TO nasdaq, public;

-- Create a temporary table to load CSV data
CREATE TEMP TABLE temp_snow_data (
    date_str TEXT,
    close_last TEXT,
    volume TEXT,
    open_price TEXT,
    high_price TEXT,
    low_price TEXT
);

-- Load CSV data using \copy command
\set symbol 'SNOW'
\copy temp_snow_data FROM 'db-setup/scripts/HistoricalData_SNOW.csv' WITH (FORMAT csv, HEADER true);

-- \set symbol 'AAPL'
-- \copy temp_snow_data FROM 'db-setup/scripts/HistoricalData_AAPL.csv' WITH (FORMAT csv, HEADER true);

-- Function to clean price data (remove $ and convert to decimal)
CREATE OR REPLACE FUNCTION clean_price(price_text TEXT) 
RETURNS DECIMAL(10,4) AS $$
BEGIN
    RETURN REPLACE(price_text, '$', '')::DECIMAL(10,4);
END;
$$ LANGUAGE plpgsql;

-- Function to parse date (MM/DD/YYYY format)
CREATE OR REPLACE FUNCTION parse_date(date_text TEXT) 
RETURNS DATE AS $$
BEGIN
    RETURN TO_DATE(date_text, 'MM/DD/YYYY');
END;
$$ LANGUAGE plpgsql;

-- Insert all CSV data into stock_quotes table
INSERT INTO stock_quotes (symbol, quote_date, close_price, volume, open_price, high_price, low_price)
SELECT 
    :'symbol' as symbol,
    parse_date(date_str) as quote_date,
    clean_price(close_last) as close_price,
    volume::BIGINT as volume,
    clean_price(open_price) as open_price,
    clean_price(high_price) as high_price,
    clean_price(low_price) as low_price
FROM temp_snow_data
WHERE date_str IS NOT NULL 
  AND date_str != ''
ON CONFLICT (symbol, quote_date) DO NOTHING;

-- Clean up helper functions
DROP FUNCTION IF EXISTS clean_price(TEXT);
DROP FUNCTION IF EXISTS parse_date(TEXT);

-- Show stock quotes statistics
\echo ''
\echo 'Stock quotes statistics:'
SELECT 
    symbol,
    COUNT(*) as total_quotes,
    MIN(quote_date) as earliest_date,
    MAX(quote_date) as latest_date,
    MIN(close_price) as min_price,
    MAX(close_price) as max_price,
    AVG(close_price)::DECIMAL(10,2) as avg_price
FROM stock_quotes 
GROUP BY symbol;
