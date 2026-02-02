## Test file for screener report generation

import std/[unittest, tables, times, strutils, options]
import ../../src/tzutrader/screener/[alerts, reports, schema]
import ../../src/tzutrader/core

suite "Report Generation Tests":

  setup:
    # Create sample alerts
    let alert1 = newAlert(
      symbol = "AAPL",
      strategyName = "RSI Mean Reversion",
      alertType = atBuySignal,
      price = 178.25,
      strength = asStrong,
      indicators = {"RSI": 28.3, "Price": 178.25}.toTable,
      metadata = {"reason": "RSI oversold"}.toTable
    )

    let alert2 = newAlert(
      symbol = "TSLA",
      strategyName = "MACD Crossover",
      alertType = atBuySignal,
      price = 235.67,
      strength = asModerate,
      indicators = {"MACD": 0.45, "Signal": 0.30}.toTable
    )

    let alert3 = newAlert(
      symbol = "GOOGL",
      strategyName = "Bollinger Breakout",
      alertType = atSellSignal,
      price = 142.80,
      strength = asWeak,
      indicators = {"Upper": 145.0, "Lower": 140.0}.toTable
    )

    let alerts = @[alert1, alert2, alert3]

    # Create sample summary
    var summary = ScreenerSummary(
      totalSymbols: 10,
      totalStrategies: 3,
      totalSignals: 3,
      signalsByType: initTable[AlertType, int](),
      signalsByStrength: initTable[AlertStrength, int](),
      topOpportunities: @[alert1]
    )
    summary.signalsByType[atBuySignal] = 2
    summary.signalsByType[atSellSignal] = 1
    summary.signalsByStrength[asStrong] = 1
    summary.signalsByStrength[asModerate] = 1
    summary.signalsByStrength[asWeak] = 1

  test "Print summary":
    let summaryText = printSummary(summary)
    check summaryText.contains("SCREENING SUMMARY")
    check summaryText.contains("Symbols Scanned:    10")
    check summaryText.contains("Signals Generated:  3")
    check summaryText.contains("Strategies Used:    3")
    check summaryText.contains("Signals by Type:")
    check summaryText.contains("Signals by Strength:")

  test "Format terminal table - summary level":
    let table = formatTerminalTable(alerts, dlSummary)
    check table.contains("MARKET SCREENER ALERTS")
    check table.contains("Total Alerts: 3")
    # Should not contain detailed alert data at summary level
    check(not table.contains("AAPL"))

  test "Format terminal table - detailed level":
    let table = formatTerminalTable(alerts, dlDetailed)
    check table.contains("MARKET SCREENER ALERTS")
    check table.contains("AAPL")
    check table.contains("TSLA")
    check table.contains("GOOGL")
    check table.contains("RSI Mean Reversi") # Truncated in table
    check table.contains("MACD Crossover")
    check table.contains("Bollinger Breako") # Truncated in table

  test "Format CSV report":
    let csv = formatCsvReport(alerts)
    check csv.contains("Symbol,Strategy,AlertType,Strength,Price,Timestamp,Indicators,Metadata")
    check csv.contains("AAPL,RSI Mean Reversion")
    check csv.contains("TSLA,MACD Crossover")
    check csv.contains("GOOGL,Bollinger Breakout")
    check csv.contains("178.25")
    check csv.contains("235.67")
    check csv.contains("142.80")

  test "Format JSON report":
    let jsonReport = formatJsonReport(alerts)
    check jsonReport.contains("\"alerts\"")
    check jsonReport.contains("\"count\"")
    check jsonReport.contains("\"generatedAt\"")
    check jsonReport.contains("\"symbol\": \"AAPL\"")
    check jsonReport.contains("\"symbol\": \"TSLA\"")
    check jsonReport.contains("\"symbol\": \"GOOGL\"")
    check jsonReport.contains("\"alertType\"")
    check jsonReport.contains("\"strength\"")

  test "Format Markdown report":
    let mdReport = formatMarkdownReport(alerts)
    check mdReport.contains("# Market Screener Report")
    check mdReport.contains("Total Alerts: 3")
    check mdReport.contains("## Alerts")
    check mdReport.contains("| Symbol | Strategy | Signal | Strength | Price | Indicators |")
    check mdReport.contains("| AAPL | RSI Mean Reversion |")
    check mdReport.contains("| TSLA | MACD Crossover |")
    check mdReport.contains("| GOOGL | Bollinger Breakout |")

  test "Print detailed alerts":
    let detailed = printDetailedAlerts(alerts)
    check detailed.contains("[Alert 1/3]")
    check detailed.contains("[Alert 2/3]")
    check detailed.contains("[Alert 3/3]")
    # The string contains ANSI codes, so check for "AAPL" which will be present
    check detailed.contains("AAPL")
    check detailed.contains("Strategy:   RSI Mean Reversion")
    check detailed.contains("Indicators:")
    check detailed.contains("Metadata:")
    check detailed.contains("reason")

  test "Generate full report - terminal format":
    let config = ScreenerOutputConfig(
      format: ofTerminal,
      detailLevel: dlDetailed,
      filepath: none(string)
    )
    let report = generateReport(alerts, summary, config)
    check report.contains("SCREENING SUMMARY")
    check report.contains("MARKET SCREENER ALERTS")
    check report.contains("AAPL")

  test "Generate full report - CSV format":
    let config = ScreenerOutputConfig(
      format: ofCsv,
      detailLevel: dlSummary,
      filepath: none(string)
    )
    let report = generateReport(alerts, summary, config)
    check report.contains("Symbol,Strategy,AlertType")
    check report.contains("AAPL,RSI Mean Reversion")

  test "Generate full report - JSON format":
    let config = ScreenerOutputConfig(
      format: ofJson,
      detailLevel: dlSummary,
      filepath: none(string)
    )
    let report = generateReport(alerts, summary, config)
    check report.contains("\"alerts\"")
    check report.contains("\"count\": 3")

  test "Generate full report - Markdown format":
    let config = ScreenerOutputConfig(
      format: ofMarkdown,
      detailLevel: dlSummary,
      filepath: none(string)
    )
    let report = generateReport(alerts, summary, config)
    check report.contains("# Market Screener Report")
    check report.contains("| Symbol |")

  test "Empty alerts handling":
    let emptyAlerts: seq[Alert] = @[]

    let table = formatTerminalTable(emptyAlerts, dlDetailed)
    check table.contains("No alerts to display")

    let csv = formatCsvReport(emptyAlerts)
    check csv.contains("Symbol,Strategy,AlertType") # Header only

    let json = formatJsonReport(emptyAlerts)
    check json.contains("\"count\": 0")

    let md = formatMarkdownReport(emptyAlerts)
    check md.contains("*No alerts found*")

    let detailed = printDetailedAlerts(emptyAlerts)
    check detailed.contains("No alerts to display")

when isMainModule:
  echo "Running report generation tests..."
