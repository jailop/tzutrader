## Data module for tzutrader - Yahoo Finance integration
##
## This module provides data streaming and fetching capabilities using
## Yahoo Finance as the data source via the yfnim library.
##
## Features:
## - Historical OHLCV data retrieval
## - Real-time/delayed quote data
## - Multiple time intervals (1m, 5m, 15m, 30m, 1h, 1d, 1wk, 1mo)
## - Simple caching mechanism
## - Iterator interface for streaming data
## - Mock data generation for testing

import std/[times, tables, sequtils, strutils, math, random, algorithm]
import core

type
  Interval* = enum
    ## Time intervals for data fetching (matching yfnim)
    Int1m = "1m"    ## 1 minute (max ~7 days history)
    Int5m = "5m"    ## 5 minutes (max ~60 days history)
    Int15m = "15m"  ## 15 minutes (max ~60 days history)
    Int30m = "30m"  ## 30 minutes (max ~60 days history)
    Int1h = "1h"    ## 1 hour (max ~2 years history)
    Int1d = "1d"    ## 1 day (unlimited history)
    Int1wk = "1wk"  ## 1 week (unlimited history)
    Int1mo = "1mo"  ## 1 month (unlimited history)

  DataStream* = ref object
    ## Data stream for a specific symbol
    symbol*: string
    interval*: Interval
    cache*: seq[OHLCV]
    cacheStart*: int64
    cacheEnd*: int64
    useCache*: bool

  Quote* = object
    ## Real-time quote data
    symbol*: string
    timestamp*: int64
    regularMarketPrice*: float64
    regularMarketChange*: float64
    regularMarketChangePercent*: float64
    regularMarketVolume*: float64
    regularMarketOpen*: float64
    regularMarketDayHigh*: float64
    regularMarketDayLow*: float64
    regularMarketPreviousClose*: float64

# Interval utilities

proc toSeconds*(interval: Interval): int64 =
  ## Convert interval to seconds
  case interval
  of Int1m: 60
  of Int5m: 300
  of Int15m: 900
  of Int30m: 1800
  of Int1h: 3600
  of Int1d: 86400
  of Int1wk: 604800
  of Int1mo: 2592000  # Approximate (30 days)

proc maxHistory*(interval: Interval): int64 =
  ## Get maximum history duration in seconds for an interval
  ## Returns 0 for unlimited
  case interval
  of Int1m: 7 * 86400      # ~7 days
  of Int5m: 60 * 86400     # ~60 days
  of Int15m: 60 * 86400    # ~60 days
  of Int30m: 60 * 86400    # ~60 days
  of Int1h: 730 * 86400    # ~2 years
  of Int1d, Int1wk, Int1mo: 0  # Unlimited

# DataStream constructors

proc newDataStream*(symbol: string, interval: Interval = Int1d, 
                   useCache: bool = true): DataStream =
  ## Create a new data stream for a symbol
  result = DataStream(
    symbol: symbol,
    interval: interval,
    cache: @[],
    cacheStart: 0,
    cacheEnd: 0,
    useCache: useCache
  )

# Cache management

proc clearCache*(ds: DataStream) =
  ## Clear the data stream cache
  ds.cache = @[]
  ds.cacheStart = 0
  ds.cacheEnd = 0

proc isCached*(ds: DataStream, startTime, endTime: int64): bool =
  ## Check if requested time range is in cache
  if not ds.useCache or ds.cache.len == 0:
    return false
  return startTime >= ds.cacheStart and endTime <= ds.cacheEnd

proc addToCache*(ds: DataStream, data: seq[OHLCV]) =
  ## Add data to cache
  if not ds.useCache or data.len == 0:
    return
  
  ds.cache.add(data)
  ds.cache.sort(proc (a, b: OHLCV): int = cmp(a.timestamp, b.timestamp))
  
  if ds.cache.len > 0:
    ds.cacheStart = ds.cache[0].timestamp
    ds.cacheEnd = ds.cache[^1].timestamp

proc getCached*(ds: DataStream, startTime, endTime: int64): seq[OHLCV] =
  ## Get data from cache for the specified time range
  result = @[]
  if not ds.useCache or ds.cache.len == 0:
    return
  
  for bar in ds.cache:
    if bar.timestamp >= startTime and bar.timestamp <= endTime:
      result.add(bar)

# Mock data generation for testing

proc generateMockOHLCV*(symbol: string, startTime, endTime: int64, 
                       interval: Interval, startPrice: float64 = 100.0,
                       volatility: float64 = 0.02): seq[OHLCV] =
  ## Generate mock OHLCV data for testing
  ## 
  ## Args:
  ##   symbol: Stock symbol
  ##   startTime: Start timestamp (Unix)
  ##   endTime: End timestamp (Unix)
  ##   interval: Time interval between bars
  ##   startPrice: Starting price (default 100.0)
  ##   volatility: Daily volatility as decimal (default 0.02 = 2%)
  result = @[]
  
  var currentTime = startTime
  var currentPrice = startPrice
  let intervalSeconds = interval.toSeconds()
  
  # Initialize random seed
  randomize()
  
  while currentTime <= endTime:
    # Generate random price movement
    let change = (rand(1.0) - 0.5) * 2.0 * volatility * currentPrice
    let open = currentPrice
    let close = currentPrice + change
    
    # Generate high and low with some randomness
    let high = max(open, close) * (1.0 + rand(volatility / 2.0))
    let low = min(open, close) * (1.0 - rand(volatility / 2.0))
    
    # Generate random volume
    let volume = rand(1000000.0) + 500000.0
    
    let bar = OHLCV(
      timestamp: currentTime,
      open: open,
      high: high,
      low: low,
      close: close,
      volume: volume
    )
    
    if bar.isValid():
      result.add(bar)
    
    currentPrice = close
    currentTime += intervalSeconds

proc generateMockQuote*(symbol: string, price: float64 = 100.0): Quote =
  ## Generate a mock quote for testing
  randomize()
  let change = (rand(1.0) - 0.5) * 2.0 * price * 0.02
  let previousClose = price - change
  
  result = Quote(
    symbol: symbol,
    timestamp: getTime().toUnix(),
    regularMarketPrice: price,
    regularMarketChange: change,
    regularMarketChangePercent: (change / previousClose) * 100.0,
    regularMarketVolume: rand(1000000.0) + 500000.0,
    regularMarketOpen: previousClose * (1.0 + rand(0.01) - 0.005),
    regularMarketDayHigh: price * (1.0 + rand(0.01)),
    regularMarketDayLow: previousClose * (1.0 - rand(0.01)),
    regularMarketPreviousClose: previousClose
  )

# Yahoo Finance integration
# Note: Will use yfnim when available, for now provide interface

when defined(useYfnim):
  # This section will be enabled when yfnim is properly installed
  import yfnim
  
  proc convertYfnimToOHLCV(yfData: yfnim.HistoricalData): seq[OHLCV] =
    ## Convert yfnim historical data to our OHLCV format
    result = @[]
    for bar in yfData.data:
      result.add(OHLCV(
        timestamp: bar.date,
        open: bar.open,
        high: bar.high,
        low: bar.low,
        close: bar.close,
        volume: bar.volume
      ))
  
  proc convertYfnimToQuote(yfQuote: yfnim.Quote): Quote =
    ## Convert yfnim quote to our Quote format
    result = Quote(
      symbol: yfQuote.symbol,
      timestamp: getTime().toUnix(),
      regularMarketPrice: yfQuote.regularMarketPrice,
      regularMarketChange: yfQuote.regularMarketChange,
      regularMarketChangePercent: yfQuote.regularMarketChangePercent,
      regularMarketVolume: yfQuote.regularMarketVolume,
      regularMarketOpen: yfQuote.regularMarketOpen,
      regularMarketDayHigh: yfQuote.regularMarketDayHigh,
      regularMarketDayLow: yfQuote.regularMarketDayLow,
      regularMarketPreviousClose: yfQuote.regularMarketPreviousClose
    )
  
  proc fetchHistoryYfnim*(ds: DataStream, startTime, endTime: int64): seq[OHLCV] =
    ## Fetch historical data using yfnim
    let intervalStr = $ds.interval
    let history = yfnim.getHistory(ds.symbol, intervalStr, startTime, endTime)
    result = convertYfnimToOHLCV(history)
  
  proc fetchQuoteYfnim*(symbol: string): Quote =
    ## Fetch current quote using yfnim
    let yfQuote = yfnim.getQuote(symbol)
    result = convertYfnimToQuote(yfQuote)

else:
  # Fallback to mock data when yfnim is not available
  proc fetchHistoryYfnim*(ds: DataStream, startTime, endTime: int64): seq[OHLCV] =
    ## Fallback: Generate mock data
    result = generateMockOHLCV(ds.symbol, startTime, endTime, ds.interval)
  
  proc fetchQuoteYfnim*(symbol: string): Quote =
    ## Fallback: Generate mock quote
    result = generateMockQuote(symbol)

# Main data fetching API

proc fetch*(ds: DataStream, startTime, endTime: int64): seq[OHLCV] =
  ## Fetch historical OHLCV data for the time range
  ## Uses cache if available and valid
  
  # Check if data is in cache
  if ds.isCached(startTime, endTime):
    return ds.getCached(startTime, endTime)
  
  # Fetch from Yahoo Finance (or mock)
  result = fetchHistoryYfnim(ds, startTime, endTime)
  
  # Add to cache
  ds.addToCache(result)

proc fetch*(ds: DataStream, days: int): seq[OHLCV] =
  ## Fetch historical data for the last N days
  let endTime = getTime().toUnix()
  let startTime = endTime - (days * 86400)
  result = ds.fetch(startTime, endTime)

proc latest*(ds: DataStream): OHLCV =
  ## Get the most recent OHLCV bar
  let data = ds.fetch(1)  # Get last day
  if data.len > 0:
    result = data[^1]
  else:
    raise newException(DataError, "No data available for " & ds.symbol)

proc getQuote*(symbol: string): Quote =
  ## Get current quote for a symbol
  result = fetchQuoteYfnim(symbol)

# Batch operations

proc fetchMultiple*(symbols: seq[string], startTime, endTime: int64, 
                   interval: Interval = Int1d): Table[string, seq[OHLCV]] =
  ## Fetch data for multiple symbols
  result = initTable[string, seq[OHLCV]]()
  
  for symbol in symbols:
    let ds = newDataStream(symbol, interval)
    result[symbol] = ds.fetch(startTime, endTime)

proc getQuotes*(symbols: seq[string]): Table[string, Quote] =
  ## Get quotes for multiple symbols
  result = initTable[string, Quote]()
  
  for symbol in symbols:
    result[symbol] = getQuote(symbol)

# Iterator interface

iterator stream*(ds: DataStream, startTime, endTime: int64): OHLCV =
  ## Stream OHLCV data one bar at a time
  let data = ds.fetch(startTime, endTime)
  for bar in data:
    yield bar

# String representations

proc `$`*(interval: Interval): string =
  ## String representation of Interval
  case interval
  of Int1m: result = "1m"
  of Int5m: result = "5m"
  of Int15m: result = "15m"
  of Int30m: result = "30m"
  of Int1h: result = "1h"
  of Int1d: result = "1d"
  of Int1wk: result = "1wk"
  of Int1mo: result = "1mo"

proc `$`*(quote: Quote): string =
  ## String representation of Quote
  result = "Quote(" & quote.symbol & 
           " $" & $quote.regularMarketPrice & 
           " " & (if quote.regularMarketChange >= 0: "+" else: "") & 
           $quote.regularMarketChange & 
           " (" & (if quote.regularMarketChangePercent >= 0: "+" else: "") &
           formatFloat(quote.regularMarketChangePercent, ffDecimal, 2) & "%)" &
           ")"

proc `$`*(ds: DataStream): string =
  ## String representation of DataStream
  result = "DataStream(" & ds.symbol & 
           ", " & $ds.interval & 
           ", cached: " & $ds.cache.len & " bars)"
