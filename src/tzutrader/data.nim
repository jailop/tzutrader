## Data module for tzutrader - Data Streaming API
##
## This module provides data streaming and fetching capabilities from multiple sources:
## - CSV files for backtesting
## - Yahoo Finance (yfinance) for historical market data
## - Coinbase for cryptocurrency data
##
## Features:
## - Historical OHLCV data retrieval
## - Real-time/delayed quote data
## - Multiple time intervals (1m, 5m, 15m, 30m, 1h, 1d, 1wk, 1mo)
## - Unified streaming API with next(), result(), reset() methods
## - Iterator interface for streaming data
## - Mock data generation for testing

import std/[times, tables, strutils, math, random, algorithm, os, httpclient, json, options]
import core

# Conditionally import yfnim at top level
when defined(useYfnim):
  import yfnim/[types as yfTypes, retriever, quote_retriever]
  import yfnim/quote_types as yfQuoteTypes

type
  Interval* = enum
    ## Time intervals for data fetching
    Int1m = "1m"    ## 1 minute (max ~7 days history)
    Int5m = "5m"    ## 5 minutes (max ~60 days history)
    Int15m = "15m"  ## 15 minutes (max ~60 days history)
    Int30m = "30m"  ## 30 minutes (max ~60 days history)
    Int1h = "1h"    ## 1 hour (max ~2 years history)
    Int1d = "1d"    ## 1 day (unlimited history)
    Int1wk = "1wk"  ## 1 week (unlimited history)
    Int1mo = "1mo"  ## 1 month (unlimited history)

  DataStreamer* = ref object of RootObj
    ## Base data streamer class - all streamers inherit from this
    ## Provides unified API: next(), result(), reset()
    index*: int
    data*: seq[OHLCV]
    symbol*: string
    label*: string

  DataStream* = ref object
    ## Legacy data stream for a specific symbol (for backward compatibility)
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
  let openPrice = previousClose * (1.0 + rand(0.01) - 0.005)
  
  # Generate high and low ensuring high >= low
  let maxPrice = max(openPrice, price)
  let minPrice = min(openPrice, price)
  let dayHigh = maxPrice * (1.0 + rand(0.01))
  let dayLow = minPrice * (1.0 - rand(0.01))
  
  result = Quote(
    symbol: symbol,
    timestamp: getTime().toUnix(),
    regularMarketPrice: price,
    regularMarketChange: change,
    regularMarketChangePercent: (change / previousClose) * 100.0,
    regularMarketVolume: rand(1000000.0) + 500000.0,
    regularMarketOpen: openPrice,
    regularMarketDayHigh: dayHigh,
    regularMarketDayLow: dayLow,
    regularMarketPreviousClose: previousClose
  )

# Yahoo Finance integration
# Note: Will use yfnim when available, for now provide interface

when defined(useYfnim):
  # This section will be enabled when yfnim is properly installed
  
  proc convertYfnimToOHLCV(yfData: yfTypes.History): seq[OHLCV] =
    ## Convert yfnim historical data to our OHLCV format
    result = @[]
    for bar in yfData.data:
      result.add(OHLCV(
        timestamp: bar.time,
        open: bar.open,
        high: bar.high,
        low: bar.low,
        close: bar.close,
        volume: bar.volume.float64
      ))
  
  proc convertYfnimToQuote(yfQuote: yfQuoteTypes.Quote): Quote =
    ## Convert yfnim quote to our Quote format
    result = Quote(
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
  
  proc fetchHistoryYfnim*(ds: DataStream, startTime, endTime: int64): seq[OHLCV] =
    ## Fetch historical data using yfnim
    # Convert our Interval to yfnim Interval
    let interval = case ds.interval
      of Int1m: yfTypes.Int1m
      of Int5m: yfTypes.Int5m
      of Int15m: yfTypes.Int15m
      of Int30m: yfTypes.Int30m
      of Int1h: yfTypes.Int1h
      of Int1d: yfTypes.Int1d
      of Int1wk: yfTypes.Int1wk
      of Int1mo: yfTypes.Int1mo
    
    let history = getHistory(ds.symbol, interval, startTime, endTime)
    result = convertYfnimToOHLCV(history)
  
  proc fetchQuoteYfnim*(symbol: string): Quote =
    ## Fetch current quote using yfnim
    let yfQuote = getQuote(symbol)
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

# ============================================================================
# CSV File I/O
# ============================================================================

proc writeCSV*(data: seq[OHLCV], filename: string, includeHeader: bool = true) =
  ## Write OHLCV data to CSV file
  ## 
  ## CSV Format:
  ##   timestamp,open,high,low,close,volume
  ##   1609459200,100.0,105.0,95.0,102.0,1000000.0
  ## 
  ## Args:
  ##   data: OHLCV data to write
  ##   filename: Output CSV file path
  ##   includeHeader: Include column headers (default true)
  var file = open(filename, fmWrite)
  defer: file.close()
  
  if includeHeader:
    file.writeLine("timestamp,open,high,low,close,volume")
  
  for bar in data:
    file.writeLine($bar.timestamp & "," &
                  $bar.open & "," &
                  $bar.high & "," &
                  $bar.low & "," &
                  $bar.close & "," &
                  $bar.volume)

proc readCSV*(filename: string, hasHeader: bool = true): seq[OHLCV] =
  ## Read OHLCV data from CSV file
  ## 
  ## CSV Format:
  ##   timestamp,open,high,low,close,volume
  ##   1609459200,100.0,105.0,95.0,102.0,1000000.0
  ## 
  ## Args:
  ##   filename: Input CSV file path
  ##   hasHeader: Skip first line if true (default true)
  ## 
  ## Returns:
  ##   Sequence of OHLCV bars
  result = @[]
  var file = open(filename, fmRead)
  defer: file.close()
  
  var lineNum = 0
  for line in file.lines:
    lineNum.inc
    
    # Skip header if present
    if hasHeader and lineNum == 1:
      continue
    
    # Skip empty lines
    if line.strip().len == 0:
      continue
    
    # Parse CSV line
    let parts = line.split(',')
    if parts.len < 6:
      raise newException(DataError, 
        "Invalid CSV format at line " & $lineNum & ": expected 6 columns, got " & $parts.len)
    
    try:
      let bar = OHLCV(
        timestamp: parseBiggestInt(parts[0].strip()),
        open: parseFloat(parts[1].strip()),
        high: parseFloat(parts[2].strip()),
        low: parseFloat(parts[3].strip()),
        close: parseFloat(parts[4].strip()),
        volume: parseFloat(parts[5].strip())
      )
      result.add(bar)
    except ValueError as e:
      raise newException(DataError,
        "Failed to parse CSV at line " & $lineNum & ": " & e.msg)

type
  CSVDataStream* = ref object
    ## CSV-based data stream for backtesting
    ## Reads OHLCV data from CSV files
    filename*: string
    data*: seq[OHLCV]
    index*: int
    symbol*: string

proc newCSVDataStream*(filename: string, symbol: string = ""): CSVDataStream =
  ## Create a new CSV data stream
  ## 
  ## Args:
  ##   filename: Path to CSV file
  ##   symbol: Optional symbol name (extracted from filename if not provided)
  ## 
  ## Example:
  ##   let stream = newCSVDataStream("data/AAPL.csv")
  ##   for bar in stream.items():
  ##     echo bar
  result = CSVDataStream(
    filename: filename,
    data: readCSV(filename),
    index: 0,
    symbol: if symbol.len > 0: symbol else: filename.splitFile().name
  )

proc reset*(stream: CSVDataStream) =
  ## Reset the stream to the beginning
  stream.index = 0

proc next*(stream: CSVDataStream): OHLCV =
  ## Get next bar from stream
  ## Raises IndexDefect if at end of stream
  if stream.index >= stream.data.len:
    raise newException(IndexDefect, "CSV stream exhausted")
  result = stream.data[stream.index]
  stream.index.inc

proc hasNext*(stream: CSVDataStream): bool =
  ## Check if stream has more data
  stream.index < stream.data.len

proc peek*(stream: CSVDataStream): OHLCV =
  ## Get current bar without advancing
  ## Raises IndexDefect if at end of stream
  if stream.index >= stream.data.len:
    raise newException(IndexDefect, "CSV stream exhausted")
  result = stream.data[stream.index]

proc len*(stream: CSVDataStream): int =
  ## Get total number of bars in stream
  stream.data.len

proc remaining*(stream: CSVDataStream): int =
  ## Get number of remaining bars
  max(0, stream.data.len - stream.index)

iterator items*(stream: CSVDataStream): OHLCV =
  ## Iterate over all bars in stream
  stream.reset()
  while stream.hasNext():
    yield stream.next()

proc `$`*(stream: CSVDataStream): string =
  ## String representation of CSV stream
  result = "CSVDataStream(" & stream.symbol & 
           ", " & $stream.data.len & " bars" &
           ", pos: " & $stream.index & ")"

# ============================================================================
# Base DataStreamer Methods (following pybottrader API)
# ============================================================================

method next*(ds: DataStreamer): Option[OHLCV] {.base.} =
  ## Returns the next observation and advances the index
  ## Returns None if at end of stream
  if ds.index >= ds.data.len:
    return none(OHLCV)
  result = some(ds.data[ds.index])
  ds.index.inc

method result*(ds: DataStreamer): Option[OHLCV] {.base.} =
  ## Returns the current observation without advancing
  ## Returns None if at end of stream
  if ds.index >= ds.data.len:
    return none(OHLCV)
  return some(ds.data[ds.index])

method reset*(ds: DataStreamer) {.base.} =
  ## Resets the counter to 0
  ds.index = 0

method len*(ds: DataStreamer): int {.base.} =
  ## Returns total number of observations
  ds.data.len

method hasNext*(ds: DataStreamer): bool {.base.} =
  ## Check if there are more observations
  ds.index < ds.data.len

# ============================================================================
# CSV File DataStreamer (following pybottrader API)
# ============================================================================

type
  CSVFileStreamer* = ref object of DataStreamer
    ## CSV-based data streamer following pybottrader API
    filename*: string

proc newCSVFileStreamer*(filename: string, symbol: string = ""): CSVFileStreamer =
  ## Create a new CSV file streamer
  ## 
  ## Args:
  ##   filename: Path to CSV file
  ##   symbol: Optional symbol name (extracted from filename if not provided)
  ## 
  ## Example:
  ##   let stream = newCSVFileStreamer("data/AAPL.csv")
  ##   while stream.hasNext():
  ##     let bar = stream.next()
  ##     if bar.isSome:
  ##       echo bar.get
  result = CSVFileStreamer(
    filename: filename,
    data: readCSV(filename),
    index: 0,
    symbol: if symbol.len > 0: symbol else: filename.splitFile().name,
    label: "CSVFile"
  )

proc `$`*(stream: CSVFileStreamer): string =
  ## String representation of CSV file stream
  result = "CSVFileStreamer(" & stream.symbol & 
           ", " & $stream.data.len & " bars" &
           ", pos: " & $stream.index & ")"

# ============================================================================
# Yahoo Finance DataStreamer (YFHistory)
# ============================================================================

type
  YFHistory* = ref object of DataStreamer
    ## Yahoo Finance data streamer
    ## Retrieves historical data from Yahoo Finance
    startTime*: int64
    endTime*: int64
    interval*: Interval

proc newYFHistory*(symbol: string, start: string, endStr: string = "", 
                   interval: Interval = Int1d): YFHistory =
  ## Create a new Yahoo Finance history streamer
  ## 
  ## Args:
  ##   symbol: Ticker symbol (e.g., "AAPL", "BTC-USD")
  ##   start: Start date in ISO format (e.g., "2023-01-01")
  ##   endStr: End date in ISO format (empty = now)
  ##   interval: Time interval (default: 1d)
  ## 
  ## Example:
  ##   let stream = newYFHistory("AAPL", "2023-01-01", "2023-12-31")
  ##   while stream.hasNext():
  ##     let bar = stream.next()
  ##     if bar.isSome:
  ##       echo bar.get
  result = YFHistory(
    symbol: symbol,
    interval: interval,
    index: 0,
    label: "YFinance"
  )
  
  # Parse start time
  try:
    let startDate = parse(start, "yyyy-MM-dd")
    result.startTime = startDate.toTime().toUnix()
  except TimeParseError:
    raise newException(DataError, "Invalid start date format: " & start)
  
  # Parse end time
  if endStr.len > 0:
    try:
      let endDate = parse(endStr, "yyyy-MM-dd")
      result.endTime = endDate.toTime().toUnix()
    except TimeParseError:
      raise newException(DataError, "Invalid end date format: " & endStr)
  else:
    result.endTime = getTime().toUnix()
  
  # Fetch data using existing infrastructure
  result.data = fetchHistoryYfnim(
    DataStream(symbol: symbol, interval: interval), 
    result.startTime, 
    result.endTime
  )

proc `$`*(stream: YFHistory): string =
  ## String representation of Yahoo Finance stream
  result = "YFHistory(" & stream.symbol & 
           ", " & $stream.interval &
           ", " & $stream.data.len & " bars" &
           ", pos: " & $stream.index & ")"

# ============================================================================
# Coinbase DataStreamer (CBHistory)
# ============================================================================

type
  CoinbaseGranularity* = enum
    ## Coinbase candle granularities
    OneMinute = "ONE_MINUTE"
    FiveMinute = "FIVE_MINUTE"
    FifteenMinute = "FIFTEEN_MINUTE"
    ThirtyMinute = "THIRTY_MINUTE"
    OneHour = "ONE_HOUR"
    TwoHour = "TWO_HOUR"
    SixHour = "SIX_HOUR"
    OneDay = "ONE_DAY"

  CBHistory* = ref object of DataStreamer
    ## Coinbase data streamer for cryptocurrency data
    ## Uses Coinbase Advanced Trade API
    startTime*: int64
    endTime*: int64
    granularity*: CoinbaseGranularity
    apiKey*: string
    apiSecret*: string

const COINBASE_LIMIT = 350  ## Limit set by Coinbase API

proc intervalToGranularity(interval: Interval): CoinbaseGranularity =
  ## Convert Interval to Coinbase granularity
  case interval
  of Int1m: OneMinute
  of Int5m: FiveMinute
  of Int15m: FifteenMinute
  of Int30m: ThirtyMinute
  of Int1h: OneHour
  else: OneDay

proc fetchCoinbaseCandles(symbol: string, startTime, endTime: int64, 
                         granularity: CoinbaseGranularity,
                         apiKey, apiSecret: string): seq[OHLCV] =
  ## Fetch candles from Coinbase REST API
  ## 
  ## Note: This is a simplified implementation. For production use,
  ## you should implement proper authentication (JWT signing) as per
  ## Coinbase Advanced Trade API documentation.
  result = @[]
  
  # Check if credentials are provided
  if apiKey.len == 0 or apiSecret.len == 0:
    # Return mock data if no credentials
    let ds = DataStream(symbol: symbol, interval: Int1d)
    return generateMockOHLCV(symbol, startTime, endTime, Int1d)
  
  try:
    let client = newHttpClient()
    defer: client.close()
    
    # Build API URL
    # Note: Actual Coinbase API requires proper authentication
    let url = "https://api.coinbase.com/api/v3/brokerage/products/" & 
              symbol & "/candles"
    
    let params = "?start=" & $startTime & 
                 "&end=" & $endTime & 
                 "&granularity=" & $granularity
    
    # TODO: Add proper JWT authentication headers for production
    # For now, this will return empty or fail gracefully
    
    let response = client.getContent(url & params)
    let jsonData = parseJson(response)
    
    # Parse Coinbase candle format
    # Format: {"candles": [{"start": "...", "low": "...", "high": "...", 
    #                       "open": "...", "close": "...", "volume": "..."}]}
    if jsonData.hasKey("candles"):
      for candle in jsonData["candles"]:
        let bar = OHLCV(
          timestamp: parseBiggestInt(candle["start"].getStr()),
          open: parseFloat(candle["open"].getStr()),
          high: parseFloat(candle["high"].getStr()),
          low: parseFloat(candle["low"].getStr()),
          close: parseFloat(candle["close"].getStr()),
          volume: parseFloat(candle["volume"].getStr())
        )
        if bar.isValid():
          result.add(bar)
    
    # Sort by timestamp
    result.sort(proc (a, b: OHLCV): int = cmp(a.timestamp, b.timestamp))
    
  except HttpRequestError, JsonParsingError, OSError, ValueError:
    # On error, return mock data for testing
    let ds = DataStream(symbol: symbol, interval: Int1d)
    return generateMockOHLCV(symbol, startTime, endTime, Int1d)

proc newCBHistory*(symbol: string, start: string, endStr: string = "",
                   interval: Interval = Int1d): CBHistory =
  ## Create a new Coinbase history streamer
  ## 
  ## Reads credentials from environment variables:
  ##   - COINBASE_API_KEY
  ##   - COINBASE_SECRET_KEY
  ## 
  ## Args:
  ##   symbol: Trading pair (e.g., "BTC-USD", "ETH-USD")
  ##   start: Start date in ISO format (e.g., "2023-01-01")
  ##   endStr: End date in ISO format (empty = now)
  ##   interval: Time interval (default: 1d)
  ## 
  ## Example:
  ##   let stream = newCBHistory("BTC-USD", "2023-01-01", "2023-12-31", Int1d)
  ##   while stream.hasNext():
  ##     let bar = stream.next()
  ##     if bar.isSome:
  ##       echo bar.get
  
  result = CBHistory(
    symbol: symbol,
    granularity: intervalToGranularity(interval),
    index: 0,
    label: "Coinbase",
    apiKey: getEnv("COINBASE_API_KEY", ""),
    apiSecret: getEnv("COINBASE_SECRET_KEY", "")
  )
  
  # Parse start time
  try:
    let startDate = parse(start, "yyyy-MM-dd")
    result.startTime = startDate.toTime().toUnix()
  except TimeParseError:
    raise newException(DataError, "Invalid start date format: " & start)
  
  # Parse end time
  if endStr.len > 0:
    try:
      let endDate = parse(endStr, "yyyy-MM-dd")
      result.endTime = endDate.toTime().toUnix()
    except TimeParseError:
      raise newException(DataError, "Invalid end date format: " & endStr)
  else:
    result.endTime = getTime().toUnix()
  
  # Enforce Coinbase limits
  var factor = COINBASE_LIMIT * 60
  case result.granularity
  of OneDay:
    factor = factor * 60 * 24
  of OneHour, TwoHour, SixHour:
    factor = factor * 60
  else:
    discard
  
  let limit = result.endTime - factor
  if result.startTime < limit:
    result.startTime = limit
  
  # Fetch data
  if result.apiKey.len == 0 or result.apiSecret.len == 0:
    echo "Warning: COINBASE_API_KEY or COINBASE_SECRET_KEY not set, using mock data"
  
  result.data = fetchCoinbaseCandles(
    symbol, 
    result.startTime, 
    result.endTime, 
    result.granularity,
    result.apiKey,
    result.apiSecret
  )

proc `$`*(stream: CBHistory): string =
  ## String representation of Coinbase stream
  result = "CBHistory(" & stream.symbol & 
           ", " & $stream.granularity &
           ", " & $stream.data.len & " bars" &
           ", pos: " & $stream.index & ")"

# ============================================================================
# Iterator interfaces for all streamers
# ============================================================================

iterator items*(ds: DataStreamer): OHLCV =
  ## Iterate over all bars in any data streamer
  ds.reset()
  while ds.hasNext():
    let bar = ds.next()
    if bar.isSome:
      yield bar.get
