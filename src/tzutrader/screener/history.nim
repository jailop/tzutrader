## Screener Results Persistence Module
##
## This module provides functionality to save and load screener results
## for historical tracking and analysis.

import std/[times, json, os, strutils, tables, strformat, algorithm]
import ./alerts
import ./schema

type
  ScreenerHistoryEntry* = object
    ## A single screener run saved to history
    timestamp*: Time
    configName*: string
    alerts*: seq[Alert]
    symbolsScanned*: int
    strategiesUsed*: int
    totalSignals*: int

# Helper functions to convert between string representation and enum
proc parseAlertType(s: string): AlertType =
  ## Parse AlertType from string representation
  case s
  of "BUY": atBuySignal
  of "SELL": atSellSignal
  of "EXIT LONG": atExitLong
  of "EXIT SHORT": atExitShort
  of "NEUTRAL": atNeutral
  else: raise newException(ValueError, "Invalid AlertType string: " & s)

proc parseAlertStrength(s: string): AlertStrength =
  ## Parse AlertStrength from string representation
  case s
  of "WEAK": asWeak
  of "MODERATE": asModerate
  of "STRONG": asStrong
  else: raise newException(ValueError, "Invalid AlertStrength string: " & s)

proc alertToJsonNode(alert: Alert): JsonNode =
  ## Convert alert to JSON node
  result = %* {
    "symbol": alert.symbol,
    "strategyName": alert.strategyName,
    "timestamp": alert.timestamp.toUnix(),
    "alertType": $alert.alertType,
    "strength": $alert.strength,
    "price": alert.price
  }
  
  if alert.indicators.len > 0:
    var indicatorsJson = newJObject()
    for key, val in alert.indicators.pairs:
      indicatorsJson[key] = %val
    result["indicators"] = indicatorsJson
  
  if alert.metadata.len > 0:
    var metadataJson = newJObject()
    for key, val in alert.metadata.pairs:
      metadataJson[key] = %val
    result["metadata"] = metadataJson

proc alertFromJsonNode(node: JsonNode): Alert =
  ## Convert JSON node to alert
  result = Alert(
    symbol: node["symbol"].getStr(),
    strategyName: node["strategyName"].getStr(),
    timestamp: fromUnix(node["timestamp"].getInt()),
    alertType: parseAlertType(node["alertType"].getStr()),
    strength: parseAlertStrength(node["strength"].getStr()),
    price: node["price"].getFloat()
  )
  
  if node.hasKey("indicators"):
    for key, val in node["indicators"].pairs:
      result.indicators[key] = val.getFloat()
  
  if node.hasKey("metadata"):
    for key, val in node["metadata"].pairs:
      result.metadata[key] = val.getStr()

proc saveScreenerHistory*(
  configName: string,
  alerts: seq[Alert],
  symbolsScanned: int,
  strategiesUsed: int,
  historyDir: string = "screener_history"
): void =
  ## Save screener results to history
  ## Creates a JSON file with timestamp in the history directory
  
  # Create history directory if it doesn't exist
  if not dirExists(historyDir):
    createDir(historyDir)
  
  # Create entry
  let entry = ScreenerHistoryEntry(
    timestamp: getTime(),
    configName: configName,
    alerts: alerts,
    symbolsScanned: symbolsScanned,
    strategiesUsed: strategiesUsed,
    totalSignals: alerts.len
  )
  
  # Convert to JSON
  var alertsJson = newJArray()
  for alert in alerts:
    alertsJson.add(alertToJsonNode(alert))
  
  let entryJson = %* {
    "timestamp": entry.timestamp.toUnix(),
    "configName": entry.configName,
    "symbolsScanned": entry.symbolsScanned,
    "strategiesUsed": entry.strategiesUsed,
    "totalSignals": entry.totalSignals,
    "alerts": alertsJson
  }
  
  # Generate filename with timestamp
  let timestamp = entry.timestamp.format("yyyyMMdd'_'HHmmss")
  let filename = &"{configName}_{timestamp}.json"
  let filepath = historyDir / filename
  
  # Write to file
  writeFile(filepath, entryJson.pretty())

proc loadScreenerHistory*(filepath: string): ScreenerHistoryEntry =
  ## Load screener results from history file
  
  let content = readFile(filepath)
  let json = parseJson(content)
  
  result = ScreenerHistoryEntry(
    timestamp: fromUnix(json["timestamp"].getInt()),
    configName: json["configName"].getStr(),
    symbolsScanned: json["symbolsScanned"].getInt(),
    strategiesUsed: json["strategiesUsed"].getInt(),
    totalSignals: json["totalSignals"].getInt(),
    alerts: @[]
  )
  
  for alertNode in json["alerts"]:
    result.alerts.add(alertFromJsonNode(alertNode))

proc listScreenerHistory*(historyDir: string = "screener_history"): seq[string] =
  ## List all screener history files
  result = @[]
  
  if not dirExists(historyDir):
    return
  
  for file in walkFiles(historyDir / "*.json"):
    result.add(file)
  
  # Sort by modification time (newest first)
  result.sort(proc(a, b: string): int =
    let aTime = getLastModificationTime(a)
    let bTime = getLastModificationTime(b)
    if aTime > bTime: -1
    elif aTime < bTime: 1
    else: 0
  )

proc getLatestScreenerResult*(
  configName: string,
  historyDir: string = "screener_history"
): ScreenerHistoryEntry =
  ## Get the latest result for a specific configuration
  
  let files = listScreenerHistory(historyDir)
  
  for file in files:
    if configName in file:
      return loadScreenerHistory(file)
  
  raise newException(IOError, &"No history found for config: {configName}")

proc compareScreenerResults*(
  entry1: ScreenerHistoryEntry,
  entry2: ScreenerHistoryEntry
): tuple[newSignals: seq[Alert], removedSignals: seq[Alert]] =
  ## Compare two screener results to find new and removed signals
  
  # Find new signals (in entry2 but not in entry1)
  result.newSignals = @[]
  for alert2 in entry2.alerts:
    var found = false
    for alert1 in entry1.alerts:
      if alert1.symbol == alert2.symbol and alert1.strategyName == alert2.strategyName:
        found = true
        break
    if not found:
      result.newSignals.add(alert2)
  
  # Find removed signals (in entry1 but not in entry2)
  result.removedSignals = @[]
  for alert1 in entry1.alerts:
    var found = false
    for alert2 in entry2.alerts:
      if alert1.symbol == alert2.symbol and alert1.strategyName == alert2.strategyName:
        found = true
        break
    if not found:
      result.removedSignals.add(alert1)

proc printHistorySummary*(entries: seq[ScreenerHistoryEntry]): string =
  ## Print a summary of historical screener runs
  result = "SCREENER HISTORY\n"
  result.add("=" .repeat(60) & "\n")
  
  for entry in entries:
    let dateStr = entry.timestamp.format("yyyy-MM-dd HH:mm:ss")
    result.add(&"{dateStr} | {entry.configName}\n")
    result.add(&"  Symbols: {entry.symbolsScanned}, ")
    result.add(&"Strategies: {entry.strategiesUsed}, ")
    result.add(&"Signals: {entry.totalSignals}\n")
  
  result.add("=" .repeat(60) & "\n")

export ScreenerHistoryEntry, saveScreenerHistory, loadScreenerHistory,
       listScreenerHistory, getLatestScreenerResult, compareScreenerResults,
       printHistorySummary
