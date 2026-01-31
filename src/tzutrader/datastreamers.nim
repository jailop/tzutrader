## Data Streamers Module
##
## This module provides a unified interface for streaming data from multiple
## providers with O(1) memory usage and type-safe APIs.
##
## Quick Start:
##
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
