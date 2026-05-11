# Phase 6: Cortex Agent

Create a Cortex Agent that combines the structured stock quote data (via Cortex Analyst) with the unstructured earnings reports (via Cortex Search) into a single conversational interface.

This is the payoff of the workshop -- a natural-language agent that can answer questions spanning both quantitative market data and qualitative financial narratives.

## 6.1 Create the Agent

The agent definition is at [`snowflake/models/nasdaq_agent.sql`](../snowflake/models/nasdaq_agent.sql). It configures two tools:

- **StockQuoteAnalyst** -- Cortex Analyst over the `HISTORICAL_QUOTES_SEMANTIC_VIEW` for structured price/volume queries
- **EarningsReportSearch** -- Cortex Search over the `EARNINGS_REPORTS_SEARCH` service for earnings report content

> **Cortex Code CLI**
>
> ```
> Check your skills for Cortex. Read the agent SQL at
> nasdaq-demo/snowflake/models/nasdaq_agent.sql and create the
> NASDAQ_AGENT in the NASDAQ_DEMO database.
> ```

Manual SQL:

```bash
cd nasdaq-demo
snow sql -f snowflake/models/nasdaq_agent.sql
```

## 6.2 Test the Agent

Copy and paste these questions into the agent UI in Snowsight to test the blended intelligence across both structured and unstructured data:

```
Tesla's stock dropped significantly in early 2025. Is there anything in the
earnings reports that explains this movement?
```

```
How did Tesla's stock price react around the time they reported record
vehicle deliveries? What did the earnings report say about revenue growth?
```

> **Cortex Code CLI**
>
> ```
> Run the NASDAQ_AGENT in the NASDAQ_DEMO database using
> SNOWFLAKE.CORTEX.DATA_AGENT_RUN and ask: "What was the closing
> stock price for TSLA on the day they reported Q3 2024 earnings,
> and what were the key takeaways from that report?"
> Parse the response with TRY_PARSE_JSON and show the text content.
> ```
