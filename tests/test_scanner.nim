## Tests for Scanner Module

import std/[unittest, tables, times, math, os, strformat, strutils]
import ../src/tzutrader/[core, data, indicators, strategy, portfolio, trader, scanner]

# Helper: Generate test data
proc generateTestData(symbol: string, bars: int, trend: float = 0.001): seq[OHLCV] =
  result = newSeq[OHLCV](bars)
  let baseTime = now() - initDuration(days = bars)
  let basePrice = 100.0

  for i in 0..<bars:
    let
      trendFactor = 1.0 + (trend * float(i))
      open = basePrice * trendFactor
      high = open * 1.02
      low = open * 0.98
      close = open + (high - low) * 0.5
      volume = 1000000.0
      timestamp = (baseTime + initDuration(days = i)).toTime().toUnix()

    result[i] = OHLCV(
      timestamp: timestamp,
      open: open,
      high: high,
      low: low,
      close: close,
      volume: volume
    )

suite "Scanner Construction Tests":
  test "Create scanner with default parameters":
    let strategy = newRSIStrategy(14, 30.0, 70.0)
    let scanner = newScanner(strategy, @["AAPL", "MSFT"])

    check scanner.symbols.len == 2
    check scanner.initialCash == 100000.0
    check scanner.commission == 0.0
    check scanner.verbose == false

  test "Create scanner with custom parameters":
    let strategy = newRSIStrategy(14, 30.0, 70.0)
    let scanner = newScanner(
      strategy,
      @["AAPL", "MSFT", "GOOG"],
      initialCash = 10000.0,
      commission = 0.001,
      verbose = true
    )

    check scanner.symbols.len == 3
    check scanner.initialCash == 10000.0
    check scanner.commission == 0.001
    check scanner.verbose == true

suite "Scan Execution Tests":
  test "Scan multiple symbols":
    let strategy = newRSIStrategy(14, 30.0, 70.0)
    let scanner = newScanner(strategy, @["AAPL", "MSFT"], initialCash = 10000.0)

    var dataMap = initTable[string, seq[OHLCV]]()
    dataMap["AAPL"] = generateTestData("AAPL", 100, 0.002)
    dataMap["MSFT"] = generateTestData("MSFT", 100, 0.001)

    let results = scanner.scan(dataMap)

    check results.len == 2
    check results[0].symbol == "AAPL" or results[0].symbol == "MSFT"
    check results[1].symbol == "AAPL" or results[1].symbol == "MSFT"

  test "Scan with missing symbol data":
    let strategy = newRSIStrategy(14, 30.0, 70.0)
    let scanner = newScanner(strategy, @["AAPL", "MSFT", "GOOG"])

    var dataMap = initTable[string, seq[OHLCV]]()
    dataMap["AAPL"] = generateTestData("AAPL", 100)
    # MSFT and GOOG missing

    let results = scanner.scan(dataMap)

    check results.len == 1
    check results[0].symbol == "AAPL"

  test "Scan with empty data":
    let strategy = newRSIStrategy(14, 30.0, 70.0)
    let scanner = newScanner(strategy, @["AAPL"])

    var dataMap = initTable[string, seq[OHLCV]]()
    dataMap["AAPL"] = @[] # Empty data

    let results = scanner.scan(dataMap)

    check results.len == 0

  test "Scan result contains report and signals":
    let strategy = newRSIStrategy(14, 30.0, 70.0)
    let scanner = newScanner(strategy, @["AAPL"])

    var dataMap = initTable[string, seq[OHLCV]]()
    dataMap["AAPL"] = generateTestData("AAPL", 100)

    let results = scanner.scan(dataMap)

    check results.len == 1
    check results[0].symbol == "AAPL"
    check results[0].report.symbol == "AAPL"
    check results[0].signals.len > 0

suite "Ranking Tests":
  test "Rank by total return":
    var results: seq[ScanResult] = @[]

    # Create mock results with different returns
    let strat = newRSIStrategy(14, 30.0, 70.0)
    let data1 = generateTestData("AAPL", 100, 0.005) # Much higher trend
    let data2 = generateTestData("MSFT", 100, 0.0001) # Much lower trend

    let report1 = quickBacktest("AAPL", strat, data1, 10000.0)
    let report2 = quickBacktest("MSFT", strat, data2, 10000.0)

    results.add(ScanResult(symbol: "MSFT", report: report2, signals: @[]))
    results.add(ScanResult(symbol: "AAPL", report: report1, signals: @[]))

    results.rankBy(TotalReturn)

    # First result should have higher return than second
    check results[0].report.totalReturn >= results[1].report.totalReturn

  test "Rank ascending vs descending":
    var results: seq[ScanResult] = @[]

    let strat = newRSIStrategy(14, 30.0, 70.0)
    let data1 = generateTestData("AAPL", 100, 0.005)
    let data2 = generateTestData("MSFT", 100, 0.0001)

    let report1 = quickBacktest("AAPL", strat, data1, 10000.0)
    let report2 = quickBacktest("MSFT", strat, data2, 10000.0)

    results.add(ScanResult(symbol: "MSFT", report: report2, signals: @[]))
    results.add(ScanResult(symbol: "AAPL", report: report1, signals: @[]))

    # Descending order (high to low) - default
    results.rankBy(TotalReturn, ascending = false)
    check results[0].report.totalReturn >= results[1].report.totalReturn

    # Ascending order (low to high)
    results.rankBy(TotalReturn, ascending = true)
    check results[0].report.totalReturn <= results[1].report.totalReturn

suite "Filter Tests":
  test "Filter by minimum return":
    let strat = newRSIStrategy(14, 30.0, 70.0)

    var results: seq[ScanResult] = @[]
    let data1 = generateTestData("AAPL", 100, 0.005) # Good return
    let data2 = generateTestData("MSFT", 100, 0.0) # Flat/poor return

    let report1 = quickBacktest("AAPL", strat, data1, 10000.0)
    let report2 = quickBacktest("MSFT", strat, data2, 10000.0)

    results.add(ScanResult(symbol: "AAPL", report: report1, signals: @[]))
    results.add(ScanResult(symbol: "MSFT", report: report2, signals: @[]))

    # Filter for returns > 5% (only AAPL should pass)
    let filtered = results.filter(minReturn = 5.0)

    # Check that filtered results all meet criteria
    for r in filtered:
      check r.report.totalReturn >= 5.0

  test "Filter by minimum trades":
    let strat = newRSIStrategy(14, 30.0, 70.0)

    var results: seq[ScanResult] = @[]
    let data = generateTestData("AAPL", 100)

    let report = quickBacktest("AAPL", strat, data, 10000.0)
    results.add(ScanResult(symbol: "AAPL", report: report, signals: @[]))

    # Filter for at least 1 trade
    let filtered = results.filter(minTrades = 1)

    # Should only include results with trades
    for r in filtered:
      check r.report.totalTrades >= 1

  test "Filter by multiple criteria":
    let strat = newRSIStrategy(14, 30.0, 70.0)

    var results: seq[ScanResult] = @[]
    let data = generateTestData("AAPL", 100, 0.002)

    let report = quickBacktest("AAPL", strat, data, 10000.0)
    results.add(ScanResult(symbol: "AAPL", report: report, signals: @[]))

    # Filter with multiple criteria
    let filtered = results.filter(
      minReturn = 0.0,
      minSharpe = 0.0,
      maxDrawdown = 50.0
    )

    # Check criteria are met
    for r in filtered:
      check r.report.totalReturn >= 0.0
      check r.report.sharpeRatio >= 0.0
      check r.report.maxDrawdown <= 50.0

suite "Top N Tests":
  test "Get top N results":
    var results: seq[ScanResult] = @[]
    let strat = newRSIStrategy(14, 30.0, 70.0)

    for i in 0..4:
      let trend = 0.001 * float(i + 1)
      let data = generateTestData(&"SYM{i}", 100, trend)
      let report = quickBacktest(&"SYM{i}", strat, data, 10000.0)
      results.add(ScanResult(symbol: &"SYM{i}", report: report, signals: @[]))

    results.rankBy(TotalReturn)
    let top3 = results.topN(3)

    check top3.len == 3

  test "Top N when N > results.len":
    var results: seq[ScanResult] = @[]
    let strat = newRSIStrategy(14, 30.0, 70.0)

    let data = generateTestData("AAPL", 100)
    let report = quickBacktest("AAPL", strat, data, 10000.0)
    results.add(ScanResult(symbol: "AAPL", report: report, signals: @[]))

    let top10 = results.topN(10)

    check top10.len == 1 # Only 1 result available

suite "Summary Tests":
  test "Generate summary for results":
    let strat = newRSIStrategy(14, 30.0, 70.0)

    var results: seq[ScanResult] = @[]
    let data1 = generateTestData("AAPL", 100, 0.002)
    let data2 = generateTestData("MSFT", 100, 0.001)

    let report1 = quickBacktest("AAPL", strat, data1, 10000.0)
    let report2 = quickBacktest("MSFT", strat, data2, 10000.0)

    results.add(ScanResult(symbol: "AAPL", report: report1, signals: @[]))
    results.add(ScanResult(symbol: "MSFT", report: report2, signals: @[]))

    let summaryText = results.summary()

    check summaryText.len > 0
    check "SCAN RESULTS SUMMARY" in summaryText
    check "AAPL" in summaryText
    check "MSFT" in summaryText
    check "Average Return" in summaryText

  test "Summary for empty results":
    let results: seq[ScanResult] = @[]
    let summaryText = results.summary()

    check summaryText.len > 0
    check "Total symbols scanned: 0" in summaryText

suite "String Representation Tests":
  test "ScanResult to string":
    let strat = newRSIStrategy(14, 30.0, 70.0)
    let data = generateTestData("AAPL", 100)
    let report = quickBacktest("AAPL", strat, data, 10000.0)

    let scanResult = ScanResult(symbol: "AAPL", report: report, signals: @[])
    let str = $scanResult

    check str.len > 0
    check "AAPL" in str

echo "Scanner module: All tests defined"
