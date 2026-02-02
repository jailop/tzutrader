## RSI Strategy Example
##
## Demonstrates the RSI (Relative Strength Index) strategy.
## This strategy buys when RSI is oversold and sells when overbought.

import std/[times, strformat, sequtils]
import ../src/tzutrader

proc main() =
  echo "="
  echo "RSI Strategy Example"
  echo "="
  echo ""

  # Load CSV data
  echo "Loading AAPL sample data..."
  let data = readCSV("data/AAPL_sample.csv")
  echo &"Loaded {data.len} bars"
  echo &"Date range: {data[0].timestamp.fromUnix().format(\"yyyy-MM-dd\")} to {data[^1].timestamp.fromUnix().format(\"yyyy-MM-dd\")}"
  echo ""

  # Create RSI strategy
  echo "Creating RSI Strategy (Period: 14, Oversold: 30, Overbought: 70)"
  let strategy = newRSIStrategy(period = 14, oversold = 30.0, overbought = 70.0)

  # Streaming mode: Process all bars
  echo "\n=== STREAMING MODE ==="
  var signals: seq[Signal] = @[]
  for bar in data:
    signals.add(strategy.onBar(bar))

  var buyCount = 0
  var sellCount = 0
  var stayCount = 0

  for signal in signals:
    case signal.position
    of Position.Buy:
      buyCount.inc
      echo &"BUY  @ {signal.timestamp.fromUnix().format(\"yyyy-MM-dd\")}: ${signal.price:.2f} - {signal.reason}"
    of Position.Sell:
      sellCount.inc
      echo &"SELL @ {signal.timestamp.fromUnix().format(\"yyyy-MM-dd\")}: ${signal.price:.2f} - {signal.reason}"
    of Position.Stay:
      stayCount.inc

  echo &"\nSummary:"
  echo &"  Total signals: {signals.len}"
  echo &"  Buy signals:  {buyCount}"
  echo &"  Sell signals: {sellCount}"
  echo &"  Stay signals: {stayCount}"

  # Streaming mode demonstration
  echo "\n=== STREAMING MODE ==="
  let streamStrategy = newRSIStrategy(period = 14, oversold = 30.0,
      overbought = 70.0)

  var streamBuys = 0
  var streamSells = 0

  for bar in data:
    let signal = streamStrategy.onBar(bar)
    if signal.position == Position.Buy:
      streamBuys.inc
      echo &"BUY  @ {signal.timestamp.fromUnix().format(\"yyyy-MM-dd\")}: ${signal.price:.2f}"
    elif signal.position == Position.Sell:
      streamSells.inc
      echo &"SELL @ {signal.timestamp.fromUnix().format(\"yyyy-MM-dd\")}: ${signal.price:.2f}"

  echo &"\nStreaming Summary:"
  echo &"  Buy signals:  {streamBuys}"
  echo &"  Sell signals: {streamSells}"

  # Parameter tuning example
  echo "\n=== PARAMETER TUNING ==="
  echo "Testing different RSI parameters:"

  let params = @[
    (period: 7, oversold: 25.0, overbought: 75.0),
    (period: 14, oversold: 30.0, overbought: 70.0),
    (period: 21, oversold: 35.0, overbought: 65.0)
  ]

  for p in params:
    let testStrat = newRSIStrategy(period = p.period, oversold = p.oversold,
        overbought = p.overbought)
    var testSignals: seq[Signal] = @[]
    for bar in data:
      testSignals.add(testStrat.onBar(bar))
    let buys = testSignals.filterIt(it.position == Position.Buy).len
    let sells = testSignals.filterIt(it.position == Position.Sell).len
    echo &"  RSI({p.period}, {p.oversold:.0f}, {p.overbought:.0f}): {buys} buys, {sells} sells"

when isMainModule:
  main()
