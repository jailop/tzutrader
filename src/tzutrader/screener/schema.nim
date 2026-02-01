## Schema Type Definitions for Screener Configuration
##
## This module defines the types used for configuring the market screener
## via YAML files. These types form the structure for screener configurations.

import std/[tables, options, strformat, strutils, times]
import ../declarative/schema  # Reuse MetadataYAML and ParamValue
import ../data  # Reuse Interval type
import alerts

type
  # ============================================================================
  # Time Period Types
  # ============================================================================
  
  TimeUnit* = enum
    ## Time unit for lookback periods
    tuMinutes = "m"    ## Minutes
    tuHours = "h"      ## Hours
    tuDays = "d"       ## Days
    tuWeeks = "w"      ## Weeks
    tuMonths = "mo"    ## Months
    tuYears = "y"      ## Years
  
  LookbackPeriod* = object
    ## Relative time period (e.g., "3h", "90d", "1y")
    value*: int        ## Numeric value
    unit*: TimeUnit    ## Time unit
  
  # ============================================================================
  # Strategy Configuration
  # ============================================================================
  
  ScreenerStrategyKind* = enum
    ## Type of strategy configuration
    skBuiltIn          ## Built-in strategy (e.g., "rsi", "macd")
    skYamlFile         ## YAML-defined strategy from file
  
  ScreenerStrategyConfig* = object
    ## Strategy configuration for screener
    case kind*: ScreenerStrategyKind
    of skBuiltIn:
      name*: string                        ## Strategy name (e.g., "rsi")
      params*: Table[string, ParamValue]   ## Strategy parameters
    of skYamlFile:
      filePath*: string                    ## Path to YAML strategy file
  
  # ============================================================================
  # Data Configuration
  # ============================================================================
  
  DataSourceType* = enum
    ## Type of data source
    dsYahoo            ## Yahoo Finance
    dsCoinbase         ## Coinbase
    dsCsv              ## CSV files
  
  ScreenerDataConfig* = object
    ## Data source configuration
    case source*: DataSourceType
    of dsYahoo:
      symbols*: seq[string]                ## Stock symbols
      lookback*: LookbackPeriod            ## How far back to look
      interval*: Interval                  ## Bar interval (from data module)
    of dsCoinbase:
      pairs*: seq[string]                  ## Trading pairs (e.g., "BTC-USD")
      lookbackCB*: LookbackPeriod          ## How far back to look
      intervalCB*: Interval                ## Bar interval (from data module)
    of dsCsv:
      directory*: string                   ## Directory with CSV files
      lookbackCSV*: Option[LookbackPeriod] ## Optional filtering
  
  # ============================================================================
  # Output Configuration
  # ============================================================================
  
  OutputFormat* = enum
    ## Output format for screener results
    ofTerminal         ## Terminal table (default)
    ofCsv              ## CSV file
    ofJson             ## JSON file
    ofMarkdown         ## Markdown file
  
  DetailLevel* = enum
    ## Level of detail in output
    dlSummary          ## Summary view (key info only)
    dlDetailed         ## Detailed view (all info)
  
  ScreenerOutputConfig* = object
    ## Output configuration
    format*: OutputFormat                  ## Output format
    detailLevel*: DetailLevel              ## Level of detail
    filepath*: Option[string]              ## Output file (none = stdout)
    saveHistory*: bool                     ## Save results to history (default: false)
    historyDir*: string                    ## History directory (default: "screener_history")
  
  # ============================================================================
  # Filters
  # ============================================================================
  
  ScreenerFilters* = object
    ## Filters for alert selection
    signalTypes*: seq[AlertType]           ## Filter by signal types
    minStrength*: AlertStrength            ## Minimum signal strength
    topN*: Option[int]                     ## Return only top N signals
  
  # ============================================================================
  # Complete Screener Configuration
  # ============================================================================
  
  ScreenerConfig* = object
    ## Complete screener configuration
    metadata*: MetadataYAML                ## Metadata (name, description, etc.)
    strategies*: seq[ScreenerStrategyConfig]  ## Strategies to run
    data*: ScreenerDataConfig              ## Data configuration
    output*: ScreenerOutputConfig          ## Output configuration
    filters*: ScreenerFilters              ## Alert filters

  ScreenerConfigError* = object of CatchableError
    ## Error in screener configuration

# ============================================================================
# Constructor Functions
# ============================================================================

proc newLookbackPeriod*(value: int, unit: TimeUnit): LookbackPeriod =
  ## Create a new lookback period
  result = LookbackPeriod(value: value, unit: unit)

proc newBuiltInStrategy*(name: string, 
                        params: Table[string, ParamValue] = initTable[string, ParamValue]()): ScreenerStrategyConfig =
  ## Create a built-in strategy configuration
  result = ScreenerStrategyConfig(
    kind: skBuiltIn,
    name: name,
    params: params
  )

proc newYamlStrategy*(filePath: string): ScreenerStrategyConfig =
  ## Create a YAML file strategy configuration
  result = ScreenerStrategyConfig(
    kind: skYamlFile,
    filePath: filePath
  )

proc newYahooDataConfig*(symbols: seq[string], lookback: LookbackPeriod, 
                        interval: Interval = Int1d): ScreenerDataConfig =
  ## Create Yahoo Finance data configuration
  result = ScreenerDataConfig(
    source: dsYahoo,
    symbols: symbols,
    lookback: lookback,
    interval: interval
  )

proc newCoinbaseDataConfig*(pairs: seq[string], lookback: LookbackPeriod,
                           interval: Interval = Int1h): ScreenerDataConfig =
  ## Create Coinbase data configuration
  result = ScreenerDataConfig(
    source: dsCoinbase,
    pairs: pairs,
    lookbackCB: lookback,
    intervalCB: interval
  )

proc newCsvDataConfig*(directory: string, 
                      lookback: Option[LookbackPeriod] = none(LookbackPeriod)): ScreenerDataConfig =
  ## Create CSV data configuration
  result = ScreenerDataConfig(
    source: dsCsv,
    directory: directory,
    lookbackCSV: lookback
  )

proc newOutputConfig*(format: OutputFormat = ofTerminal, 
                     detailLevel: DetailLevel = dlSummary,
                     filepath: Option[string] = none(string),
                     saveHistory: bool = false,
                     historyDir: string = "screener_history"): ScreenerOutputConfig =
  ## Create output configuration
  result = ScreenerOutputConfig(
    format: format,
    detailLevel: detailLevel,
    filepath: filepath,
    saveHistory: saveHistory,
    historyDir: historyDir
  )

proc newScreenerFilters*(signalTypes: seq[AlertType] = @[atBuySignal, atSellSignal],
                        minStrength: AlertStrength = asModerate,
                        topN: Option[int] = none(int)): ScreenerFilters =
  ## Create screener filters
  result = ScreenerFilters(
    signalTypes: signalTypes,
    minStrength: minStrength,
    topN: topN
  )

proc newScreenerConfig*(metadata: MetadataYAML,
                       strategies: seq[ScreenerStrategyConfig],
                       data: ScreenerDataConfig,
                       output: ScreenerOutputConfig = newOutputConfig(),
                       filters: ScreenerFilters = newScreenerFilters()): ScreenerConfig =
  ## Create a complete screener configuration
  result = ScreenerConfig(
    metadata: metadata,
    strategies: strategies,
    data: data,
    output: output,
    filters: filters
  )

# ============================================================================
# String Parsing Functions
# ============================================================================

proc parseLookbackPeriod*(s: string): LookbackPeriod =
  ## Parse a lookback period string (e.g., "3h", "90d", "1y")
  ## 
  ## Examples:
  ## - "3h" -> LookbackPeriod(value: 3, unit: tuHours)
  ## - "90d" -> LookbackPeriod(value: 90, unit: tuDays)
  ## - "1y" -> LookbackPeriod(value: 1, unit: tuYears)
  ## - "6mo" -> LookbackPeriod(value: 6, unit: tuMonths)
  
  if s.len == 0:
    raise newException(ScreenerConfigError, "Empty lookback period string")
  
  # Find where the unit starts
  var numEnd = 0
  for i, c in s:
    if c in {'0'..'9'}:
      numEnd = i + 1
    else:
      break
  
  if numEnd == 0:
    raise newException(ScreenerConfigError, &"Invalid lookback period: {s} (no numeric value)")
  
  let valueStr = s[0..<numEnd]
  let unitStr = s[numEnd..^1]
  
  let value = try:
    parseInt(valueStr)
  except ValueError:
    raise newException(ScreenerConfigError, &"Invalid numeric value in lookback period: {valueStr}")
  
  let unit = case unitStr
    of "m": tuMinutes
    of "h": tuHours
    of "d": tuDays
    of "w": tuWeeks
    of "mo": tuMonths
    of "y": tuYears
    else:
      raise newException(ScreenerConfigError, &"Invalid time unit: {unitStr} (use m/h/d/w/mo/y)")
  
  result = LookbackPeriod(value: value, unit: unit)

proc parseTimeInterval*(s: string): Interval =
  ## Parse a time interval string to the existing Interval enum
  ## 
  ## Examples:
  ## - "1m" -> Int1m
  ## - "5m" -> Int5m
  ## - "1h" -> Int1h
  ## - "1d" -> Int1d
  
  case s
  of "1m": Int1m
  of "5m": Int5m
  of "15m": Int15m
  of "30m": Int30m
  of "1h": Int1h
  of "1d": Int1d
  of "1w", "1wk": Int1wk
  of "1mo": Int1mo
  else:
    raise newException(ScreenerConfigError, &"Invalid time interval: {s} (use 1m/5m/15m/30m/1h/1d/1wk/1mo)")

# ============================================================================
# Time Conversion Functions
# ============================================================================

proc lookbackToStartDate*(lookback: LookbackPeriod, currentTime: DateTime = now()): DateTime =
  ## Convert a lookback period to an absolute start date
  ## 
  ## Examples:
  ## - lookback = "90d", currentTime = 2024-02-15 -> 2024-11-17
  ## - lookback = "3h", currentTime = 2024-02-15 15:00 -> 2024-02-15 12:00
  
  case lookback.unit
  of tuMinutes:
    result = currentTime - initDuration(minutes = lookback.value)
  of tuHours:
    result = currentTime - initDuration(hours = lookback.value)
  of tuDays:
    result = currentTime - initDuration(days = lookback.value)
  of tuWeeks:
    result = currentTime - initDuration(weeks = lookback.value)
  of tuMonths:
    # Approximate: 1 month = 30 days
    result = currentTime - initDuration(days = lookback.value * 30)
  of tuYears:
    # Approximate: 1 year = 365 days
    result = currentTime - initDuration(days = lookback.value * 365)

proc lookbackToBarCount*(lookback: LookbackPeriod, interval: Interval): int =
  ## Estimate the number of bars needed for a given lookback period and interval
  ## This is useful for ensuring we fetch enough data for indicator calculations
  ## 
  ## Examples:
  ## - lookback = "3h", interval = Int5m -> 36 bars (3 * 60 / 5)
  ## - lookback = "90d", interval = Int1d -> 90 bars
  
  # First convert lookback to minutes
  let lookbackMinutes = case lookback.unit
    of tuMinutes: lookback.value
    of tuHours: lookback.value * 60
    of tuDays: lookback.value * 24 * 60
    of tuWeeks: lookback.value * 7 * 24 * 60
    of tuMonths: lookback.value * 30 * 24 * 60  # Approximate
    of tuYears: lookback.value * 365 * 24 * 60  # Approximate
  
  # Use the existing toSeconds() and convert to minutes
  let intervalMinutes = interval.toSeconds() div 60
  
  result = lookbackMinutes div int(intervalMinutes)

# ============================================================================
# String Representation
# ============================================================================

proc `$`*(lookback: LookbackPeriod): string =
  ## String representation of lookback period
  result = $lookback.value & $lookback.unit

# Note: Interval already has `$` defined in data.nim

proc `$`*(format: OutputFormat): string =
  ## String representation of output format
  case format
  of ofTerminal: "terminal"
  of ofCsv: "csv"
  of ofJson: "json"
  of ofMarkdown: "markdown"

proc `$`*(level: DetailLevel): string =
  ## String representation of detail level
  case level
  of dlSummary: "summary"
  of dlDetailed: "detailed"

# ============================================================================
# Screener Results
# ============================================================================

type
  ScreenerSummary* = object
    ## Summary statistics from screener run
    totalSymbols*: int
    totalStrategies*: int
    totalSignals*: int
    signalsByType*: Table[AlertType, int]
    signalsByStrength*: Table[AlertStrength, int]
    topOpportunities*: seq[Alert]
