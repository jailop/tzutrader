## CSV Data Stream Example
##
## Demonstrates reading and working with CSV data files

import std/[strformat, strutils]
import ../src/tzutrader/core
import ../src/tzutrader/data
import ../src/tzutrader/indicators

echo "=" .repeat(70)
echo "CSV Data Stream Example"
echo "=" .repeat(70)

# ============================================================================
# Example 1: Basic CSV Reading
# ============================================================================

echo "\nExample 1: Basic CSV Reading"
echo "-" .repeat(70)

let csvStream = newCSVDataStream("data/TEST.csv")
echo "Loaded: ", csvStream
echo "Total bars: ", csvStream.len()
echo "\nFirst 5 bars:"

csvStream.reset()
for i in 0..4:
  if csvStream.hasNext():
    let bar = csvStream.next()
    echo &"  [{i}] Close: ${bar.close:.2f}, Volume: {bar.volume:.0f}"

# ============================================================================
# Example 2: Streaming with Indicators
# ============================================================================

echo "\n\nExample 2: Streaming with Indicators"
echo "-" .repeat(70)

let aaplStream = newCSVDataStream("data/AAPL.csv", "AAPL")
echo "Analyzing ", aaplStream.symbol, " (", aaplStream.len(), " bars)"

# Create streaming indicators
var sma20 = newSMA(20)
var ema20 = newEMA(20)
var rsi14 = newRSI(14)

# Process data
var bars = 0
var signals = 0
aaplStream.reset()

while aaplStream.hasNext():
  let bar = aaplStream.next()
  bars.inc
  
  # Update indicators
  let smaVal = sma20.update(bar.close)
  let emaVal = ema20.update(bar.close)
  let rsiVal = rsi14.update(bar.open, bar.close)
  
  # Show last 5 bars with indicators
  if bars > aaplStream.len() - 5:
    let smaStr = if smaVal.isNaN: "N/A" else: &"{smaVal:.2f}"
    let emaStr = if emaVal.isNaN: "N/A" else: &"{emaVal:.2f}"
    let rsiStr = if rsiVal.isNaN: "N/A" else: &"{rsiVal:.2f}"
    echo &"  Bar {bars:3}: Close=${bar.close:6.2f} SMA={smaStr:>7} EMA={emaStr:>7} RSI={rsiStr:>6}"
  
  # Count oversold/overbought signals
  if not rsiVal.isNaN:
    if rsiVal < 30:
      signals.inc  # Oversold signal
    elif rsiVal > 70:
      signals.inc  # Overbought signal

echo &"\nTotal bars processed: {bars}"
echo &"RSI signals generated: {signals}"

# ============================================================================
# Example 3: Batch Processing Multiple CSV Files
# ============================================================================

echo "\n\nExample 3: Batch Processing Multiple CSV Files"
echo "-" .repeat(70)

let symbols = @["AAPL", "MSFT", "BEAR", "SIDEWAYS", "CYCLE"]

echo "\nSymbol Analysis:"
echo "Symbol     Bars     Start      End        Change"
echo "-" .repeat(70)

for symbol in symbols:
  let filename = "data/" & symbol & ".csv"
  let data = readCSV(filename)
  
  let startPrice = data[0].close
  let endPrice = data[^1].close
  let change = ((endPrice - startPrice) / startPrice) * 100.0
  
  echo &"{symbol:<10} {data.len:<8} ${startPrice:<9.2f} ${endPrice:<9.2f} {change:+.2f}%"

# ============================================================================
# Example 4: Streaming Pattern - Simulated Real-time Processing
# ============================================================================

echo "\n\nExample 4: Simulated Real-time Processing"
echo "-" .repeat(70)

echo "\nSimulating real-time bar processing..."
let rtStream = newCSVDataStream("data/TEST.csv")
var rsiStream = newRSI(14)
var position = "None"

rtStream.reset()
var barCount = 0

while rtStream.hasNext():
  let bar = rtStream.next()
  barCount.inc
  
  let rsiVal = rsiStream.update(bar.open, bar.close)
  
  # Simple RSI strategy
  if not rsiVal.isNaN:
    var signal = ""
    if rsiVal < 30 and position != "Long":
      position = "Long"
      signal = "🟢 BUY"
    elif rsiVal > 70 and position != "Flat":
      position = "Flat"
      signal = "🔴 SELL"
    
    if signal.len > 0:
      echo &"  Bar {barCount:2}: ${bar.close:6.2f} | RSI={rsiVal:5.2f} | {signal}"

echo &"\nProcessed {barCount} bars"
echo &"Final position: {position}"

# ============================================================================
# Summary
# ============================================================================

echo "\n" & "=" .repeat(70)
echo "CSV Examples Complete!"
echo "=" .repeat(70)
echo "\nKey Features Demonstrated:"
echo "  ✓ Reading CSV files into OHLCV data"
echo "  ✓ CSV streaming for sequential processing"
echo "  ✓ Real-time indicator updates from CSV"
echo "  ✓ Batch processing multiple files"
echo "  ✓ Simulated real-time trading from CSV"
echo "\nAvailable CSV files in data/:"
echo "  - AAPL.csv, MSFT.csv, BEAR.csv"
echo "  - SIDEWAYS.csv, CYCLE.csv"
echo "  - TEST.csv, LONG.csv"
