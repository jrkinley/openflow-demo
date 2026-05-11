# IMF DataMapper Demo

An Openflow demo that ingests macroeconomic data from the [IMF DataMapper API](https://www.imf.org/external/datamapper/api/v1/) and writes it to a Snowflake table via Snowpipe Streaming.

## Overview

The flow calls the IMF DataMapper API to fetch World Economic Outlook (WEO) indicator data for all available countries and years. The response is parsed, flattened into rows of `(indicator, country_code, year, value)`, and written to a Snowflake table. Data covers 190+ countries with historical values and IMF projections.

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

## Project structure

```
imf-datamapper-demo/
├── README.md
├── SKILL.md                   # Cortex Code CLI skill
├── imf-weo.json               # Openflow flow definition
├── imf-indicator.groovy       # Groovy script (JSON flattening)
├── pyproject.toml             # Python dependencies (nipyapi)
├── .python-version            # Python 3.11
└── uv.lock                    # uv lockfile
```

## Cortex Code CLI Skill

This demo is driven by a [Cortex Code CLI](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-cli) skill that walks you through each step interactively — from environment setup to flow deployment, verification, and teardown.

### Install the skill

```bash
cp -r imf-datamapper-demo ~/.snowflake/cortex/skills/
```

### Run the demo

Open the Cortex Code CLI and prompt:

```
Run IMF API demo
```

The skill will:

1. Check prerequisites (Python environment, Snowflake connectivity)
2. List active Openflow runtimes and let you select one
3. Create the target database, table, and external access integration if needed
4. Deploy the IMF DataMapper flow and wait for completion
5. Show the top 10 countries by GDP per capita

### Tear down

```
Clean up IMF API demo
```

## References

- [Cortex Code CLI](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-cli)
- [Openflow](https://docs.snowflake.com/en/user-guide/data-integration/openflow)
- [IMF DataMapper API](https://www.imf.org/external/datamapper/api/v1/)
- [NiPyApi](https://nipyapi.readthedocs.io/)
