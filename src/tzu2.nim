## TzuTrader CLI v2 (tzu2) - Command: tzu2
##
## **DISCLAIMER**: This software is for educational and research purposes only.
## It does not provide financial advice. Trading involves substantial risk of loss.
## Past performance does not guarantee future results. The authors are not responsible
## for any losses from using this tool. Users accept full responsibility for their
## trading decisions. Consult qualified financial professionals before investing.
##
## Modern command-line interface powered by cligen and runner.nim
## 
## Usage:
##   tzu2 --run-strat=<STRATEGY> --symbol=<SYMBOL> --start=<DATE> [options]
##   tzu2 --run-strat=<STRATEGY> --csv=<FILE> [options]
##
## Strategy selection:
##   --run-strat=<STRATEGY>        Built-in strategy to backtest
##
## Data sources:
##   --symbol=<SYMBOL> or -s       Symbol to trade (Yahoo Finance default)
##   --start=<DATE>                Start date (YYYY-MM-DD, required for symbol)
##   --end=<DATE>                  End date (YYYY-MM-DD, optional)
##   --provider=<NAME>             Data provider (yahoo, coinbase) - default: yahoo
##   --csv=<FILE>                  Load data from CSV file
##
## Portfolio options (all strategies):
##   --initial-cash=100000.0       Starting capital
##   --commission=0.0              Commission rate (0.001 = 0.1%)
##   --min-commission=0.0          Minimum commission per trade
##   --risk-free-rate=0.02         Risk-free rate for Sharpe ratio
##
## Available strategies (16 total):
##   Mean Reversion: rsi, bollinger, stochastic, mfi, cci
##   Trend Following: crossover, macd, kama, aroon, psar, triplem, adx
##   Volatility: keltner
##   Hybrid: volume, dualmomentum, filteredrsi

import std/[strformat, os, tables, strutils]
import tzutrader/[data, strategy, runner, portfolio, trader]
import tzutrader/strategies/base
import cligen

# ============================================================================
# DATA SOURCE TYPES
# ============================================================================

type
  DataSourceKind = enum
    dskCSV,           # CSV file
    dskAutomatic      # Automatic fetch via runner
  
  DataSourceConfig = object
    case kind*: DataSourceKind
    of dskCSV:
      csvPath*: string
    of dskAutomatic:
      symbol*: string
      provider*: string
      startDate*: string
      endDate*: string

# ============================================================================
# DATA SOURCE DETECTION
# ============================================================================

proc detectDataSource(symbol, csv, provider, start, endDate: string): DataSourceConfig =
  ## Detect which data source to use based on provided arguments
  ## Priority: CSV > Automatic (symbol + dates)
  
  # CSV takes precedence
  if csv.len > 0:
    if not fileExists(csv):
      echo &"Error: CSV file not found: {csv}"
      quit(1)
    return DataSourceConfig(kind: dskCSV, csvPath: csv)
  
  # Automatic fetching requires symbol + start date
  if symbol.len > 0 and start.len > 0:
    let prov = if provider.len > 0: provider else: "yahoo"
    return DataSourceConfig(
      kind: dskAutomatic,
      symbol: symbol,
      provider: prov,
      startDate: start,
      endDate: if endDate.len > 0: endDate else: ""
    )
  
  # Error: insufficient arguments
  echo "Error: Must specify data source:"
  echo "  Option 1: --symbol=AAPL --start=2023-01-01"
  echo "  Option 2: --csv=data/AAPL.csv"
  echo ""
  echo "Examples:"
  echo "  tzu2 --run-strat=rsi --symbol=AAPL --start=2023-01-01"
  echo "  tzu2 --run-strat=rsi --csv=data/AAPL.csv"
  quit(1)

# ============================================================================
# STRATEGY FACTORY (from tzu.nim)
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
# RUNNER EXECUTION
# ============================================================================

proc runWithAutoFetch(strategy: Strategy, symbol: string, 
                      startDate: string, endDate: string,
                      config: PortfolioConfig, verbose: bool): BacktestReport =
  ## Execute strategy with automatic data fetching via runner
  
  # Create runner with portfolio config
  let runner = newRunner(strategy, config, verbose)
  
  # Runner automatically:
  # 1. Queries strategy.getDataRequirements()
  # 2. Fetches data from providers
  # 3. Synchronizes streams
  # 4. Executes strategy callbacks
  # 5. Returns report
  return runner.run(symbol, startDate, endDate)

proc runWithManualData(strategy: Strategy, csvPath: string,
                       config: PortfolioConfig, verbose: bool): BacktestReport =
  ## Execute strategy with manual CSV data via runner
  
  # Load CSV manually
  let data = readCSV(csvPath)
  let symbol = csvPath.splitFile().name
  
  # Create runner
  let runner = newRunner(strategy, config, verbose)
  
  # Pass pre-loaded data
  return runner.runWithData(symbol, data)

proc runStrategyBacktest(
  strategy: Strategy,
  dataConfig: DataSourceConfig,
  portfolioConfig: PortfolioConfig,
  verbose: bool
): int =
  ## Execute backtest using runner interface
  
  try:
    case dataConfig.kind
    of dskAutomatic:
      # Use runner with automatic data fetching
      if verbose:
        echo &"Fetching data: {dataConfig.symbol} from {dataConfig.provider}"
        echo &"Period: {dataConfig.startDate} to " & 
             (if dataConfig.endDate.len > 0: dataConfig.endDate else: "today")
      
      let report = runWithAutoFetch(
        strategy,
        dataConfig.symbol,
        dataConfig.startDate,
        dataConfig.endDate,
        portfolioConfig,
        verbose
      )
      echo report
    
    of dskCSV:
      # Use runner with manual data
      if verbose:
        echo &"Loading data from CSV: {dataConfig.csvPath}"
      
      let report = runWithManualData(
        strategy,
        dataConfig.csvPath,
        portfolioConfig,
        verbose
      )
      echo report
    
    return 0
  
  except ValueError as e:
    echo &"Error: {e.msg}"
    return 1
  except IOError as e:
    echo &"Error reading data: {e.msg}"
    return 1
  except Exception as e:
    echo &"Unexpected error: {e.msg}"
    return 1

# ============================================================================
# MAIN CLI COMMAND
# ============================================================================

proc tzu2(
  runStrat = "",
  symbol = "",
  csv = "",
  provider = "yahoo",
  start = "",
  endDate = "",
  
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
  initialCash = 100000.0,
  commission = 0.0,
  minCommission = 0.0,
  riskFreeRate = 0.02,
  
  verbose = false
): int =
  ## TzuTrader CLI v2 - Backtest trading strategies (modern runner interface)
  ## 
  ## Usage:
  ##   tzu2 --run-strat=rsi --symbol=AAPL --start=2023-01-01
  ##   tzu2 --run-strat=rsi --csv=data/AAPL.csv
  ##   tzu2 --run-strat=macd --symbol=AAPL --start=2023-01-01 --fast=10
  ##
  ## Available strategies:
  ##   Mean Reversion: rsi, bollinger, stochastic, mfi, cci
  ##   Trend Following: crossover, macd, kama, aroon, psar, triplem, adx
  ##   Volatility: keltner
  ##   Hybrid: volume, dualmomentum, filteredrsi
  
  # Validate required arguments
  if runStrat.len == 0:
    echo "Error: --run-strat=<STRATEGY> is required"
    echo ""
    echo "Usage: tzu2 --run-strat=<STRATEGY> [options]"
    echo ""
    echo "Examples:"
    echo "  tzu2 --run-strat=rsi --symbol=AAPL --start=2023-01-01"
    echo "  tzu2 --run-strat=rsi --csv=data/AAPL.csv"
    echo ""
    echo "Available strategies:"
    echo "  Mean Reversion: rsi, bollinger, stochastic, mfi, cci"
    echo "  Trend Following: crossover, macd, kama, aroon, psar, triplem, adx"
    echo "  Volatility: keltner"
    echo "  Hybrid: volume, dualmomentum, filteredrsi"
    echo ""
    echo "For more help: tzu2 --help"
    return 1
  
  # Detect data source
  let dataConfig = detectDataSource(symbol, csv, provider, start, endDate)
  
  # Build strategy parameters table
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
  
  # Create strategy
  let strategy = createStrategy(runStrat, params)
  
  # Build portfolio config
  let portfolioConfig = PortfolioConfig(
    initialCash: initialCash,
    commission: commission,
    minCommission: minCommission,
    riskFreeRate: riskFreeRate
  )
  
  # Execute backtest
  return runStrategyBacktest(strategy, dataConfig, portfolioConfig, verbose)

# ============================================================================
# CLI WIRING - Auto-generated by cligen
# ============================================================================

when isMainModule:
  dispatch(tzu2, short = {"runStrat": 'r', "symbol": 's'})
