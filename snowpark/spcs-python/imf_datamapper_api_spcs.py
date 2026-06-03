#!/usr/bin/env python3
"""
IMF DataMapper API - Snowpipe Streaming v2 (High-Performance) Version
Fetches World Economic Outlook data from IMF and streams into Snowflake
using the Snowpipe Streaming SDK with SPCS OAuth token authentication.
"""

import json
import os
import sys
import tempfile
import uuid
from datetime import datetime, timezone

import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry
from snowflake.ingest.streaming import StreamingIngestClient

os.environ["SS_LOG_LEVEL"] = "info"

BASE_URL = "https://www.imf.org/external/datamapper/api/v1"
DATASET = "WEO"
TIMEOUT_SECONDS = 120
BATCH_SIZE = 1000

SNOWFLAKE_ACCOUNT = os.getenv("SNOWFLAKE_ACCOUNT")
SNOWFLAKE_HOST = os.getenv("SNOWFLAKE_HOST")
SNOWFLAKE_DATABASE = os.getenv("SNOWFLAKE_DATABASE", "API_DEMO")
SNOWFLAKE_SCHEMA = os.getenv("SNOWFLAKE_SCHEMA", "PUBLIC")
TABLE_NAME = os.getenv("TABLE_NAME", "IMF_DATAMAPPER_INDICATORS_SSV2")
PIPE_NAME = os.getenv("PIPE_NAME", "IMF_SSV2_PIPE")


def write_streaming_profile():
    """Write an SSv2 SDK profile.json using SPCS workload-identity token auth."""
    profile = {
        "authorization_type": "SPCS",
        "url": f"https://{SNOWFLAKE_HOST}",
        "account": SNOWFLAKE_ACCOUNT,
        "role": "ACCOUNTADMIN",
        "spcs_token_path": "/snowflake/session/token",
    }
    profile_path = os.path.join(tempfile.gettempdir(), "profile.json")
    with open(profile_path, "w") as f:
        json.dump(profile, f)
    return profile_path


def create_http_session():
    """Create an HTTP session with retry logic for IMF API calls."""
    session = requests.Session()
    retries = Retry(total=3, backoff_factor=1, status_forcelist=[429, 500, 502, 503, 504])
    session.mount("https://", HTTPAdapter(max_retries=retries))
    return session


def fetch_weo_indicators(http_session):
    """Fetch list of WEO indicators from IMF DataMapper API."""
    response = http_session.get(f"{BASE_URL}/indicators", timeout=TIMEOUT_SECONDS)
    response.raise_for_status()
    indicators = response.json().get("indicators", {})
    return {
        code: info for code, info in indicators.items()
        if info.get("dataset") == DATASET and code
    }


def fetch_indicator_data(http_session, indicator_code):
    """Fetch data for a single indicator."""
    response = http_session.get(f"{BASE_URL}/{indicator_code}", timeout=TIMEOUT_SECONDS)
    response.raise_for_status()
    return response.json()


def parse_indicator_rows(indicator_code, data, ingestion_timestamp):
    """Parse indicator data into row dicts matching the target table schema."""
    values = data.get("values", {}).get(indicator_code, {})
    rows = []
    for country, yearly_data in values.items():
        for year, value in yearly_data.items():
            if value is not None:
                rows.append({
                    "INDICATOR": indicator_code,
                    "COUNTRY_CODE": country,
                    "YEAR": int(year),
                    "VALUE": float(value),
                    "INGESTION_TIMESTAMP": ingestion_timestamp.isoformat(),
                })
    return rows


def main():
    ingestion_timestamp = datetime.now(timezone.utc)

    try:
        # Fetch IMF data
        http_session = create_http_session()
        print("Fetching IMF WEO indicators...")
        weo_indicators = fetch_weo_indicators(http_session)
        print(f"Found {len(weo_indicators)} WEO indicators")

        # Collect all rows
        all_rows = []
        for indicator_code in weo_indicators:
            data = fetch_indicator_data(http_session, indicator_code)
            rows = parse_indicator_rows(indicator_code, data, ingestion_timestamp)
            all_rows.extend(rows)

        print(f"Total rows to ingest: {len(all_rows)}")

        if not all_rows:
            print("No data to ingest, exiting.")
            return

        # Stream data via Snowpipe Streaming v2
        profile_path = write_streaming_profile()
        client_name = f"IMF_DATAMAPPER_{uuid.uuid4().hex[:8]}"

        with StreamingIngestClient(
            client_name=client_name,
            db_name=SNOWFLAKE_DATABASE,
            schema_name=SNOWFLAKE_SCHEMA,
            pipe_name=PIPE_NAME,
            profile_json=profile_path,
        ) as client:
            print(f"SSv2 client created: {client_name}")

            channel_name = f"imf-channel-{uuid.uuid4().hex[:8]}"
            with client.open_channel(channel_name)[0] as channel:
                print(f"Channel opened: {channel.channel_name}")

                # Stream rows with offset tracking
                for i, row in enumerate(all_rows):
                    offset_token = str(i + 1)
                    channel.append_row(row, offset_token)

                    if (i + 1) % 10000 == 0:
                        print(f"  Streamed {i + 1} rows...")

                print(f"All {len(all_rows)} rows submitted. Waiting for commit...")

                # Wait for all rows to be committed
                expected_offset = str(len(all_rows))

                def all_committed(token):
                    return token is not None and int(token) >= len(all_rows)

                channel.wait_for_commit(all_committed, timeout_seconds=120)

                # Verify
                status = channel.get_channel_status()
                print(f"Ingestion complete!")
                print(f"  Committed offset: {status.latest_committed_offset_token}")
                print(f"  Rows inserted:    {status.rows_inserted_count}")
                print(f"  Rows errored:     {status.rows_error_count}")

                if status.rows_error_count > 0:
                    print(f"  Last error: {status.last_error_message}")
                    sys.exit(1)

        print(f"Successfully streamed {len(all_rows)} rows into "
              f"{SNOWFLAKE_DATABASE}.{SNOWFLAKE_SCHEMA}.{TABLE_NAME}")

    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
