## TzuTrader CLI v0.9.0 - Command: tzu
##
## **DISCLAIMER**: This software is for educational and research purposes only.
## It does not provide financial advice. Trading involves substantial risk of loss.
## Past performance does not guarantee future results. The authors are not responsible
## for any losses from using this tool. Users accept full responsibility for their
## trading decisions. Consult qualified financial professionals before investing.
##
## Automatic command-line interface powered by cligen
## 
## Usage:
##   tzu --backtest=<STRATEGY> [data-source] [strategy-options] [portfolio-options]
##   tzu --strategy=<FILE> [data-source] [portfolio-options]
##
## Commands:
##   --backtest=<STRATEGY>         Backtest a built-in strategy
##   --strategy=<FILE>             Backtest a YAML strategy file
##   --batch=<FILE>                Run batch tests from configuration
##   --sweep=<FILE>                Run parameter sweep optimization
##   --screen=<FILE>               Screen multiple symbols for signals
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
import tzutrader/declarative/[parser, validator, strategy_builder, batch_runner, results, sweep_runner]
import tzutrader/screener/[screener, parser as screener_parser, reports, schema]
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
      echo "Usage: tzu --backtest=rsi --symbol=AAPL --start=2023-01-01"
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
    echo "  tzu --backtest=rsi --symbol=AAPL --start=2023-01-01    (Yahoo Finance - default)"
    echo "  --csvFile=data.csv                                     (CSV file)"
    echo "  --yahoo=AAPL --start=2023-01-01                        (Yahoo Finance explicit)"
    echo "  --coinbase=BTC-USD --start=2023-01-01                  (Coinbase, needs env vars)"
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
# SCREENER HELPER
# ============================================================================

proc runScreenerFromFile(screenerFile: string, verbose: bool = false): int =
  ## Run market screener from YAML configuration file
  ## Returns 0 on success, 1 on error
  
  # Check file exists
  if not fileExists(screenerFile):
    echo &"Error: Screener config file not found: {screenerFile}"
    return 1
  
  # Parse YAML configuration
  if verbose:
    echo &"Loading screener config from: {screenerFile}"
  
  let config = try:
    parseScreenerYAMLFile(screenerFile)
  except ScreenerParseError as e:
    echo &"Error parsing screener config: {e.msg}"
    return 1
  except:
    echo &"Unexpected error parsing config: {getCurrentExceptionMsg()}"
    return 1
  
  # Validate configuration
  if verbose:
    echo "Validating screener configuration..."
  
  let validation = validateConfig(config)
  if not validation.valid:
    echo "Screener configuration validation failed:"
    for err in validation.errors:
      echo &"  - {err}"
    # Continue anyway if there are only warnings
    if validation.errors.len > 0:
      echo ""
  
  # Create screener
  if verbose:
    echo &"Creating screener with {config.strategies.len} strategies..."
    case config.data.source
    of dsYahoo:
      echo &"  Data source: Yahoo Finance ({config.data.symbols.len} symbols)"
    of dsCoinbase:
      echo &"  Data source: Coinbase ({config.data.pairs.len} pairs)"
    of dsCsv:
      echo &"  Data source: CSV files from {config.data.directory}"
  
  var screenerObj = newScreener(config)
  
  # Run screener
  if verbose:
    echo "Running screener..."
  
  let result = try:
    screenerObj.run()
  except ScreenerError as e:
    echo &"Screener error: {e.msg}"
    return 1
  except:
    echo &"Unexpected error during screening: {getCurrentExceptionMsg()}"
    return 1
  
  # Generate and print report
  let screenerResult = formatResult(result, config.output)
  echo screenerResult
  
  # Write to file if specified
  if config.output.filepath.isSome():
    let filepath = config.output.filepath.get()
    try:
      writeFile(filepath, screenerResult)
      if verbose:
        echo &"\nReport written to: {filepath}"
    except IOError as e:
      echo &"Warning: Could not write report to file: {e.msg}"
  
  return 0

# ============================================================================
# MAIN CLI COMMAND
# ============================================================================

proc tzu(
  backtest = "",  # Built-in strategy name to backtest
  strategy = "",  # Path to YAML strategy file
  batch = "",  # Path to batch test configuration file
  sweep = "",  # Path to parameter sweep configuration file
  screen = "",  # Path to screener configuration file
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
  ## TzuTrader CLI - Backtest trading strategies and screen markets
  ## 
  ## Usage:
  ##   tzu --backtest=rsi --symbol=AAPL --start=2023-01-01
  ##   tzu --strategy=my_strategy.yml --symbol=AAPL --start=2023-01-01
  ##   tzu --batch=batch_config.yml
  ##   tzu --sweep=sweep_config.yml
  ##   tzu --screen=screener_config.yml
  ##   tzu --backtest=macd --csvFile=data.csv
  ##
  ## Available strategies:
  ##   Mean Reversion: rsi, bollinger, stochastic, mfi, cci
  ##   Trend Following: crossover, macd, kama, aroon, psar, triplem, adx
  ##   Volatility: keltner
  ##   Hybrid: volume, dualmomentum, filteredrsi
  ##   Custom: Use --strategy to load YAML declarative strategies
  ##   Batch: Use --batch to run multiple strategies at once
  ##   Sweep: Use --sweep for automated parameter optimization
  ##   Screen: Use --screen to scan multiple symbols for signals
  
  # Check that only one mode is provided
  let modesProvided = (if backtest.len > 0: 1 else: 0) +
                     (if strategy.len > 0: 1 else: 0) +
                     (if batch.len > 0: 1 else: 0) +
                     (if sweep.len > 0: 1 else: 0) +
                     (if screen.len > 0: 1 else: 0)
  
  if modesProvided == 0:
    echo "Error: Must specify one command: --backtest, --strategy, --batch, --sweep, or --screen"
    echo ""
    echo "Usage: tzu [COMMAND] [options]"
    echo ""
    echo "Commands:"
    echo "  --backtest=STRATEGY   Backtest a built-in strategy"
    echo "  --strategy=FILE       Backtest a YAML strategy file"
    echo "  --batch=FILE          Run batch tests from configuration"
    echo "  --sweep=FILE          Run parameter sweep optimization"
    echo "  --screen=FILE         Screen multiple symbols for signals"
    echo ""
    echo "Built-in strategies:"
    echo "  Mean Reversion: rsi, bollinger, stochastic, mfi, cci"
    echo "  Trend Following: crossover, macd, kama, aroon, psar, triplem, adx"
    echo "  Volatility: keltner"
    echo "  Hybrid: volume, dualmomentum, filteredrsi"
    echo ""
    echo "Examples:"
    echo "  tzu --backtest=rsi --symbol=AAPL --start=2023-01-01"
    echo "  tzu --backtest=rsi -s AAPL --start=2023-01-01"
    echo "  tzu --strategy=strategies/my_rsi.yml --symbol=AAPL --start=2023-01-01"
    echo "  tzu --batch=examples/batch/basic_batch.yml"
    echo "  tzu --sweep=examples/sweep/rsi_optimization.yml"
    echo "  tzu --screen=examples/screeners/basic_rsi_screener.yml"
    echo "  tzu --backtest=macd --csvFile=data.csv --fast=10 --slow=20"
    echo ""
    echo "For detailed options, use: tzu --help"
    return 1
  
  if modesProvided > 1:
    echo "Error: Can only use ONE command at a time"
    echo "Choose one of: --backtest, --strategy, --batch, --sweep, or --screen"
    return 1
  
  # Handle market screener mode
  if screen.len > 0:
    return runScreenerFromFile(screen, verbose)
  
  # Handle parameter sweep mode
  if sweep.len > 0:
    # Check file exists
    if not fileExists(sweep):
      echo &"Error: Parameter sweep configuration file not found: {sweep}"
      return 1
    
    echo &"Running parameter sweep from: {sweep}"
    echo ""
    
    try:
      let sweepResults = runParameterSweepFromFile(sweep, verbose)
      
      # Print summary
      echo ""
      printSummary(sweepResults)
      
      # Print best parameters
      printBestParameters(sweepResults, rmTotalReturn, 10)
      
      return 0
    
    except SweepRunnerError as e:
      echo &"Parameter sweep error: {e.msg}"
      return 1
    except:
      echo &"Unexpected error: {getCurrentExceptionMsg()}"
      return 1
  
  # Handle batch test mode
  if batch.len > 0:
    # Check file exists
    if not fileExists(batch):
      echo &"Error: Batch configuration file not found: {batch}"
      return 1
    
    echo &"Running batch test from: {batch}"
    echo ""
    
    try:
      let batchResults = runBatchTestFromFile(batch, verbose)
      
      # Print summary
      echo ""
      printSummary(batchResults)
      
      # Print top performers
      echo "\nTop 10 by Total Return:"
      let top10 = batchResults.getTopN(rmTotalReturn, 10)
      for i, r in top10:
        echo &"  {i+1:2}. {r.strategyName:25} on {r.symbol:6}: {r.totalReturn:8.2f}% (Sharpe: {r.sharpeRatio:5.2f})"
      
      return 0
    
    except BatchRunnerError as e:
      echo &"Batch test error: {e.msg}"
      return 1
    except:
      echo &"Unexpected error: {getCurrentExceptionMsg()}"
      return 1
  
  # Handle YAML strategy
  if strategy.len > 0:
    # Check file exists
    if not fileExists(strategy):
      echo &"Error: Strategy file not found: {strategy}"
      return 1
    
    # Parse YAML strategy
    echo &"Loading strategy from: {strategy}"
    let strategyDef = try:
      parseStrategyYAMLFile(strategy)
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
  
  let strategyObj = createStrategy(backtest, params)
  return runStrategyBacktest(strategyObj, symbol, csvFile, yahoo, coinbase, start, endDate,
                             initialCash, commission, minCommission, riskFreeRate, verbose)

# ============================================================================
# CLI WIRING - Auto-generated by cligen
# ============================================================================

when isMainModule:
  dispatch(tzu, short = {"backtest": 'b', "symbol": 's', "strategy": 't'})
