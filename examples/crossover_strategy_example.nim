## Crossover Strategy Example
##
## Demonstrates the Moving Average Crossover strategy.
## This strategy generates buy signals on golden cross (fast MA > slow MA)
## and sell signals on death cross (fast MA < slow MA).

import std/[times, sequtils, strformat]
import ../src/tzutrader/core
import ../src/tzutrader/data
import ../src/tzutrader/strategy

proc main() =
  echo "="
  echo "Moving Average Crossover Strategy Example"
  echo "="
  echo ""
  
  # Load CSV data
  echo "Loading AAPL sample data..."
  let data = readCSV("data/AAPL_sample.csv")
  echo &"Loaded {data.len} bars"
  echo ""
  
  # Create MA Crossover strategy
  echo "Creating MA Crossover Strategy (Fast: 10, Slow: 20)"
  let strategy = newCrossoverStrategy(fastPeriod = 10, slowPeriod = 20)
  
  # Batch mode analysis
  echo "\n=== BATCH MODE ==="
  let signals = strategy.analyze(data)
  
  var buySignals: seq[Signal] = @[]
  var sellSignals: seq[Signal] = @[]
  
  for signal in signals:
    case signal.position
    of Position.Buy:
      buySignals.add(signal)
      echo &"GOLDEN CROSS @ {signal.timestamp.fromUnix().format(\"yyyy-MM-dd\")}: ${signal.price:.2f}"
      echo &"  {signal.reason}"
    of Position.Sell:
      sellSignals.add(signal)
      echo &"DEATH CROSS  @ {signal.timestamp.fromUnix().format(\"yyyy-MM-dd\")}: ${signal.price:.2f}"
      echo &"  {signal.reason}"
    of Position.Stay:
      discard
  
  echo &"\nSummary:"
  echo &"  Total bars:     {signals.len}"
  echo &"  Golden crosses: {buySignals.len}"
  echo &"  Death crosses:  {sellSignals.len}"
  
  # Streaming mode demonstration
  echo "\n=== STREAMING MODE ==="
  let streamStrategy = newCrossoverStrategy(fastPeriod = 10, slowPeriod = 20)
  
  var streamBuys = 0
  var streamSells = 0
  
  echo "Processing bars in real-time mode..."
  for i, bar in data:
    let signal = streamStrategy.onBar(bar)
    if signal.position == Position.Buy:
      streamBuys.inc
      echo &"[{i+1}/{data.len}] GOLDEN CROSS @ ${signal.price:.2f}"
    elif signal.position == Position.Sell:
      streamSells.inc
      echo &"[{i+1}/{data.len}] DEATH CROSS  @ ${signal.price:.2f}"
  
  echo &"\nStreaming Summary:"
  echo &"  Golden crosses: {streamBuys}"
  echo &"  Death crosses:  {streamSells}"
  
  # Parameter comparison
  echo "\n=== PARAMETER COMPARISON ==="
  echo "Testing different MA periods:"
  
  let configurations = @[
    (fast: 5, slow: 10),
    (fast: 10, slow: 20),
    (fast: 20, slow: 50),
    (fast: 50, slow: 200)
  ]
  
  for config in configurations:
    let testStrat = newCrossoverStrategy(fastPeriod = config.fast, slowPeriod = config.slow)
    let testSignals = testStrat.analyze(data)
    let buys = testSignals.filterIt(it.position == Position.Buy).len
    let sells = testSignals.filterIt(it.position == Position.Sell).len
    echo &"  MA({config.fast}/{config.slow}): {buys} golden, {sells} death crosses"
  
  echo "\nDone!"

when isMainModule:
  main()
