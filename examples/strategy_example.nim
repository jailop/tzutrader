## Strategy Example
## 
## This example demonstrates all 4 built-in strategies:
## - RSI Strategy
## - Moving Average Crossover Strategy
## - MACD Strategy
## - Bollinger Bands Strategy
##
## Both batch mode and streaming mode are shown.

import std/[times, strformat, sequtils]
import ../src/tzutrader/core
import ../src/tzutrader/data
import ../src/tzutrader/strategy

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
  
  # ============================================================================
  # BATCH MODE EXAMPLES
  # ============================================================================
  
  echo "\n" & "=".repeat(60)
  echo "BATCH MODE: Analyze entire dataset at once"
  echo "=".repeat(60)
  
  # 1. RSI Strategy
  echo "\n1. RSI Strategy (Period: 14, Oversold: 30, Overbought: 70)"
  let rsiStrat = newRSIStrategy(period = 14, oversold = 30.0, overbought = 70.0)
  var rsiSignals: seq[Signal] = @[]
  for bar in data:
    rsiSignals.add(on(rsiStrat, bar))
  printSignalSummary("RSI Strategy", rsiSignals)
  
  # 2. Moving Average Crossover Strategy
  echo "\n2. Moving Average Crossover (Fast: 10, Slow: 20)"
  let crossStrat = newCrossoverStrategy(fastPeriod = 10, slowPeriod = 20)
  var crossSignals: seq[Signal] = @[]
  for bar in data:
    crossSignals.add(on(crossStrat, bar))
  printSignalSummary("Crossover Strategy", crossSignals)
  
  # 3. MACD Strategy
  echo "\n3. MACD Strategy (Fast: 12, Slow: 26, Signal: 9)"
  let macdStrat = newMACDStrategy(fastPeriod = 12, slowPeriod = 26, signalPeriod = 9)
  var macdSignals: seq[Signal] = @[]
  for bar in data:
    macdSignals.add(on(macdStrat, bar))
  printSignalSummary("MACD Strategy", macdSignals)
  
  # 4. Bollinger Bands Strategy
  echo "\n4. Bollinger Bands Strategy (Period: 20, StdDev: 2.0)"
  let bbStrat = newBollingerStrategy(period = 20, stdDev = 2.0)
  var bbSignals: seq[Signal] = @[]
  for bar in data:
    bbSignals.add(on(bbStrat, bar))
  printSignalSummary("Bollinger Bands Strategy", bbSignals)
  
  # ============================================================================
  # STREAMING MODE EXAMPLE
  # ============================================================================
  
  echo "\n" & "=".repeat(60)
  echo "STREAMING MODE: Process bars one at a time"
  echo "=".repeat(60)
  
  echo "\nSimulating real-time data stream with RSI Strategy..."
  let streamStrat = newRSIStrategy(period = 14, oversold = 30.0, overbought = 70.0)
  
  var streamSignals: seq[Signal] = @[]
  var lastSignalPos = Position.Stay
  
  echo "Processing bars..."
  for i, bar in data:
    let signal = on(streamStrat, bar)
    streamSignals.add(signal)
    
    # Print only when signal changes
    if signal.position != lastSignalPos and signal.position != Position.Stay:
      echo &"  [{i+1}/{data.len}] {bar.timestamp.fromUnix.format(\"yyyy-MM-dd\")}: {signal.position} @ ${signal.price:.2f}"
      lastSignalPos = signal.position
  
  printSignalSummary("Streaming RSI Strategy", streamSignals)
  
  # ============================================================================
  # STRATEGY COMPARISON
  # ============================================================================
  
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
  
  # ============================================================================
  # MULTI-SYMBOL EXAMPLE
  # ============================================================================
  
  echo "\n" & "=".repeat(60)
  echo "MULTI-SYMBOL ANALYSIS"
  echo "=".repeat(60)
  
  let symbols = @["AAPL_sample.csv", "MSFT_sample.csv"]
  let strategy = newCrossoverStrategy(fastPeriod = 10, slowPeriod = 20)
  
  echo &"\nRunning Crossover Strategy on multiple symbols:"
  for symbol in symbols:
    let symbolData = readCSV(&"data/{symbol}")
    var symbolSignals: seq[Signal] = @[]
    for bar in symbolData:
      symbolSignals.add(on(strategy, bar))
    
    let buys = symbolSignals.filterIt(it.position == Position.Buy).len
    let sells = symbolSignals.filterIt(it.position == Position.Sell).len
    
    echo &"\n{symbol}:"
    echo &"  Bars: {symbolData.len}"
    echo &"  Buy signals: {buys}"
    echo &"  Sell signals: {sells}"
    
    # Reset strategy for next symbol
    strategy.reset()
  
  # ============================================================================
  # CUSTOM PARAMETERS EXAMPLE
  # ============================================================================
  
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
    var testSignals: seq[Signal] = @[]
    for bar in data:
      testSignals.add(on(testStrat, bar))
    let buys = testSignals.filterIt(it.position == Position.Buy).len
    let sells = testSignals.filterIt(it.position == Position.Sell).len
    
    echo &"  RSI({params.period}, {params.oversold:.0f}, {params.overbought:.0f}): {buys} buys, {sells} sells"
  
  echo "\n" & "=".repeat(60)
  echo "Example completed!"
  echo "=".repeat(60)
  echo ""
  echo "Next steps:"
  echo "  - Combine strategies for consensus signals"
  echo "  - Implement portfolio management (Phase 5)"
  echo "  - Run backtests with transaction costs (Phase 6)"
  echo ""

when isMainModule:
  main()
