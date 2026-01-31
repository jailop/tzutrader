## Base strategy types and interface for tzutrader strategies
##
## This module defines the base Strategy class that all strategies inherit from.
##
## Multi-Data Support:
## - Strategies can declare requirements for multiple data types (OHLCV, Quote, etc.)
## - DataContext provides synchronized multi-data access
## - Three callback patterns:
##   1. Single data: on[T](data: T) - for simple strategies
##   2. Multi-data: onData(ctx: DataContext) - for complex strategies
##   3. Legacy: onBar(bar: OHLCV) - for backward compatibility

import std/[tables]
import ../core
from ../data import Quote
from ../datastreamers/types import DataKind, DataProvider

export core, Quote, DataKind, DataProvider

type
  DataFrequency* = enum
    ## Data frequency/timeframe requirements
    dfRealtime   ## Real-time tick data
    dfMinute     ## Minute bars (1m, 5m, etc.)
    dfHourly     ## Hourly bars
    dfDaily      ## Daily bars
    dfWeekly     ## Weekly bars
  
  DataRequirement* = object
    ## Declares a data type requirement for a strategy
    dataKind*: DataKind             ## Type of data needed (OHLCV, Quote, etc.)
    providers*: seq[DataProvider]   ## Preferred providers (in order of preference)
    required*: bool                 ## Is this data required or optional?
    frequency*: DataFrequency       ## Desired frequency
    metadata*: Table[string, string]  ## Provider-specific configuration
  
  DataValue* = object
    ## Variant object (discriminated union) for holding any data type
    ## Stack-allocated, no heap/pointers needed
    case kind*: DataKind
    of dkOHLCV:
      ohlcv*: OHLCV
    of dkQuote:
      quote*: Quote
    of dkTick, dkOrderBook, dkTrades, dkGreeks, dkFundamentals:
      # Future data types - placeholder for now
      # Will be implemented when providers support these types
      discard
  
  DataContext* = object
    ## Transient object containing synchronized multi-type data
    ## Only lives during callback, then discarded
    ## Backtester creates this for each time point
    timestamp*: int64        ## Unix timestamp (derived from data)
    data*: seq[DataValue]    ## All data items at this timestamp
  
  PositionSizingType* = enum
    ## How the strategy calculates position sizes
    pstDefault,   ## Use backtester default (95% of cash)
    pstFixed,     ## Fixed number of shares
    pstPercent    ## Percentage of portfolio equity
  
  Strategy* = ref object of RootObj
    ## Base strategy class
    ## All strategies should inherit from this
    ## Strategies are streaming-only and maintain minimal state
    name*: string
    symbol*: string

# Helper constructors for DataValue and DataContext

proc newDataValue*(ohlcv: OHLCV): DataValue =
  ## Create a DataValue containing OHLCV data
  DataValue(kind: dkOHLCV, ohlcv: ohlcv)

proc newDataValue*(quote: Quote): DataValue =
  ## Create a DataValue containing Quote data
  DataValue(kind: dkQuote, quote: quote)

proc newDataContext*(timestamp: int64, data: seq[DataValue]): DataContext =
  ## Create a DataContext with synchronized data
  DataContext(timestamp: timestamp, data: data)

proc newDataContext*(ohlcv: OHLCV): DataContext =
  ## Create a DataContext from a single OHLCV bar
  ## Convenience constructor for simple strategies
  DataContext(
    timestamp: ohlcv.timestamp,
    data: @[newDataValue(ohlcv)]
  )

proc newDataRequirement*(
  dataKind: DataKind,
  providers: seq[DataProvider] = @[],
  required: bool = true,
  frequency: DataFrequency = dfDaily,
  metadata: Table[string, string] = initTable[string, string]()
): DataRequirement =
  ## Create a DataRequirement specification
  DataRequirement(
    dataKind: dataKind,
    providers: providers,
    required: required,
    frequency: frequency,
    metadata: metadata
  )

# DataContext access helpers

proc hasData*(ctx: DataContext, kind: DataKind): bool =
  ## Check if DataContext contains data of specified kind
  for value in ctx.data:
    if value.kind == kind:
      return true
  return false

proc getData*(ctx: DataContext, kind: DataKind): DataValue =
  ## Get first data item of specified kind from DataContext
  ## Raises ValueError if kind not found
  for value in ctx.data:
    if value.kind == kind:
      return value
  raise newException(ValueError, "DataContext does not contain data of kind: " & $kind)

proc tryGetData*(ctx: DataContext, kind: DataKind): tuple[found: bool, value: DataValue] =
  ## Try to get data of specified kind, returns (found, value) tuple
  for value in ctx.data:
    if value.kind == kind:
      return (true, value)
  return (false, DataValue(kind: dkOHLCV))  # Default empty value

proc getOHLCV*(ctx: DataContext): OHLCV =
  ## Convenience: Extract OHLCV from DataContext
  let value = ctx.getData(dkOHLCV)
  if value.kind != dkOHLCV:
    raise newException(ValueError, "Expected OHLCV data")
  return value.ohlcv

proc getQuote*(ctx: DataContext): Quote =
  ## Convenience: Extract Quote from DataContext
  let value = ctx.getData(dkQuote)
  if value.kind != dkQuote:
    raise newException(ValueError, "Expected Quote data")
  return value.quote

# Base procs that all strategies must implement

proc name*(s: Strategy): string =
  ## Get strategy name
  s.name

proc getDataRequirements*(s: Strategy): seq[DataRequirement] =
  ## Declare data requirements for this strategy
  ## 
  ## Default: Returns single OHLCV requirement for backward compatibility
  ## Override this in strategies that need multiple data types
  ## 
  ## Example:
  ##   proc getDataRequirements*(s: MyStrategy): seq[DataRequirement] =
  ##     @[
  ##       newDataRequirement(dkOHLCV, required = true, frequency = dfDaily),
  ##       newDataRequirement(dkQuote, required = false, frequency = dfRealtime)
  ##     ]
  @[newDataRequirement(dkOHLCV, required = true, frequency = dfDaily)]

proc on*(s: Strategy, bar: OHLCV): Signal =
  ## Callback for OHLCV data (new pattern)
  ## 
  ## This is the primary callback for strategies that work with OHLCV bars.
  ## 
  ## Args:
  ##   bar: Single OHLCV bar
  ## 
  ## Returns:
  ##   Signal with position recommendation
  ## 
  ## Example:
  ##   proc on*(s: RSIStrategy, bar: OHLCV): Signal =
  ##     s.rsi.update(bar.close)
  ##     if s.rsi.value < 30: return newSignal(Buy, s.symbol, bar.close)
  ##     elif s.rsi.value > 70: return newSignal(Sell, s.symbol, bar.close)
  ##     else: return newSignal(Stay, s.symbol, bar.close)
  raise newException(StrategyError, "on(OHLCV) not implemented for " & s.name)

proc on*(s: Strategy, quote: Quote): Signal =
  ## Callback for Quote data (new pattern)
  ## 
  ## This is the primary callback for strategies that work with real-time quotes.
  ## 
  ## Args:
  ##   quote: Single Quote
  ## 
  ## Returns:
  ##   Signal with position recommendation
  ## 
  ## Example:
  ##   proc on*(s: ScalpStrategy, quote: Quote): Signal =
  ##     let spread = quote.regularMarketDayHigh - quote.regularMarketDayLow
  ##     if spread > s.threshold:
  ##       return newSignal(Buy, s.symbol, quote.regularMarketPrice)
  ##     else:
  ##       return newSignal(Stay, s.symbol, quote.regularMarketPrice)
  raise newException(StrategyError, "on(Quote) not implemented for " & s.name)

proc onData*(s: Strategy, ctx: DataContext): Signal =
  ## Process synchronized multi-data context (new pattern)
  ## 
  ## This callback is for advanced strategies that need multiple data types
  ## simultaneously (e.g., OHLCV + Quote + OrderBook).
  ## 
  ## Args:
  ##   ctx: DataContext containing all synchronized data at a single timestamp
  ## 
  ## Returns:
  ##   Signal with position recommendation
  ## 
  ## Example:
  ##   proc onData*(s: ArbitrageStrategy, ctx: DataContext): Signal =
  ##     let bar = ctx.getOHLCV()
  ##     let quote = ctx.getQuote()
  ##     let spread = quote.regularMarketDayHigh - quote.regularMarketDayLow
  ##     if spread > s.threshold:
  ##       return newSignal(Buy, s.symbol, bar.close)
  ##     else:
  ##       return newSignal(Stay, s.symbol, bar.close)
  
  # Default: Extract OHLCV and delegate to on(OHLCV)
  if ctx.hasData(dkOHLCV):
    let bar = ctx.getOHLCV()
    return s.on(bar)
  else:
    raise newException(StrategyError, "onData() requires at least OHLCV data")

proc onBar*(s: Strategy, bar: OHLCV): Signal =
  ## Process a single bar and generate signal (legacy streaming mode)
  ## 
  ## **BACKWARD COMPATIBILITY**: This proc is maintained for existing strategies.
  ## It now delegates to the on(OHLCV) proc.
  ## 
  ## Args:
  ##   bar: Single OHLCV bar
  ## 
  ## Returns:
  ##   Signal with position recommendation
  s.on(bar)

proc analyze*(s: Strategy, data: seq[OHLCV]): seq[Signal] =
  ## Analyze historical data and generate signals for each bar (batch mode)
  ## 
  ## **DEPRECATED**: Batch mode is deprecated. Use streaming onBar() instead.
  ## 
  ## This proc processes all historical data at once. For real-time trading
  ## or more memory-efficient processing, use the onBar() proc with streaming data.
  ## 
  ## Args:
  ##   data: Historical OHLCV data
  ## 
  ## Returns:
  ##   Sequence of signals, one for each bar
  raise newException(StrategyError, "analyze() batch mode is deprecated. Use onBar() for streaming mode.")

proc reset*(s: Strategy) =
  ## Reset strategy state (for streaming mode)
  discard

proc getPositionSizing*(s: Strategy): tuple[sizingType: PositionSizingType, value: float] =
  ## Get position sizing preference for this strategy
  ## 
  ## Returns:
  ##   Tuple of (sizing type, value):
  ##   - (pstDefault, 0.0): Use backtester default (95% of cash)
  ##   - (pstFixed, N): Use fixed N shares
  ##   - (pstPercent, P): Use P percent of portfolio equity
  ## 
  ## Default implementation returns pstDefault
  result = (pstDefault, 0.0)

# String representations

proc `$`*(freq: DataFrequency): string =
  ## String representation of DataFrequency
  case freq
  of dfRealtime: "realtime"
  of dfMinute: "minute"
  of dfHourly: "hourly"
  of dfDaily: "daily"
  of dfWeekly: "weekly"

proc `$`*(req: DataRequirement): string =
  ## String representation of DataRequirement
  result = "DataRequirement(kind=" & $req.dataKind & 
           ", required=" & $req.required &
           ", freq=" & $req.frequency
  if req.providers.len > 0:
    result &= ", providers=["
    for i, p in req.providers:
      if i > 0: result &= ", "
      result &= $p
    result &= "]"
  result &= ")"

proc `$`*(value: DataValue): string =
  ## String representation of DataValue
  case value.kind
  of dkOHLCV: "DataValue(OHLCV: " & $value.ohlcv & ")"
  of dkQuote: "DataValue(Quote: " & $value.quote & ")"
  else: "DataValue(" & $value.kind & ")"

proc `$`*(ctx: DataContext): string =
  ## String representation of DataContext
  result = "DataContext(timestamp=" & $ctx.timestamp & 
           ", data=[" & $ctx.data.len & " items])"
