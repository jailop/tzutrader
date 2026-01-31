## Data Streamers Module
##
## Generic, extensible data streaming library for TzuTrader.
##
## This module provides a unified interface for streaming data from multiple
## providers with O(1) memory usage and type-safe APIs.
##
## Supported Providers:
## - CSV: Local CSV files
## - Yahoo Finance: Stock market data (OHLCV + Quotes)
## - Coinbase: Cryptocurrency data (OHLCV)
##
## Supported Data Types:
## - OHLCV: Open, High, Low, Close, Volume bars
## - Quote: Real-time market quotes (Yahoo only)
##
## Quick Start:
##   import tzutrader/datastreamers
##
##   # Stream from Yahoo Finance
##   let data = streamYahoo[OHLCV]("AAPL", "2023-01-01", "2023-12-31")
##   for bar in data.items():
##     echo bar
##
##   # Stream from CSV
##   let csv = streamCSV[OHLCV]("data.csv", "AAPL")
##   for bar in csv.items():
##     echo bar
##
##   # Stream from Coinbase
##   let btc = streamCoinbase[OHLCV]("BTC-USD", "2023-01-01", "2023-12-31")
##   for candle in btc.items():
##     echo candle
##
## Design Principles:
## 1. Provider as enum parameter (not factory objects)
## 2. Streaming-first (O(1) memory, not batch-first)
## 3. Type-safe (generic DataStreamer[T])
## 4. Iterator interface as primary consumption method
## 5. Extensible (easy to add new providers/types)
##
## Key Types:
## - DataStreamer[T]: Base streaming interface
## - StreamParams: Configuration for creating streamers
## - DataProvider: Enum of supported providers (dpCSV, dpYahoo, dpCoinbase)
## - DataKind: Enum of supported data types (dkOHLCV, dkQuote)
##
## Core API:
## - stream[T](params): Generic streaming function
## - streamCSV[T](...): Stream from CSV file
## - streamYahoo[T](...): Stream from Yahoo Finance
## - streamCoinbase[T](...): Stream from Coinbase
## - supportedProviders[T](): Query which providers support type T
## - supportedTypes(provider): Query which types provider supports

# Re-export all public APIs from submodules
import datastreamers/types
import datastreamers/base
import datastreamers/csv_streamer
import datastreamers/yahoo_streamer
import datastreamers/coinbase_streamer
import datastreamers/api

# Export everything users need
export types
export base
export csv_streamer
export yahoo_streamer
export coinbase_streamer
export api

# Re-export commonly used types from core and data modules
from core import OHLCV, DataError
from data import Interval, Quote

export OHLCV, DataError
export Interval, Quote
export CoinbaseGranularity
