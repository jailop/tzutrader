# Reference Guide: Market Screening

## Overview

The screener module scans multiple symbols across one or more strategies to identify current trading opportunities. Unlike backtesting (which evaluates historical performance) or scanning (which ranks symbols by backtest results), screening focuses on finding actionable signals right now.

Screening answers questions like: "Which stocks are showing RSI oversold signals today?" or "What crypto pairs have MACD bullish crossovers in the last hour?"

Module: `tzutrader/screener/`

Sub-modules:
- `screener.nim` - Main screening logic
- `alerts.nim` - Alert data structures and filtering
- `schema.nim` - Configuration types
- `parser.nim` - YAML configuration parsing
- `reports.nim` - Output formatting
- `history.nim` - Result persistence

## Why Screen Markets

### Opportunity Discovery

Screening automates the search for trading setups across dozens or hundreds of symbols. Instead of manually checking charts, the screener identifies signals automatically.

### Time Efficiency

A screener can evaluate 100+ symbols in seconds—something that would take hours manually. This allows traders to focus on analysis rather than signal hunting.

### Consistency

Automated screening applies the same criteria consistently across all symbols, eliminating human bias and oversight.

### Multi-Strategy Confirmation

Run multiple strategies simultaneously to find opportunities confirmed by different technical approaches (e.g., RSI + MACD + Bollinger).

### Market Context

See the breadth of signals across the market. Many buy signals might indicate oversold conditions; few signals might suggest a strong trend.

## Alert Types

### AlertType Enum

```nim
type
  AlertType* = enum
    atBuySignal      ## Buy signal generated
    atSellSignal     ## Sell signal generated
    atExitLong       ## Exit long position
    atExitShort      ## Exit short position
    atNeutral        ## No signal
```

Signal Types:

| Type | Description | Use Case |
|------|-------------|----------|
| `atBuySignal` | Entry signal for long position | Finding buying opportunities |
| `atSellSignal` | Entry signal for short position | Finding shorting opportunities |
| `atExitLong` | Exit signal for existing long | Managing long positions |
| `atExitShort` | Exit signal for existing short | Managing short positions |
| `atNeutral` | No action signal | Informational only |

### AlertStrength Enum

```nim
type
  AlertStrength* = enum
    asWeak           ## Weak signal (low confidence)
    asModerate       ## Moderate signal (medium confidence)
    asStrong         ## Strong signal (high confidence)
```

Strength Levels:

| Strength | Confidence | Use Case |
|----------|-----------|----------|
| `asWeak` | Low | Research, watchlist building |
| `asModerate` | Medium | Initial screening, further analysis |
| `asStrong` | High | Actionable signals, immediate consideration |

Strength is calculated based on how definitively the signal conditions are met (e.g., RSI at 25 is stronger oversold than RSI at 32).

## Core Types

### Alert Type

```nim
type
  Alert* = object
    symbol*: string                      ## Symbol that generated the alert
    strategyName*: string                ## Strategy that generated the alert
    timestamp*: Time                     ## When the alert was generated
    alertType*: AlertType                ## Type of alert (Buy, Sell, etc.)
    strength*: AlertStrength             ## Signal strength
    price*: float64                      ## Price at alert generation
    indicators*: Table[string, float64]  ## Latest indicator values
    metadata*: Table[string, string]     ## Additional context/information
```

Fields:

| Field | Type | Description |
|-------|------|-------------|
| `symbol` | string | Ticker symbol (e.g., "AAPL") |
| `strategyName` | string | Name of strategy that generated signal |
| `timestamp` | Time | Alert generation time (Unix timestamp) |
| `alertType` | AlertType | Signal type (buy, sell, exit) |
| `strength` | AlertStrength | Signal confidence level |
| `price` | float64 | Current/latest price |
| `indicators` | Table | Key indicator values (e.g., RSI: 28.5) |
| `metadata` | Table | Extra info (e.g., reason for signal) |

### AlertCollection Type

```nim
type
  AlertCollection* = object
    generatedAt*: Time                   ## When the screener was run
    alerts*: seq[Alert]                  ## All alerts generated
    totalSymbols*: int                   ## Total symbols scanned
    totalStrategies*: int                ## Total strategies evaluated
```

Fields:

| Field | Type | Description |
|-------|------|-------------|
| `generatedAt` | Time | Screener run timestamp |
| `alerts` | seq[Alert] | All generated alerts |
| `totalSymbols` | int | Number of symbols scanned |
| `totalStrategies` | int | Number of strategies used |

## Configuration Types

### ScreenerStrategyConfig

```nim
type
  ScreenerStrategyKind* = enum
    skBuiltIn          ## Built-in strategy (e.g., "rsi", "macd")
    skYamlFile         ## YAML-defined strategy from file
  
  ScreenerStrategyConfig* = object
    case kind*: ScreenerStrategyKind
    of skBuiltIn:
      name*: string                        ## Strategy name
      params*: Table[string, ParamValue]   ## Strategy parameters
    of skYamlFile:
      filePath*: string                    ## Path to YAML strategy file
```

Built-in Strategy Example:

```nim
let rsiConfig = ScreenerStrategyConfig(
  kind: skBuiltIn,
  name: "rsi",
  params: toTable({
    "period": ParamValue(kind: pkInt, intVal: 14),
    "oversold": ParamValue(kind: pkFloat, floatVal: 30.0)
  })
)
```

YAML Strategy Example:

```nim
let customConfig = ScreenerStrategyConfig(
  kind: skYamlFile,
  filePath: "strategies/my_rsi.yml"
)
```

### LookbackPeriod

```nim
type
  TimeUnit* = enum
    tuMinutes = "m"    ## Minutes
    tuHours = "h"      ## Hours
    tuDays = "d"       ## Days
    tuWeeks = "w"      ## Weeks
    tuMonths = "mo"    ## Months
    tuYears = "y"      ## Years
  
  LookbackPeriod* = object
    value*: int        ## Numeric value
    unit*: TimeUnit    ## Time unit
```

Examples:

```nim
# 90 days
let period1 = LookbackPeriod(value: 90, unit: tuDays)

# 3 hours
let period2 = LookbackPeriod(value: 3, unit: tuHours)

# 6 months
let period3 = LookbackPeriod(value: 6, unit: tuMonths)
```

### ScreenerDataConfig

```nim
type
  DataSourceType* = enum
    dsYahoo            ## Yahoo Finance
    dsCoinbase         ## Coinbase
    dsCsv              ## CSV files
  
  ScreenerDataConfig* = object
    case source*: DataSourceType
    of dsYahoo:
      symbols*: seq[string]                ## Stock symbols
      lookback*: LookbackPeriod            ## How far back to look
      interval*: Interval                  ## Bar interval
    of dsCoinbase:
      pairs*: seq[string]                  ## Trading pairs
      lookbackCB*: LookbackPeriod          ## How far back to look
      intervalCB*: Interval                ## Bar interval
    of dsCsv:
      directory*: string                   ## Directory with CSV files
      lookbackCSV*: Option[LookbackPeriod] ## Optional filtering
```

Yahoo Finance Example:

```nim
let yahooData = ScreenerDataConfig(
  source: dsYahoo,
  symbols: @["AAPL", "MSFT", "GOOGL"],
  lookback: LookbackPeriod(value: 90, unit: tuDays),
  interval: Int1d
)
```

Coinbase Example:

```nim
let coinbaseData = ScreenerDataConfig(
  source: dsCoinbase,
  pairs: @["BTC-USD", "ETH-USD"],
  lookbackCB: LookbackPeriod(value: 7, unit: tuDays),
  intervalCB: Int1h
)
```

### ScreenerFilters

```nim
type
  ScreenerFilters* = object
    signalTypes*: seq[AlertType]           ## Filter by signal types
    minStrength*: AlertStrength            ## Minimum signal strength
    topN*: Option[int]                     ## Return only top N signals
```

Fields:

| Field | Type | Description |
|-------|------|-------------|
| `signalTypes` | seq[AlertType] | Which signal types to include |
| `minStrength` | AlertStrength | Minimum acceptable strength |
| `topN` | Option[int] | Limit to top N results (sorted by strength) |

Example:

```nim
let filters = ScreenerFilters(
  signalTypes: @[atBuySignal, atSellSignal],
  minStrength: asModerate,
  topN: some(10)
)
```

### ScreenerOutputConfig

```nim
type
  OutputFormat* = enum
    ofTerminal         ## Terminal table (default)
    ofCsv              ## CSV file
    ofJson             ## JSON file
    ofMarkdown         ## Markdown file
  
  DetailLevel* = enum
    dlSummary          ## Summary view (key info only)
    dlDetailed         ## Detailed view (all info)
  
  ScreenerOutputConfig* = object
    format*: OutputFormat                  ## Output format
    detailLevel*: DetailLevel              ## Level of detail
    filepath*: Option[string]              ## Output file (none = stdout)
    saveHistory*: bool                     ## Save results to history
    historyDir*: string                    ## History directory
```

Example:

```nim
let output = ScreenerOutputConfig(
  format: ofTerminal,
  detailLevel: dlDetailed,
  filepath: none(string),  # Print to terminal
  saveHistory: false,
  historyDir: "screener_history"
)
```

### Complete ScreenerConfig

```nim
type
  ScreenerConfig* = object
    metadata*: MetadataYAML                ## Metadata (name, description, etc.)
    strategies*: seq[ScreenerStrategyConfig]  ## Strategies to run
    data*: ScreenerDataConfig              ## Data configuration
    output*: ScreenerOutputConfig          ## Output configuration
    filters*: ScreenerFilters              ## Alert filters
```

## Core Functions

### Alert Construction

#### newAlert

```nim
proc newAlert*(symbol: string, strategyName: string, alertType: AlertType,
               price: float64, strength: AlertStrength = asModerate,
               indicators: Table[string, float64] = initTable[string, float64](),
               metadata: Table[string, string] = initTable[string, string]()): Alert
```

Create a new alert with current timestamp.

Parameters:

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `symbol` | string | — | Symbol ticker |
| `strategyName` | string | — | Strategy name |
| `alertType` | AlertType | — | Signal type |
| `price` | float64 | — | Current price |
| `strength` | AlertStrength | asModerate | Signal strength |
| `indicators` | Table | empty | Indicator values |
| `metadata` | Table | empty | Additional info |

Example:

```nim
let alert = newAlert(
  symbol = "AAPL",
  strategyName = "RSI Mean Reversion",
  alertType = atBuySignal,
  price = 178.25,
  strength = asStrong,
  indicators = {"rsi": 28.5}.toTable,
  metadata = {"reason": "RSI oversold"}.toTable
)
```

#### newAlertFromSignal

```nim
proc newAlertFromSignal*(signal: Signal, strategyName: string,
                         strength: AlertStrength = asModerate,
                         indicators: Table[string, float64] = initTable[string, float64]()): Alert
```

Create an alert from a backtest Signal object.

Parameters:

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `signal` | Signal | — | Signal from strategy |
| `strategyName` | string | — | Strategy name |
| `strength` | AlertStrength | asModerate | Signal strength |
| `indicators` | Table | empty | Indicator values |

Example:

```nim
# In strategy callback
proc onBar(state: var StrategyState, bar: OHLCV): Signal =
  # ... strategy logic ...
  if rsi < 30:
    let signal = Signal(position: Buy, price: bar.close, symbol: "AAPL", ...)
    
    # Later, in screener
    let alert = newAlertFromSignal(
      signal = signal,
      strategyName = "RSI",
      strength = asStrong,
      indicators = {"rsi": rsi}.toTable
    )
```

### Alert Filtering

#### filterByType

```nim
proc filterByType*(alerts: seq[Alert], alertTypes: seq[AlertType]): seq[Alert]
```

Filter alerts by alert type(s).

Example:

```nim
let buySignals = alerts.filterByType(@[atBuySignal])
let entrySignals = alerts.filterByType(@[atBuySignal, atSellSignal])
```

#### filterByStrength

```nim
proc filterByStrength*(alerts: seq[Alert], minStrength: AlertStrength): seq[Alert]
```

Filter alerts by minimum strength.

Example:

```nim
let strongAlerts = alerts.filterByStrength(asStrong)
let tradableAlerts = alerts.filterByStrength(asModerate)
```

#### filterBySymbol

```nim
proc filterBySymbol*(alerts: seq[Alert], symbols: seq[string]): seq[Alert]
```

Filter alerts by symbol(s).

Example:

```nim
let techAlerts = alerts.filterBySymbol(@["AAPL", "MSFT", "GOOGL"])
```

#### filterByStrategy

```nim
proc filterByStrategy*(alerts: seq[Alert], strategies: seq[string]): seq[Alert]
```

Filter alerts by strategy name(s).

Example:

```nim
let rsiAlerts = alerts.filterByStrategy(@["rsi"])
```

### Alert Sorting

#### sortByStrength

```nim
proc sortByStrength*(alerts: var seq[Alert], ascending: bool = false)
```

Sort alerts by strength (descending by default).

Example:

```nim
var alerts = @[...]
alerts.sortByStrength()  # Strongest first
```

#### sortBySymbol

```nim
proc sortBySymbol*(alerts: var seq[Alert])
```

Sort alerts alphabetically by symbol.

#### sortByPrice

```nim
proc sortByPrice*(alerts: var seq[Alert], ascending: bool = true)
```

Sort alerts by price.

#### sortByTimestamp

```nim
proc sortByTimestamp*(alerts: var seq[Alert], ascending: bool = false)
```

Sort alerts by timestamp (most recent first by default).

### Alert Utilities

#### topN

```nim
proc topN*(alerts: seq[Alert], n: int): seq[Alert]
```

Get top N alerts (assumes already sorted).

Example:

```nim
var alerts = @[...]
alerts.sortByStrength()
let top10 = alerts.topN(10)
```

#### countByType

```nim
proc countByType*(alerts: seq[Alert]): Table[AlertType, int]
```

Count alerts by type.

Example:

```nim
let counts = alerts.countByType()
echo "Buy signals: ", counts[atBuySignal]
echo "Sell signals: ", counts[atSellSignal]
```

#### countByStrength

```nim
proc countByStrength*(alerts: seq[Alert]): Table[AlertStrength, int]
```

Count alerts by strength.

Example:

```nim
let counts = alerts.countByStrength()
echo "Strong: ", counts[asStrong]
echo "Moderate: ", counts[asModerate]
```

## Screener Operations

### Creating a Screener

```nim
proc newScreener*(config: ScreenerConfig): Screener
```

Create a new screener from configuration.

Example:

```nim
let config = parseScreenerYAMLFile("my_screener.yml")
var screener = newScreener(config)
```

### Running the Screener

```nim
proc run*(screener: var Screener): ScreenerResult
```

Run the screener and generate alerts.

Returns: `ScreenerResult` containing:
- `alerts`: AlertCollection with all generated alerts
- `summary`: ScreenerSummary with statistics

Example:

```nim
var screener = newScreener(config)
let result = screener.run()

echo "Total alerts: ", result.alerts.alerts.len
echo "Symbols scanned: ", result.summary.totalSymbols
```

## Configuration Parsing

### parseScreenerYAMLFile

```nim
proc parseScreenerYAMLFile*(filepath: string): ScreenerConfig
```

Parse a screener YAML configuration file.

Parameters:
- `filepath`: Path to YAML configuration file

Returns: Parsed `ScreenerConfig`

Raises: `ScreenerParseError` if parsing fails

Example:

```nim
try:
  let config = parseScreenerYAMLFile("screeners/daily_scan.yml")
  var screener = newScreener(config)
  let result = screener.run()
except ScreenerParseError as e:
  echo "Parse error: ", e.msg
```

### validateConfig

```nim
proc validateConfig*(config: ScreenerConfig): ValidationResult
```

Validate screener configuration.

Returns: `ValidationResult` with:
- `valid`: bool - Whether config is valid
- `errors`: seq[string] - List of validation errors

Example:

```nim
let config = parseScreenerYAMLFile("my_screener.yml")
let validation = validateConfig(config)

if not validation.valid:
  echo "Configuration errors:"
  for err in validation.errors:
    echo "  - ", err
```

## Time Period Utilities

### parseLookbackPeriod

```nim
proc parseLookbackPeriod*(s: string): LookbackPeriod
```

Parse a lookback period string (e.g., "3h", "90d", "1y").

Examples:

```nim
let period1 = parseLookbackPeriod("90d")   # 90 days
let period2 = parseLookbackPeriod("6mo")   # 6 months
let period3 = parseLookbackPeriod("3h")    # 3 hours
```

### lookbackToStartDate

```nim
proc lookbackToStartDate*(lookback: LookbackPeriod, currentTime: DateTime = now()): DateTime
```

Convert a lookback period to an absolute start date.

Example:

```nim
let period = parseLookbackPeriod("90d")
let startDate = lookbackToStartDate(period)
echo "Fetch data from: ", startDate.format("yyyy-MM-dd")
```

### lookbackToBarCount

```nim
proc lookbackToBarCount*(lookback: LookbackPeriod, interval: Interval): int
```

Estimate the number of bars needed for a given lookback period and interval.

Example:

```nim
let lookback = parseLookbackPeriod("3h")
let barCount = lookbackToBarCount(lookback, Int5m)
echo "Need approximately ", barCount, " bars"  # ~36 bars
```

## Report Generation

### formatResult

```nim
proc formatResult*(result: ScreenerResult, output: ScreenerOutputConfig): string
```

Format screener results according to output configuration.

Parameters:
- `result`: ScreenerResult from screener.run()
- `output`: ScreenerOutputConfig specifying format

Returns: Formatted string (terminal, CSV, JSON, or Markdown)

Example:

```nim
let result = screener.run()
let report = formatResult(result, config.output)

if config.output.filepath.isSome:
  writeFile(config.output.filepath.get, report)
else:
  echo report
```

## History Tracking

### saveScreenerHistory

```nim
proc saveScreenerHistory*(entry: ScreenerHistoryEntry, directory: string)
```

Save screener results to history.

Parameters:
- `entry`: ScreenerHistoryEntry to save
- `directory`: Directory to save history files

Example:

```nim
let entry = ScreenerHistoryEntry(
  timestamp: getTime(),
  configName: config.metadata.name,
  alerts: result.alerts.alerts,
  symbolsScanned: result.summary.totalSymbols,
  strategiesUsed: result.summary.totalStrategies,
  totalSignals: result.alerts.alerts.len
)

saveScreenerHistory(entry, "screener_history")
```

### loadScreenerHistory

```nim
proc loadScreenerHistory*(directory: string, limit: int = 10): seq[ScreenerHistoryEntry]
```

Load recent screener history entries.

Parameters:
- `directory`: Directory containing history files
- `limit`: Maximum number of entries to load (default: 10)

Returns: Sequence of history entries, newest first

Example:

```nim
let history = loadScreenerHistory("screener_history", limit = 30)
echo "Found ", history.len, " historical runs"
```

### compareScreenerResults

```nim
proc compareScreenerResults*(current: seq[Alert], previous: seq[Alert]): tuple[
  new: seq[Alert],
  removed: seq[Alert],
  recurring: seq[Alert]
]
```

Compare current screening results with previous run.

Returns: Tuple with:
- `new`: Alerts that are new (not in previous)
- `removed`: Alerts from previous that are gone
- `recurring`: Alerts that appear in both

Example:

```nim
let history = loadScreenerHistory("screener_history", limit = 1)
if history.len > 0:
  let comparison = compareScreenerResults(
    current = currentAlerts,
    previous = history[0].alerts
  )
  
  echo "New alerts: ", comparison.new.len
  echo "Removed: ", comparison.removed.len
  echo "Recurring: ", comparison.recurring.len
```

## JSON Serialization

### Alert to JSON

```nim
proc toJson*(alert: Alert): JsonNode
```

Convert Alert to JSON.

Example:

```nim
let alert = newAlert(...)
let json = alert.toJson()
echo json.pretty()
```

### AlertCollection to JSON

```nim
proc toJson*(collection: AlertCollection): JsonNode
```

Convert AlertCollection to JSON.

Example:

```nim
let result = screener.run()
let json = result.alerts.toJson()
writeFile("alerts.json", json.pretty())
```

## Complete Example

```nim
import tzutrader/screener/[screener, parser, reports, alerts]

# Parse configuration
let config = parseScreenerYAMLFile("screeners/daily_scan.yml")

# Validate
let validation = validateConfig(config)
if not validation.valid:
  echo "Errors: ", validation.errors
  quit(1)

# Create and run screener
var screener = newScreener(config)
let result = screener.run()

# Filter results
var filteredAlerts = result.alerts.alerts
filteredAlerts = filteredAlerts.filterByType(@[atBuySignal])
filteredAlerts = filteredAlerts.filterByStrength(asModerate)
filteredAlerts.sortByStrength()
let topAlerts = filteredAlerts.topN(10)

# Display results
echo "Top 10 Buy Signals:"
for alert in topAlerts:
  echo &"{alert.symbol}: {alert.strength} at ${alert.price:.2f}"

# Save history
if config.output.saveHistory:
  let entry = ScreenerHistoryEntry(
    timestamp: getTime(),
    configName: config.metadata.name,
    alerts: result.alerts.alerts,
    symbolsScanned: result.summary.totalSymbols,
    strategiesUsed: result.summary.totalStrategies,
    totalSignals: result.alerts.alerts.len
  )
  saveScreenerHistory(entry, config.output.historyDir)
```

## See Also

- [User Guide: Market Screening](../user_guide/08_screening.md) - How to use the screener
