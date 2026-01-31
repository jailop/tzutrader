## Yahoo Finance Data Streamer
##
## Provides streaming access to Yahoo Finance market data.
##
## Supported data types:
## - OHLCV: Historical price bars (open, high, low, close, volume)
## - Quote: Real-time quote data
##
## Features:
## - Multiple time intervals (1m, 5m, 15m, 30m, 1h, 1d, 1wk, 1mo)
## - Historical and real-time data
## - Automatic fallback to mock data when yfnim is unavailable
##
## Note: When yfnim is not available, generates realistic mock data for testing.

import std/[times, strutils, tables]
import ../core
import types
import base

# Import existing Interval type and utilities from data module
import ../data except DataStreamer

# Conditionally import yfnim at top level
when defined(useYfnim):
  import yfnim/types as yfTypes
  import yfnim/[retriever, quote_retriever, quote_types]

type
  YahooStreamer*[T] = ref object of DataStreamer[T]
    ## Yahoo Finance streamer for OHLCV and Quote data
    interval: data.Interval
    startTime: int64
    endTime: int64
    data: seq[OHLCV]  # Cached data for OHLCV streaming
    index: int
    quote: data.Quote      # For quote streaming

# Helper procs

proc fetchYahooHistory(symbol: string, interval: data.Interval, 
                       startTime, endTime: int64): seq[OHLCV] =
  ## Fetch historical OHLCV data from Yahoo Finance
  ## Uses yfnim when available, falls back to mock data
  when defined(useYfnim):
    # Convert our Interval to yfnim Interval
    let yfInterval = case interval
      of Int1m: yfTypes.Int1m
      of Int5m: yfTypes.Int5m
      of Int15m: yfTypes.Int15m
      of Int30m: yfTypes.Int30m
      of Int1h: yfTypes.Int1h
      of Int1d: yfTypes.Int1d
      of Int1wk: yfTypes.Int1wk
      of Int1mo: yfTypes.Int1mo
    
    let history = getHistory(symbol, yfInterval, startTime, endTime)
    result = @[]
    for bar in history.data:
      result.add(OHLCV(
        timestamp: bar.time,
        open: bar.open,
        high: bar.high,
        low: bar.low,
        close: bar.close,
        volume: bar.volume.float64
      ))
  else:
    # Fallback to mock data
    result = generateMockOHLCV(symbol, startTime, endTime, interval)

proc fetchYahooQuote(symbol: string): data.Quote =
  ## Fetch current quote from Yahoo Finance
  ## Uses yfnim when available, falls back to mock data
  when defined(useYfnim):
    let yfQuote = quote_retriever.getQuote(symbol)
    result = data.Quote(
      symbol: yfQuote.symbol,
      timestamp: yfQuote.regularMarketTime,
      regularMarketPrice: yfQuote.regularMarketPrice,
      regularMarketChange: yfQuote.regularMarketChange,
      regularMarketChangePercent: yfQuote.regularMarketChangePercent,
      regularMarketVolume: yfQuote.regularMarketVolume.float64,
      regularMarketOpen: yfQuote.regularMarketOpen,
      regularMarketDayHigh: yfQuote.regularMarketDayHigh,
      regularMarketDayLow: yfQuote.regularMarketDayLow,
      regularMarketPreviousClose: yfQuote.regularMarketPreviousClose
    )
  else:
    # Fallback to mock data
    result = generateMockQuote(symbol)

proc parseYahooInterval(s: string): data.Interval =
  ## Parse interval string to Interval enum
  case s.toLowerAscii()
  of "1m": Int1m
  of "5m": Int5m
  of "15m": Int15m
  of "30m": Int30m
  of "1h": Int1h
  of "1d": Int1d
  of "1wk": Int1wk
  of "1mo": Int1mo
  else: raise newException(DataError, "Invalid interval: " & s)

# Public interface

proc newYahooStreamer*[T](params: StreamParams): YahooStreamer[T] =
  ## Create a new Yahoo Finance streamer
  ##
  ## Type parameter T can be OHLCV or Quote
  ##
  ## Args:
  ##   params: Stream parameters with Yahoo-specific fields:
  ##     - symbol: Stock symbol (required)
  ##     - startTime: Start timestamp (for OHLCV only)
  ##     - endTime: End timestamp (for OHLCV only)
  ##     - metadata["interval"]: Time interval (default: "1d")
  ##       Valid: "1m", "5m", "15m", "30m", "1h", "1d", "1wk", "1mo"
  ##
  ## Raises:
  ##   UnsupportedDataTypeError: If T is not OHLCV or Quote
  ##   DataError: If symbol is not provided
  
  # Check if type is supported
  when T isnot OHLCV and T isnot data.Quote:
    raise newException(UnsupportedDataTypeError,
      "Yahoo Finance streamer only supports OHLCV and Quote data types, got: " & $getDataKind[T]())
  
  if params.symbol.len == 0:
    raise newException(DataError, "Yahoo Finance streamer requires a symbol")
  
  # Parse interval
  let intervalStr = params.metadata.getOrDefault("interval", "1d")
  let interval = parseYahooInterval(intervalStr)
  
  result = YahooStreamer[T](
    symbol: params.symbol,
    interval: interval,
    startTime: params.startTime,
    endTime: params.endTime,
    index: 0
  )
  
  # For OHLCV, fetch data immediately
  when T is OHLCV:
    result.data = fetchYahooHistory(params.symbol, interval, 
                                    params.startTime, params.endTime)

proc newYahooStreamer*[T](symbol: string, startTime: int64, endTime: int64,
                          interval: data.Interval = Int1d): YahooStreamer[T] =
  ## Convenience constructor for Yahoo Finance streamer
  ##
  ## Args:
  ##   symbol: Stock symbol (e.g., "AAPL", "MSFT")
  ##   startTime: Start timestamp (Unix epoch seconds)
  ##   endTime: End timestamp (Unix epoch seconds)
  ##   interval: Time interval (default: 1d)
  var params = StreamParams(
    provider: dpYahoo,
    symbol: symbol,
    startTime: startTime,
    endTime: endTime,
    metadata: {"interval": $interval}.toTable
  )
  result = newYahooStreamer[T](params)

proc newYahooStreamer*[T](symbol: string, start: string, `end`: string,
                          interval: data.Interval = Int1d): YahooStreamer[T] =
  ## Convenience constructor with date strings (ISO 8601 format)
  ##
  ## Args:
  ##   symbol: Stock symbol
  ##   start: Start date (e.g., "2023-01-01")
  ##   end: End date (e.g., "2023-12-31", empty string defaults to today)
  ##   interval: Time interval (default: 1d)
  let startTime = parse(start, "yyyy-MM-dd").toTime().toUnix()
  let endTime = if `end`.len > 0:
    parse(`end`, "yyyy-MM-dd").toTime().toUnix()
  else:
    getTime().toUnix()  # Default to today
  result = newYahooStreamer[T](symbol, startTime, endTime, interval)

# Implement DataStreamer interface for OHLCV

proc next*(stream: YahooStreamer[OHLCV]): bool =
  ## Advance to next data point
  ## Returns true if successful, false if end of stream
  if stream.index < stream.data.len:
    stream.index.inc
    return true
  return false

proc current*(stream: YahooStreamer[OHLCV]): OHLCV =
  ## Get current data point
  ## Must call next() first
  if stream.index <= 0 or stream.index > stream.data.len:
    raise newException(DataError, "No current data - call next() first")
  return stream.data[stream.index - 1]

proc reset*(stream: YahooStreamer[OHLCV]) =
  ## Reset stream to beginning
  stream.index = 0

proc len*(stream: YahooStreamer[OHLCV]): int =
  ## Get total number of items in stream
  return stream.data.len

proc hasNext*(stream: YahooStreamer[OHLCV]): bool =
  ## Check if more data is available
  return stream.index < stream.data.len

# Implement DataStreamer interface for Quote

proc next*(stream: YahooStreamer[data.Quote]): bool =
  ## Advance to next data point
  ## For quotes, this fetches a fresh quote
  stream.quote = fetchYahooQuote(stream.symbol)
  return true

proc current*(stream: YahooStreamer[data.Quote]): data.Quote =
  ## Get current quote
  ## Must call next() first
  if stream.quote.symbol.len == 0:
    raise newException(DataError, "No current data - call next() first")
  return stream.quote

proc reset*(stream: YahooStreamer[data.Quote]) =
  ## Reset stream to beginning
  ## For quotes, this is a no-op
  discard

proc len*(stream: YahooStreamer[data.Quote]): int =
  ## Get total number of items in stream
  ## For quotes, this is always 1 (latest quote)
  return 1

proc hasNext*(stream: YahooStreamer[data.Quote]): bool =
  ## Check if more data is available
  ## For quotes, always true (can always fetch latest)
  return true
