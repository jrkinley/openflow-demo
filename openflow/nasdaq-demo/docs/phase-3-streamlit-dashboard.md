# Phase 3: Streamlit Dashboard

Deploy a Streamlit-in-Snowflake app to visualise the structured stock quote data that landed in Phase 2. This gives you an interactive way to explore price trends, volume spikes, and unusual trading activity before building the AI capabilities in later phases.

## 3.1 Create the Typed Table

The raw data from Phase 2 needs to be cleaned and typed into a consistent format that all downstream phases depend on. The source table differs depending on the path you followed:

- **Phase 2A (Kafka)**: `NASDAQ_DEMO.PUBLIC.HISTORICAL_STOCK_QUOTES` -- raw string columns with `$` prefixes on prices
- **Phase 2B (PostgreSQL CDC)**: `NASDAQ_DEMO.NASDAQ.HISTORICAL_STOCK_QUOTES` -- already typed from PostgreSQL

> **Cortex Code CLI**
>
> ```
> In the NASDAQ_DEMO database, check which HISTORICAL_STOCK_QUOTES
> table exists: NASDAQ_DEMO.PUBLIC, NASDAQ_DEMO.NASDAQ, or both.
> If both exist, favour the CDC path (NASDAQ schema).
>
> If using the NASDAQ schema (CDC path), the data is already typed.
> Create a view called NASDAQ_DEMO.PUBLIC.HISTORICAL_QUOTES_TYPED
> that selects from NASDAQ_DEMO.NASDAQ.HISTORICAL_STOCK_QUOTES and
> maps the columns to the same output names: SYMBOL, QUOTE_DATE,
> CLOSE_LAST_USD, VOLUME, OPEN_USD, HIGH_USD, LOW_USD.
>
> If using the PUBLIC schema (Kafka path), create a view called
> NASDAQ_DEMO.PUBLIC.HISTORICAL_QUOTES_TYPED that converts
> the DATE column to DATE, strips the $ prefix from the price
> columns (CLOSE_LAST, OPEN, HIGH, LOW) and casts them to DOUBLE,
> and keeps SYMBOL and VOLUME as-is.
> ```

Manual SQL for the **Kafka path**:

```sql
CREATE OR REPLACE VIEW NASDAQ_DEMO.PUBLIC.HISTORICAL_QUOTES_TYPED AS
    SELECT
        SYMBOL,
        TO_DATE(DATE) AS QUOTE_DATE,
        TO_DOUBLE(LTRIM(CLOSE_LAST, '$')) AS CLOSE_LAST_USD,
        VOLUME,
        TO_DOUBLE(LTRIM(OPEN, '$')) AS OPEN_USD,
        TO_DOUBLE(LTRIM(HIGH, '$')) AS HIGH_USD,
        TO_DOUBLE(LTRIM(LOW, '$')) AS LOW_USD
    FROM NASDAQ_DEMO.PUBLIC.HISTORICAL_STOCK_QUOTES;
```

Manual SQL for the **CDC path**:

```sql
CREATE OR REPLACE VIEW NASDAQ_DEMO.PUBLIC.HISTORICAL_QUOTES_TYPED AS
    SELECT
        SYMBOL,
        QUOTE_DATE,
        CLOSE_PRICE AS CLOSE_LAST_USD,
        VOLUME,
        OPEN_PRICE AS OPEN_USD,
        HIGH_PRICE AS HIGH_USD,
        LOW_PRICE AS LOW_USD
    FROM NASDAQ_DEMO.NASDAQ.HISTORICAL_STOCK_QUOTES;
```

**Checkpoint** -- verify the typed data:

```sql
SELECT
    SYMBOL,
    COUNT(QUOTE_DATE) AS NUM_QUOTES,
    MIN(QUOTE_DATE) AS EARLIEST,
    MAX(QUOTE_DATE) AS LATEST,
    MAX(CLOSE_LAST_USD) AS MAX_CLOSE
FROM NASDAQ_DEMO.PUBLIC.HISTORICAL_QUOTES_TYPED
GROUP BY SYMBOL
ORDER BY SYMBOL;
```

## 3.2 Deploy the Streamlit App

> **Cortex Code CLI**
>
> ```
> Read the Streamlit app at nasdaq-demo/snowflake/streamlit_app.py.
> If a Streamlit app called NASDAQ_FINANCIAL_DASHBOARD already exists
> in the NASDAQ_DEMO database, drop it first. Then deploy the app as
> a Streamlit-in-Snowflake app in the NASDAQ_DEMO database. It
> queries the HISTORICAL_QUOTES_TYPED view created in the previous
> step.
> ```

Alternatively, create the app manually in Snowsight:

1. In Snowsight, navigate to **Projects** -> **Streamlit**
2. Click **+ Streamlit App**
3. Set the database to `NASDAQ_DEMO` and schema to `PUBLIC`
4. Paste the contents of `snowflake/streamlit_app.py` into the editor

## 3.3 Explore the Data

Open the dashboard and start exploring:

- Pick a stock (e.g. TSLA) and scan the price history
- Look for interesting days -- big price swings, volume spikes, or unusual activity
- Note any dates that stand out -- you'll come back to these in later phases when you can ask the Cortex Agent what happened

This visual exploration sets the context for the AI phases that follow.
