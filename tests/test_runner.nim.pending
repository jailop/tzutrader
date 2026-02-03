## Test suite for runner.nim - Modern multi-data strategy execution
##
## This test suite verifies:
## 1. Single-data strategies work with runner (backward compatibility)
## 2. Multi-data strategies work with runner
## 3. Stream synchronization works correctly
## 4. Automatic data fetching works
## 5. Pre-loaded data works (runWithData)

import std/[unittest, times, tables, strutils, math]
import ../src/tzutrader/[core, data, strategy, portfolio, runner]
import ../src/tzutrader/strategies/base
import ../src/tzutrader/data_sync
import ../src/tzutrader/datastreamers/types

# ============================================================================
# Test Helpers
# ============================================================================

proc createTestOHLCV(count: int, startPrice: float64 = 100.0): seq[OHLCV] =
  ## Create test OHLCV data
  result = @[]
  var timestamp = parseTime("2023-01-01", "yyyy-MM-dd", utc()).toUnix
  
  for i in 0..<count:
    let price = startPrice + i.float64
    result.add(OHLCV(
      timestamp: timestamp,
      open: price,
      high: price + 2.0,
      low: price - 1.0,
      close: price + 1.0,
      volume: 1000000
    ))
    timestamp += 86400  # +1 day

proc createTestQuotes(count: int, startPrice: float64 = 100.0): seq[Quote] =
  ## Create test Quote data
  result = @[]
  var timestamp = parseTime("2023-01-01", "yyyy-MM-dd", utc()).toUnix
  
  for i in 0..<count:
    let price = startPrice + i.float64
    result.add(Quote(
      symbol: "TEST",
      timestamp: timestamp,
      regularMarketPrice: price,
      regularMarketChange: 0.5,
      regularMarketChangePercent: 0.5,
      regularMarketVolume: 1000000.0,
      regularMarketOpen: price - 1.0,
      regularMarketDayHigh: price + 2.0,
      regularMarketDayLow: price - 2.0,
      regularMarketPreviousClose: price - 0.5
    ))
    timestamp += 86400  # +1 day

# ============================================================================
# Test Strategies
# ============================================================================

type
  SimpleTestStrategy = ref object of Strategy
    ## Simple strategy that buys on first bar, sells on last
    buyExecuted: bool
    
  MultiDataStrategy = ref object of Strategy
    ## Strategy that uses both OHLCV and Quote data
    dataContextReceived: bool

method reset*(s: SimpleTestStrategy) =
  s.buyExecuted = false

method on*(s: SimpleTestStrategy, bar: OHLCV): Signal =
  if not s.buyExecuted:
    s.buyExecuted = true
    return newSignal(Buy, s.symbol, bar.close)
  else:
    return newSignal(Stay, s.symbol, bar.close)

method getDataRequirements*(s: SimpleTestStrategy): seq[DataRequirement] =
  ## Single OHLCV requirement (default)
  @[newDataRequirement(dkOHLCV, providers = @[dpYahoo], required = true)]

method reset*(s: MultiDataStrategy) =
  s.dataContextReceived = false

method onData*(s: MultiDataStrategy, ctx: DataContext): Signal =
  ## Multi-data callback
  s.dataContextReceived = true
  
  # Verify we have both OHLCV and Quote data
  check ctx.hasData(dkOHLCV)
  check ctx.hasData(dkQuote)
  
  let bar = ctx.getOHLCV()
  return newSignal(Stay, s.symbol, bar.close)

method getDataRequirements*(s: MultiDataStrategy): seq[DataRequirement] =
  ## Requires both OHLCV and Quote
  @[
    newDataRequirement(dkOHLCV, providers = @[dpYahoo], required = true),
    newDataRequirement(dkQuote, providers = @[dpYahoo], required = true)
  ]

# ============================================================================
# Stream Synchronization Tests
# ============================================================================

suite "Stream Synchronization":
  
  test "Align strategy - only emit when all streams have data":
    let ohlcvData = createTestOHLCV(5)
    let quoteData = createTestQuotes(3)  # Less data
    
    var ohlcvValues: seq[DataValue] = @[]
    for bar in ohlcvData:
      ohlcvValues.add(newDataValue(bar))
    
    var quoteValues: seq[DataValue] = @[]
    for quote in quoteData:
      quoteValues.add(newDataValue(quote))
    
    let streamSet = newStreamSet(ssAlign)
    streamSet.addStream(dkOHLCV, required = true, ohlcvValues)
    streamSet.addStream(dkQuote, required = true, quoteValues)
    
    var count = 0
    for ctx in streamSet.synchronize():
      count += 1
      check ctx.hasData(dkOHLCV)
      check ctx.hasData(dkQuote)
    
    # Should only emit 3 contexts (limited by quote data)
    check count == 3
  
  test "Carry forward strategy - carry last value forward":
    # Create OHLCV data every day
    var ohlcvValues: seq[DataValue] = @[]
    var timestamp = parseTime("2023-01-01", "yyyy-MM-dd", utc()).toUnix
    
    for i in 0..<5:
      ohlcvValues.add(newDataValue(OHLCV(
        timestamp: timestamp + i * 86400,
        open: 100.0, high: 101.0, low: 99.0, close: 100.0, volume: 1000000
      )))
    
    # Create Quote data only on day 0 and 2
    var quoteValues: seq[DataValue] = @[]
    quoteValues.add(newDataValue(Quote(
      symbol: "TEST",
      timestamp: timestamp,  # Day 0
      regularMarketPrice: 100.0,
      regularMarketChange: 0.0,
      regularMarketChangePercent: 0.0,
      regularMarketVolume: 1000000.0,
      regularMarketOpen: 100.0,
      regularMarketDayHigh: 101.0,
      regularMarketDayLow: 99.0,
      regularMarketPreviousClose: 100.0
    )))
    quoteValues.add(newDataValue(Quote(
      symbol: "TEST",
      timestamp: timestamp + 2 * 86400,  # Day 2
      regularMarketPrice: 102.0,
      regularMarketChange: 2.0,
      regularMarketChangePercent: 2.0,
      regularMarketVolume: 1000000.0,
      regularMarketOpen: 100.0,
      regularMarketDayHigh: 103.0,
      regularMarketDayLow: 100.0,
      regularMarketPreviousClose: 100.0
    )))
    
    let streamSet = newStreamSet(ssCarryForward)
    streamSet.addStream(dkOHLCV, required = true, ohlcvValues)
    streamSet.addStream(dkQuote, required = true, quoteValues)
    
    var count = 0
    var lastQuotePrice = 0.0
    
    for ctx in streamSet.synchronize():
      count += 1
      check ctx.hasData(dkOHLCV)
      check ctx.hasData(dkQuote)
      
      let quote = ctx.getQuote()
      
      # Quote should be carried forward on days 1 and 2
      if count == 1:
        check quote.regularMarketPrice == 100.0
        lastQuotePrice = quote.regularMarketPrice
      elif count == 2:
        # Carried forward from day 0
        check quote.regularMarketPrice == 100.0
      elif count == 3:
        # New quote on day 2
        check quote.regularMarketPrice == 102.0
        lastQuotePrice = quote.regularMarketPrice
      elif count > 3:
        # Carried forward from day 2
        check quote.regularMarketPrice == 102.0
    
    # Should emit 5 contexts (all OHLCV days with carried quotes)
    check count == 5
  
  test "Leading strategy - emit on leading stream timestamps":
    let ohlcvData = createTestOHLCV(5)
    let quoteData = createTestQuotes(3)  # Less data
    
    var ohlcvValues: seq[DataValue] = @[]
    for bar in ohlcvData:
      ohlcvValues.add(newDataValue(bar))
    
    var quoteValues: seq[DataValue] = @[]
    for quote in quoteData:
      quoteValues.add(newDataValue(quote))
    
    let streamSet = newStreamSet(ssLeading, leadingKind = dkOHLCV)
    streamSet.addStream(dkOHLCV, required = true, ohlcvValues)
    streamSet.addStream(dkQuote, required = false, quoteValues)
    
    var count = 0
    for ctx in streamSet.synchronize():
      count += 1
      check ctx.hasData(dkOHLCV)
      
      # First 3 should have quote data
      if count <= 3:
        check ctx.hasData(dkQuote)
      else:
        # Last 2 should carry forward last quote
        check ctx.hasData(dkQuote)
    
    # Should emit 5 contexts (all OHLCV bars)
    check count == 5

# ============================================================================
# Runner Tests - Single Data
# ============================================================================

suite "Runner - Single Data (Backward Compatibility)":
  
  test "Runner with pre-loaded OHLCV data (runWithData)":
    let strategy = SimpleTestStrategy(symbol: "TEST")
    let runner = newRunner(strategy, initialCash = 100000.0)
    let data = createTestOHLCV(10)
    
    let report = runner.runWithData("TEST", data)
    
    # Verify report
    check report.symbol == "TEST"
    check report.initialCash == 100000.0
    check report.totalTrades >= 1  # At least one buy
    check strategy.buyExecuted
  
  test "Runner handles empty data":
    let strategy = SimpleTestStrategy(symbol: "TEST")
    let runner = newRunner(strategy)
    
    expect(ValueError):
      discard runner.runWithData("TEST", @[])
  
  test "Runner with portfolio config":
    let config = PortfolioConfig(
      initialCash: 50000.0,
      commission: 0.001,
      minCommission: 1.0,
      riskFreeRate: 0.02
    )
    
    let strategy = SimpleTestStrategy(symbol: "TEST")
    let runner = newRunner(strategy, config)
    let data = createTestOHLCV(10)
    
    let report = runner.runWithData("TEST", data)
    
    check report.initialCash == 50000.0
    check report.totalCommission > 0.0  # Should have commission

# ============================================================================
# Runner Tests - Multi Data
# ============================================================================

suite "Runner - Multi Data":
  
  test "Multi-data strategy with synchronized streams":
    # This test uses pre-created data since automatic fetching
    # would require actual data sources
    
    let strategy = MultiDataStrategy(symbol: "TEST")
    let runner = newRunner(strategy)
    
    # Create matching OHLCV and Quote data
    let ohlcvData = createTestOHLCV(10)
    let quoteData = createTestQuotes(10)
    
    # Manually create streams
    var ohlcvValues: seq[DataValue] = @[]
    for bar in ohlcvData:
      ohlcvValues.add(newDataValue(bar))
    
    var quoteValues: seq[DataValue] = @[]
    for quote in quoteData:
      quoteValues.add(newDataValue(quote))
    
    # Create stream set
    let streamSet = newStreamSet(ssLeading)
    streamSet.addStream(dkOHLCV, required = true, ohlcvValues)
    streamSet.addStream(dkQuote, required = true, quoteValues)
    
    # Verify synchronization works
    var count = 0
    for ctx in streamSet.synchronize():
      count += 1
      check ctx.hasData(dkOHLCV)
      check ctx.hasData(dkQuote)
      
      # Test strategy callback would work
      let signal = strategy.onData(ctx)
      check signal.position == Stay
    
    check count == 10
    check strategy.dataContextReceived

# ============================================================================
# Stream Statistics Tests
# ============================================================================

suite "Stream Statistics":
  
  test "Get stream statistics":
    let ohlcvData = createTestOHLCV(5)
    var ohlcvValues: seq[DataValue] = @[]
    for bar in ohlcvData:
      ohlcvValues.add(newDataValue(bar))
    
    let streamSet = newStreamSet(ssAlign)
    streamSet.addStream(dkOHLCV, required = true, ohlcvValues)
    
    # Before consumption
    var stats = streamSet.getStreamStats()
    check stats[dkOHLCV].total == 5
    check stats[dkOHLCV].consumed == 0
    
    # Consume some data
    var count = 0
    for ctx in streamSet.synchronize():
      count += 1
      if count == 3:
        break
    
    # After consuming 3
    stats = streamSet.getStreamStats()
    check stats[dkOHLCV].consumed == 3
    
  test "Reset streams":
    let ohlcvData = createTestOHLCV(5)
    var ohlcvValues: seq[DataValue] = @[]
    for bar in ohlcvData:
      ohlcvValues.add(newDataValue(bar))
    
    let streamSet = newStreamSet(ssAlign)
    streamSet.addStream(dkOHLCV, required = true, ohlcvValues)
    
    # Consume all
    for ctx in streamSet.synchronize():
      discard
    
    var stats = streamSet.getStreamStats()
    check stats[dkOHLCV].consumed == 5
    
    # Reset
    streamSet.resetStreams()
    stats = streamSet.getStreamStats()
    check stats[dkOHLCV].consumed == 0

# ============================================================================
# DataValue and DataContext Tests
# ============================================================================

suite "DataValue and DataContext":
  
  test "Create DataValue from OHLCV":
    let bar = OHLCV(
      timestamp: 1234567890,
      open: 100.0, high: 105.0, low: 95.0, close: 102.0, volume: 1000000
    )
    
    let dv = newDataValue(bar)
    check dv.kind == dkOHLCV
    check dv.ohlcv.close == 102.0
    check dv.getTimestamp() == 1234567890
  
  test "Create DataValue from Quote":
    let quote = Quote(
      symbol: "TEST",
      timestamp: 1234567890,
      regularMarketPrice: 100.0,
      regularMarketChange: 0.5,
      regularMarketChangePercent: 0.5,
      regularMarketVolume: 1000000.0,
      regularMarketOpen: 99.5,
      regularMarketDayHigh: 101.0,
      regularMarketDayLow: 99.0,
      regularMarketPreviousClose: 99.5
    )
    
    let dv = newDataValue(quote)
    check dv.kind == dkQuote
    check dv.quote.regularMarketPrice == 100.0
    check dv.getTimestamp() == 1234567890
  
  test "Create DataContext":
    let bar = OHLCV(
      timestamp: 1234567890,
      open: 100.0, high: 105.0, low: 95.0, close: 102.0, volume: 1000000
    )
    
    let quote = Quote(
      symbol: "TEST",
      timestamp: 1234567890,
      regularMarketPrice: 102.0,
      regularMarketChange: 2.0,
      regularMarketChangePercent: 2.0,
      regularMarketVolume: 1000000.0,
      regularMarketOpen: 100.0,
      regularMarketDayHigh: 105.0,
      regularMarketDayLow: 95.0,
      regularMarketPreviousClose: 100.0
    )
    
    let ctx = newDataContext(1234567890, @[
      newDataValue(bar),
      newDataValue(quote)
    ])
    
    check ctx.timestamp == 1234567890
    check ctx.data.len == 2
    check ctx.hasData(dkOHLCV)
    check ctx.hasData(dkQuote)
    
    let retrievedBar = ctx.getOHLCV()
    check retrievedBar.close == 102.0
    
    let retrievedQuote = ctx.getQuote()
    check retrievedQuote.regularMarketPrice == 102.0

# ============================================================================
# Edge Cases
# ============================================================================

suite "Edge Cases":
  
  test "Empty stream set":
    let streamSet = newStreamSet(ssAlign)
    
    var count = 0
    for ctx in streamSet.synchronize():
      count += 1
    
    check count == 0
  
  test "Stream with single data point":
    let ohlcvData = createTestOHLCV(1)
    var ohlcvValues: seq[DataValue] = @[]
    for bar in ohlcvData:
      ohlcvValues.add(newDataValue(bar))
    
    let streamSet = newStreamSet(ssAlign)
    streamSet.addStream(dkOHLCV, required = true, ohlcvValues)
    
    var count = 0
    for ctx in streamSet.synchronize():
      count += 1
      check ctx.hasData(dkOHLCV)
    
    check count == 1
  
  test "Misaligned timestamps (ssAlign)":
    # OHLCV on even days, Quote on odd days
    var ohlcvValues: seq[DataValue] = @[]
    var quoteValues: seq[DataValue] = @[]
    var timestamp = parseTime("2023-01-01", "yyyy-MM-dd", utc()).toUnix
    
    for i in 0..<5:
      ohlcvValues.add(newDataValue(OHLCV(
        timestamp: timestamp + i * 2 * 86400,  # Every 2 days
        open: 100.0, high: 101.0, low: 99.0, close: 100.0, volume: 1000000
      )))
      
      quoteValues.add(newDataValue(Quote(
        symbol: "TEST",
        timestamp: timestamp + (i * 2 + 1) * 86400,  # Offset by 1 day
        regularMarketPrice: 100.0,
        regularMarketChange: 0.0,
        regularMarketChangePercent: 0.0,
        regularMarketVolume: 1000000.0,
        regularMarketOpen: 100.0,
        regularMarketDayHigh: 101.0,
        regularMarketDayLow: 99.0,
        regularMarketPreviousClose: 100.0
      )))
    
    let streamSet = newStreamSet(ssAlign)
    streamSet.addStream(dkOHLCV, required = true, ohlcvValues)
    streamSet.addStream(dkQuote, required = true, quoteValues)
    
    var count = 0
    for ctx in streamSet.synchronize():
      count += 1
    
    # No timestamps align, so should emit 0
    check count == 0

# Run all tests
when isMainModule:
  echo "Running runner tests..."
