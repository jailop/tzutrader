## High-Level Data Streaming API
##
## This module provides the main user-facing API for streaming data from
## multiple providers (CSV, Yahoo Finance, Coinbase).
##
## Key Design Principle:
## - Provider is a simple enum parameter, NOT a factory object
## - Simple, clean API: stream[T](provider, ...)
##
## Examples:
##   # Stream OHLCV data from Yahoo Finance
##   let data = streamYahoo[OHLCV]("AAPL", "2023-01-01", "2023-12-31")
##   for bar in data.items():
##     echo bar
##
##   # Stream from CSV file
##   let csv = streamCSV[OHLCV]("data.csv", "AAPL")
##   for bar in csv.items():
##     echo bar
##
##   # Generic streaming with provider parameter
##   let params = StreamParams(provider: dpYahoo, symbol: "AAPL", ...)
##   let stream = stream[OHLCV](params)

import std/[times, tables]
import ../core
import types
import base
import csv_streamer
import yahoo_streamer
import coinbase_streamer

# Import Interval and other types from data module
import ../data except DataStreamer, CoinbaseGranularity

export types, base
export Interval, OHLCV, Quote

# ============================================================================
# Iterator for DataStreamer - defined here where all concrete types are known
# ============================================================================

iterator items*[T](streamer: DataStreamer[T]): T =
  ## Stream all items one at a time
  ## This is the idiomatic Nim way to consume streams
  ## 
  ## Usage:
  ##   let stream = streamYahoo[OHLCV]("AAPL", "2023-01-01", "2023-12-31")
  ##   for bar in stream.items():
  ##     echo bar
  while streamer.next():
    # Call current() using type-based dispatch
    # We need to cast to the concrete type since current() is a proc not a method
    when T is OHLCV:
      if streamer of YahooStreamer[OHLCV]:
        yield YahooStreamer[OHLCV](streamer).current()
      elif streamer of CSVStreamer[OHLCV]:
        yield CSVStreamer[OHLCV](streamer).current()
      elif streamer of CoinbaseStreamer[OHLCV]:
        yield CoinbaseStreamer[OHLCV](streamer).current()
      else:
        raise newException(DataError, "Unknown streamer type")
    elif T is Quote:
      if streamer of YahooStreamer[Quote]:
        yield YahooStreamer[Quote](streamer).current()
      else:
        raise newException(DataError, "Unknown quote streamer type")
    else:
      {.error: "Unsupported data type for streaming".}

# ============================================================================
# Generic stream() function - Provider as parameter
# ============================================================================

proc stream*[T](params: StreamParams): DataStreamer[T] =
  ## Generic streaming function - provider specified in params
  ##
  ## This is the most flexible way to create a streamer. All provider-specific
  ## streamers ultimately call this function.
  ##
  ## Args:
  ##   params: StreamParams with provider, symbol, and provider-specific metadata
  ##
  ## Returns:
  ##   DataStreamer[T] for the specified provider
  ##
  ## Raises:
  ##   UnsupportedDataTypeError: If provider doesn't support type T
  ##
  ## Example:
  ##   var params = StreamParams(
  ##     provider: dpYahoo,
  ##     symbol: "AAPL",
  ##     startTime: parseTime("2023-01-01"),
  ##     endTime: parseTime("2023-12-31"),
  ##     metadata: {"interval": "1d"}.toTable
  ##   )
  ##   let data = stream[OHLCV](params)
  
  # Check if provider supports this data type
  if not supports(params.provider, T):
    raise newException(UnsupportedDataTypeError,
      $params.provider & " does not support " & $getDataKind[T]())
  
  # Dispatch to appropriate streamer
  case params.provider
  of dpCSV:
    result = newCSVStreamer[T](params)
  of dpYahoo:
    result = newYahooStreamer[T](params)
  of dpCoinbase:
    result = newCoinbaseStreamer[T](params)

# ============================================================================
# Convenience functions - Provider-specific
# ============================================================================

# CSV streaming

proc streamCSV*[T](filename: string, symbol: string = "",
                   startTime: int64 = 0, endTime: int64 = high(int64),
                   hasHeader: bool = true): DataStreamer[T] =
  ## Stream data from CSV file
  ##
  ## Args:
  ##   filename: Path to CSV file
  ##   symbol: Symbol name (extracted from filename if empty)
  ##   startTime: Optional start timestamp filter (default: 0)
  ##   endTime: Optional end timestamp filter (default: unlimited)
  ##   hasHeader: Skip first line if true (default: true)
  ##
  ## Example:
  ##   let data = streamCSV[OHLCV]("data/AAPL.csv")
  ##   for bar in data.items():
  ##     echo bar
  result = newCSVStreamer[T](filename, symbol, startTime, endTime, hasHeader)

# Yahoo Finance streaming

proc streamYahoo*[T](symbol: string, startTime: int64, endTime: int64,
                     interval: Interval = Int1d): DataStreamer[T] =
  ## Stream data from Yahoo Finance (with Unix timestamps)
  ##
  ## Args:
  ##   symbol: Stock symbol (e.g., "AAPL", "MSFT")
  ##   startTime: Start timestamp (Unix epoch seconds)
  ##   endTime: End timestamp (Unix epoch seconds)
  ##   interval: Time interval (default: 1d)
  ##
  ## Example:
  ##   let start = parse("2023-01-01", "yyyy-MM-dd").toTime().toUnix()
  ##   let end = parse("2023-12-31", "yyyy-MM-dd").toTime().toUnix()
  ##   let data = streamYahoo[OHLCV]("AAPL", start, end)
  result = newYahooStreamer[T](symbol, startTime, endTime, interval)

proc streamYahoo*[T](symbol: string, start: string, `end`: string,
                     interval: Interval = Int1d): DataStreamer[T] =
  ## Stream data from Yahoo Finance (with date strings)
  ##
  ## Args:
  ##   symbol: Stock symbol
  ##   start: Start date (ISO 8601 format: "2023-01-01")
  ##   end: End date (ISO 8601 format: "2023-12-31")
  ##   interval: Time interval (default: 1d)
  ##
  ## Example:
  ##   let data = streamYahoo[OHLCV]("AAPL", "2023-01-01", "2023-12-31")
  ##   for bar in data.items():
  ##     echo bar
  result = newYahooStreamer[T](symbol, start, `end`, interval)

proc streamYahoo*[T](symbol: string, days: int,
                     interval: Interval = Int1d): DataStreamer[T] =
  ## Stream data from Yahoo Finance (last N days)
  ##
  ## Args:
  ##   symbol: Stock symbol
  ##   days: Number of days of history
  ##   interval: Time interval (default: 1d)
  ##
  ## Example:
  ##   # Get last 30 days of data
  ##   let data = streamYahoo[OHLCV]("AAPL", 30)
  let endTime = getTime().toUnix()
  let startTime = endTime - (days * 86400)
  result = newYahooStreamer[T](symbol, startTime, endTime, interval)

# Coinbase streaming

proc streamCoinbase*[T](symbol: string, startTime: int64, endTime: int64,
                        granularity: CoinbaseGranularity = OneDay,
                        apiKey: string = "", apiSecret: string = ""): DataStreamer[T] =
  ## Stream data from Coinbase (with Unix timestamps)
  ##
  ## Args:
  ##   symbol: Trading pair (e.g., "BTC-USD", "ETH-USD")
  ##   startTime: Start timestamp (Unix epoch seconds)
  ##   endTime: End timestamp (Unix epoch seconds)
  ##   granularity: Candle granularity (default: OneDay)
  ##   apiKey: Optional API key (from env if empty)
  ##   apiSecret: Optional API secret (from env if empty)
  ##
  ## Environment Variables (if apiKey/apiSecret not provided):
  ##   - COINBASE_API_KEY
  ##   - COINBASE_SECRET_KEY
  ##
  ## Example:
  ##   let data = streamCoinbase[OHLCV]("BTC-USD", start, end, OneDay)
  result = newCoinbaseStreamer[T](symbol, startTime, endTime, 
                                  granularity, apiKey, apiSecret)

proc streamCoinbase*[T](symbol: string, start: string, `end`: string,
                        granularity: CoinbaseGranularity = OneDay,
                        apiKey: string = "", apiSecret: string = ""): DataStreamer[T] =
  ## Stream data from Coinbase (with date strings)
  ##
  ## Args:
  ##   symbol: Trading pair
  ##   start: Start date (ISO 8601 format: "2023-01-01")
  ##   end: End date (ISO 8601 format: "2023-12-31")
  ##   granularity: Candle granularity (default: OneDay)
  ##   apiKey: Optional API key
  ##   apiSecret: Optional API secret
  ##
  ## Example:
  ##   let data = streamCoinbase[OHLCV]("BTC-USD", "2023-01-01", "2023-12-31")
  result = newCoinbaseStreamer[T](symbol, start, `end`, granularity, apiKey, apiSecret)

proc streamCoinbase*[T](symbol: string, days: int,
                        granularity: CoinbaseGranularity = OneDay,
                        apiKey: string = "", apiSecret: string = ""): DataStreamer[T] =
  ## Stream data from Coinbase (last N days)
  ##
  ## Args:
  ##   symbol: Trading pair
  ##   days: Number of days of history
  ##   granularity: Candle granularity (default: OneDay)
  ##   apiKey: Optional API key
  ##   apiSecret: Optional API secret
  ##
  ## Example:
  ##   # Get last 30 days of BTC data
  ##   let data = streamCoinbase[OHLCV]("BTC-USD", 30)
  let endTime = getTime().toUnix()
  let startTime = endTime - (days * 86400)
  result = newCoinbaseStreamer[T](symbol, startTime, endTime, 
                                  granularity, apiKey, apiSecret)

# ============================================================================
# Utility functions
# ============================================================================

proc parseDate*(dateStr: string): int64 =
  ## Parse ISO 8601 date string to Unix timestamp
  ##
  ## Args:
  ##   dateStr: Date in "YYYY-MM-DD" format
  ##
  ## Returns:
  ##   Unix timestamp (seconds since epoch)
  ##
  ## Example:
  ##   let timestamp = parseDate("2023-01-01")
  result = parse(dateStr, "yyyy-MM-dd").toTime().toUnix()

proc formatDate*(timestamp: int64): string =
  ## Format Unix timestamp to ISO 8601 date string
  ##
  ## Args:
  ##   timestamp: Unix timestamp (seconds since epoch)
  ##
  ## Returns:
  ##   Date in "YYYY-MM-DD" format
  ##
  ## Example:
  ##   echo formatDate(1672531200)  # "2023-01-01"
  result = format(fromUnix(timestamp), "yyyy-MM-dd")

# ============================================================================
# Provider query functions
# ============================================================================

proc supportedProviders*[T](): seq[DataProvider] =
  ## Get list of providers that support data type T
  ##
  ## Example:
  ##   echo supportedProviders[OHLCV]()  # @[dpCSV, dpYahoo, dpCoinbase]
  ##   echo supportedProviders[Quote]()   # @[dpYahoo]
  result = @[]
  for provider in DataProvider:
    if supports(provider, T):
      result.add(provider)

proc supportedTypes*(provider: DataProvider): seq[DataKind] =
  ## Get list of data types supported by provider
  ##
  ## Example:
  ##   echo supportedTypes(dpYahoo)     # @[dkOHLCV, dkQuote]
  ##   echo supportedTypes(dpCoinbase)  # @[dkOHLCV]
  result = provider.supportedTypes()
