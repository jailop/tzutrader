## MACD Strategy Example
##
## Demonstrates the MACD (Moving Average Convergence Divergence) strategy.
## This strategy generates buy signals when MACD crosses above the signal line
## and sell signals when MACD crosses below the signal line.

import std/[times, strformat, sequtils]
import ../src/tzutrader

proc main() =
  echo "="
  echo "MACD Strategy Example"
  echo "="
  echo ""

  # Load CSV data
  echo "Loading AAPL sample data..."
  let data = readCSV("data/AAPL_sample.csv")
  echo &"Loaded {data.len} bars"
  echo ""

  # Create MACD strategy
  echo "Creating MACD Strategy (Fast: 12, Slow: 26, Signal: 9)"
  let strategy = newMACDStrategy(fastPeriod = 12, slowPeriod = 26,
      signalPeriod = 9)

  # Streaming mode analysis
  echo "\n=== STREAMING MODE ==="
  var signals: seq[Signal] = @[]
  for bar in data:
    signals.add(strategy.onBar(bar))

  var buySignals: seq[Signal] = @[]
  var sellSignals: seq[Signal] = @[]

  for signal in signals:
    case signal.position
    of Position.Buy:
      buySignals.add(signal)
      echo &"BULLISH CROSSOVER @ {signal.timestamp.fromUnix().format(\"yyyy-MM-dd\")}: ${signal.price:.2f}"
      echo &"  {signal.reason}"
    of Position.Sell:
      sellSignals.add(signal)
      echo &"BEARISH CROSSOVER @ {signal.timestamp.fromUnix().format(\"yyyy-MM-dd\")}: ${signal.price:.2f}"
      echo &"  {signal.reason}"
    of Position.Stay:
      discard

  echo &"\nSummary:"
  echo &"  Total bars:        {signals.len}"
  echo &"  Bullish crossovers: {buySignals.len}"
  echo &"  Bearish crossovers: {sellSignals.len}"

  # Streaming mode demonstration
  echo "\n=== STREAMING MODE ==="
  let streamStrategy = newMACDStrategy(fastPeriod = 12, slowPeriod = 26,
      signalPeriod = 9)

  var streamBuys = 0
  var streamSells = 0

  echo "Processing bars in real-time mode..."
  for i, bar in data:
    let signal = streamStrategy.onBar(bar)
    if signal.position == Position.Buy:
      streamBuys.inc
      echo &"[{i+1}/{data.len}] BULLISH @ ${signal.price:.2f}"
    elif signal.position == Position.Sell:
      streamSells.inc
      echo &"[{i+1}/{data.len}] BEARISH @ ${signal.price:.2f}"

  echo &"\nStreaming Summary:"
  echo &"  Bullish crossovers: {streamBuys}"
  echo &"  Bearish crossovers: {streamSells}"

  # Parameter tuning
  echo "\n=== PARAMETER TUNING ==="
  echo "Testing different MACD parameters:"

  let configurations = @[
    (fast: 8, slow: 17, signal: 9),
    (fast: 12, slow: 26, signal: 9),
    (fast: 19, slow: 39, signal: 9)
  ]

  for config in configurations:
    let testStrat = newMACDStrategy(
      fastPeriod = config.fast,
      slowPeriod = config.slow,
      signalPeriod = config.signal
    )
    var testSignals: seq[Signal] = @[]
    for bar in data:
      testSignals.add(testStrat.onBar(bar))
    let buys = testSignals.filterIt(it.position == Position.Buy).len
    let sells = testSignals.filterIt(it.position == Position.Sell).len
    echo &"  MACD({config.fast},{config.slow},{config.signal}): {buys} bullish, {sells} bearish"

when isMainModule:
  main()
