## Tests for Multi-Data Strategy Infrastructure
##
## This test suite verifies:
## 1. DataValue variant object construction
## 2. DataContext with multiple data types
## 3. Concrete on(OHLCV) and on(Quote) methods
## 4. onData() multi-data callback
## 5. Backward compatibility with onBar()
## 6. DataRequirement declarations

import std/[unittest, tables, strutils]
import ../src/tzutrader/[core, data, strategies/base]
import ../src/tzutrader/datastreamers/types

# Helper to create sample OHLCV bar
proc createSampleBar(timestamp: int64 = 1704067200, price: float64 = 100.0): OHLCV =
  OHLCV(
    timestamp: timestamp,
    open: price,
    high: price * 1.02,
    low: price * 0.98,
    close: price * 1.01,
    volume: 1000000.0
  )

# Helper to create sample Quote
proc createSampleQuote(timestamp: int64 = 1704067200, price: float64 = 100.0): Quote =
  Quote(
    symbol: "AAPL",
    timestamp: timestamp,
    regularMarketPrice: price,
    regularMarketChange: 1.5,
    regularMarketChangePercent: 1.5,
    regularMarketVolume: 50000000.0,
    regularMarketOpen: price - 0.5,
    regularMarketDayHigh: price * 1.02,
    regularMarketDayLow: price * 0.98,
    regularMarketPreviousClose: price - 1.5
  )

# Test Strategy Types (must be at module level)
type
  SimpleOHLCVStrategy = ref object of Strategy
    callCount: int

method on*(s: SimpleOHLCVStrategy, bar: OHLCV): Signal =
  s.callCount.inc
  newSignal(Stay, "TEST", bar.close, "Simple OHLCV strategy")

type
  MultiDataStrategy = ref object of Strategy
    onDataCalled: bool

method onData*(s: MultiDataStrategy, ctx: DataContext): Signal =
  s.onDataCalled = true
  let bar = ctx.getOHLCV()
  
  if ctx.hasData(dkQuote):
    let quote = ctx.getQuote()
    # Use both OHLCV and Quote data
    let spread = quote.regularMarketDayHigh - quote.regularMarketDayLow
    if spread > 2.0:
      return newSignal(Buy, "TEST", bar.close, "Large spread detected")
  
  newSignal(Stay, "TEST", bar.close, "Multi-data strategy")

type
  CustomRequirementsStrategy = ref object of Strategy

method getDataRequirements*(s: CustomRequirementsStrategy): seq[DataRequirement] =
  @[
    newDataRequirement(dkOHLCV, providers = @[dpYahoo], frequency = dfDaily),
    newDataRequirement(dkQuote, providers = @[dpYahoo], frequency = dfRealtime, required = false)
  ]

method on*(s: CustomRequirementsStrategy, bar: OHLCV): Signal =
  newSignal(Stay, "TEST", bar.close)

type
  LegacyStrategy = ref object of Strategy

method on*(s: LegacyStrategy, bar: OHLCV): Signal =
  # This is what old strategies do - just implement the callback
  newSignal(Buy, "LEGACY", bar.close, "Legacy strategy")

# Test Suite
suite "Multi-Data Strategy Infrastructure Tests":
  
  test "DataValue - OHLCV Construction":
    let bar = createSampleBar()
    let value = newDataValue(bar)
    
    check:
      value.kind == dkOHLCV
      value.ohlcv.timestamp == bar.timestamp
      value.ohlcv.close == bar.close
  
  test "DataValue - Quote Construction":
    let quote = createSampleQuote()
    let value = newDataValue(quote)
    
    check:
      value.kind == dkQuote
      value.quote.symbol == "AAPL"
      value.quote.regularMarketPrice == 100.0
  
  test "DataValue - String Representation":
    let bar = createSampleBar()
    let value = newDataValue(bar)
    let str = $value
    
    check:
      "DataValue" in str
      "OHLCV" in str
  
  test "DataContext - Single OHLCV Construction":
    let bar = createSampleBar()
    let ctx = newDataContext(bar)
    
    check:
      ctx.timestamp == bar.timestamp
      ctx.data.len == 1
      ctx.data[0].kind == dkOHLCV
  
  test "DataContext - Multi-Data Construction":
    let timestamp: int64 = 1704067200
    let bar = createSampleBar(timestamp)
    let quote = createSampleQuote(timestamp)
    
    let ctx = newDataContext(timestamp, @[
      newDataValue(bar),
      newDataValue(quote)
    ])
    
    check:
      ctx.timestamp == timestamp
      ctx.data.len == 2
      ctx.data[0].kind == dkOHLCV
      ctx.data[1].kind == dkQuote
  
  test "DataContext - hasData()":
    let bar = createSampleBar()
    let quote = createSampleQuote()
    let ctx = newDataContext(1704067200, @[
      newDataValue(bar),
      newDataValue(quote)
    ])
    
    check:
      ctx.hasData(dkOHLCV)
      ctx.hasData(dkQuote)
      not ctx.hasData(dkTick)
      not ctx.hasData(dkOrderBook)
  
  test "DataContext - getData()":
    let bar = createSampleBar()
    let quote = createSampleQuote()
    let ctx = newDataContext(1704067200, @[
      newDataValue(bar),
      newDataValue(quote)
    ])
    
    let ohlcvValue = ctx.getData(dkOHLCV)
    let quoteValue = ctx.getData(dkQuote)
    
    check:
      ohlcvValue.kind == dkOHLCV
      quoteValue.kind == dkQuote
      ohlcvValue.ohlcv.close == bar.close
      quoteValue.quote.symbol == "AAPL"
  
  test "DataContext - getData() Not Found":
    let bar = createSampleBar()
    let ctx = newDataContext(bar)
    
    expect ValueError:
      discard ctx.getData(dkQuote)
  
  test "DataContext - tryGetData()":
    let bar = createSampleBar()
    let ctx = newDataContext(bar)
    
    let (found1, value1) = ctx.tryGetData(dkOHLCV)
    let (found2, value2) = ctx.tryGetData(dkQuote)
    
    check:
      found1 == true
      value1.kind == dkOHLCV
      found2 == false
  
  test "DataContext - getOHLCV() Helper":
    let bar = createSampleBar()
    let ctx = newDataContext(bar)
    
    let extracted = ctx.getOHLCV()
    
    check:
      extracted.timestamp == bar.timestamp
      extracted.close == bar.close
  
  test "DataContext - getQuote() Helper":
    let quote = createSampleQuote()
    let ctx = newDataContext(1704067200, @[newDataValue(quote)])
    
    let extracted = ctx.getQuote()
    
    check:
      extracted.symbol == "AAPL"
      extracted.regularMarketPrice == 100.0
  
  test "DataContext - String Representation":
    let bar = createSampleBar()
    let ctx = newDataContext(bar)
    let str = $ctx
    
    check:
      "DataContext" in str
      "timestamp=" in str
      "data=[1 items]" in str
  
  test "DataRequirement - Construction":
    let req = newDataRequirement(
      dkOHLCV,
      providers = @[dpYahoo, dpCSV],
      required = true,
      frequency = dfDaily
    )
    
    check:
      req.dataKind == dkOHLCV
      req.providers.len == 2
      req.providers[0] == dpYahoo
      req.required == true
      req.frequency == dfDaily
  
  test "DataRequirement - Default Values":
    let req = newDataRequirement(dkQuote)
    
    check:
      req.dataKind == dkQuote
      req.providers.len == 0
      req.required == true
      req.frequency == dfDaily
  
  test "DataRequirement - With Metadata":
    var metadata = initTable[string, string]()
    metadata["interval"] = "1h"
    metadata["extended_hours"] = "true"
    
    let req = newDataRequirement(
      dkOHLCV,
      metadata = metadata
    )
    
    check:
      req.metadata.hasKey("interval")
      req.metadata["interval"] == "1h"
  
  test "DataRequirement - String Representation":
    let req = newDataRequirement(dkOHLCV, providers = @[dpYahoo])
    let str = $req
    
    check:
      "DataRequirement" in str
      "ohlcv" in str
      "required=true" in str
  
  test "DataFrequency - String Representation":
    check:
      $dfRealtime == "realtime"
      $dfMinute == "minute"
      $dfHourly == "hourly"
      $dfDaily == "daily"
      $dfWeekly == "weekly"
  
  test "Strategy - on(OHLCV) Callback":
    let strategy = SimpleOHLCVStrategy(name: "SimpleOHLCV", symbol: "TEST")
    let bar = createSampleBar()
    
    let signal = strategy.on(bar)
    
    check:
      signal.position == Stay
      signal.price == bar.close
      strategy.callCount == 1
  
  test "Strategy - onBar() Delegates to on(OHLCV)":
    let strategy = SimpleOHLCVStrategy(name: "SimpleOHLCV", symbol: "TEST")
    let bar = createSampleBar()
    
    # Call onBar (legacy method)
    let signal = strategy.onBar(bar)
    
    check:
      signal.position == Stay
      strategy.callCount == 1  # Should have called on(OHLCV)
  
  test "Strategy - onData() Multi-Data Callback":
    let strategy = MultiDataStrategy(name: "MultiData", symbol: "TEST")
    let bar = createSampleBar()
    let quote = createSampleQuote()
    let ctx = newDataContext(bar.timestamp, @[
      newDataValue(bar),
      newDataValue(quote)
    ])
    
    let signal = strategy.onData(ctx)
    
    check:
      strategy.onDataCalled == true
      signal.position == Buy  # Should trigger on spread > 2.0
      "spread" in signal.reason.toLowerAscii()
  
  test "Strategy - getDataRequirements() Default":
    let strategy = SimpleOHLCVStrategy(name: "Simple", symbol: "TEST")
    let requirements = strategy.getDataRequirements()
    
    check:
      requirements.len == 1
      requirements[0].dataKind == dkOHLCV
      requirements[0].required == true
  
  test "Strategy - getDataRequirements() Custom":
    let strategy = CustomRequirementsStrategy(name: "Custom", symbol: "TEST")
    let requirements = strategy.getDataRequirements()
    
    check:
      requirements.len == 2
      requirements[0].dataKind == dkOHLCV
      requirements[0].required == true
      requirements[0].frequency == dfDaily
      requirements[1].dataKind == dkQuote
      requirements[1].required == false
      requirements[1].frequency == dfRealtime
  
  test "Strategy - Backward Compatibility with Existing Strategies":
    let strategy = LegacyStrategy(name: "Legacy", symbol: "LEGACY")
    let bar = createSampleBar()
    
    # Old code calls onBar()
    let signal1 = strategy.onBar(bar)
    
    # New code calls on(OHLCV)
    let signal2 = strategy.on(bar)
    
    # Both should work identically
    check:
      signal1.position == Buy
      signal2.position == Buy
      signal1.position == signal2.position
  
  test "Strategy - onData() Default Implementation":
    # Strategy that only implements on(OHLCV) should work with onData()
    let strategy = SimpleOHLCVStrategy(name: "Simple", symbol: "TEST")
    let bar = createSampleBar()
    let ctx = newDataContext(bar)
    
    # onData() should delegate to on(OHLCV) by default
    let signal = strategy.onData(ctx)
    
    check:
      signal.position == Stay
      strategy.callCount == 1

when isMainModule:
  echo "Running Multi-Data Strategy Infrastructure Tests..."
  echo "==================================================="
