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
            COMMENT = 'The stock ticker symbol (e.g. MSFT, TSLA).',
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
                        {"name": "SYMBOL", "sample_values": ["MSFT", "TSLA"]},
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
                    "name": "Quote counts and price ranges by symbol",
                    "question": "How many historical quotes for each Nasdaq stock symbol, and what are their minimum and maximum prices in USD?",
                    "sql": "SELECT SYMBOL, COUNT(QUOTE_DATE) AS num_quotes, MAX(VOLUME), MIN(CLOSE_LAST_USD), MAX(CLOSE_LAST_USD), MAX(QUOTE_DATE) FROM HISTORICAL_QUOTES_TYPED GROUP BY SYMBOL ORDER BY SYMBOL;",
                    "use_as_onboarding_question": false,
                    "verified_by": "James Kinley",
                    "verified_at": 1764940835
                },
                {
                    "name": "Tesla stock price on a specific date",
                    "question": "What was Tesla'\''s stock price on June 05, 2025?",
                    "sql": "SELECT SYMBOL, QUOTE_DATE, CLOSE_LAST_USD FROM HISTORICAL_QUOTES_TYPED WHERE SYMBOL = '\''TSLA'\'' AND QUOTE_DATE = '\''2025-06-05'\'';",
                    "use_as_onboarding_question": false,
                    "verified_by": "James Kinley",
                    "verified_at": 1764940996
                }
            ]
        }'
    );
