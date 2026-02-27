# Phase 6: Snowflake Intelligence

Surface the NASDAQ Agent through Snowflake Intelligence to provide a natural-language interface for exploring stock movements and earnings report insights.

This is the cherry on top -- everything built in the previous phases comes together here.

## 6.1 Open Snowflake Intelligence

1. In Snowsight, navigate to **AI & ML** -> **Snowflake Intelligence**
2. Select the **NASDAQ_AGENT** created in Phase 5

The agent is now available as a conversational interface backed by both the structured stock data and the unstructured earnings reports.

## 6.2 Explore the Data

A good workflow is to start with the Streamlit dashboard to spot interesting patterns, then switch to Snowflake Intelligence to dig deeper.

**Start with the Streamlit app** (`snowflake/streamlit_app.py`) to visually explore stock price trends. Look for interesting days -- big price swings, volume spikes, or divergences between MSFT and TSLA.

**Then ask Snowflake Intelligence about what you see:**

> What happened to Tesla's stock price on [interesting date]? Was there an earnings announcement around that time?

> Microsoft's stock dropped 5% in [month]. Is there anything in the earnings reports that would explain a negative movement?

> Compare Tesla and Microsoft's stock performance in Q2 2025. Which company had stronger earnings results that quarter?

> What was the trading volume for TSLA on the day they released Q1 2025 earnings? What were the key takeaways from that report?

## 6.3 Suggested Workshop Flow

1. Open the Streamlit dashboard and pick a stock (e.g. TSLA)
2. Identify an interesting date with unusual price or volume activity
3. Switch to Snowflake Intelligence and ask about that date
4. Ask a follow-up that combines both data sources
5. Let the workshop participants try their own questions

This interactive exploration demonstrates how Openflow brings external data into Snowflake where Cortex AI can make it accessible through natural language.
