## Market Screener Report Generation Module
##
## This module provides various report formats for displaying screener results:
## - Terminal: Formatted tables with color support
## - CSV: Machine-readable format for export
## - JSON: Structured format for API integration
## - Markdown: Documentation-friendly format
##
## Example:
## ```nim
## let report = generateReport(result, config.output)
## echo report
## ```

import std/[times, strutils, strformat, tables, json, algorithm]
import ./alerts
import ./schema
import ../core

const
  # Terminal formatting characters
  HorizontalLine = "─"
  DoubleHorizontalLine = "═"
  VerticalLine = "│"
  
  # Column widths for terminal table
  ColSymbol = 8
  ColStrategy = 18
  ColSignal = 10
  ColStrength = 10
  ColPrice = 12
  ColIndicators = 40

# ANSI color codes for terminal output
proc colorReset(): string = "\e[0m"
proc colorBold(): string = "\e[1m"
proc colorRed(): string = "\e[31m"
proc colorGreen(): string = "\e[32m"
proc colorYellow(): string = "\e[33m"
proc colorBlue(): string = "\e[34m"
proc colorCyan(): string = "\e[36m"

proc colorForAlertType(alertType: AlertType): string =
  ## Returns appropriate color for alert type
  case alertType
  of atBuySignal: colorGreen()
  of atSellSignal: colorRed()
  of atExitLong: colorYellow()
  of atExitShort: colorYellow()
  of atNeutral: colorReset()

proc colorForStrength(strength: AlertStrength): string =
  ## Returns appropriate color for signal strength
  case strength
  of asWeak: colorReset()
  of asModerate: colorYellow()
  of asStrong: colorBold() & colorGreen()

proc truncate(s: string, maxLen: int): string =
  ## Truncates string to maxLen, adding ellipsis if needed
  if s.len <= maxLen:
    return s.alignLeft(maxLen)
  else:
    return s[0 ..< maxLen - 1] & "…"

proc formatIndicators(indicators: Table[string, float]): string =
  ## Formats indicator map as compact string
  if indicators.len == 0:
    return "-"
  
  var parts: seq[string]
  for key, val in indicators.pairs:
    parts.add(&"{key}: {val:.2f}")
  
  result = parts.join(", ")

proc formatMetadata(metadata: Table[string, string]): string =
  ## Formats metadata map as compact string
  if metadata.len == 0:
    return ""
  
  var parts: seq[string]
  for key, val in metadata.pairs:
    parts.add(&"{key}={val}")
  
  result = parts.join(", ")

proc printSummary*(summary: ScreenerSummary): string =
  ## Prints a summary of screening results
  result = &"""
{colorBold()}SCREENING SUMMARY{colorReset()}
{DoubleHorizontalLine.repeat(50)}
Symbols Scanned:    {summary.totalSymbols}
Signals Generated:  {summary.totalSignals}
Strategies Used:    {summary.totalStrategies}
"""

  # Show signal breakdown by type
  if summary.signalsByType.len > 0:
    result.add("\n" & colorBold() & "Signals by Type:" & colorReset() & "\n")
    for alertType, count in summary.signalsByType.pairs:
      let color = colorForAlertType(alertType)
      result.add(&"  {color}{($alertType).alignLeft(15)}{colorReset()} {count:>3}\n")
  
  # Show signal breakdown by strength
  if summary.signalsByStrength.len > 0:
    result.add("\n" & colorBold() & "Signals by Strength:" & colorReset() & "\n")
    for strength, count in summary.signalsByStrength.pairs:
      let color = colorForStrength(strength)
      result.add(&"  {color}{($strength).alignLeft(15)}{colorReset()} {count:>3}\n")
  
  result.add(DoubleHorizontalLine.repeat(50) & "\n")

proc formatTerminalTable*(alerts: seq[Alert], detailLevel: DetailLevel = dlSummary): string =
  ## Formats alerts as a terminal table with optional color support
  if alerts.len == 0:
    return colorYellow() & "No alerts to display" & colorReset() & "\n"
  
  # Header
  let totalWidth = ColSymbol + ColStrategy + ColSignal + ColStrength + ColPrice + ColIndicators + 12
  result = DoubleHorizontalLine.repeat(totalWidth) & "\n"
  result.add(colorBold() & "MARKET SCREENER ALERTS" & colorReset() & "\n")
  result.add(DoubleHorizontalLine.repeat(totalWidth) & "\n")
  
  if detailLevel == dlSummary:
    # Just show counts
    result.add(&"Total Alerts: {alerts.len}\n")
    result.add(DoubleHorizontalLine.repeat(totalWidth) & "\n")
    return result
  
  # Column headers
  result.add(
    "Symbol".alignLeft(ColSymbol) & VerticalLine &
    " Strategy".alignLeft(ColStrategy) & VerticalLine &
    " Signal".alignLeft(ColSignal) & VerticalLine &
    " Strength".alignLeft(ColStrength) & VerticalLine &
    " Price".alignLeft(ColPrice) & VerticalLine &
    " Indicators".alignLeft(ColIndicators) & "\n"
  )
  result.add(HorizontalLine.repeat(totalWidth) & "\n")
  
  # Alert rows
  for alert in alerts:
    let typeColor = colorForAlertType(alert.alertType)
    let strengthColor = colorForStrength(alert.strength)
    
    let indicators = formatIndicators(alert.indicators)
    let displayIndicators = if indicators.len > ColIndicators:
      indicators[0 ..< ColIndicators - 1] & "…"
    else:
      indicators.alignLeft(ColIndicators)
    
    result.add(
      alert.symbol.truncate(ColSymbol) & VerticalLine &
      " " & alert.strategyName.truncate(ColStrategy - 1) & VerticalLine &
      " " & typeColor & ($alert.alertType).alignLeft(ColSignal - 1) & colorReset() & VerticalLine &
      " " & strengthColor & ($alert.strength).alignLeft(ColStrength - 1) & colorReset() & VerticalLine &
      " " & (&"{alert.price:.2f}").alignLeft(ColPrice - 1) & VerticalLine &
      " " & displayIndicators & "\n"
    )
    
    # Add metadata row if detailed
    if detailLevel == dlDetailed and alert.metadata.len > 0:
      let meta = formatMetadata(alert.metadata)
      result.add("  " & colorCyan() & meta & colorReset() & "\n")
  
  result.add(DoubleHorizontalLine.repeat(totalWidth) & "\n")

proc formatCsvReport*(alerts: seq[Alert]): string =
  ## Formats alerts as CSV for export
  # CSV Header
  result = "Symbol,Strategy,AlertType,Strength,Price,Timestamp,Indicators,Metadata\n"
  
  # Data rows
  for alert in alerts:
    let indicators = formatIndicators(alert.indicators).replace(",", ";")
    let metadata = formatMetadata(alert.metadata).replace(",", ";")
    let timestamp = alert.timestamp.format("yyyy-MM-dd HH:mm:ss")
    
    result.add(&"{alert.symbol},{alert.strategyName},{alert.alertType},{alert.strength},")
    result.add(&"{alert.price:.2f},{timestamp},\"{indicators}\",\"{metadata}\"\n")

proc alertToJson(alert: Alert): JsonNode =
  ## Converts an alert to JSON
  result = %* {
    "symbol": alert.symbol,
    "strategy": alert.strategyName,
    "alertType": $alert.alertType,
    "strength": $alert.strength,
    "price": alert.price,
    "timestamp": alert.timestamp.format("yyyy-MM-dd'T'HH:mm:ss'Z'")
  }
  
  # Add indicators
  if alert.indicators.len > 0:
    var indicatorsJson = newJObject()
    for key, val in alert.indicators.pairs:
      indicatorsJson[key] = %val
    result["indicators"] = indicatorsJson
  
  # Add metadata
  if alert.metadata.len > 0:
    var metadataJson = newJObject()
    for key, val in alert.metadata.pairs:
      metadataJson[key] = %val
    result["metadata"] = metadataJson

proc formatJsonReport*(alerts: seq[Alert]): string =
  ## Formats alerts as JSON
  var alertsJson = newJArray()
  for alert in alerts:
    alertsJson.add(alertToJson(alert))
  
  let report = %* {
    "alerts": alertsJson,
    "count": alerts.len,
    "generatedAt": now().format("yyyy-MM-dd'T'HH:mm:ss'Z'")
  }
  
  result = report.pretty()

proc formatMarkdownReport*(alerts: seq[Alert]): string =
  ## Formats alerts as Markdown table
  result = "# Market Screener Report\n\n"
  result.add(&"Generated: {now().format(\"yyyy-MM-dd HH:mm:ss\")}\n\n")
  
  if alerts.len == 0:
    result.add("*No alerts found*\n")
    return
  
  result.add(&"Total Alerts: {alerts.len}\n\n")
  result.add("## Alerts\n\n")
  
  # Table header
  result.add("| Symbol | Strategy | Signal | Strength | Price | Indicators |\n")
  result.add("|--------|----------|--------|----------|-------|------------|\n")
  
  # Table rows
  for alert in alerts:
    let indicators = formatIndicators(alert.indicators).replace("|", "\\|")
    result.add(&"| {alert.symbol} | {alert.strategyName} | {alert.alertType} | {alert.strength} | ")
    result.add(&"{alert.price:.2f} | {indicators} |\n")
  
  result.add("\n")

proc printDetailedAlerts*(alerts: seq[Alert]): string =
  ## Prints alerts with full details (all indicators and metadata)
  if alerts.len == 0:
    return colorYellow() & "No alerts to display" & colorReset() & "\n"
  
  result = ""
  for i, alert in alerts:
    result.add(colorBold() & &"\n[Alert {i + 1}/{alerts.len}]" & colorReset() & "\n")
    result.add(DoubleHorizontalLine.repeat(60) & "\n")
    result.add(&"Symbol:     {colorCyan()}{alert.symbol}{colorReset()}\n")
    result.add(&"Strategy:   {alert.strategyName}\n")
    
    let typeColor = colorForAlertType(alert.alertType)
    result.add(&"Signal:     {typeColor}{alert.alertType}{colorReset()}\n")
    
    let strengthColor = colorForStrength(alert.strength)
    result.add(&"Strength:   {strengthColor}{alert.strength}{colorReset()}\n")
    
    result.add(&"Price:      ${alert.price:.2f}\n")
    result.add(&"Timestamp:  {alert.timestamp.format(\"yyyy-MM-dd HH:mm:ss\")}\n")
    
    # Indicators
    if alert.indicators.len > 0:
      result.add("\n" & colorBold() & "Indicators:" & colorReset() & "\n")
      for key, val in alert.indicators.pairs:
        result.add(&"  {key.alignLeft(20)} {val:>10.2f}\n")
    
    # Metadata
    if alert.metadata.len > 0:
      result.add("\n" & colorBold() & "Metadata:" & colorReset() & "\n")
      for key, val in alert.metadata.pairs:
        result.add(&"  {key.alignLeft(20)} {val}\n")
    
    result.add(HorizontalLine.repeat(60) & "\n")

proc generateReport*(alerts: seq[Alert], summary: ScreenerSummary, config: ScreenerOutputConfig): string =
  ## Main entry point for generating reports based on output configuration
  ## Returns formatted report as string
  
  case config.format
  of ofTerminal:
    # Terminal output with summary and table
    result = printSummary(summary) & "\n"
    
    result.add(formatTerminalTable(alerts, config.detailLevel))
    
  of ofCsv:
    result = formatCsvReport(alerts)
    
  of ofJson:
    result = formatJsonReport(alerts)
    
  of ofMarkdown:
    result = formatMarkdownReport(alerts)

proc generateReportWithSummary*(alerts: seq[Alert], summary: ScreenerSummary, 
                                config: ScreenerOutputConfig, showSummary: bool = true): string =
  ## Generates report with optional summary section
  ## Useful for showing just alerts without summary header
  
  if showSummary and config.format == ofTerminal:
    result = printSummary(summary) & "\n"
  
  case config.format
  of ofTerminal:
    result.add(formatTerminalTable(alerts, config.detailLevel))
  of ofCsv:
    result = formatCsvReport(alerts)
  of ofJson:
    result = formatJsonReport(alerts)
  of ofMarkdown:
    result = formatMarkdownReport(alerts)

# Export convenience functions for direct use
export printSummary, formatTerminalTable, formatCsvReport, formatJsonReport, formatMarkdownReport, printDetailedAlerts
