# IMF DataMapper Demo

An Openflow demo that ingests macroeconomic data from the [IMF DataMapper API](https://www.imf.org/external/datamapper/api/v1/) and writes it to a Snowflake table.

## Data Source

The [IMF DataMapper API](https://www.imf.org/external/datamapper/api/v1/) provides free, public access to the International Monetary Fund's World Economic Outlook (WEO) dataset. The API returns time-series data for a wide range of macroeconomic indicators across all IMF member countries.

### Indicators

| Indicator Code | Description |
|----------------|-------------|
| NGDPDPC | GDP per capita (current prices, USD) |
| NGDPD | GDP (current prices, USD billions) |
| NGDP_RPCH | GDP growth (annual % change) |
| PCPIPCH | Inflation (average consumer prices, annual % change) |
| LUR | Unemployment rate (% of total labor force) |
| GGXWDG_NGDP | Government gross debt (% of GDP) |
| BCA_NGDPD | Current account balance (% of GDP) |
| LP | Population (millions) |

Data is available for **190+ countries** with historical values and IMF projections.

## Target Table

Data is loaded into the following Snowflake table:

| Column | Type | Description |
|--------|------|-------------|
| `INDICATOR` | VARCHAR | WEO indicator code (e.g., NGDPDPC, PCPIPCH) |
| `COUNTRY_CODE` | VARCHAR | ISO country code |
| `YEAR` | INTEGER | Data year |
| `VALUE` | FLOAT | Indicator value |
| `INGESTION_TIMESTAMP` | TIMESTAMP_NTZ | When the data was loaded |

## How It Works

1. The flow calls the IMF DataMapper API to fetch WEO indicator data for all available countries and years.
2. The response is parsed and flattened into rows of `(indicator, country_code, year, value)`.
3. The data is written to a Snowflake table using the Openflow Snowpipe Streaming processor.
