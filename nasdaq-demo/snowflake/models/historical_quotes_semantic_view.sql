CREATE OR REPLACE SEMANTIC VIEW HISTORICAL_QUOTES_SEMANTIC_VIEW
    TABLES (
        NASDAQ_DEMO.PUBLIC.HISTORICAL_QUOTES_TYPED
            COMMENT = 'Historical stock quotes for NASDAQ symbols including date, closing price, trading volume, open, high, and low prices. All monetary values are in USD.'
    )
    FACTS (
        HISTORICAL_QUOTES_TYPED.CLOSE_LAST_USD AS CLOSE_LAST_USD
            COMMENT = 'The closing price of the stock in US dollars.',
        HISTORICAL_QUOTES_TYPED.HIGH_USD AS HIGH_USD
            COMMENT = 'The highest price of the stock in US dollars for the trading day.',
        HISTORICAL_QUOTES_TYPED.LOW_USD AS LOW_USD
            COMMENT = 'The lowest price of the stock in US dollars for the trading day.',
        HISTORICAL_QUOTES_TYPED.OPEN_USD AS OPEN_USD
            COMMENT = 'The opening price of the stock in US dollars.'
    )
    DIMENSIONS (
        HISTORICAL_QUOTES_TYPED.SYMBOL AS SYMBOL
            COMMENT = 'The stock ticker symbol (e.g. TSLA).',
        HISTORICAL_QUOTES_TYPED.VOLUME AS VOLUME
            COMMENT = 'The total number of shares traded on a given day.',
        HISTORICAL_QUOTES_TYPED.QUOTE_DATE AS QUOTE_DATE
            COMMENT = 'The date on which the stock quote was recorded.'
    )
    WITH EXTENSION (
        CA = '{
            "tables": [
                {
                    "name": "HISTORICAL_QUOTES_TYPED",
                    "dimensions": [
                        {"name": "SYMBOL", "sample_values": ["TSLA"]},
                        {"name": "VOLUME", "sample_values": ["27406500", "23024340", "18913700"]}
                    ],
                    "facts": [
                        {"name": "CLOSE_LAST_USD", "sample_values": ["510.05", "497.1", "509.9"]},
                        {"name": "HIGH_USD", "sample_values": ["420.69", "459.585", "524.66"]},
                        {"name": "LOW_USD", "sample_values": ["510.6791", "505.62", "456.89"]},
                        {"name": "OPEN_USD", "sample_values": ["537.18", "364.125", "418.25"]}
                    ],
                    "time_dimensions": [
                        {"name": "QUOTE_DATE", "sample_values": ["2025-11-04", "2025-02-25", "2025-01-31"]}
                    ]
                }
            ],
            "verified_queries": [
                {
                    "name": "Stock closing price on a specific date",
                    "question": "What was Tesla'\''s closing price on June 5, 2025?",
                    "sql": "SELECT SYMBOL, QUOTE_DATE, CLOSE_LAST_USD, VOLUME FROM HISTORICAL_QUOTES_TYPED WHERE SYMBOL = '\''TSLA'\'' AND QUOTE_DATE = '\''2025-06-05'\'';",
                    "use_as_onboarding_question": true,
                    "verified_by": "James Kinley",
                    "verified_at": 1764940996
                },
                {
                    "name": "Daily price range and volatility",
                    "question": "Show the daily high, low, and closing prices for TSLA over the past week.",
                    "sql": "SELECT QUOTE_DATE, OPEN_USD, HIGH_USD, LOW_USD, CLOSE_LAST_USD, (HIGH_USD - LOW_USD) AS DAILY_RANGE_USD, VOLUME FROM HISTORICAL_QUOTES_TYPED WHERE SYMBOL = '\''TSLA'\'' AND QUOTE_DATE >= DATEADD(DAY, -7, CURRENT_DATE()) ORDER BY QUOTE_DATE DESC;",
                    "use_as_onboarding_question": false,
                    "verified_by": "James Kinley",
                    "verified_at": 1764940996
                },
                {
                    "name": "Monthly average closing price trend",
                    "question": "What is the monthly average closing price for TSLA over the past 6 months?",
                    "sql": "SELECT DATE_TRUNC('\''MONTH'\'', QUOTE_DATE) AS MONTH, ROUND(AVG(CLOSE_LAST_USD), 2) AS AVG_CLOSE_USD, ROUND(AVG(VOLUME), 0) AS AVG_DAILY_VOLUME, COUNT(*) AS TRADING_DAYS FROM HISTORICAL_QUOTES_TYPED WHERE SYMBOL = '\''TSLA'\'' AND QUOTE_DATE >= DATEADD(MONTH, -6, CURRENT_DATE()) GROUP BY MONTH ORDER BY MONTH DESC;",
                    "use_as_onboarding_question": true,
                    "verified_by": "James Kinley",
                    "verified_at": 1764940996
                },
                {
                    "name": "Highest volume trading days",
                    "question": "What were the top 10 highest volume trading days for TSLA and how did the price move on those days?",
                    "sql": "SELECT QUOTE_DATE, VOLUME, OPEN_USD, CLOSE_LAST_USD, ROUND(CLOSE_LAST_USD - OPEN_USD, 2) AS INTRADAY_CHANGE_USD, ROUND(((CLOSE_LAST_USD - OPEN_USD) / OPEN_USD) * 100, 2) AS INTRADAY_CHANGE_PCT FROM HISTORICAL_QUOTES_TYPED WHERE SYMBOL = '\''TSLA'\'' ORDER BY VOLUME DESC LIMIT 10;",
                    "use_as_onboarding_question": false,
                    "verified_by": "James Kinley",
                    "verified_at": 1764940996
                },
                {
                    "name": "Quarterly performance comparison",
                    "question": "Compare TSLA'\''s quarterly performance over the past year showing average price, total volume, and price change from start to end of each quarter.",
                    "sql": "WITH daily AS (SELECT DATE_TRUNC('\''QUARTER'\'', QUOTE_DATE) AS QUARTER, QUOTE_DATE, CLOSE_LAST_USD, VOLUME FROM HISTORICAL_QUOTES_TYPED WHERE SYMBOL = '\''TSLA'\'' AND QUOTE_DATE >= DATEADD(YEAR, -1, CURRENT_DATE())), quarterly_agg AS (SELECT QUARTER, ROUND(AVG(CLOSE_LAST_USD), 2) AS AVG_CLOSE_USD, MIN(CLOSE_LAST_USD) AS MIN_CLOSE_USD, MAX(CLOSE_LAST_USD) AS MAX_CLOSE_USD, SUM(VOLUME) AS TOTAL_VOLUME FROM daily GROUP BY QUARTER), quarterly_endpoints AS (SELECT DISTINCT QUARTER, FIRST_VALUE(CLOSE_LAST_USD) OVER (PARTITION BY QUARTER ORDER BY QUOTE_DATE) AS QUARTER_OPEN, LAST_VALUE(CLOSE_LAST_USD) OVER (PARTITION BY QUARTER ORDER BY QUOTE_DATE ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS QUARTER_CLOSE FROM daily) SELECT a.QUARTER, a.AVG_CLOSE_USD, a.MIN_CLOSE_USD, a.MAX_CLOSE_USD, a.TOTAL_VOLUME, e.QUARTER_OPEN, e.QUARTER_CLOSE, ROUND(((e.QUARTER_CLOSE - e.QUARTER_OPEN) / e.QUARTER_OPEN) * 100, 2) AS QUARTER_RETURN_PCT FROM quarterly_agg a JOIN quarterly_endpoints e ON a.QUARTER = e.QUARTER ORDER BY a.QUARTER DESC;",
                    "use_as_onboarding_question": false,
                    "verified_by": "James Kinley",
                    "verified_at": 1764940996
                }
            ]
        }'
    );
