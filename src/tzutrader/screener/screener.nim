## Market Screener - Main Module
##
## This module provides the core screener functionality for scanning
## multiple symbols across multiple strategies and generating alerts.
##
## The screener:
## - Fetches market data for multiple symbols
## - Runs multiple strategies on each symbol
## - Generates alerts from the latest signals
## - Filters and ranks results
## - Produces structured output
##
## Usage:
## ```nim
## let config = newScreenerConfig(...)
## var screener = newScreener(config)
## let results = screener.run()
## ```

import std/[tables, times, strformat, sequtils, algorithm, strutils, os, options]
import ../core
import ../data
import ../strategy
import ../declarative/[parser, validator, strategy_builder, schema as declSchema]
import ../strategies/[rsi, macd, bollinger, crossover, stochastic, mfi, cci,
                      kama, aroon, parabolic_sar, triple_ma, adx_trend,
                      keltner, volume_breakout, dual_momentum, filtered_mean_reversion]
import alerts
import schema
import reports
import history

type
  Screener* = object
    ## Main screener object
    config*: ScreenerConfig
    strategies*: seq[tuple[name: string, strategy: Strategy]]
    
  ScreenerResult* = object
    ## Results from a screener run
    alerts*: AlertCollection
    summary*: ScreenerSummary
  
  ScreenerError* = object of CatchableError
    ## Error during screener execution

# ============================================================================
# Screener Construction
# ============================================================================

proc loadStrategy(config: ScreenerStrategyConfig): tuple[name: string, strategy: Strategy] =
  ## Load a strategy from configuration
  case config.kind
  of skBuiltIn:
    # Create built-in strategy
    var params = initTable[string, float64]()
    for key, val in config.params:
      case val.kind
      of pkInt:
        params[key] = float64(val.intVal)
      of pkFloat:
        params[key] = val.floatVal
      of pkString:
        # Try to parse string as float
        try:
          params[key] = parseFloat(val.strVal)
        except ValueError:
          discard
      of pkBool:
        params[key] = if val.boolVal: 1.0 else: 0.0
    
    # Create strategy based on name
    let strategy = case config.name.toLowerAscii()
      of "rsi":
        let period = if params.hasKey("period"): int(params["period"]) else: 14
        let oversold = if params.hasKey("oversold"): params["oversold"] else: 30.0
        let overbought = if params.hasKey("overbought"): params["overbought"] else: 70.0
        newRSIStrategy(period, oversold, overbought)
      
      of "macd":
        let fast = if params.hasKey("fast"): int(params["fast"]) else: 12
        let slow = if params.hasKey("slow"): int(params["slow"]) else: 26
        let signal = if params.hasKey("signal"): int(params["signal"]) else: 9
        newMACDStrategy(fast, slow, signal)
      
      of "bollinger":
        let period = if params.hasKey("period"): int(params["period"]) else: 20
        let stdDev = if params.hasKey("stdDev"): params["stdDev"] else: 2.0
        newBollingerStrategy(period, stdDev)
      
      of "crossover":
        let fastPeriod = if params.hasKey("fastPeriod"): int(params["fastPeriod"]) else: 50
        let slowPeriod = if params.hasKey("slowPeriod"): int(params["slowPeriod"]) else: 200
        newCrossoverStrategy(fastPeriod, slowPeriod)
      
      of "stochastic":
        let kPeriod = if params.hasKey("kPeriod"): int(params["kPeriod"]) else: 14
        let dPeriod = if params.hasKey("dPeriod"): int(params["dPeriod"]) else: 3
        let oversold = if params.hasKey("oversold"): params["oversold"] else: 20.0
        let overbought = if params.hasKey("overbought"): params["overbought"] else: 80.0
        newStochasticStrategy(kPeriod, dPeriod, oversold, overbought)
      
      of "mfi":
        let period = if params.hasKey("period"): int(params["period"]) else: 14
        let oversold = if params.hasKey("oversold"): params["oversold"] else: 20.0
        let overbought = if params.hasKey("overbought"): params["overbought"] else: 80.0
        newMFIStrategy(period, oversold, overbought)
      
      of "cci":
        let period = if params.hasKey("period"): int(params["period"]) else: 20
        let oversold = if params.hasKey("oversold"): params["oversold"] else: -100.0
        let overbought = if params.hasKey("overbought"): params["overbought"] else: 100.0
        newCCIStrategy(period, oversold, overbought)
      
      else:
        raise newException(ScreenerError, &"Unknown built-in strategy: {config.name}")
    
    result = (name: config.name, strategy: strategy)
  
  of skYamlFile:
    # Load YAML strategy
    let strategyDef = parseStrategyYAMLFile(config.filePath)
    let validation = validateStrategy(strategyDef)
    if not validation.valid:
      raise newException(ScreenerError, &"Invalid YAML strategy: {validation.errors.join(\", \")}")
    
    let strategy = buildStrategy(strategyDef)
    result = (name: strategyDef.metadata.name, strategy: strategy)

proc newScreener*(config: ScreenerConfig): Screener =
  ## Create a new screener from configuration
  result.config = config
  result.strategies = @[]
  
  # Load all strategies
  for stratConfig in config.strategies:
    try:
      result.strategies.add(loadStrategy(stratConfig))
    except Exception as e:
      raise newException(ScreenerError, &"Failed to load strategy: {e.msg}")

# ============================================================================
# Data Fetching
# ============================================================================

proc fetchData(config: ScreenerDataConfig): Table[string, seq[OHLCV]] =
  ## Fetch data for all symbols based on configuration
  result = initTable[string, seq[OHLCV]]()
  
  case config.source
  of dsYahoo:
    # Calculate date range from lookback
    let endDate = now()
    let startDate = lookbackToStartDate(config.lookback, endDate)
    let startStr = startDate.format("yyyy-MM-dd")
    let endStr = endDate.format("yyyy-MM-dd")
    
    # Fetch data for each symbol
    for symbol in config.symbols:
      try:
        let streamer = newYFHistory(symbol, startStr, endStr)
        result[symbol] = toSeq(streamer.items())
      except Exception as e:
        echo &"Warning: Failed to fetch data for {symbol}: {e.msg}"
        continue
  
  of dsCoinbase:
    # Calculate date range from lookback
    let endDate = now()
    let startDate = lookbackToStartDate(config.lookbackCB, endDate)
    let startStr = startDate.format("yyyy-MM-dd")
    let endStr = endDate.format("yyyy-MM-dd")
    
    # Fetch data for each pair
    for pair in config.pairs:
      try:
        let streamer = newCBHistory(pair, startStr, endStr)
        result[pair] = toSeq(streamer.items())
      except Exception as e:
        echo &"Warning: Failed to fetch data for {pair}: {e.msg}"
        continue
  
  of dsCsv:
    # Load from CSV files
    for file in walkFiles(config.directory / "*.csv"):
      let symbol = file.splitFile().name
      try:
        result[symbol] = readCSV(file)
      except Exception as e:
        echo &"Warning: Failed to read CSV for {symbol}: {e.msg}"
        continue

# ============================================================================
# Signal Processing
# ============================================================================

proc assessStrength*(signal: Signal, indicators: Table[string, float64]): AlertStrength =
  ## Assess the strength of a signal based on indicator values
  ## This is a simple heuristic that can be improved
  
  # For now, just return moderate for all signals
  # In future, could analyze indicator values for strength assessment
  # For example:
  # - RSI near extremes (< 20 or > 80) = strong
  # - RSI moderately oversold/overbought = moderate
  # - RSI slightly off center = weak
  
  result = asModerate
  
  # Simple strength assessment based on signal reason
  if signal.reason.len > 0:
    let reasonLower = signal.reason.toLowerAscii()
    if "strong" in reasonLower or "extreme" in reasonLower:
      result = asStrong
    elif "weak" in reasonLower or "minor" in reasonLower:
      result = asWeak

proc generateAlert*(symbol: string, strategyName: string,
                   signal: Signal, bar: OHLCV,
                   indicators: Table[string, float64]): Alert =
  ## Generate an alert from a signal
  let strength = assessStrength(signal, indicators)
  var alert = newAlertFromSignal(signal, strategyName, strength, indicators)
  # Override symbol field in case signal doesn't have it set
  alert.symbol = symbol
  result = alert

proc scanSymbol*(screener: Screener, symbol: string, 
                data: seq[OHLCV]): seq[Alert] =
  ## Scan a single symbol with all strategies
  result = @[]
  
  if data.len == 0:
    return
  
  # Get the last bar for current price
  let lastBar = data[^1]
  
  # Run each strategy
  for strategyInfo in screener.strategies:
    let (name, strategy) = strategyInfo
    
    # Reset strategy
    strategy.reset()
    
    # Process all bars
    var lastSignal: Signal
    for bar in data:
      lastSignal = strategy.onBar(bar)
    
    # Only generate alert if there's an actual signal (not Stay)
    if lastSignal.position != Stay:
      # TODO: Extract indicator values (need strategy introspection)
      # For now, use empty indicators table
      let indicators = initTable[string, float64]()
      
      let alert = generateAlert(symbol, name, lastSignal, lastBar, indicators)
      result.add(alert)

# ============================================================================
# Main Screener Execution
# ============================================================================

proc applyFilters*(alerts: seq[Alert], filters: ScreenerFilters): seq[Alert] =
  ## Apply filters to alerts
  result = alerts
  
  # Filter by signal types
  if filters.signalTypes.len > 0:
    result = filterByType(result, filters.signalTypes)
  
  # Filter by strength
  result = filterByStrength(result, filters.minStrength)
  
  # Sort by strength (strong first)
  result.sortByStrength()
  
  # Apply topN filter
  if filters.topN.isSome:
    result = topN(result, filters.topN.get())

proc generateSummary*(alerts: seq[Alert], totalSymbols: int, 
                     totalStrategies: int): ScreenerSummary =
  ## Generate summary statistics from alerts
  result = ScreenerSummary(
    totalSymbols: totalSymbols,
    totalStrategies: totalStrategies,
    totalSignals: alerts.len,
    signalsByType: countByType(alerts),
    signalsByStrength: countByStrength(alerts),
    topOpportunities: @[]
  )
  
  # Get top 10 opportunities (or all if less than 10)
  var sortedAlerts = alerts
  sortedAlerts.sortByStrength()
  result.topOpportunities = topN(sortedAlerts, 10)

proc run*(screener: var Screener): ScreenerResult =
  ## Run the screener
  ## 
  ## This is the main entry point that:
  ## 1. Fetches data for all symbols
  ## 2. Runs all strategies on all symbols
  ## 3. Generates alerts from signals
  ## 4. Applies filters
  ## 5. Returns results
  
  # Fetch data
  echo "Fetching market data..."
  let dataMap = fetchData(screener.config.data)
  
  if dataMap.len == 0:
    raise newException(ScreenerError, "No data fetched for any symbols")
  
  echo &"Loaded data for {dataMap.len} symbols"
  
  # Scan all symbols
  echo "Scanning symbols..."
  var allAlerts: seq[Alert] = @[]
  
  for symbol, data in dataMap:
    if data.len > 0:
      echo &"  Scanning {symbol}... ({data.len} bars)"
      let symbolAlerts = scanSymbol(screener, symbol, data)
      allAlerts.add(symbolAlerts)
  
  echo &"Generated {allAlerts.len} raw alerts"
  
  # Apply filters
  let filteredAlerts = applyFilters(allAlerts, screener.config.filters)
  echo &"After filtering: {filteredAlerts.len} alerts"
  
  # Create alert collection
  let alertCollection = newAlertCollection(
    filteredAlerts,
    dataMap.len,
    screener.strategies.len
  )
  
  # Generate summary
  let summary = generateSummary(filteredAlerts, dataMap.len, screener.strategies.len)
  
  result = ScreenerResult(
    alerts: alertCollection,
    summary: summary
  )
  
  # Save to history if enabled
  if screener.config.output.saveHistory:
    try:
      saveScreenerHistory(
        screener.config.metadata.name,
        filteredAlerts,
        dataMap.len,
        screener.strategies.len,
        screener.config.output.historyDir
      )
      echo &"Saved results to history: {screener.config.output.historyDir}"
    except CatchableError as e:
      echo &"Warning: Failed to save history: {e.msg}"

# ============================================================================
# Utility Functions
# ============================================================================

proc validateConfig*(config: ScreenerConfig): tuple[valid: bool, errors: seq[string]] =
  ## Validate a screener configuration
  result.valid = true
  result.errors = @[]
  
  # Check that we have at least one strategy
  if config.strategies.len == 0:
    result.valid = false
    result.errors.add("No strategies specified")
  
  # Check that we have symbols/pairs
  case config.data.source
  of dsYahoo:
    if config.data.symbols.len == 0:
      result.valid = false
      result.errors.add("No symbols specified for Yahoo Finance")
  of dsCoinbase:
    if config.data.pairs.len == 0:
      result.valid = false
      result.errors.add("No pairs specified for Coinbase")
  of dsCsv:
    if not dirExists(config.data.directory):
      result.valid = false
      result.errors.add(&"CSV directory does not exist: {config.data.directory}")
  
  # Validate lookback/interval combinations
  case config.data.source
  of dsYahoo:
    let barCount = lookbackToBarCount(config.data.lookback, config.data.interval)
    if barCount < 20:
      result.errors.add(&"Warning: Only {barCount} bars available - may be insufficient for some indicators")
    
    # Check Yahoo limitations for intraday data using existing maxHistory
    let maxHistorySecs = config.data.interval.maxHistory()
    if maxHistorySecs > 0:  # If interval has limitations
      let lookbackDays = case config.data.lookback.unit
        of tuMinutes: config.data.lookback.value / (24 * 60)
        of tuHours: config.data.lookback.value / 24
        of tuDays: float64(config.data.lookback.value)
        of tuWeeks: float64(config.data.lookback.value * 7)
        of tuMonths: float64(config.data.lookback.value * 30)
        of tuYears: float64(config.data.lookback.value * 365)
      
      let maxDays = float64(maxHistorySecs) / 86400.0
      if lookbackDays > maxDays:
        result.errors.add(&"Warning: Yahoo Finance {config.data.interval} data limited to ~{int(maxDays)} days")
  
  of dsCoinbase:
    let barCount = lookbackToBarCount(config.data.lookbackCB, config.data.intervalCB)
    if barCount < 20:
      result.errors.add(&"Warning: Only {barCount} bars available - may be insufficient for some indicators")
  
  of dsCsv:
    discard  # No specific validation for CSV

# ============================================================================
# Report Generation
# ============================================================================

proc formatResult*(screenerResult: ScreenerResult, config: ScreenerOutputConfig): string =
  ## Generate formatted report from screener results
  ## 
  ## This is a convenience wrapper around the reports module that formats
  ## the screening results according to the output configuration.
  ## 
  ## Example:
  ## ```nim
  ## let result = screener.run()
  ## let report = result.formatResult(config.output)
  ## echo report
  ## ```
  generateReport(screenerResult.alerts.alerts, screenerResult.summary, config)

proc printResult*(screenerResult: ScreenerResult, config: ScreenerOutputConfig) =
  ## Print formatted screener results to stdout
  echo formatResult(screenerResult, config)

# Export key types and functions
export ScreenerResult, ScreenerSummary, Screener, ScreenerError
export newScreener, run, validateConfig
export formatResult, printResult

