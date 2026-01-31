## Automatic command-line interface powered by cligen
## 
## Usage:
##   tzu --run-strat=<STRATEGY> [data-source] [strategy-options] [portfolio-options]
##   tzu --yaml-strategy=<FILE> [data-source] [portfolio-options]
##   tzu batch --batch-file=<FILE> [options]
##   tzu validate --strategy-file=<FILE> [options]
##
## Strategy selection:
##   --run-strat=<STRATEGY>        Built-in strategy to backtest
##   --yaml-strategy=<FILE>        YAML declarative strategy file
##   -y <FILE>                     Short form for --yaml-strategy
##
## Data sources:
##   --symbol=<SYMBOL> or -s       Use Yahoo Finance (default, simplest)
##   --csvFile=<file>              Load data from CSV file
##   --yahoo=<symbol>              Fetch from Yahoo Finance (explicit)
##   --coinbase=<pair>             Fetch from Coinbase (requires env vars)
##
## Portfolio options (all strategies):
##   --initialCash=100000.0        Starting capital
##   --commission=0.0              Commission rate (0.001 = 0.1%)
##   --minCommission=0.0           Minimum commission per trade
##   --riskFreeRate=0.02           Risk-free rate for Sharpe ratio
##
## Available strategies (16 total):
##   Mean Reversion: rsi, bollinger, stochastic, mfi, cci
##   Trend Following: crossover, macd, kama, aroon, psar, triplem, adx
##   Volatility: keltner
##   Hybrid: volume, dualmomentum, filteredrsi
##   YAML: Use --yaml-strategy for declarative strategies

import std/[strformat, os, sequtils, tables, strutils, options]
import tzutrader/[core, data, strategy, trader, portfolio]
import tzutrader/declarative/[parser, validator, strategy_builder, batch_parser, batch_runner, reporter]
import cligen

# ============================================================================
# DATA SOURCE HELPER
# ============================================================================

type DataSourceKind = enum
  CSV, YahooFinance, Coinbase

proc loadData(symbol, csvFile, yahoo, coinbase, start, endDate: string): tuple[data: seq[OHLCV], symbol: string, kind: DataSourceKind] =
  ## Load data from one of three sources
  ## If symbol is provided without explicit source flags, uses Yahoo Finance (default)
  ## Returns (data, symbol, source_kind)
  
  # Count explicit sources
  let explicitSources = (if csvFile.len > 0: 1 else: 0) +
                        (if yahoo.len > 0: 1 else: 0) +
                        (if coinbase.len > 0: 1 else: 0)
  
  # If symbol provided without explicit source, default to Yahoo Finance
  if symbol.len > 0 and explicitSources == 0:
    if start.len == 0:
      echo "Error: --start=YYYY-MM-DD is required when using --symbol"
      echo "Usage: tzu --run-strat=rsi --symbol=AAPL --start=2023-01-01"
      quit(1)
    let streamer = newYFHistory(symbol, start, endDate)
    return (toSeq(streamer.items()), symbol, YahooFinance)
  
  # Check that explicit sources are mutually exclusive
  if explicitSources > 1:
    echo "Error: Can only specify ONE data source (csvFile, yahoo, or coinbase)"
    quit(1)
  
  # If no symbol and no explicit source, error
  if symbol.len == 0 and explicitSources == 0:
    echo "Error: Must specify a data source:"
    echo "  tzu --run-strat=rsi --symbol=AAPL --start=2023-01-01    (Yahoo Finance - default)"
    echo "  --csvFile=data.csv                                      (CSV file)"
    echo "  --yahoo=AAPL --start=2023-01-01                         (Yahoo Finance explicit)"
    echo "  --coinbase=BTC-USD --start=2023-01-01                   (Coinbase, needs env vars)"
    quit(1)
  
  # Load from CSV
  if csvFile.len > 0:
    if not fileExists(csvFile):
      echo &"Error: File not found: {csvFile}"
      quit(1)
    return (readCSV(csvFile), csvFile.splitFile().name, CSV)
  
  # Load from Yahoo Finance (explicit)
  if yahoo.len > 0:
    if start.len == 0:
      echo "Error: --start=YYYY-MM-DD is required for Yahoo Finance"
      quit(1)
    let streamer = newYFHistory(yahoo, start, endDate)
    return (toSeq(streamer.items()), yahoo, YahooFinance)
  
  # Load from Coinbase
  if coinbase.len > 0:
    if start.len == 0:
      echo "Error: Coinbase requires --start=YYYY-MM-DD"
      echo "Note: Set COINBASE_API_KEY and COINBASE_SECRET_KEY environment variables"
      quit(1)
    let streamer = newCBHistory(coinbase, start, endDate)
    return (toSeq(streamer.items()), coinbase, Coinbase)

# ============================================================================
# HELPER PROC FOR RUNNING BACKTESTS
# ============================================================================

proc runStrategyBacktest*(
  strategyObj: Strategy,
  symbol, csvFile, yahoo, coinbase, start, endDate: string,
  initialCash, commission, minCommission, riskFreeRate: float,
  verbose: bool
): int =
  ## Helper proc that all strategy commands use
  ## Handles data loading, config creation, and backtest execution
  
  let (data, sym, source) = loadData(symbol, csvFile, yahoo, coinbase, start, endDate)
  
  if verbose:
    echo &"Data: {source}, {sym}, {data.len} bars"
  
  let config = PortfolioConfig(
    initialCash: initialCash,
    commission: commission,
    minCommission: minCommission,
    riskFreeRate: riskFreeRate
  )
  
  echo quickBacktest(sym, strategyObj, data, config, verbose)
  return 0

# ============================================================================
# STRATEGY FACTORY
# ============================================================================

proc createStrategy(strategyName: string, params: Table[string, string]): Strategy =
  ## Factory function to create a strategy based on name and parameters
  ## Parameters are passed as a table for flexible parsing
  
  template getInt(key: string, default: int): int =
    if params.hasKey(key): parseInt(params[key]) else: default
  
  template getFloat(key: string, default: float): float =
    if params.hasKey(key): parseFloat(params[key]) else: default
  
  template getStr(key: string, default: string): string =
    if params.hasKey(key): params[key] else: default
  
  case strategyName.toLowerAscii()
  # Mean Reversion Strategies
  of "rsi":
    let period = getInt("period", 14)
    let oversold = getFloat("oversold", 30.0)
    let overbought = getFloat("overbought", 70.0)
    result = newRSIStrategy(period, oversold, overbought)
  
  of "bollinger":
    let period = getInt("period", 20)
    let stdDev = getFloat("stdDev", 2.0)
    result = newBollingerStrategy(period, stdDev)
  
  of "stochastic":
    let kPeriod = getInt("kPeriod", 14)
    let dPeriod = getInt("dPeriod", 3)
    let oversold = getFloat("oversold", 20.0)
    let overbought = getFloat("overbought", 80.0)
    result = newStochasticStrategy(kPeriod, dPeriod, oversold, overbought)
  
  of "mfi":
    let period = getInt("period", 14)
    let oversold = getFloat("oversold", 20.0)
    let overbought = getFloat("overbought", 80.0)
    result = newMFIStrategy(period, oversold, overbought)
  
  of "cci":
    let period = getInt("period", 20)
    let oversold = getFloat("oversold", -100.0)
    let overbought = getFloat("overbought", 100.0)
    result = newCCIStrategy(period, oversold, overbought)
  
  # Trend Following Strategies
  of "crossover":
    let fastPeriod = getInt("fastPeriod", 50)
    let slowPeriod = getInt("slowPeriod", 200)
    result = newCrossoverStrategy(fastPeriod, slowPeriod)
  
  of "macd":
    let fast = getInt("fast", 12)
    let slow = getInt("slow", 26)
    let signal = getInt("signal", 9)
    result = newMACDStrategy(fast, slow, signal)
  
  of "kama":
    let period = getInt("period", 10)
    let fastSC = getInt("fastSC", 2)
    let slowSC = getInt("slowSC", 30)
    result = newKAMAStrategy(period, fastSC, slowSC)
  
  of "aroon":
    let period = getInt("period", 25)
    let upThreshold = getFloat("upThreshold", 70.0)
    let downThreshold = getFloat("downThreshold", 30.0)
    result = newAroonStrategy(period, upThreshold, downThreshold)
  
  of "psar":
    let acceleration = getFloat("acceleration", 0.02)
    let maximum = getFloat("maximum", 0.20)
    result = newParabolicSARStrategy(acceleration, maximum)
  
  of "triplem":
    let fastPeriod = getInt("fastPeriod", 20)
    let mediumPeriod = getInt("mediumPeriod", 50)
    let slowPeriod = getInt("slowPeriod", 200)
    result = newTripleMAStrategy(fastPeriod, mediumPeriod, slowPeriod)
  
  of "adx":
    let period = getInt("period", 14)
    let threshold = getFloat("threshold", 25.0)
    result = newADXTrendStrategy(period, threshold)
  
  # Volatility Strategies
  of "keltner":
    let emaPeriod = getInt("emaPeriod", 20)
    let atrPeriod = getInt("atrPeriod", 10)
    let multiplier = getFloat("multiplier", 2.0)
    let mode = getStr("mode", "breakout")
    let channelMode = if mode == "reversion": Reversion else: Breakout
    result = newKeltnerChannelStrategy(emaPeriod, atrPeriod, multiplier, channelMode)
  
  # Hybrid Strategies
  of "volume":
    let period = getInt("period", 20)
    let volumeMultiplier = getFloat("volumeMultiplier", 1.5)
    result = newVolumeBreakoutStrategy(period, volumeMultiplier)
  
  of "dualmomentum":
    let rocPeriod = getInt("rocPeriod", 12)
    let smaPeriod = getInt("smaPeriod", 50)
    result = newDualMomentumStrategy(rocPeriod, smaPeriod)
  
  of "filteredrsi":
    let rsiPeriod = getInt("rsiPeriod", 14)
    let trendPeriod = getInt("trendPeriod", 200)
    let oversold = getFloat("oversold", 30.0)
    let overbought = getFloat("overbought", 70.0)
    result = newFilteredMeanReversionStrategy(rsiPeriod, trendPeriod, oversold, overbought)
  
  else:
    echo &"Error: Unknown strategy '{strategyName}'"
    echo "Available strategies:"
    echo "  Mean Reversion: rsi, bollinger, stochastic, mfi, cci"
    echo "  Trend Following: crossover, macd, kama, aroon, psar, triplem, adx"
    echo "  Volatility: keltner"
    echo "  Hybrid: volume, dualmomentum, filteredrsi"
    quit(1)

# ============================================================================
# MAIN CLI COMMAND
# ============================================================================

proc tzu(
  runStrat = "",
  yamlStrategy = "",  # NEW: Path to YAML strategy file
  symbol = "",
  csvFile = "", yahoo = "", coinbase = "", start = "", endDate = "",
  # RSI params
  period = 14, oversold = 30.0, overbought = 70.0,
  # Bollinger params
  stdDev = 2.0,
  # Stochastic params
  kPeriod = 14, dPeriod = 3,
  # Crossover params
  fastPeriod = 50, slowPeriod = 200,
  # MACD params
  fast = 12, slow = 26, signal = 9,
  # KAMA params
  fastSC = 2, slowSC = 30,
  # Aroon params
  upThreshold = 70.0, downThreshold = 30.0,
  # Parabolic SAR params
  acceleration = 0.02, maximum = 0.20,
  # Triple MA params
  mediumPeriod = 50,
  # ADX params
  threshold = 25.0,
  # Keltner params
  emaPeriod = 20, atrPeriod = 10, multiplier = 2.0, mode = "breakout",
  # Volume params
  volumeMultiplier = 1.5,
  # Dual Momentum params
  rocPeriod = 12, smaPeriod = 50,
  # Filtered RSI params
  rsiPeriod = 14, trendPeriod = 200,
  # Portfolio options
  initialCash = 100000.0, commission = 0.0, minCommission = 0.0, riskFreeRate = 0.02,
  verbose = false
): int =
  ## TzuTrader CLI - Backtest trading strategies
  ## 
  ## Usage:
  ##   tzu --run-strat=rsi --symbol=AAPL --start=2023-01-01
  ##   tzu --yaml-strategy=my_strategy.yml --symbol=AAPL --start=2023-01-01
  ##   tzu -y my_strategy.yml -s AAPL --start=2023-01-01
  ##   tzu --run-strat=macd --csvFile=data.csv
  ##
  ## Available strategies:
  ##   Mean Reversion: rsi, bollinger, stochastic, mfi, cci
  ##   Trend Following: crossover, macd, kama, aroon, psar, triplem, adx
  ##   Volatility: keltner
  ##   Hybrid: volume, dualmomentum, filteredrsi
  ##   YAML: Use --yaml-strategy or -y to load declarative strategies
  
  # Check that either runStrat or yamlStrategy is provided (but not both)
  if runStrat.len == 0 and yamlStrategy.len == 0:
    echo "Error: Either --run-strat=<STRATEGY> or --yaml-strategy=<FILE> is required"
    echo ""
    echo "Usage: tzu [--run-strat=<STRATEGY> | --yaml-strategy=<FILE>] [options]"
    echo ""
    echo "Built-in strategies:"
    echo "  Mean Reversion: rsi, bollinger, stochastic, mfi, cci"
    echo "  Trend Following: crossover, macd, kama, aroon, psar, triplem, adx"
    echo "  Volatility: keltner"
    echo "  Hybrid: volume, dualmomentum, filteredrsi"
    echo ""
    echo "YAML strategies:"
    echo "  Use --yaml-strategy=path/to/strategy.yml for declarative strategies"
    echo ""
    echo "Examples:"
    echo "  tzu --run-strat=rsi --symbol=AAPL --start=2023-01-01"
    echo "  tzu --run-strat=rsi -s AAPL --start=2023-01-01"
    echo "  tzu --yaml-strategy=strategies/my_rsi.yml --symbol=AAPL"
    echo "  tzu --run-strat=macd --csvFile=data.csv --fast=10 --slow=20"
    echo ""
    echo "For strategy-specific options, use: tzu --help"
    return 1
  
  if runStrat.len > 0 and yamlStrategy.len > 0:
    echo "Error: Cannot use both --run-strat and --yaml-strategy"
    echo "Choose one: built-in strategy OR YAML strategy"
    return 1
  
  # Handle YAML strategy
  if yamlStrategy.len > 0:
    # Check file exists
    if not fileExists(yamlStrategy):
      echo &"Error: YAML strategy file not found: {yamlStrategy}"
      return 1
    
    # Parse YAML strategy
    echo &"Loading YAML strategy from: {yamlStrategy}"
    let strategyDef = try:
      parseStrategyYAMLFile(yamlStrategy)
    except parser.ParseError as e:
      echo &"Error parsing YAML: {e.msg}"
      return 1
    
    # Validate strategy
    echo "Validating strategy..."
    let validation = validateStrategy(strategyDef)
    if not validation.valid:
      echo "Strategy validation failed:"
      for err in validation.errors:
        echo &"  - {err}"
      return 1
    
    echo &"Strategy '{strategyDef.metadata.name}' loaded successfully"
    
    # Build strategy
    var strategyObj = buildStrategy(strategyDef)
    
    # Run backtest
    return runStrategyBacktest(strategyObj, symbol, csvFile, yahoo, coinbase, start, endDate,
                               initialCash, commission, minCommission, riskFreeRate, verbose)
  
  # Build params table from all possible strategy parameters
  var params = initTable[string, string]()
  params["period"] = $period
  params["oversold"] = $oversold
  params["overbought"] = $overbought
  params["stdDev"] = $stdDev
  params["kPeriod"] = $kPeriod
  params["dPeriod"] = $dPeriod
  params["fastPeriod"] = $fastPeriod
  params["slowPeriod"] = $slowPeriod
  params["fast"] = $fast
  params["slow"] = $slow
  params["signal"] = $signal
  params["fastSC"] = $fastSC
  params["slowSC"] = $slowSC
  params["upThreshold"] = $upThreshold
  params["downThreshold"] = $downThreshold
  params["acceleration"] = $acceleration
  params["maximum"] = $maximum
  params["mediumPeriod"] = $mediumPeriod
  params["threshold"] = $threshold
  params["emaPeriod"] = $emaPeriod
  params["atrPeriod"] = $atrPeriod
  params["multiplier"] = $multiplier
  params["mode"] = mode
  params["volumeMultiplier"] = $volumeMultiplier
  params["rocPeriod"] = $rocPeriod
  params["smaPeriod"] = $smaPeriod
  params["rsiPeriod"] = $rsiPeriod
  params["trendPeriod"] = $trendPeriod
  
  let strategyObj = createStrategy(runStrat, params)
  return runStrategyBacktest(strategyObj, symbol, csvFile, yahoo, coinbase, start, endDate,
                             initialCash, commission, minCommission, riskFreeRate, verbose)

# ============================================================================
# BATCH TEST COMMAND
# ============================================================================

proc batch(
  batchFile: string = "",
  output: string = "",
  format: string = "html",
  verbose: bool = false
): int =
  ## Run a batch test from a YAML configuration file
  ## 
  ## This command allows you to test multiple strategies across multiple symbols
  ## in a single run, generating comparison reports.
  ## 
  ## Args:
  ##   batchFile: Path to batch test YAML file
  ##   output: Output file path (overrides batch config)
  ##   format: Output format: html, csv, or json (default: html)
  ##   verbose: Enable verbose output
  ## 
  ## Returns:
  ##   0 on success, 1 on error
  ## 
  ## Examples:
  ##   tzu batch --batch-file=tests/batch.yml
  ##   tzu batch --batch-file=tests/batch.yml --output=report.html
  ##   tzu batch --batch-file=tests/batch.yml --format=csv --verbose
  
  # Check that batch file is provided
  if batchFile.len == 0:
    echo "Error: --batch-file is required"
    echo ""
    echo "Usage: tzu batch --batch-file=<FILE> [options]"
    echo ""
    echo "Options:"
    echo "  --batch-file=<FILE>    Batch test YAML configuration"
    echo "  --output=<FILE>        Output file path (overrides config)"
    echo "  --format=html|csv|json Output format (default: html)"
    echo "  --verbose              Enable verbose output"
    echo ""
    echo "Example:"
    echo "  tzu batch --batch-file=examples/declarative/batch_test_example.yml"
    return 1
  
  # Check file exists
  if not fileExists(batchFile):
    echo &"Error: Batch test file not found: {batchFile}"
    return 1
  
  # Validate format
  if format notin ["html", "csv", "json"]:
    echo &"Error: Invalid format '{format}'. Must be html, csv, or json"
    return 1
  
  echo "="
  echo "TzuTrader Batch Test"
  echo "="
  echo &"Loading batch configuration from: {batchFile}"
  echo ""
  
  # Parse batch configuration
  let config = try:
    parseBatchTestYAMLFile(batchFile)
  except BatchParseError as e:
    echo &"Error parsing batch test YAML: {e.msg}"
    return 1
  except CatchableError as e:
    echo &"Error loading batch test: {e.msg}"
    return 1
  
  echo &"Configuration loaded successfully"
  echo &"  Strategies: {config.strategies.len}"
  echo &"  Symbols: {config.data.symbols.len}"
  echo &"  Total runs: {config.strategies.len * config.data.symbols.len}"
  echo ""
  
  # Run batch test
  let res = try:
    runBatchTest(config, verbose = verbose)
  except BatchRunError as e:
    echo &"Error running batch test: {e.msg}"
    return 1
  except CatchableError as e:
    echo &"Error during batch execution: {e.msg}"
    return 1
  
  # Display summary
  echo ""
  echo formatSummary(res)
  
  # Determine output file
  var outputFile = output
  if outputFile.len == 0:
    # Use config default if provided
    if config.output.comparisonReport.isSome():
      outputFile = config.output.comparisonReport.get()
  
  # Save report if output specified
  if outputFile.len > 0:
    let reportFormat = case format
      of "html": rfHTML
      of "csv": rfCSV
      of "json": rfJSON
      else: rfHTML
    
    try:
      saveReport(res, outputFile, reportFormat)
      echo ""
      echo &"Report saved to: {outputFile}"
    except CatchableError as e:
      echo &"Error saving report: {e.msg}"
      return 1
  
  return 0

# ============================================================================
# VALIDATE COMMAND
# ============================================================================

proc validate(
  strategyFile: string = "",
  batchFile: string = "",
  verbose: bool = false
): int =
  ## Validate a strategy or batch test YAML file without running it
  ## 
  ## This command checks for syntax errors, invalid references, and
  ## configuration issues before you run a backtest.
  ## 
  ## Args:
  ##   strategyFile: Path to strategy YAML file to validate
  ##   batchFile: Path to batch test YAML file to validate
  ##   verbose: Show detailed validation information
  ## 
  ## Returns:
  ##   0 if valid, 1 if validation fails or errors occur
  ## 
  ## Examples:
  ##   tzu validate --strategy-file=my_strategy.yml
  ##   tzu validate --batch-file=batch_test.yml --verbose
  
  # Check that exactly one file type is specified
  if strategyFile.len == 0 and batchFile.len == 0:
    echo "Error: Must specify either --strategy-file or --batch-file"
    echo ""
    echo "Usage: tzu validate [--strategy-file=<FILE> | --batch-file=<FILE>] [options]"
    echo ""
    echo "Options:"
    echo "  --strategy-file=<FILE>  Validate a strategy YAML file"
    echo "  --batch-file=<FILE>     Validate a batch test YAML file"
    echo "  --verbose               Show detailed validation information"
    echo ""
    echo "Examples:"
    echo "  tzu validate --strategy-file=examples/declarative/simple_rsi.yml"
    echo "  tzu validate --batch-file=examples/declarative/batch_test_example.yml"
    return 1
  
  if strategyFile.len > 0 and batchFile.len > 0:
    echo "Error: Cannot validate both strategy and batch file at once"
    echo "Please specify only one of --strategy-file or --batch-file"
    return 1
  
  # Validate strategy file
  if strategyFile.len > 0:
    echo "="
    echo "Strategy Validation"
    echo "="
    echo &"File: {strategyFile}"
    echo ""
    
    # Check file exists
    if not fileExists(strategyFile):
      echo &"✗ Error: File not found: {strategyFile}"
      return 1
    
    # Parse YAML
    echo "Parsing YAML..."
    let strategyDef = try:
      parseStrategyYAMLFile(strategyFile)
    except parser.ParseError as e:
      echo &"✗ Parse Error: {e.msg}"
      return 1
    except CatchableError as e:
      echo &"✗ Error: {e.msg}"
      return 1
    
    echo "✓ YAML syntax valid"
    
    if verbose:
      echo ""
      echo "Strategy Information:"
      echo &"  Name: {strategyDef.metadata.name}"
      echo &"  Description: {strategyDef.metadata.description}"
      if strategyDef.metadata.author.isSome():
        echo &"  Author: {strategyDef.metadata.author.get()}"
      echo &"  Indicators: {strategyDef.indicators.len}"
      echo &"  Position Sizing: {strategyDef.positionSizing.kind}"
    
    # Validate strategy
    echo ""
    echo "Validating strategy..."
    let validation = validateStrategy(strategyDef)
    
    if validation.valid:
      echo "✓ Strategy is valid"
      
      if verbose:
        echo ""
        echo "Validation Details:"
        echo &"  Entry conditions: OK"
        echo &"  Exit conditions: OK"
        echo &"  All indicator references: OK"
        echo &"  No duplicate IDs: OK"
      
      echo ""
      echo "="
      echo "✓ Validation Passed"
      echo "="
      return 0
    else:
      echo "✗ Strategy validation failed:"
      echo ""
      for err in validation.errors:
        echo &"  ✗ {err}"
      echo ""
      echo "="
      echo "✗ Validation Failed"
      echo "="
      return 1
  
  # Validate batch file
  if batchFile.len > 0:
    echo "="
    echo "Batch Test Validation"
    echo "="
    echo &"File: {batchFile}"
    echo ""
    
    # Check file exists
    if not fileExists(batchFile):
      echo &"✗ Error: File not found: {batchFile}"
      return 1
    
    # Parse batch YAML
    echo "Parsing batch test YAML..."
    let batchConfig = try:
      parseBatchTestYAMLFile(batchFile)
    except BatchParseError as e:
      echo &"✗ Parse Error: {e.msg}"
      return 1
    except CatchableError as e:
      echo &"✗ Error: {e.msg}"
      return 1
    
    echo "✓ YAML syntax valid"
    
    if verbose:
      echo ""
      echo "Batch Test Information:"
      echo &"  Version: {batchConfig.version}"
      echo &"  Data Source: {batchConfig.data.source}"
      echo &"  Symbols: {batchConfig.data.symbols.join(\", \")}"
      echo &"  Date Range: {batchConfig.data.startDate} to {batchConfig.data.endDate}"
      echo &"  Strategies: {batchConfig.strategies.len}"
      echo &"  Total Runs: {batchConfig.strategies.len * batchConfig.data.symbols.len}"
    
    # Validate each strategy file referenced
    echo ""
    echo "Validating referenced strategies..."
    var allValid = true
    
    for stratConfig in batchConfig.strategies:
      echo &"  Checking: {stratConfig.name} ({stratConfig.file})"
      
      if not fileExists(stratConfig.file):
        echo &"    ✗ Strategy file not found: {stratConfig.file}"
        allValid = false
        continue
      
      let strategyDef = try:
        parseStrategyYAMLFile(stratConfig.file)
      except parser.ParseError as e:
        echo &"    ✗ Parse error: {e.msg}"
        allValid = false
        continue
      except CatchableError as e:
        echo &"    ✗ Error: {e.msg}"
        allValid = false
        continue
      
      let validation = validateStrategy(strategyDef)
      if not validation.valid:
        echo &"    ✗ Validation failed:"
        for err in validation.errors:
          echo &"      - {err}"
        allValid = false
      else:
        echo &"    ✓ Valid"
    
    echo ""
    if allValid:
      echo "="
      echo "✓ Validation Passed"
      echo "="
      return 0
    else:
      echo "="
      echo "✗ Validation Failed"
      echo "="
      return 1

# ============================================================================
# CLI WIRING - Auto-generated by cligen
# ============================================================================

when isMainModule:
  import std/os
  
  # Check if first argument is a subcommand
  let args = commandLineParams()
  if args.len > 0 and args[0] in ["batch", "validate"]:
    # Use dispatchMulti for subcommands
    dispatchMulti([tzu, short = {"runStrat": 'r', "symbol": 's', "yamlStrategy": 'y'}], 
                  [batch, short = {"batchFile": 'b'}],
                  [validate, short = {"strategyFile": 's', "batchFile": 'b'}])
  else:
    # Default to main backtest command
    dispatch(tzu, short = {"runStrat": 'r', "symbol": 's', "yamlStrategy": 'y'})
