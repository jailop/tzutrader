## MACD Strategy Example
##
## Demonstrates the MACD (Moving Average Convergence Divergence) strategy.
## This strategy generates buy signals when MACD crosses above the signal line
## and sell signals when MACD crosses below the signal line.

import std/[sequtils, strformat]
import ../src/tzutrader/core
import ../src/tzutrader/data
import ../src/tzutrader/strategy

proc main() =
  let data = readCSV("data/AAPL.csv")
  let streamStrategy = newMACDStrategy(fastPeriod = 12, slowPeriod = 26, signalPeriod = 9)
  var streamBuys = 0
  var streamSells = 0
  for i, bar in data:
    let signal = streamStrategy.onBar(bar)
    if signal.position == Position.Buy:
      streamBuys.inc
      echo &"[{i+1}/{data.len}] BULLISH @ ${signal.price:.2f}"
    elif signal.position == Position.Sell:
      streamSells.inc
      echo &"[{i+1}/{data.len}] BEARISH @ ${signal.price:.2f}"
  
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
    let testSignals = testStrat.analyze(data)
    let buys = testSignals.filterIt(it.position == Position.Buy).len
    let sells = testSignals.filterIt(it.position == Position.Sell).len
    echo &"  MACD({config.fast},{config.slow},{config.signal}): {buys} bullish, {sells} bearish"

when isMainModule:
  main()
