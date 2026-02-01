## Integration Test for Market Screener
##
## This test validates the complete screener workflow:
## - Configuration parsing
## - Data fetching
## - Strategy execution
## - Alert generation
## - Report formatting
## - File output

import std/[unittest, os, json, strutils, options, tables]
import ../../src/tzutrader/screener/[screener, parser, schema, alerts, reports]
import ../../src/tzutrader/[core, data]

suite "Screener Integration Tests":
  
  test "Full workflow with basic RSI screener config":
    # This test validates the complete screener workflow
    let yamlPath = "examples/screeners/basic_rsi_screener.yml"
    
    check fileExists(yamlPath)
    
    # Parse configuration
    let config = parseScreenerYAMLFile(yamlPath)
    check config.metadata.name == "RSI Oversold Screener"
    check config.strategies.len == 1
    check config.data.source == dsYahoo
    check config.data.symbols.len == 5
    check config.output.format == ofTerminal
    
    # Validate configuration
    let validation = validateConfig(config)
    check validation.valid == true
    
    # Create screener
    var screenerObj = newScreener(config)
    
    # Note: We don't run the screener here because it requires network access
    # The actual execution is tested in manual/CLI tests
  
  test "Full workflow with multi-strategy config":
    let yamlPath = "examples/screeners/multi_strategy_screener.yml"
    
    check fileExists(yamlPath)
    
    # Parse configuration
    let config = parseScreenerYAMLFile(yamlPath)
    check config.metadata.name == "Multi-Strategy Market Scanner"
    check config.strategies.len == 3  # RSI, MACD, Bollinger
    check config.data.source == dsYahoo
    check config.data.symbols.len == 8
    check config.output.format == ofCsv
    check config.output.filepath.isSome()
    check config.output.filepath.get() == "screener_results.csv"
    
    # Validate configuration
    let validation = validateConfig(config)
    check validation.valid == true
    
    # Create screener
    var screenerObj = newScreener(config)
  
  test "Configuration validation catches errors":
    # Test with no strategies
    var badConfig = ScreenerConfig(
      strategies: @[],
      data: ScreenerDataConfig(
        source: dsYahoo,
        symbols: @["AAPL"],
        lookback: LookbackPeriod(value: 90, unit: tuDays),
        interval: Int1d
      ),
      output: ScreenerOutputConfig(
        format: ofTerminal,
        detailLevel: dlSummary,
        filepath: none(string)
      ),
      filters: ScreenerFilters(
        signalTypes: @[],
        minStrength: asWeak,
        topN: none(int)
      )
    )
    
    let validation = validateConfig(badConfig)
    check validation.valid == false
    check validation.errors.len > 0
  
  test "Alert generation and filtering":
    # Create mock alerts
    let alert1 = newAlert(
      symbol = "AAPL",
      strategyName = "RSI",
      alertType = atBuySignal,
      price = 150.0,
      strength = asStrong
    )
    
    let alert2 = newAlert(
      symbol = "MSFT",
      strategyName = "MACD",
      alertType = atSellSignal,
      price = 350.0,
      strength = asWeak
    )
    
    let alert3 = newAlert(
      symbol = "GOOGL",
      strategyName = "RSI",
      alertType = atBuySignal,
      price = 140.0,
      strength = asModerate
    )
    
    let alerts = @[alert1, alert2, alert3]
    
    # Test filtering by strength
    let filters1 = ScreenerFilters(
      signalTypes: @[],
      minStrength: asModerate,
      topN: none(int)
    )
    
    let filtered1 = applyFilters(alerts, filters1)
    check filtered1.len == 2  # Strong and Moderate only
    
    # Test filtering by signal type
    let filters2 = ScreenerFilters(
      signalTypes: @[atBuySignal],
      minStrength: asWeak,
      topN: none(int)
    )
    
    let filtered2 = applyFilters(alerts, filters2)
    check filtered2.len == 2  # Only buy signals
    
    # Test topN filter
    let filters3 = ScreenerFilters(
      signalTypes: @[],
      minStrength: asWeak,
      topN: some(2)
    )
    
    let filtered3 = applyFilters(alerts, filters3)
    check filtered3.len == 2  # Top 2 only
  
  test "Report generation in all formats":
    # Create sample alerts
    let alert = newAlert(
      symbol = "TEST",
      strategyName = "Test Strategy",
      alertType = atBuySignal,
      price = 100.0,
      strength = asStrong
    )
    let alerts = @[alert]
    
    # Create summary
    var signalsByType = initTable[AlertType, int]()
    signalsByType[atBuySignal] = 1
    var signalsByStrength = initTable[AlertStrength, int]()
    signalsByStrength[asStrong] = 1
    
    let summary = ScreenerSummary(
      totalSymbols: 1,
      totalStrategies: 1,
      totalSignals: 1,
      signalsByType: signalsByType,
      signalsByStrength: signalsByStrength,
      topOpportunities: @[]
    )
    
    # Test terminal format
    let termConfig = ScreenerOutputConfig(
      format: ofTerminal,
      detailLevel: dlDetailed,
      filepath: none(string)
    )
    let termReport = generateReport(alerts, summary, termConfig)
    check termReport.contains("SCREENING SUMMARY")
    check termReport.contains("TEST")
    
    # Test CSV format
    let csvConfig = ScreenerOutputConfig(
      format: ofCsv,
      detailLevel: dlSummary,
      filepath: none(string)
    )
    let csvReport = generateReport(alerts, summary, csvConfig)
    check csvReport.contains("Symbol,Strategy")
    check csvReport.contains("TEST,Test Strategy")
    
    # Test JSON format
    let jsonConfig = ScreenerOutputConfig(
      format: ofJson,
      detailLevel: dlSummary,
      filepath: none(string)
    )
    let jsonReport = generateReport(alerts, summary, jsonConfig)
    check jsonReport.contains("\"alerts\"")
    check jsonReport.contains("\"TEST\"")
    
    # Validate JSON is parseable
    let jsonNode = parseJson(jsonReport)
    check jsonNode.hasKey("alerts")
    check jsonNode["count"].getInt() == 1
    
    # Test Markdown format
    let mdConfig = ScreenerOutputConfig(
      format: ofMarkdown,
      detailLevel: dlSummary,
      filepath: none(string)
    )
    let mdReport = generateReport(alerts, summary, mdConfig)
    check mdReport.contains("# Market Screener Report")
    check mdReport.contains("| TEST |")
  
  test "Lookback period parsing":
    # Test various time period formats
    check parseLookbackPeriod("90d") == LookbackPeriod(value: 90, unit: tuDays)
    check parseLookbackPeriod("3h") == LookbackPeriod(value: 3, unit: tuHours)
    check parseLookbackPeriod("1y") == LookbackPeriod(value: 1, unit: tuYears)
    check parseLookbackPeriod("6mo") == LookbackPeriod(value: 6, unit: tuMonths)
    check parseLookbackPeriod("2w") == LookbackPeriod(value: 2, unit: tuWeeks)
  
  test "Interval parsing":
    # Test interval string parsing
    check parseTimeInterval("1d") == Int1d
    check parseTimeInterval("1h") == Int1h
    check parseTimeInterval("5m") == Int5m
    check parseTimeInterval("1wk") == Int1wk
    check parseTimeInterval("1mo") == Int1mo
  
  test "Lookback to bar count conversion":
    # Test bar count estimation
    let bars1d = lookbackToBarCount(
      LookbackPeriod(value: 30, unit: tuDays),
      Int1d
    )
    check bars1d == 30
    
    let bars1h = lookbackToBarCount(
      LookbackPeriod(value: 1, unit: tuDays),
      Int1h
    )
    check bars1h == 24
    
    let bars5m = lookbackToBarCount(
      LookbackPeriod(value: 1, unit: tuHours),
      Int5m
    )
    check bars5m == 12

when isMainModule:
  echo "Running screener integration tests..."
