## Strategy Example
## 
## This example demonstrates using TzuTrader's built-in strategies
## in streaming mode (processing one bar at a time).
##
## Strategies shown:
## - RSI Strategy (Mean Reversion)
## - Moving Average Crossover (Trend Following)
## - MACD Strategy (Trend Following)
## - Bollinger Bands Strategy (Mean Reversion)

import std/[times, strformat, sequtils]
import ../src/tzutrader

proc printSignalSummary(name: string, signals: seq[Signal]) =
  let buySignals = signals.filterIt(it.position == Position.Buy)
  let sellSignals = signals.filterIt(it.position == Position.Sell)
  let staySignals = signals.filterIt(it.position == Position.Stay)

  echo &"\n{name}:"
  echo &"  Total signals: {signals.len}"
  echo &"  Buy signals:   {buySignals.len}"
  echo &"  Sell signals:  {sellSignals.len}"
  echo &"  Stay signals:  {staySignals.len}"

  if buySignals.len > 0:
    echo &"  First Buy:  {buySignals[0].timestamp.fromUnix.format(\"yyyy-MM-dd\")} @ ${buySignals[0].price:.2f}"
    echo &"  Last Buy:   {buySignals[^1].timestamp.fromUnix.format(\"yyyy-MM-dd\")} @ ${buySignals[^1].price:.2f}"

  if sellSignals.len > 0:
    echo &"  First Sell: {sellSignals[0].timestamp.fromUnix.format(\"yyyy-MM-dd\")} @ ${sellSignals[0].price:.2f}"
    echo &"  Last Sell:  {sellSignals[^1].timestamp.fromUnix.format(\"yyyy-MM-dd\")} @ ${sellSignals[^1].price:.2f}"

proc analyzeWithStrategy(strategy: Strategy, data: seq[OHLCV]): seq[Signal] =
  ## Helper to process all data through a strategy in streaming mode
  result = newSeq[Signal](data.len)
  for i, bar in data:
    result[i] = strategy.onBar(bar)

proc main() =
  echo "="
  echo "TzuTrader Strategy Example"
  echo "="
  echo ""

  # Load CSV data
  echo "Loading AAPL sample data from CSV..."
  let data = readCSV("data/AAPL_sample.csv")
  echo &"Loaded {data.len} bars"
  echo &"Date range: {data[0].timestamp.fromUnix.format(\"yyyy-MM-dd\")} to {data[^1].timestamp.fromUnix.format(\"yyyy-MM-dd\")}"

  echo "\n" & "=".repeat(60)
  echo "STREAMING MODE: Process bars one at a time"
  echo "=".repeat(60)

  # 1. RSI Strategy
  echo "\n1. RSI Strategy (Period: 14, Oversold: 30, Overbought: 70)"
  let rsiStrat = newRSIStrategy(period = 14, oversold = 30.0, overbought = 70.0)
  let rsiSignals = analyzeWithStrategy(rsiStrat, data)
  printSignalSummary("RSI Strategy", rsiSignals)

  # 2. Moving Average Crossover Strategy
  echo "\n2. Moving Average Crossover (Fast: 10, Slow: 20)"
  let crossStrat = newCrossoverStrategy(fastPeriod = 10, slowPeriod = 20)
  let crossSignals = analyzeWithStrategy(crossStrat, data)
  printSignalSummary("Crossover Strategy", crossSignals)

  # 3. MACD Strategy
  echo "\n3. MACD Strategy (Fast: 12, Slow: 26, Signal: 9)"
  let macdStrat = newMACDStrategy(fastPeriod = 12, slowPeriod = 26,
      signalPeriod = 9)
  let macdSignals = analyzeWithStrategy(macdStrat, data)
  printSignalSummary("MACD Strategy", macdSignals)

  # 4. Bollinger Bands Strategy
  echo "\n4. Bollinger Bands Strategy (Period: 20, StdDev: 2.0)"
  let bbStrat = newBollingerStrategy(period = 20, stdDev = 2.0)
  let bbSignals = analyzeWithStrategy(bbStrat, data)
  printSignalSummary("Bollinger Bands Strategy", bbSignals)

  echo "\n" & "=".repeat(60)
  echo "REAL-TIME SIMULATION: Show signal changes as they happen"
  echo "=".repeat(60)

  echo "\nSimulating real-time data stream with RSI Strategy..."
  let streamStrat = newRSIStrategy(period = 14, oversold = 30.0,
      overbought = 70.0)

  var streamSignals: seq[Signal] = @[]
  var lastSignalPos = Position.Stay

  echo "Processing bars..."
  for i, bar in data:
    let signal = streamStrat.onBar(bar)
    streamSignals.add(signal)

    # Print only when signal changes
    if signal.position != lastSignalPos and signal.position != Position.Stay:
      echo &"  [{i+1}/{data.len}] {bar.timestamp.fromUnix.format(\"yyyy-MM-dd\")}: {signal.position} @ ${signal.price:.2f}"
      lastSignalPos = signal.position

  printSignalSummary("Real-time RSI Strategy", streamSignals)

  echo "\n" & "=".repeat(60)
  echo "STRATEGY COMPARISON"
  echo "=".repeat(60)

  echo &"\nComparing all strategies on same data ({data.len} bars):"
  echo ""
  echo "Strategy                    | Buy Signals | Sell Signals | Stay Signals"
  echo "-".repeat(75)

  proc formatRow(name: string, signals: seq[Signal]): string =
    let buys = signals.filterIt(it.position == Position.Buy).len
    let sells = signals.filterIt(it.position == Position.Sell).len
    let stays = signals.filterIt(it.position == Position.Stay).len
    return &"{name:<27} | {buys:>11} | {sells:>12} | {stays:>12}"

  echo formatRow("RSI (14, 30, 70)", rsiSignals)
  echo formatRow("Crossover (10, 20)", crossSignals)
  echo formatRow("MACD (12, 26, 9)", macdSignals)
  echo formatRow("Bollinger (20, 2.0)", bbSignals)

  echo "\n" & "=".repeat(60)
  echo "MULTI-SYMBOL ANALYSIS"
  echo "=".repeat(60)

  let symbols = @["AAPL_sample.csv", "MSFT_sample.csv"]
  let strategy = newCrossoverStrategy(fastPeriod = 10, slowPeriod = 20)

  echo &"\nRunning Crossover Strategy on multiple symbols:"
  for symbol in symbols:
    let symbolData = readCSV(&"data/{symbol}")

    # Reset strategy for each symbol
    strategy.reset()

    # Process all bars
    let symbolSignals = analyzeWithStrategy(strategy, symbolData)

    let buys = symbolSignals.filterIt(it.position == Position.Buy).len
    let sells = symbolSignals.filterIt(it.position == Position.Sell).len

    echo &"\n{symbol}:"
    echo &"  Bars: {symbolData.len}"
    echo &"  Buy signals: {buys}"
    echo &"  Sell signals: {sells}"

  echo "\n" & "=".repeat(60)
  echo "PARAMETER TUNING"
  echo "=".repeat(60)

  echo "\nTesting different RSI parameters:"

  let rsiParams = @[
    (period: 7, oversold: 25.0, overbought: 75.0),
    (period: 14, oversold: 30.0, overbought: 70.0),
    (period: 21, oversold: 35.0, overbought: 65.0)
  ]

  for params in rsiParams:
    let testStrat = newRSIStrategy(
      period = params.period,
      oversold = params.oversold,
      overbought = params.overbought
    )
    let testSignals = analyzeWithStrategy(testStrat, data)
    let buys = testSignals.filterIt(it.position == Position.Buy).len
    let sells = testSignals.filterIt(it.position == Position.Sell).len

    echo &"  RSI({params.period}, {params.oversold:.0f}, {params.overbought:.0f}): {buys} buys, {sells} sells"

  echo "\n" & "=".repeat(60)
  echo "Example completed!"
  echo "=".repeat(60)
  echo ""
  echo "Next steps:"
  echo "  - Try different strategy parameters"
  echo "  - Run backtests with the trader module"
  echo "  - Compare strategies on different symbols"
  echo "  - Create your own custom strategies"
  echo ""

when isMainModule:
  main()
