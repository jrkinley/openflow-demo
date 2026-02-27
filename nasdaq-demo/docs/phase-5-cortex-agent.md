# Phase 5: Cortex Agent

Create a Cortex Agent that combines the structured stock quote data (via Cortex Analyst) with the unstructured earnings reports (via Cortex Search) into a single conversational interface.

This is the payoff of the workshop -- a natural-language agent that can answer questions spanning both quantitative market data and qualitative financial narratives.

## 5.1 Create the Agent

The agent definition is at [`snowflake/models/nasdaq_agent.sql`](../snowflake/models/nasdaq_agent.sql). It configures two tools:

- **StockQuoteAnalyst** -- Cortex Analyst over the `HISTORICAL_QUOTES_SEMANTIC_VIEW` for structured price/volume queries
- **EarningsReportSearch** -- Cortex Search over the `EARNINGS_REPORTS_SEARCH` service for earnings report content

> **Cortex Code CLI**
>
> ```
> Check your skills for Cortex Agents. Read the agent SQL at
> nasdaq-demo/snowflake/models/nasdaq_agent.sql and create the
> NASDAQ_AGENT in the NASDAQ_DEMO database.
> ```

Manual SQL:

```bash
cd nasdaq-demo
snow sql -f snowflake/models/nasdaq_agent.sql
```

**Checkpoint** -- verify the agent was created:

```bash
snow sql -q "SHOW AGENTS IN NASDAQ_DEMO.PUBLIC;" --format json
```

## 5.2 Test the Agent

Try some questions that exercise both tools:

**Structured data (Analyst):**

```
What was Tesla's highest closing price in 2025?
```

```
Compare the average daily trading volume for MSFT and TSLA over the last 6 months.
```

**Unstructured data (Search):**

```
What were the key highlights from Tesla's Q3 2024 earnings report?
```

```
What did Microsoft report about cloud revenue growth in their most recent quarter?
```

**Combined (both tools):**

```
Tesla's stock dropped significantly in early 2025. Is there anything in the
earnings reports that explains this movement?
```

```
How did Microsoft's stock price react around the time they reported record
cloud revenue? What did the earnings report say about Azure growth?
```

> **Cortex Code CLI**
>
> ```
> Run the NASDAQ_AGENT in the NASDAQ_DEMO database and ask: "What was
> Tesla's closing stock price on the day they reported Q3 2024 earnings,
> and what were the key takeaways from that report?"
> ```
