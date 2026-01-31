## TzuTrader CLI v0.8.0 - Command: tzu
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
##   tzu --run-strat=<STRATEGY> [data-source] [strategy-options] [portfolio-options]
##
## Strategy selection:
##   --run-strat=<STRATEGY>        Strategy to backtest (required)
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

import std/[strformat, os, sequtils, tables, strutils]
import tzutrader/[core, data, strategy, trader, portfolio]
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
  ##   tzu --run-strat=macd --csvFile=data.csv
  ##
  ## Available strategies:
  ##   Mean Reversion: rsi, bollinger, stochastic, mfi, cci
  ##   Trend Following: crossover, macd, kama, aroon, psar, triplem, adx
  ##   Volatility: keltner
  ##   Hybrid: volume, dualmomentum, filteredrsi
  
  if runStrat.len == 0:
    echo "Error: --run-strat=<STRATEGY> is required"
    echo ""
    echo "Usage: tzu --run-strat=<STRATEGY> [options]"
    echo ""
    echo "Available strategies:"
    echo "  Mean Reversion: rsi, bollinger, stochastic, mfi, cci"
    echo "  Trend Following: crossover, macd, kama, aroon, psar, triplem, adx"
    echo "  Volatility: keltner"
    echo "  Hybrid: volume, dualmomentum, filteredrsi"
    echo ""
    echo "Examples:"
    echo "  tzu --run-strat=rsi --symbol=AAPL --start=2023-01-01"
    echo "  tzu --run-strat=rsi -s AAPL --start=2023-01-01"
    echo "  tzu --run-strat=macd --csvFile=data.csv --fast=10 --slow=20"
    echo ""
    echo "For strategy-specific options, use: tzu --help"
    return 1
  
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
# CLI WIRING - Auto-generated by cligen
# ============================================================================

when isMainModule:
  dispatch(tzu, short = {"runStrat": 'r', "symbol": 's'})
