## Tests for Export Module

import std/[unittest, json, os, times]

include ../src/tzutrader/core
include ../src/tzutrader/data
include ../src/tzutrader/indicators
include ../src/tzutrader/strategy
include ../src/tzutrader/portfolio
include ../src/tzutrader/trader
include ../src/tzutrader/scanner
include ../src/tzutrader/exports

# Helper: Generate test data
proc generateTestData(bars: int): seq[OHLCV] =
  result = newSeq[OHLCV](bars)
  let baseTime = now() - initDuration(days = bars)
  
  for i in 0..<bars:
    let
      open = 100.0 + float(i) * 0.1
      high = open * 1.01
      low = open * 0.99
      close = open + 0.05
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

suite "JSON Export Tests":
  test "BacktestReport to JSON":
    let strategy = newRSIStrategy(14, 30.0, 70.0)
    let data = generateTestData(100)
    let report = quickBacktest("AAPL", strategy, data, 10000.0)
    
    let jsonNode = report.toJson()
    
    check jsonNode.kind == JObject
    check jsonNode.hasKey("symbol")
    check jsonNode.hasKey("total_return")
    check jsonNode.hasKey("sharpe_ratio")
    check jsonNode.hasKey("win_rate")
    check jsonNode["symbol"].getStr() == "AAPL"
  
  test "ScanResult to JSON":
    let strategy = newRSIStrategy(14, 30.0, 70.0)
    let data = generateTestData(100)
    let report = quickBacktest("AAPL", strategy, data, 10000.0)
    let signals = strategy.analyze(data)
    
    let scanResult = ScanResult(
      symbol: "AAPL",
      report: report,
      signals: signals
    )
    
    let jsonNode = scanResult.toJson()
    
    check jsonNode.kind == JObject
    check jsonNode.hasKey("symbol")
    check jsonNode.hasKey("report")
    check jsonNode.hasKey("signals_count")
    check jsonNode["symbol"].getStr() == "AAPL"
  
  test "Export BacktestReport to JSON file":
    let strategy = newRSIStrategy(14, 30.0, 70.0)
    let data = generateTestData(100)
    let report = quickBacktest("AAPL", strategy, data, 10000.0)
    
    let filename = "test_report.json"
    report.exportJson(filename)
    
    check fileExists(filename)
    
    let content = readFile(filename)
    check content.len > 0
    check "AAPL" in content
    
    # Cleanup
    removeFile(filename)
  
  test "Export scan results to JSON file":
    let strategy = newRSIStrategy(14, 30.0, 70.0)
    
    var results: seq[ScanResult] = @[]
    let data1 = generateTestData(100)
    let report1 = quickBacktest("AAPL", strategy, data1, 10000.0)
    results.add(ScanResult(symbol: "AAPL", report: report1, signals: @[]))
    
    let data2 = generateTestData(100)
    let report2 = quickBacktest("MSFT", strategy, data2, 10000.0)
    results.add(ScanResult(symbol: "MSFT", report: report2, signals: @[]))
    
    let filename = "test_scan_results.json"
    results.exportJson(filename)
    
    check fileExists(filename)
    
    let content = readFile(filename)
    check content.len > 0
    check "AAPL" in content
    check "MSFT" in content
    
    # Cleanup
    removeFile(filename)

suite "CSV Export Tests":
  test "CSV header generation":
    let header = toCsvHeader()
    
    check header.len > 0
    check "symbol" in header
    check "total_return" in header
    check "sharpe_ratio" in header
    check "win_rate" in header
  
  test "BacktestReport to CSV row":
    let strategy = newRSIStrategy(14, 30.0, 70.0)
    let data = generateTestData(100)
    let report = quickBacktest("AAPL", strategy, data, 10000.0)
    
    let row = report.toCsvRow()
    
    check row.len > 0
    check "AAPL" in row
  
  test "Export BacktestReport to CSV file":
    let strategy = newRSIStrategy(14, 30.0, 70.0)
    let data = generateTestData(100)
    let report = quickBacktest("AAPL", strategy, data, 10000.0)
    
    let filename = "test_report.csv"
    report.exportCsv(filename)
    
    check fileExists(filename)
    
    let content = readFile(filename)
    check content.len > 0
    check "AAPL" in content
    check "symbol" in content  # Header
    
    # Cleanup
    removeFile(filename)
  
  test "Export scan results to CSV file":
    let strategy = newRSIStrategy(14, 30.0, 70.0)
    
    var results: seq[ScanResult] = @[]
    let data1 = generateTestData(100)
    let report1 = quickBacktest("AAPL", strategy, data1, 10000.0)
    results.add(ScanResult(symbol: "AAPL", report: report1, signals: @[]))
    
    let data2 = generateTestData(100)
    let report2 = quickBacktest("MSFT", strategy, data2, 10000.0)
    results.add(ScanResult(symbol: "MSFT", report: report2, signals: @[]))
    
    let filename = "test_scan_results.csv"
    results.exportCsv(filename)
    
    check fileExists(filename)
    
    let content = readFile(filename)
    check content.len > 0
    check "AAPL" in content
    check "MSFT" in content
    
    # Cleanup
    removeFile(filename)

suite "Trade Log Export Tests":
  test "TradeLog to JSON":
    let log = TradeLog(
      timestamp: 1234567890,
      symbol: "AAPL",
      action: Position.Buy,
      quantity: 10.0,
      price: 150.0,
      cash: 8500.0,
      equity: 10000.0
    )
    
    let jsonNode = log.toJson()
    
    check jsonNode.kind == JObject
    check jsonNode.hasKey("symbol")
    check jsonNode.hasKey("action")
    check jsonNode.hasKey("quantity")
    check jsonNode["symbol"].getStr() == "AAPL"
  
  test "Export trade logs to JSON file":
    let logs = @[
      TradeLog(
        timestamp: 1234567890,
        symbol: "AAPL",
        action: Position.Buy,
        quantity: 10.0,
        price: 150.0,
        cash: 8500.0,
        equity: 10000.0
      ),
      TradeLog(
        timestamp: 1234567900,
        symbol: "AAPL",
        action: Position.Sell,
        quantity: 10.0,
        price: 155.0,
        cash: 10050.0,
        equity: 10050.0
      )
    ]
    
    let filename = "test_trade_logs.json"
    logs.exportTradeLog(filename)
    
    check fileExists(filename)
    
    let content = readFile(filename)
    check content.len > 0
    check "AAPL" in content
    
    # Cleanup
    removeFile(filename)
  
  test "Export trade logs to CSV file":
    let logs = @[
      TradeLog(
        timestamp: 1234567890,
        symbol: "AAPL",
        action: Position.Buy,
        quantity: 10.0,
        price: 150.0,
        cash: 8500.0,
        equity: 10000.0
      ),
      TradeLog(
        timestamp: 1234567900,
        symbol: "AAPL",
        action: Position.Sell,
        quantity: 10.0,
        price: 155.0,
        cash: 10050.0,
        equity: 10050.0
      )
    ]
    
    let filename = "test_trade_logs.csv"
    logs.exportTradeLogCsv(filename)
    
    check fileExists(filename)
    
    let content = readFile(filename)
    check content.len > 0
    check "AAPL" in content
    check "timestamp" in content  # Header
    
    # Cleanup
    removeFile(filename)

echo "Export module: All tests defined"
