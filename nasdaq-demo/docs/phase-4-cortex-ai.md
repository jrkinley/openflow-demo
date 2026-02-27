# Phase 4: Cortex AI

Build AI capabilities over the structured and unstructured data that landed in Snowflake during Phases 2 and 3.

By the end of this phase you will have:
- Parsed and chunked the earnings report PDFs
- A **Cortex Search** service for natural-language queries over earnings reports
- A **Cortex Analyst** semantic view for structured stock quote analysis

These components are combined into a Cortex Agent in [Phase 5](phase-5-cortex-agent.md).

## 4.1 Parse Earnings Report PDFs

Use `AI_PARSE_DOCUMENT` to extract text content from the PDF files in the Snowflake stage.

> **Cortex Code CLI**
>
> ```
> Check your skills for Cortex AI. In the NASDAQ_DEMO database, refresh
> the EARNINGS_REPORTS_STAGE, then create a table called
> EARNINGS_REPORTS_PARSED with columns relative_path (VARCHAR) and
> markdown (VARIANT). Insert into it by using AI_PARSE_DOCUMENT in
> LAYOUT mode on each file in the stage directory.
> ```

Manual SQL:

```sql
ALTER STAGE NASDAQ_DEMO.PUBLIC.EARNINGS_REPORTS_STAGE REFRESH;

CREATE OR REPLACE TABLE NASDAQ_DEMO.PUBLIC.EARNINGS_REPORTS_PARSED (
    relative_path VARCHAR,
    markdown VARIANT
);

INSERT INTO EARNINGS_REPORTS_PARSED (relative_path, markdown)
WITH staged_reports AS (
    SELECT relative_path
    FROM DIRECTORY(@EARNINGS_REPORTS_STAGE)
)
SELECT
    relative_path,
    AI_PARSE_DOCUMENT(
        TO_FILE('@EARNINGS_REPORTS_STAGE', relative_path),
        {'mode': 'LAYOUT'}
    ) AS markdown
FROM staged_reports;
```

**Checkpoint:**

```sql
SELECT relative_path, LEFT(markdown:content::STRING, 200) AS preview
FROM EARNINGS_REPORTS_PARSED
ORDER BY relative_path
LIMIT 5;
```

## 4.2 Chunk the Parsed Text

Split the extracted text into chunks for Cortex Search indexing.

> **Cortex Code CLI**
>
> ```
> Check your skills for Cortex AI. In the NASDAQ_DEMO database, create
> a table called EARNINGS_REPORTS_CHUNKS with columns relative_path
> (VARCHAR) and chunk (STRING). Populate it by using
> SNOWFLAKE.CORTEX.SPLIT_TEXT_RECURSIVE_CHARACTER on the content field
> from EARNINGS_REPORTS_PARSED, using markdown format with a chunk size
> of 2000 tokens, 100 token overlap, and paragraph separators.
> ```

Manual SQL:

```sql
CREATE OR REPLACE TABLE NASDAQ_DEMO.PUBLIC.EARNINGS_REPORTS_CHUNKS (
    relative_path VARCHAR,
    chunk STRING
);

INSERT INTO EARNINGS_REPORTS_CHUNKS (relative_path, chunk)
WITH report_chunks AS (
    SELECT
        relative_path,
        SNOWFLAKE.CORTEX.SPLIT_TEXT_RECURSIVE_CHARACTER(
            markdown:content::STRING,
            'markdown',
            2000,
            100,
            ['\n\n']
        ) AS chunks
    FROM EARNINGS_REPORTS_PARSED
)
SELECT
    relative_path,
    c.value AS chunk
FROM report_chunks,
LATERAL FLATTEN(INPUT => chunks) c;
```

**Checkpoint:**

```sql
SELECT relative_path, LEFT(chunk, 200) AS preview
FROM EARNINGS_REPORTS_CHUNKS
ORDER BY relative_path
LIMIT 5;
```

## 4.3 Create Cortex Search Service

Create a Cortex Search service over the chunked earnings report text.

> **Cortex Code CLI**
>
> ```
> Check your skills for Cortex Search. In the NASDAQ_DEMO database,
> create a Cortex Search service called EARNINGS_REPORTS_SEARCH on the
> chunk column of the EARNINGS_REPORTS_CHUNKS table, using the
> COMPUTE_WH warehouse and a target lag of 5 minutes.
> ```

Manual SQL:

```sql
CREATE OR REPLACE CORTEX SEARCH SERVICE NASDAQ_DEMO.PUBLIC.EARNINGS_REPORTS_SEARCH
ON chunk
WAREHOUSE = 'COMPUTE_WH'
TARGET_LAG = '5 minutes'
AS (
    SELECT relative_path, chunk
    FROM EARNINGS_REPORTS_CHUNKS
);
```

**Checkpoint:**

```sql
SELECT *
FROM TABLE(
    CORTEX_SEARCH_DATA_SCAN(
        SERVICE_NAME => 'EARNINGS_REPORTS_SEARCH'
    )
)
LIMIT 10;
```

## 4.4 Create Cortex Analyst Semantic View

Create a semantic view over the structured stock quote data so Cortex Analyst can answer natural-language questions about prices, volumes, and trends.

The semantic view definition is at [`snowflake/models/historical_quotes_semantic_view.sql`](../snowflake/models/historical_quotes_semantic_view.sql). It includes sample values and verified queries to improve Cortex Analyst accuracy.

> **Cortex Code CLI**
>
> ```
> Check your skills for Cortex Analyst. Read the semantic view SQL at
> nasdaq-demo/snowflake/models/historical_quotes_semantic_view.sql and
> create it in the NASDAQ_DEMO database. Then test it by asking:
> "What was the highest closing price for TSLA?"
> ```

Manual SQL:

```bash
cd nasdaq-demo
snow sql -f snowflake/models/historical_quotes_semantic_view.sql
```

**Checkpoint** -- test Cortex Analyst with a sample question:

```
What was the average daily trading volume for MSFT in the last quarter?
```

## Notebooks

Snowflake notebook versions of this phase are planned for a future update.
