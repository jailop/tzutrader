## Bollinger Bands Strategy Example
##
## Demonstrates the Bollinger Bands mean reversion strategy.
## This strategy generates buy signals when price touches the lower band
## and sell signals when price touches the upper band.

import std/[times, strformat]

include ../src/tzutrader/core
include ../src/tzutrader/data
include ../src/tzutrader/indicators
include ../src/tzutrader/strategy

proc main() =
  echo "="
  echo "Bollinger Bands Strategy Example"
  echo "="
  echo ""
  
  # Load CSV data
  echo "Loading AAPL sample data..."
  let data = readCSV("data/AAPL_sample.csv")
  echo &"Loaded {data.len} bars"
  echo ""
  
  # Create Bollinger Bands strategy
  echo "Creating Bollinger Bands Strategy (Period: 20, StdDev: 2.0)"
  var strategy = newBollingerStrategy(period = 20, stdDev = 2.0)
  strategy.symbol = "AAPL"
  
  # Streaming mode analysis
  echo "\n=== STREAMING MODE ==="
  var buySignals: seq[Signal] = @[]
  var sellSignals: seq[Signal] = @[]
  var allSignals: seq[Signal] = @[]
  
  for bar in data:
    let signal = strategy.onBar(bar)
    allSignals.add(signal)
    
    case signal.position
    of Position.Buy:
      buySignals.add(signal)
      echo &"LOWER BAND TOUCH @ {signal.timestamp.fromUnix().format(\"yyyy-MM-dd\")}: ${signal.price:.2f}"
      echo &"  {signal.reason}"
    of Position.Sell:
      sellSignals.add(signal)
      echo &"UPPER BAND TOUCH @ {signal.timestamp.fromUnix().format(\"yyyy-MM-dd\")}: ${signal.price:.2f}"
      echo &"  {signal.reason}"
    of Position.Stay:
      discard
  
  echo &"\nSummary:"
  echo &"  Total bars:       {allSignals.len}"
  echo &"  Lower band touch: {buySignals.len} (oversold - buy)"
  echo &"  Upper band touch: {sellSignals.len} (overbought - sell)"
  
  # Show Bollinger Bands values for last 10 bars
  echo "\n=== BOLLINGER BANDS VALUES ==="
  echo "Recalculating with streaming to show last 10 bars:"
  echo "Date         | Price   | Lower   | Middle  | Upper"
  echo "-".repeat(60)
  
  # Reset and process again, saving last 10 BB values
  strategy.reset()
  var bbValues: seq[BollingerResult] = @[]
  
  for bar in data:
    discard strategy.onBar(bar)
    bbValues.add(strategy.bbIndicator[0])  # Save current BB value
  
  for i in max(0, data.len - 10)..<data.len:
    let bar = data[i]
    let date = bar.timestamp.fromUnix().format("yyyy-MM-dd")
    let price = bar.close
    let bb = bbValues[i]
    
    var indicator = ""
    if not bb.lower.isNaN:
      if price <= bb.lower:
        indicator = " <- BUY"
      elif price >= bb.upper:
        indicator = " <- SELL"
    
    if not bb.lower.isNaN:
      echo &"{date} | ${price:>6.2f} | ${bb.lower:>6.2f} | ${bb.middle:>6.2f} | ${bb.upper:>6.2f}{indicator}"
  
  # Parameter tuning
  echo "\n=== PARAMETER TUNING ==="
  echo "Testing different Bollinger Bands parameters:"
  
  let configurations = @[
    (period: 10, stdDev: 1.5),
    (period: 20, stdDev: 2.0),
    (period: 20, stdDev: 2.5),
    (period: 30, stdDev: 2.0)
  ]
  
  for config in configurations:
    let testStrat = newBollingerStrategy(period = config.period, stdDev = config.stdDev)
    let testSignals = testStrat.analyze(data)
    let buys = testSignals.filterIt(it.position == Position.Buy).len
    let sells = testSignals.filterIt(it.position == Position.Sell).len
    echo &"  BB({config.period}, {config.stdDev}): {buys} buys, {sells} sells"
  
  echo "\n=== NOTES ==="
  echo "Bollinger Bands Strategy uses mean reversion:"
  echo "  - Buy when price touches/breaks lower band (oversold)"
  echo "  - Sell when price touches/breaks upper band (overbought)"
  echo "  - Exit when price returns near middle band"
  echo ""
  echo "Note: Streaming mode is not recommended for Bollinger Bands"
  echo "      as it requires full history for standard deviation calculation."
  
  echo "\nDone!"

when isMainModule:
  main()
