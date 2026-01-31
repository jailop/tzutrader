## Data Streamers - Core Types
##
## This module defines the core types for the generic data streaming system.
## It provides type-safe streaming of multiple data types (OHLCV, Quote, etc.)
## from various providers (CSV, Yahoo Finance, Coinbase, etc.)

import std/[tables, options]
import ../core

# Import Quote type from data module
from ../data import Quote

type
  DataKind* = enum
    ## Enumeration of supported data types
    ## Used for runtime capability checking
    dkOHLCV = "ohlcv"       # Candlestick/OHLC data
    dkQuote = "quote"       # Real-time quote data
    dkTick = "tick"         # Tick-by-tick data (future)
    dkOrderBook = "book"    # Order book snapshot (future)
    dkTrades = "trades"     # Trade history (future)
    dkGreeks = "greeks"     # Options Greeks (future)
    dkFundamentals = "fund" # Fundamental data (future)

  DataProvider* = enum
    ## Available data providers
    ## Provider is just a parameter - no factory objects needed!
    dpCSV = "csv"
    dpYahoo = "yahoo"
    dpCoinbase = "coinbase"

  StreamParams* = object
    ## Parameters for initializing a data stream
    provider*: DataProvider    # Which data source to use
    symbol*: string            # Symbol to stream
    startTime*: int64          # Start timestamp (0 = beginning)
    endTime*: int64            # End timestamp (high(int64) = unlimited)
    metadata*: Table[string, string]  # Provider-specific options and configuration

  UnsupportedDataTypeError* = object of DataError
    ## Exception raised when requesting unsupported data type
    dataKind*: DataKind
    provider*: DataProvider

# Type-to-Kind mapping (compile-time)
proc getDataKind*[T](): DataKind =
  ## Map type T to DataKind enum value at compile time
  when T is OHLCV:
    dkOHLCV
  elif T is Quote:
    dkQuote
  # Future types can be added here
  # elif T is Tick:
  #   dkTick
  # elif T is OrderBook:
  #   dkOrderBook
  else:
    {.error: "Unsupported data type for streaming".}

# Provider capability queries
proc supportedTypes*(provider: DataProvider): seq[DataKind] =
  ## Get list of types supported by provider
  case provider
  of dpCSV:
    @[dkOHLCV]
  of dpYahoo:
    @[dkOHLCV, dkQuote]
  of dpCoinbase:
    @[dkOHLCV]

proc supportsOHLCV*(provider: DataProvider): bool =
  ## Check if provider supports OHLCV data type
  dkOHLCV in provider.supportedTypes()

proc supportsQuote*(provider: DataProvider): bool =
  ## Check if provider supports Quote data type
  dkQuote in provider.supportedTypes()

template supports*(provider: DataProvider, T: typedesc): bool =
  ## Check if provider supports data type T
  when T is OHLCV:
    provider.supportsOHLCV()
  elif T is Quote:
    provider.supportsQuote()
  else:
    false

proc requireSupport*[T](provider: DataProvider) =
  ## Assert that provider supports type T, raise exception otherwise
  if not supports(provider, T):
    let dataKind = getDataKind[T]()
    raise newException(UnsupportedDataTypeError,
      "Provider '" & $provider & "' does not support data type: " & $dataKind)

# String representations
proc `$`*(kind: DataKind): string =
  ## String representation of DataKind
  case kind
  of dkOHLCV: "ohlcv"
  of dkQuote: "quote"
  of dkTick: "tick"
  of dkOrderBook: "orderbook"
  of dkTrades: "trades"
  of dkGreeks: "greeks"
  of dkFundamentals: "fundamentals"

proc `$`*(provider: DataProvider): string =
  ## String representation of DataProvider
  case provider
  of dpCSV: "CSV"
  of dpYahoo: "YahooFinance"
  of dpCoinbase: "Coinbase"
