CREATE OR REPLACE AGENT NASDAQ_DEMO.PUBLIC.NASDAQ_AGENT
    COMMENT = 'Financial services agent combining structured stock quote analysis with unstructured earnings report search.'
    PROFILE = '{"display_name": "NASDAQ Financial Analyst", "color": "blue"}'
    FROM SPECIFICATION
    $$
    orchestration:
        budget:
            seconds: 60
            tokens: 16000

    instructions:
        response: >
            You are a financial analyst assistant with access to NASDAQ historical
            stock quote data and quarterly earnings reports for Microsoft (MSFT)
            and Tesla (TSLA). Provide clear, data-driven answers. When answering
            questions about stock prices or trading volumes, use the Analyst tool.
            When answering questions about earnings reports, financial results,
            or company performance narratives, use the Search tool. For questions
            that span both structured data and earnings reports, use both tools
            and synthesise the results.
        orchestration: >
            For stock price, volume, or quantitative questions use Analyst.
            For earnings report content, financial commentary, or qualitative
            questions use Search. For questions combining both, call Analyst
            first for the data then Search for context.
        sample_questions:
            - question: "What was Tesla's closing stock price on the day they reported Q3 2024 earnings?"
            - question: "How did Microsoft's revenue growth compare to its stock price movement in FY25?"
            - question: "What were the key highlights from Tesla's most recent earnings report?"
            - question: "Show me the trading volume for MSFT around earnings announcement dates"

    tools:
        - tool_spec:
            type: cortex_analyst_text_to_sql
            name: StockQuoteAnalyst
            description: >
                Analyses structured NASDAQ historical stock quote data including
                daily open, high, low, close prices and trading volumes for
                MSFT and TSLA. Use for quantitative questions about stock prices,
                trading volumes, price movements, and date-specific queries.
        - tool_spec:
            type: cortex_search
            name: EarningsReportSearch
            description: >
                Searches quarterly earnings report PDFs for MSFT and TSLA.
                Use for questions about revenue, profit, guidance, financial
                results, management commentary, and company performance narratives.

    tool_resources:
        StockQuoteAnalyst:
            semantic_view: NASDAQ_DEMO.PUBLIC.HISTORICAL_QUOTES_SEMANTIC_VIEW
        EarningsReportSearch:
            name: NASDAQ_DEMO.PUBLIC.EARNINGS_REPORTS_SEARCH
            max_results: 5
            title_column: relative_path
    $$;
