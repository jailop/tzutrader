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
##   tzu {STRATEGY} [data-source] [strategy-options] [portfolio-options]
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

import std/[strformat, os, sequtils]
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
      echo "Error: --start=YYYY-MM-DD is required when using symbol"
      echo "Usage: tzutrader rsi AAPL --start=2023-01-01"
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
    echo "  tzutrader rsi AAPL --start=2023-01-01    (Yahoo Finance - default)"
    echo "  --csvFile=data.csv                       (CSV file)"
    echo "  --yahoo=AAPL --start=2023-01-01          (Yahoo Finance explicit)"
    echo "  --coinbase=BTC-USD --start=2023-01-01    (Coinbase, needs env vars)"
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
# MEAN REVERSION STRATEGIES (5)
# ============================================================================

proc rsi(
  symbol = "",
  csvFile = "", yahoo = "", coinbase = "", start = "", endDate = "",
  period = 14, oversold = 30.0, overbought = 70.0,
  initialCash = 100000.0, commission = 0.0, minCommission = 0.0, riskFreeRate = 0.02,
  verbose = false
): int =
  ## Backtest RSI mean reversion strategy
  ## 
  ## Buys when RSI falls below oversold threshold,
  ## sells when it rises above overbought threshold.
  ##
  ## Data sources:
  ##   symbol (positional)              Use Yahoo Finance (default): rsi AAPL --start=2023-01-01
  ##   --csvFile=data.csv               Load from CSV file
  ##   --yahoo=AAPL --start=2023-01-01  Fetch from Yahoo Finance (explicit)
  ##   --coinbase=BTC-USD --start=2023-01-01  Fetch from Coinbase (needs env vars)
  ##
  ## Portfolio options (auto-generated):
  ##   --initialCash=100000.0       Starting capital
  ##   --commission=0.0             Commission rate (0.001 = 0.1%)
  ##   --minCommission=0.0          Minimum commission per trade
  ##   --riskFreeRate=0.02          Risk-free rate for Sharpe ratio (0.02 = 2%)
  
  let strategyObj = newRSIStrategy(period, oversold, overbought)
  return runStrategyBacktest(strategyObj, symbol, csvFile, yahoo, coinbase, start, endDate,
                             initialCash, commission, minCommission, riskFreeRate, verbose)

proc bollinger(
  symbol = "",
  csvFile = "", yahoo = "", coinbase = "", start = "", endDate = "",
  period = 20, stdDev = 2.0,
  initialCash = 100000.0, commission = 0.0, minCommission = 0.0, riskFreeRate = 0.02,
  verbose = false
): int =
  ## Backtest Bollinger Bands mean reversion strategy
  ## 
  ## Buys when price touches lower band, sells when it touches upper band.
  
  let strategyObj = newBollingerStrategy(period, stdDev)
  return runStrategyBacktest(strategyObj, symbol, csvFile, yahoo, coinbase, start, endDate,
                             initialCash, commission, minCommission, riskFreeRate, verbose)

proc stochastic(
  symbol = "",
  csvFile = "", yahoo = "", coinbase = "", start = "", endDate = "",
  kPeriod = 14, dPeriod = 3, oversold = 20.0, overbought = 80.0,
  initialCash = 100000.0, commission = 0.0, minCommission = 0.0, riskFreeRate = 0.02,
  verbose = false
): int =
  ## Backtest Stochastic Oscillator mean reversion strategy
  ## 
  ## Buys when %K crosses above oversold threshold, sells when it crosses below overbought threshold.
  
  let strategyObj = newStochasticStrategy(kPeriod, dPeriod, oversold, overbought)
  return runStrategyBacktest(strategyObj, symbol, csvFile, yahoo, coinbase, start, endDate,
                             initialCash, commission, minCommission, riskFreeRate, verbose)

proc mfi(
  symbol = "",
  csvFile = "", yahoo = "", coinbase = "", start = "", endDate = "",
  period = 14, oversold = 20.0, overbought = 80.0,
  initialCash = 100000.0, commission = 0.0, minCommission = 0.0, riskFreeRate = 0.02,
  verbose = false
): int =
  ## Backtest Money Flow Index mean reversion strategy
  ## 
  ## Volume-weighted RSI. Buys at oversold levels, sells at overbought levels.
  
  let strategyObj = newMFIStrategy(period, oversold, overbought)
  return runStrategyBacktest(strategyObj, symbol, csvFile, yahoo, coinbase, start, endDate,
                             initialCash, commission, minCommission, riskFreeRate, verbose)

proc cci(
  symbol = "",
  csvFile = "", yahoo = "", coinbase = "", start = "", endDate = "",
  period = 20, oversold = -100.0, overbought = 100.0,
  initialCash = 100000.0, commission = 0.0, minCommission = 0.0, riskFreeRate = 0.02,
  verbose = false
): int =
  ## Backtest Commodity Channel Index mean reversion strategy
  ## 
  ## Measures price deviation from average. Buys at extreme lows, sells at extreme highs.
  
  let strategyObj = newCCIStrategy(period, oversold, overbought)
  return runStrategyBacktest(strategyObj, symbol, csvFile, yahoo, coinbase, start, endDate,
                             initialCash, commission, minCommission, riskFreeRate, verbose)

# ============================================================================
# TREND FOLLOWING STRATEGIES (7)
# ============================================================================

proc crossover(
  symbol = "",
  csvFile = "", yahoo = "", coinbase = "", start = "", endDate = "",
  fastPeriod = 50, slowPeriod = 200,
  initialCash = 100000.0, commission = 0.0, minCommission = 0.0, riskFreeRate = 0.02,
  verbose = false
): int =
  ## Backtest Moving Average Crossover trend following strategy
  ## 
  ## Classic trend strategy. Buys when fast MA crosses above slow MA, sells when it crosses below.
  
  let strategyObj = newCrossoverStrategy(fastPeriod, slowPeriod)
  return runStrategyBacktest(strategyObj, symbol, csvFile, yahoo, coinbase, start, endDate,
                             initialCash, commission, minCommission, riskFreeRate, verbose)

proc macd(
  symbol = "",
  csvFile = "", yahoo = "", coinbase = "", start = "", endDate = "",
  fast = 12, slow = 26, signal = 9,
  initialCash = 100000.0, commission = 0.0, minCommission = 0.0, riskFreeRate = 0.02,
  verbose = false
): int =
  ## Backtest MACD trend following strategy
  ## 
  ## Buys when MACD crosses above signal line, sells when it crosses below.
  
  let strategyObj = newMACDStrategy(fast, slow, signal)
  return runStrategyBacktest(strategyObj, symbol, csvFile, yahoo, coinbase, start, endDate,
                             initialCash, commission, minCommission, riskFreeRate, verbose)

proc kama(
  symbol = "",
  csvFile = "", yahoo = "", coinbase = "", start = "", endDate = "",
  period = 10, fastSC = 2, slowSC = 30,
  initialCash = 100000.0, commission = 0.0, minCommission = 0.0, riskFreeRate = 0.02,
  verbose = false
): int =
  ## Backtest Kaufman Adaptive Moving Average trend following strategy
  ## 
  ## Adaptive MA that adjusts to market volatility. Buys when price crosses above KAMA.
  
  let strategyObj = newKAMAStrategy(period, fastSC, slowSC)
  return runStrategyBacktest(strategyObj, symbol, csvFile, yahoo, coinbase, start, endDate,
                             initialCash, commission, minCommission, riskFreeRate, verbose)

proc aroon(
  symbol = "",
  csvFile = "", yahoo = "", coinbase = "", start = "", endDate = "",
  period = 25, upThreshold = 70.0, downThreshold = 30.0,
  initialCash = 100000.0, commission = 0.0, minCommission = 0.0, riskFreeRate = 0.02,
  verbose = false
): int =
  ## Backtest Aroon trend identification strategy
  ## 
  ## Identifies trend strength and direction.
  
  let strategyObj = newAroonStrategy(period, upThreshold, downThreshold)
  return runStrategyBacktest(strategyObj, symbol, csvFile, yahoo, coinbase, start, endDate,
                             initialCash, commission, minCommission, riskFreeRate, verbose)

proc psar(
  symbol = "",
  csvFile = "", yahoo = "", coinbase = "", start = "", endDate = "",
  acceleration = 0.02, maximum = 0.20,
  initialCash = 100000.0, commission = 0.0, minCommission = 0.0, riskFreeRate = 0.02,
  verbose = false
): int =
  ## Backtest Parabolic SAR trend following strategy
  ## 
  ## Trailing stop and reverse system.
  
  let strategyObj = newParabolicSARStrategy(acceleration, maximum)
  return runStrategyBacktest(strategyObj, symbol, csvFile, yahoo, coinbase, start, endDate,
                             initialCash, commission, minCommission, riskFreeRate, verbose)

proc triplem(
  symbol = "",
  csvFile = "", yahoo = "", coinbase = "", start = "", endDate = "",
  fastPeriod = 20, mediumPeriod = 50, slowPeriod = 200,
  initialCash = 100000.0, commission = 0.0, minCommission = 0.0, riskFreeRate = 0.02,
  verbose = false
): int =
  ## Backtest Triple Moving Average trend following strategy
  ## 
  ## Uses three MAs to confirm trend strength. Buys when fast > medium > slow.
  
  let strategyObj = newTripleMAStrategy(fastPeriod, mediumPeriod, slowPeriod)
  return runStrategyBacktest(strategyObj, symbol, csvFile, yahoo, coinbase, start, endDate,
                             initialCash, commission, minCommission, riskFreeRate, verbose)

proc adx(
  symbol = "",
  csvFile = "", yahoo = "", coinbase = "", start = "", endDate = "",
  period = 14, threshold = 25.0,
  initialCash = 100000.0, commission = 0.0, minCommission = 0.0, riskFreeRate = 0.02,
  verbose = false
): int =
  ## Backtest ADX Trend Strength strategy
  ## 
  ## Measures trend strength (not direction). Trades when ADX > threshold.
  
  let strategyObj = newADXTrendStrategy(period, threshold)
  return runStrategyBacktest(strategyObj, symbol, csvFile, yahoo, coinbase, start, endDate,
                             initialCash, commission, minCommission, riskFreeRate, verbose)

# ============================================================================
# VOLATILITY STRATEGIES (1)
# ============================================================================

proc keltner(
  symbol = "",
  csvFile = "", yahoo = "", coinbase = "", start = "", endDate = "",
  emaPeriod = 20, atrPeriod = 10, multiplier = 2.0, mode = "breakout",
  initialCash = 100000.0, commission = 0.0, minCommission = 0.0, riskFreeRate = 0.02,
  verbose = false
): int =
  ## Backtest Keltner Channel volatility strategy
  ## 
  ## Channels based on ATR (volatility).
  ## Mode 'breakout': buys at upper band breakout.
  ## Mode 'reversion': mean reversion at lower band.
  
  let channelMode = if mode == "reversion": Reversion else: Breakout
  let strategyObj = newKeltnerChannelStrategy(emaPeriod, atrPeriod, multiplier, channelMode)
  return runStrategyBacktest(strategyObj, symbol, csvFile, yahoo, coinbase, start, endDate,
                             initialCash, commission, minCommission, riskFreeRate, verbose)

# ============================================================================
# HYBRID STRATEGIES (3)
# ============================================================================

proc volume(
  symbol = "",
  csvFile = "", yahoo = "", coinbase = "", start = "", endDate = "",
  period = 20, volumeMultiplier = 1.5,
  initialCash = 100000.0, commission = 0.0, minCommission = 0.0, riskFreeRate = 0.02,
  verbose = false
): int =
  ## Backtest Volume Breakout hybrid strategy
  ## 
  ## Combines price action with volume confirmation.
  
  let strategyObj = newVolumeBreakoutStrategy(period, volumeMultiplier)
  return runStrategyBacktest(strategyObj, symbol, csvFile, yahoo, coinbase, start, endDate,
                             initialCash, commission, minCommission, riskFreeRate, verbose)

proc dualmomentum(
  symbol = "",
  csvFile = "", yahoo = "", coinbase = "", start = "", endDate = "",
  rocPeriod = 12, smaPeriod = 50,
  initialCash = 100000.0, commission = 0.0, minCommission = 0.0, riskFreeRate = 0.02,
  verbose = false
): int =
  ## Backtest Dual Momentum hybrid strategy
  ## 
  ## Combines momentum (ROC) with trend filter (SMA).
  
  let strategyObj = newDualMomentumStrategy(rocPeriod, smaPeriod)
  return runStrategyBacktest(strategyObj, symbol, csvFile, yahoo, coinbase, start, endDate,
                             initialCash, commission, minCommission, riskFreeRate, verbose)

proc filteredrsi(
  symbol = "",
  csvFile = "", yahoo = "", coinbase = "", start = "", endDate = "",
  rsiPeriod = 14, trendPeriod = 200, oversold = 30.0, overbought = 70.0,
  initialCash = 100000.0, commission = 0.0, minCommission = 0.0, riskFreeRate = 0.02,
  verbose = false
): int =
  ## Backtest Filtered RSI hybrid strategy
  ## 
  ## RSI mean reversion with long-term trend filter.
  
  let strategyObj = newFilteredMeanReversionStrategy(rsiPeriod, trendPeriod, oversold, overbought)
  return runStrategyBacktest(strategyObj, symbol, csvFile, yahoo, coinbase, start, endDate,
                             initialCash, commission, minCommission, riskFreeRate, verbose)

# ============================================================================
# CLI WIRING - Auto-generated by cligen
# ============================================================================

when isMainModule:
  dispatchMulti(
    # Mean Reversion
    [rsi, short = {"symbol": 's'}],
    [bollinger, short = {"symbol": 's'}],
    [stochastic, short = {"symbol": 's'}],
    [mfi, short = {"symbol": 's'}],
    [cci, short = {"symbol": 's'}],
    # Trend Following
    [crossover, short = {"symbol": 's'}],
    [macd, short = {"symbol": 's'}],
    [kama, short = {"symbol": 's'}],
    [aroon, short = {"symbol": 's'}],
    [psar, short = {"symbol": 's'}],
    [triplem, short = {"symbol": 's'}],
    [adx, short = {"symbol": 's'}],
    # Volatility
    [keltner, short = {"symbol": 's'}],
    # Hybrid
    [volume, short = {"symbol": 's'}],
    [dualmomentum, short = {"symbol": 's'}],
    [filteredrsi, short = {"symbol": 's'}]
  )
