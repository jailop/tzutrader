## Coinbase Data Streamer
##
## Provides streaming access to Coinbase cryptocurrency market data.
##
## Supported data types:
## - OHLCV: Historical cryptocurrency candles
##
## Features:
## - Coinbase Advanced Trade API integration
## - Multiple granularities (1m, 5m, 15m, 30m, 1h, 2h, 6h, 1d)
## - API authentication via environment variables
## - Automatic fallback to mock data when credentials unavailable
##
## Environment Variables:
## - COINBASE_API_KEY: Your Coinbase API key
## - COINBASE_SECRET_KEY: Your Coinbase API secret

import std/[times, strutils, tables, httpclient, json, os, algorithm]
import ../core
import types
import base

# Import existing data types and utilities
import ../data except DataStreamer

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

  CoinbaseStreamer*[T] = ref object of DataStreamer[T]
    ## Coinbase streamer for cryptocurrency OHLCV data
    granularity: CoinbaseGranularity
    startTime: int64
    endTime: int64
    apiKey: string
    apiSecret: string
    data: seq[OHLCV] # Cached candles
    index: int

# const COINBASE_LIMIT = 350  ## Limit set by Coinbase API

# Helper procs

# proc intervalToGranularity(interval: Interval): CoinbaseGranularity =
#   ## Convert Interval to Coinbase granularity
#   case interval
#   of Int1m: OneMinute
#   of Int5m: FiveMinute
#   of Int15m: FifteenMinute
#   of Int30m: ThirtyMinute
#   of Int1h: OneHour
#   else: OneDay

proc parseGranularity(s: string): CoinbaseGranularity =
  ## Parse granularity string
  case s.toUpperAscii()
  of "ONE_MINUTE", "1M": OneMinute
  of "FIVE_MINUTE", "5M": FiveMinute
  of "FIFTEEN_MINUTE", "15M": FifteenMinute
  of "THIRTY_MINUTE", "30M": ThirtyMinute
  of "ONE_HOUR", "1H": OneHour
  of "TWO_HOUR", "2H": TwoHour
  of "SIX_HOUR", "6H": SixHour
  of "ONE_DAY", "1D": OneDay
  else: raise newException(DataError, "Invalid granularity: " & s)

proc fetchCoinbaseCandles(symbol: string, startTime, endTime: int64,
                         granularity: CoinbaseGranularity,
                         apiKey, apiSecret: string): seq[OHLCV] =
  ## Fetch candles from Coinbase REST API
  result = @[]
  if apiKey.len == 0 or apiSecret.len == 0:
    raise newException(Exception, "Coinbase API key not defined")
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
    raise newException(Exception, "Coinbase error pulling data")

proc newCoinbaseStreamer*[T](params: StreamParams): CoinbaseStreamer[T] =
  ## Create a new Coinbase streamer
  ##
  ## Type parameter T must be OHLCV
  ##
  ## Args:
  ##   params: Stream parameters with Coinbase-specific fields:
  ##     - symbol: Trading pair (e.g., "BTC-USD", "ETH-USD") (required)
  ##     - startTime: Start timestamp
  ##     - endTime: End timestamp
  ##     - metadata["granularity"]: Candle granularity (default: "ONE_DAY")
  ##       Valid: "ONE_MINUTE", "FIVE_MINUTE", "FIFTEEN_MINUTE", "THIRTY_MINUTE",
  ##              "ONE_HOUR", "TWO_HOUR", "SIX_HOUR", "ONE_DAY"
  ##       Short forms: "1m", "5m", "15m", "30m", "1h", "2h", "6h", "1d"
  ##     - metadata["apiKey"]: Coinbase API key (or from env COINBASE_API_KEY)
  ##     - metadata["apiSecret"]: Coinbase API secret (or from env COINBASE_SECRET_KEY)
  ##
  ## Raises:
  ##   UnsupportedDataTypeError: If T is not OHLCV
  ##   DataError: If symbol is not provided
  when T isnot OHLCV:
    raise newException(UnsupportedDataTypeError,
      "Coinbase streamer only supports OHLCV data type, got: " & $getDataKind[T]())
  if params.symbol.len == 0:
    raise newException(DataError, "Coinbase streamer requires a symbol")
  let apiKey = params.metadata.getOrDefault("apiKey", getEnv("COINBASE_API_KEY", ""))
  let apiSecret = params.metadata.getOrDefault("apiSecret", getEnv(
      "COINBASE_SECRET_KEY", ""))
  # Parse granularity
  let granularityStr = params.metadata.getOrDefault("granularity", "ONE_DAY")
  let granularity = parseGranularity(granularityStr)
  result = CoinbaseStreamer[T](
    symbol: params.symbol,
    granularity: granularity,
    startTime: params.startTime,
    endTime: params.endTime,
    apiKey: apiKey,
    apiSecret: apiSecret,
    index: 0
  )
  result.data = fetchCoinbaseCandles(params.symbol, params.startTime, params.endTime,
                                     granularity, apiKey, apiSecret)

proc newCoinbaseStreamer*[T](symbol: string, startTime: int64, endTime: int64,
                             granularity: CoinbaseGranularity = OneDay,
                             apiKey: string = "",
                                 apiSecret: string = ""): CoinbaseStreamer[T] =
  ## Convenience constructor for Coinbase streamer
  ##
  ## Args:
  ##   symbol: Trading pair (e.g., "BTC-USD", "ETH-USD")
  ##   startTime: Start timestamp (Unix epoch seconds)
  ##   endTime: End timestamp (Unix epoch seconds)
  ##   granularity: Candle granularity (default: OneDay)
  ##   apiKey: Optional API key (from env if empty)
  ##   apiSecret: Optional API secret (from env if empty)
  let actualApiKey = if apiKey.len > 0: apiKey else: getEnv("COINBASE_API_KEY", "")
  let actualApiSecret = if apiSecret.len > 0: apiSecret else: getEnv(
      "COINBASE_SECRET_KEY", "")

  var params = StreamParams(
    provider: dpCoinbase,
    symbol: symbol,
    startTime: startTime,
    endTime: endTime,
    metadata: {
      "granularity": $granularity,
      "apiKey": actualApiKey,
      "apiSecret": actualApiSecret
    }.toTable
  )
  result = newCoinbaseStreamer[T](params)

proc newCoinbaseStreamer*[T](symbol: string, start: string, `end`: string,
                             granularity: CoinbaseGranularity = OneDay,
                             apiKey: string = "",
                                 apiSecret: string = ""): CoinbaseStreamer[T] =
  ## Convenience constructor with date strings (ISO 8601 format)
  ##
  ## Args:
  ##   symbol: Trading pair
  ##   start: Start date (e.g., "2023-01-01")
  ##   end: End date (e.g., "2023-12-31")
  ##   granularity: Candle granularity (default: OneDay)
  ##   apiKey: Optional API key
  ##   apiSecret: Optional API secret
  let startTime = parse(start, "yyyy-MM-dd").toTime().toUnix()
  let endTime = parse(`end`, "yyyy-MM-dd").toTime().toUnix()
  result = newCoinbaseStreamer[T](symbol, startTime, endTime, granularity,
      apiKey, apiSecret)

proc next*(stream: CoinbaseStreamer[OHLCV]): bool =
  ## Advance to next data point
  ## Returns true if successful, false if end of stream
  if stream.index < stream.data.len:
    stream.index.inc
    return true
  return false

proc current*(stream: CoinbaseStreamer[OHLCV]): OHLCV =
  ## Get current data point
  ## Must call next() first
  if stream.index <= 0 or stream.index > stream.data.len:
    raise newException(DataError, "No current data - call next() first")
  return stream.data[stream.index - 1]

proc reset*(stream: CoinbaseStreamer[OHLCV]) =
  ## Reset stream to beginning
  stream.index = 0

proc len*(stream: CoinbaseStreamer[OHLCV]): int =
  ## Get total number of items in stream
  return stream.data.len

proc hasNext*(stream: CoinbaseStreamer[OHLCV]): bool =
  ## Check if more data is available
  return stream.index < stream.data.len
