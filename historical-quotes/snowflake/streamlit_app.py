"""
Stock Quote History Visualization
A Streamlit application for visualizing historical stock data from Snowflake.
Inspired by the Streamlit stockpeers demo.
"""

import streamlit as st
import pandas as pd
import altair as alt
from datetime import datetime, timedelta

# Page configuration
st.set_page_config(
    page_title="Stock Quote History",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Custom CSS for better styling
st.markdown("""
    <style>
    .main {
        padding: 0rem 1rem;
    }
    .stMetric {
        background-color: #f0f2f6;
        padding: 10px;
        border-radius: 5px;
    }
    </style>
    """, unsafe_allow_html=True)


@st.cache_data(ttl=600)
def load_data():
    """Load stock quote data from Snowflake."""
    # When deployed in Snowflake, this will use the app's context
    conn = st.connection("snowflake")
    
    query = """
    SELECT 
        SYMBOL,
        QUOTE_DATE,
        CLOSE_LAST_USD,
        VOLUME,
        OPEN_USD,
        HIGH_USD,
        LOW_USD
    FROM HISTORICAL_QUOTES_TYPED
    ORDER BY QUOTE_DATE DESC
    """
    
    df = conn.query(query)
    df['QUOTE_DATE'] = pd.to_datetime(df['QUOTE_DATE'])
    
    return df


@st.cache_data(ttl=600)
def load_forecast_data():
    """Load forecast data from Snowflake Cortex ML."""
    try:
        conn = st.connection("snowflake")
        
        query = """
        SELECT 
            SERIES::STRING AS SYMBOL,
            TS,
            FORECAST,
            LOWER_BOUND,
            UPPER_BOUND
        FROM "FORECAST-STOCK-QUOTES"
        ORDER BY TS
        """
        
        df = conn.query(query)
        df['TS'] = pd.to_datetime(df['TS'])
        
        return df
    except Exception as e:
        st.warning(f"Could not load forecast data: {str(e)}")
        return pd.DataFrame()


@st.cache_data
def calculate_returns(df, symbol):
    """Calculate daily returns and cumulative returns for a symbol."""
    symbol_df = df[df['SYMBOL'] == symbol].sort_values('QUOTE_DATE')
    symbol_df['DAILY_RETURN'] = symbol_df['CLOSE_LAST_USD'].pct_change() * 100
    symbol_df['CUMULATIVE_RETURN'] = ((symbol_df['CLOSE_LAST_USD'] / symbol_df['CLOSE_LAST_USD'].iloc[0]) - 1) * 100
    return symbol_df


def format_large_number(num):
    """Format large numbers with K, M, B suffixes."""
    if num >= 1_000_000_000:
        return f"{num/1_000_000_000:.2f}B"
    elif num >= 1_000_000:
        return f"{num/1_000_000:.2f}M"
    elif num >= 1_000:
        return f"{num/1_000:.2f}K"
    else:
        return f"{num:.0f}"


# Main app
st.title("Nasdaq Stock Quote History")
st.markdown("Explore and compare historical stock performance")

# Load data
try:
    with st.spinner("Loading data from Snowflake..."):
        df = load_data()
    
    if df.empty:
        st.warning("No data available in the HISTORICAL_QUOTES_TYPED table.")
        st.stop()
    
    # Sidebar filters
    st.sidebar.header("Filters")
    
    # Get available symbols
    available_symbols = sorted(df['SYMBOL'].unique())
    
    # Symbol selection
    selected_symbols = st.sidebar.multiselect(
        "Select Stock Symbols",
        options=available_symbols,
        default=available_symbols[:min(3, len(available_symbols))],
        help="Choose one or more stock symbols to visualize"
    )
    
    if not selected_symbols:
        st.warning("Please select at least one stock symbol from the sidebar.")
        st.stop()
    
    # Date range selection
    min_date = df['QUOTE_DATE'].min().date()
    max_date = df['QUOTE_DATE'].max().date()
    
    default_start = max(min_date, max_date - timedelta(days=365))
    
    date_range = st.sidebar.date_input(
        "Date Range",
        value=(default_start, max_date),
        min_value=min_date,
        max_value=max_date,
        help="Select the date range for analysis"
    )
    
    if len(date_range) == 2:
        start_date, end_date = date_range
    else:
        start_date = end_date = date_range[0]
    
    # Filter data
    filtered_df = df[
        (df['SYMBOL'].isin(selected_symbols)) &
        (df['QUOTE_DATE'].dt.date >= start_date) &
        (df['QUOTE_DATE'].dt.date <= end_date)
    ].copy()
    
    if filtered_df.empty:
        st.warning("No data available for the selected filters.")
        st.stop()
    
    # Metrics comparison
    st.header("Key Metrics")
    st.markdown("Current price and performance metrics for each selected stock symbol in the chosen date range.")
    
    cols = st.columns(len(selected_symbols))
    for idx, symbol in enumerate(selected_symbols):
        symbol_df = filtered_df[filtered_df['SYMBOL'] == symbol].sort_values('QUOTE_DATE')
        
        if not symbol_df.empty:
            latest_price = symbol_df['CLOSE_LAST_USD'].iloc[-1]
            first_price = symbol_df['CLOSE_LAST_USD'].iloc[0]
            price_change = latest_price - first_price
            price_change_pct = (price_change / first_price) * 100
            avg_volume = symbol_df['VOLUME'].mean()
            
            with cols[idx]:
                st.metric(
                    label=f"{symbol}",
                    value=f"${latest_price:.2f}",
                    delta=f"{price_change_pct:+.2f}%"
                )
                st.caption(f"Avg Volume: {format_large_number(avg_volume)}")
    
    # Price comparison chart
    st.header("Price Comparison")
    st.markdown("Track closing prices over time to compare absolute stock values and identify trends.")
    
    price_chart = alt.Chart(filtered_df).mark_line(point=True).encode(
        x=alt.X('QUOTE_DATE:T', title='Date', axis=alt.Axis(format='%b %Y')),
        y=alt.Y('CLOSE_LAST_USD:Q', title='Closing Price (USD)', scale=alt.Scale(zero=False)),
        color=alt.Color('SYMBOL:N', title='Symbol', legend=alt.Legend(orient='top')),
        tooltip=[
            alt.Tooltip('SYMBOL:N', title='Symbol'),
            alt.Tooltip('QUOTE_DATE:T', title='Date', format='%b %d, %Y'),
            alt.Tooltip('CLOSE_LAST_USD:Q', title='Close', format='$.2f'),
            alt.Tooltip('VOLUME:Q', title='Volume', format=',')
        ]
    ).properties(
        height=400
    ).interactive()
    
    st.altair_chart(price_chart, use_container_width=True)
    
    # Forecast section
    st.header("Price Forecast")
    st.markdown("AI-powered price predictions using Snowflake Cortex ML. The shaded area represents the confidence interval (lower and upper bounds).")
    
    # Load forecast data
    forecast_df = load_forecast_data()
    
    if not forecast_df.empty:
        # Filter forecast data for selected symbols
        filtered_forecast_df = forecast_df[forecast_df['SYMBOL'].isin(selected_symbols)].copy()
        
        if not filtered_forecast_df.empty:
            # Define shared color scale
            color_scale = alt.Color(
                'SYMBOL:N', 
                title='Symbol', 
                legend=alt.Legend(orient='top', symbolType='stroke', symbolStrokeWidth=3)
            )
            
            # Create confidence interval area chart (no legend, matches forecast colors)
            confidence_area = alt.Chart(filtered_forecast_df).mark_area(opacity=0.2).encode(
                x=alt.X('TS:T', title='Date', axis=alt.Axis(format='%b %Y')),
                y=alt.Y('LOWER_BOUND:Q', title='Forecasted Price (USD)', scale=alt.Scale(zero=False)),
                y2='UPPER_BOUND:Q',
                color=alt.Color('SYMBOL:N', legend=None)
            )
            
            # Create the forecast line chart with legend
            forecast_line = alt.Chart(filtered_forecast_df).mark_line(point=True, strokeWidth=2).encode(
                x=alt.X('TS:T'),
                y=alt.Y('FORECAST:Q'),
                color=color_scale,
                tooltip=[
                    alt.Tooltip('SYMBOL:N', title='Symbol'),
                    alt.Tooltip('TS:T', title='Date', format='%b %d, %Y'),
                    alt.Tooltip('FORECAST:Q', title='Forecast', format='$.2f'),
                    alt.Tooltip('LOWER_BOUND:Q', title='Lower Bound', format='$.2f'),
                    alt.Tooltip('UPPER_BOUND:Q', title='Upper Bound', format='$.2f')
                ]
            )
            
            forecast_chart = (confidence_area + forecast_line).properties(
                height=400
            ).interactive()
            
            st.altair_chart(forecast_chart, use_container_width=True)
        else:
            st.info("No forecast data available for the selected symbols.")
    else:
        st.info("Forecast data is not available. Please ensure the FORECAST-STOCK-QUOTES table exists and contains data.")
    
    # Normalized returns comparison
    st.header("Cumulative Returns Comparison")
    st.markdown("Compare relative performance across stocks by normalizing returns to the same starting point. This helps identify which stocks have outperformed regardless of their absolute price levels.")
    st.markdown("_Returns normalized to 0% at the start date_")
    
    # Calculate normalized returns for each symbol
    returns_data = []
    for symbol in selected_symbols:
        symbol_returns = calculate_returns(filtered_df, symbol)
        returns_data.append(symbol_returns)
    
    if returns_data:
        returns_df = pd.concat(returns_data, ignore_index=True)
        
        returns_chart = alt.Chart(returns_df).mark_line(size=3).encode(
            x=alt.X('QUOTE_DATE:T', title='Date', axis=alt.Axis(format='%b %Y')),
            y=alt.Y('CUMULATIVE_RETURN:Q', title='Cumulative Return (%)', scale=alt.Scale(zero=False)),
            color=alt.Color('SYMBOL:N', title='Symbol', legend=alt.Legend(orient='top')),
            tooltip=[
                alt.Tooltip('SYMBOL:N', title='Symbol'),
                alt.Tooltip('QUOTE_DATE:T', title='Date', format='%b %d, %Y'),
                alt.Tooltip('CUMULATIVE_RETURN:Q', title='Return', format='.2f')
            ]
        ).properties(
            height=400
        ).interactive()
        
        # Add zero line
        zero_line = alt.Chart(pd.DataFrame({'y': [0]})).mark_rule(
            strokeDash=[5, 5],
            color='gray'
        ).encode(y='y:Q')
        
        st.altair_chart(returns_chart + zero_line, use_container_width=True)
    
    # Volume analysis
    st.header("Trading Volume Analysis")
    st.markdown("Analyze trading activity and liquidity patterns. Higher volumes often indicate greater investor interest and can signal potential price movements.")
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.subheader("Volume Over Time")
        volume_chart = alt.Chart(filtered_df).mark_bar().encode(
            x=alt.X('QUOTE_DATE:T', title='Date', axis=alt.Axis(format='%b %Y')),
            y=alt.Y('VOLUME:Q', title='Volume'),
            color=alt.Color('SYMBOL:N', title='Symbol'),
            tooltip=[
                alt.Tooltip('SYMBOL:N', title='Symbol'),
                alt.Tooltip('QUOTE_DATE:T', title='Date', format='%b %d, %Y'),
                alt.Tooltip('VOLUME:Q', title='Volume', format=',')
            ]
        ).properties(
            height=300
        ).interactive()
        
        st.altair_chart(volume_chart, use_container_width=True)
    
    with col2:
        st.subheader("Average Volume by Symbol")
        avg_volume_df = filtered_df.groupby('SYMBOL')['VOLUME'].mean().reset_index()
        avg_volume_df.columns = ['SYMBOL', 'AVG_VOLUME']
        
        avg_volume_chart = alt.Chart(avg_volume_df).mark_bar().encode(
            x=alt.X('SYMBOL:N', title='Symbol', sort='-y'),
            y=alt.Y('AVG_VOLUME:Q', title='Average Volume'),
            color=alt.Color('SYMBOL:N', legend=None),
            tooltip=[
                alt.Tooltip('SYMBOL:N', title='Symbol'),
                alt.Tooltip('AVG_VOLUME:Q', title='Avg Volume', format=',')
            ]
        ).properties(
            height=300
        )
        
        st.altair_chart(avg_volume_chart, use_container_width=True)
    
    # Price range analysis (candlestick-style view)
    st.header("Price Range Analysis")
    st.markdown("Examine intraday price movements between opening, high, low, and closing prices. For single stocks, see candlestick-style visualization; for multiple stocks, compare daily volatility patterns.")
    
    # For single symbol, show detailed candlestick-style chart
    if len(selected_symbols) == 1:
        symbol = selected_symbols[0]
        symbol_df = filtered_df[filtered_df['SYMBOL'] == symbol].copy()
        
        # Calculate color based on open vs close
        symbol_df['COLOR'] = symbol_df.apply(
            lambda row: 'green' if row['CLOSE_LAST_USD'] >= row['OPEN_USD'] else 'red',
            axis=1
        )
        
        # High-low range
        range_chart = alt.Chart(symbol_df).mark_rule().encode(
            x=alt.X('QUOTE_DATE:T', title='Date', axis=alt.Axis(format='%b %Y')),
            y=alt.Y('LOW_USD:Q', title='Price (USD)', scale=alt.Scale(zero=False)),
            y2='HIGH_USD:Q',
            color=alt.Color('COLOR:N', scale=None, legend=None),
            tooltip=[
                alt.Tooltip('QUOTE_DATE:T', title='Date', format='%b %d, %Y'),
                alt.Tooltip('OPEN_USD:Q', title='Open', format='$.2f'),
                alt.Tooltip('HIGH_USD:Q', title='High', format='$.2f'),
                alt.Tooltip('LOW_USD:Q', title='Low', format='$.2f'),
                alt.Tooltip('CLOSE_LAST_USD:Q', title='Close', format='$.2f')
            ]
        ).properties(
            height=400
        )
        
        # Open-close bars
        bar_chart = alt.Chart(symbol_df).mark_bar(size=10).encode(
            x=alt.X('QUOTE_DATE:T'),
            y=alt.Y('OPEN_USD:Q'),
            y2='CLOSE_LAST_USD:Q',
            color=alt.Color('COLOR:N', scale=None, legend=None)
        )
        
        st.altair_chart((range_chart + bar_chart).interactive(), use_container_width=True)
    else:
        # For multiple symbols, show daily volatility comparison
        volatility_df = filtered_df.copy()
        volatility_df['DAILY_RANGE'] = ((volatility_df['HIGH_USD'] - volatility_df['LOW_USD']) / volatility_df['OPEN_USD'] * 100)
        
        volatility_chart = alt.Chart(volatility_df).mark_line().encode(
            x=alt.X('QUOTE_DATE:T', title='Date', axis=alt.Axis(format='%b %Y')),
            y=alt.Y('DAILY_RANGE:Q', title='Daily Volatility (%)'),
            color=alt.Color('SYMBOL:N', title='Symbol', legend=alt.Legend(orient='top')),
            tooltip=[
                alt.Tooltip('SYMBOL:N', title='Symbol'),
                alt.Tooltip('QUOTE_DATE:T', title='Date', format='%b %d, %Y'),
                alt.Tooltip('DAILY_RANGE:Q', title='Volatility', format='.2f')
            ]
        ).properties(
            height=400
        ).interactive()
        
        st.altair_chart(volatility_chart, use_container_width=True)
    
    # Data table
    with st.expander("View Raw Data"):
        display_df = filtered_df.sort_values(['SYMBOL', 'QUOTE_DATE'], ascending=[True, False])
        st.dataframe(
            display_df.style.format({
                'CLOSE_LAST_USD': '${:.2f}',
                'OPEN_USD': '${:.2f}',
                'HIGH_USD': '${:.2f}',
                'LOW_USD': '${:.2f}',
                'VOLUME': '{:,.0f}',
                'QUOTE_DATE': lambda x: x.strftime('%Y-%m-%d')
            }),
            height=400,
            use_container_width=True
        )
        
        # Download button
        csv = display_df.to_csv(index=False)
        st.download_button(
            label="Download Data as CSV",
            data=csv,
            file_name=f"stock_quotes_{start_date}_{end_date}.csv",
            mime="text/csv"
        )
    
    # Footer
    st.markdown("---")
    st.markdown(
        f"**Data Range:** {min_date.strftime('%b %d, %Y')} to {max_date.strftime('%b %d, %Y')} | "
        f"**Total Records:** {len(df):,} | "
        f"**Symbols:** {len(available_symbols)}"
    )

except Exception as e:
    st.error(f"An error occurred: {str(e)}")
    st.info("Make sure you're running this app in Snowflake with access to the HISTORICAL_QUOTES_TYPED table.")
    
    # Show debug info
    with st.expander("Debug Information"):
        st.write("Error details:", e)
        st.write("This app expects a table named HISTORICAL_QUOTES_TYPED with the following schema:")
        st.code("""
        SYMBOL          VARCHAR(16777216)
        QUOTE_DATE      DATE
        CLOSE_LAST_USD  FLOAT
        VOLUME          NUMBER(38,0)
        OPEN_USD        FLOAT
        HIGH_USD        FLOAT
        LOW_USD         FLOAT
        """)

