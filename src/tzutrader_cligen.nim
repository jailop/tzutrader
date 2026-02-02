## TzuTrader CLI (cligen version) - Proof of Concept
##
## This demonstrates automatic CLI generation using cligen for 3 strategies.
## Compare this ~80 lines with the original 594 lines in tzutrader_cli.nim!

import std/[strformat, os]
import tzutrader/[core, data, strategy, portfolio, trader]
import cligen

proc rsi(
  csvFile: string,
  period = 14,
  oversold = 30.0,
  overbought = 70.0,
  initialCash = 100000.0,
  commission = 0.0,
  verbose = false
): int =
  ## Backtest RSI mean reversion strategy
  ##
  ## The RSI strategy buys when RSI falls below the oversold threshold
  ## and sells when it rises above the overbought threshold.
  ##
  ## Args:
  ##   csvFile: Path to CSV file with price data (required)
  ##   period: RSI calculation period (default: 14)
  ##   oversold: Buy signal threshold (default: 30.0)
  ##   overbought: Sell signal threshold (default: 70.0)
  ##   initialCash: Starting capital (default: 100000.0)
  ##   commission: Commission rate as decimal (default: 0.0)
  ##   verbose: Show detailed progress (default: false)

  # Validate file exists
  if not fileExists(csvFile):
    echo &"Error: File not found: {csvFile}"
    return 1

  # Extract symbol from filename
  let symbol = csvFile.splitFile().name

  if verbose:
    echo &"Running RSI backtest on {csvFile}"
    echo &"Strategy: RSI(period={period}, oversold={oversold}, overbought={overbought})"
    echo &"Initial cash: ${initialCash}"
    echo &"Commission: {commission * 100}%"
    echo ""

  # Create strategy and run backtest
  let strategy = newRSIStrategy(period, oversold, overbought)
  let report = quickBacktestCSV(symbol, strategy, csvFile, initialCash,
      commission, verbose)

  echo report
  return 0

proc macd(
  csvFile: string,
  fast = 12,
  slow = 26,
  signal = 9,
  initialCash = 100000.0,
  commission = 0.0,
  verbose = false
): int =
  ## Backtest MACD trend following strategy
  ##
  ## The MACD strategy generates buy signals when MACD crosses above
  ## the signal line and sell signals when it crosses below.
  ##
  ## Args:
  ##   csvFile: Path to CSV file with price data (required)
  ##   fast: Fast EMA period (default: 12)
  ##   slow: Slow EMA period (default: 26)
  ##   signal: Signal line period (default: 9)
  ##   initialCash: Starting capital (default: 100000.0)
  ##   commission: Commission rate as decimal (default: 0.0)
  ##   verbose: Show detailed progress (default: false)

  if not fileExists(csvFile):
    echo &"Error: File not found: {csvFile}"
    return 1

  let symbol = csvFile.splitFile().name

  if verbose:
    echo &"Running MACD backtest on {csvFile}"
    echo &"Strategy: MACD(fast={fast}, slow={slow}, signal={signal})"
    echo ""

  let strategy = newMACDStrategy(fast, slow, signal)
  let report = quickBacktestCSV(symbol, strategy, csvFile, initialCash,
      commission, verbose)

  echo report
  return 0

proc bollinger(
  csvFile: string,
  period = 20,
  stdDev = 2.0,
  initialCash = 100000.0,
  commission = 0.0,
  verbose = false
): int =
  ## Backtest Bollinger Bands mean reversion strategy
  ##
  ## The Bollinger strategy buys when price touches the lower band
  ## and sells when it touches the upper band.
  ##
  ## Args:
  ##   csvFile: Path to CSV file with price data (required)
  ##   period: Moving average period (default: 20)
  ##   stdDev: Standard deviation multiplier (default: 2.0)
  ##   initialCash: Starting capital (default: 100000.0)
  ##   commission: Commission rate as decimal (default: 0.0)
  ##   verbose: Show detailed progress (default: false)

  if not fileExists(csvFile):
    echo &"Error: File not found: {csvFile}"
    return 1

  let symbol = csvFile.splitFile().name

  if verbose:
    echo &"Running Bollinger Bands backtest on {csvFile}"
    echo &"Strategy: Bollinger(period={period}, stdDev={stdDev})"
    echo ""

  let strategy = newBollingerStrategy(period, stdDev)
  let report = quickBacktestCSV(symbol, strategy, csvFile, initialCash,
      commission, verbose)

  echo report
  return 0

# This is ALL the code needed to wire up the CLI!
# cligen automatically generates:
# - Argument parsing for all parameters
# - Type conversion (string, int, float, bool)
# - Help text from doc comments
# - Subcommand routing
when isMainModule:
  dispatchMulti(
    [rsi, help = {
      "csvFile": "Path to CSV file with OHLCV data",
      "period": "RSI calculation period",
      "oversold": "Buy when RSI drops below this",
      "overbought": "Sell when RSI rises above this",
      "initialCash": "Starting capital in dollars",
      "commission": "Commission rate (e.g., 0.001 for 0.1%)",
      "verbose": "Show detailed progress messages"
    }],
    [macd, help = {
      "csvFile": "Path to CSV file with OHLCV data",
      "fast": "Fast EMA period",
      "slow": "Slow EMA period",
      "signal": "Signal line period",
      "initialCash": "Starting capital in dollars",
      "commission": "Commission rate (e.g., 0.001 for 0.1%)",
      "verbose": "Show detailed progress messages"
    }],
    [bollinger, help = {
      "csvFile": "Path to CSV file with OHLCV data",
      "period": "Bollinger Bands period",
      "stdDev": "Standard deviation multiplier",
      "initialCash": "Starting capital in dollars",
      "commission": "Commission rate (e.g., 0.001 for 0.1%)",
      "verbose": "Show detailed progress messages"
    }]
  )
