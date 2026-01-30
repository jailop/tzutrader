## Example demonstrating the use of technical indicators
##
## This example shows both batch and streaming modes for calculating
## various technical indicators.

import std/[strformat, strutils]

include ../src/tzutrader/core
include ../src/tzutrader/indicators

# ============================================================================
# Helper: Print indicator values
# ============================================================================

proc printValues(name: string, values: seq[float64], count: int = 5) =
  echo &"\n{name}:"
  let start = max(0, values.len - count)
  for i in start..<values.len:
    if values[i].isNaN:
      echo &"  [{i}] NaN"
    else:
      echo &"  [{i}] {values[i]:.2f}"

# ============================================================================
# Example 1: Batch Mode - Calculate indicators on historical data
# ============================================================================

echo repeat("=", 70)
echo "Example 1: Batch Mode Indicators"
echo repeat("=", 70)

# Sample price data (e.g., Apple stock closing prices)
let closePrices = @[
  150.0, 152.0, 151.5, 153.0, 154.5, 155.0, 154.0, 156.0, 157.5, 158.0,
  159.0, 160.5, 161.0, 159.5, 160.0, 161.5, 163.0, 164.0, 165.5, 166.0,
  167.0, 168.5, 169.0, 170.0, 171.5, 172.0, 171.0, 172.5, 174.0, 175.0
]

echo &"\nAnalyzing {closePrices.len} price points..."
echo &"Price range: ${closePrices[0]:.2f} - ${closePrices[^1]:.2f}"

# Calculate various indicators
let sma10 = sma(closePrices, 10)
let ema10 = ema(closePrices, 10)
let rsi14 = rsi(closePrices, 14)
let roc10 = roc(closePrices, 10)

# Display last 5 values
printValues("SMA(10)", sma10)
printValues("EMA(10)", ema10)
printValues("RSI(14)", rsi14)
printValues("ROC(10)", roc10)

# MACD
let macdResult = macd(closePrices)
echo "\nMACD (last 3 values):"
for i in countdown(closePrices.len - 1, closePrices.len - 3):
  if not macdResult.macd[i].isNaN:
    echo &"  [{i}] MACD: {macdResult.macd[i]:.3f}, Signal: {macdResult.signal[i]:.3f}, Histogram: {macdResult.histogram[i]:.3f}"

# Bollinger Bands
let bb = bollinger(closePrices, 20, 2.0)
echo "\nBollinger Bands (last 3 values):"
for i in countdown(closePrices.len - 1, closePrices.len - 3):
  if not bb.upper[i].isNaN:
    echo &"  [{i}] Upper: {bb.upper[i]:.2f}, Middle: {bb.middle[i]:.2f}, Lower: {bb.lower[i]:.2f}"

# ============================================================================
# Example 2: Streaming Mode - Real-time indicator updates
# ============================================================================

echo "\n" & "=" .repeat(70)
echo "Example 2: Streaming Mode Indicators"
echo repeat("=", 70)

# Create streaming indicators
var smaSt = newSMA(5)
var emaSt = newEMA(5)
var rsiSt = newRSI(14)
var macdSt = newMACD()

# Simulate incoming price data
let incomingPrices = @[100.0, 102.0, 101.0, 103.0, 105.0, 104.0, 106.0, 108.0, 107.0, 110.0]

echo "\nProcessing incoming prices in real-time..."
echo "Index    Price      SMA(5)     EMA(5)     RSI(14)"
echo repeat("-", 50)

for i, price in incomingPrices:
  let smaVal = smaSt.update(price)
  let emaVal = emaSt.update(price)
  let rsiVal = rsiSt.update(price)
  
  # Format output
  let smaStr = if smaVal.isNaN: "N/A" else: &"{smaVal:.2f}"
  let emaStr = if emaVal.isNaN: "N/A" else: &"{emaVal:.2f}"
  let rsiStr = if rsiVal.isNaN: "N/A" else: &"{rsiVal:.2f}"
  
  echo &"{i:<8} ${price:<9.2f} {smaStr:<10} {emaStr:<10} {rsiStr:<10}"

# ============================================================================
# Example 3: Multi-indicator analysis
# ============================================================================

echo "\n" & "=" .repeat(70)
echo "Example 3: Multi-Indicator Analysis"
echo repeat("=", 70)

# Generate OHLCV data for ATR
var ohlcvData = newSeq[OHLCV](30)
for i in 0..<30:
  let close = 150.0 + float(i) * 0.5
  ohlcvData[i] = OHLCV(
    timestamp: 1000 + i,
    open: close - 0.5,
    high: close + 1.0,
    low: close - 1.5,
    close: close,
    volume: 1_000_000.0 + float(i) * 10_000.0
  )

let highs = ohlcvData.mapIt(it.high)
let lows = ohlcvData.mapIt(it.low)
let closes = ohlcvData.mapIt(it.close)
let volumes = ohlcvData.mapIt(it.volume)

# Calculate ATR and OBV
let atr14 = atr(highs, lows, closes, 14)
let obvVals = obv(closes, volumes)

echo "\nVolatility & Volume Analysis:"
printValues("ATR(14)", atr14, 3)
printValues("OBV", obvVals, 3)

# ============================================================================
# Example 4: Trading Signal Detection
# ============================================================================

echo "\n" & "=" .repeat(70)
echo "Example 4: Trading Signal Detection"
echo repeat("=", 70)

# RSI-based signal
let lastRSI = rsi14[^1]
if not lastRSI.isNaN:
  if lastRSI > 70:
    echo &"\n🔴 RSI Signal: OVERBOUGHT (RSI = {lastRSI:.2f})"
    echo "   Consider selling or waiting for pullback"
  elif lastRSI < 30:
    echo &"\n🟢 RSI Signal: OVERSOLD (RSI = {lastRSI:.2f})"
    echo "   Potential buying opportunity"
  else:
    echo &"\n⚪ RSI Signal: NEUTRAL (RSI = {lastRSI:.2f})"
    echo "   No strong signal"

# MACD signal
let lastMACD = macdResult.macd[^1]
let lastSignal = macdResult.signal[^1]
if not lastMACD.isNaN and not lastSignal.isNaN:
  if lastMACD > lastSignal:
    echo &"\n🟢 MACD Signal: BULLISH"
    echo &"   MACD ({lastMACD:.3f}) above Signal ({lastSignal:.3f})"
  else:
    echo &"\n🔴 MACD Signal: BEARISH"
    echo &"   MACD ({lastMACD:.3f}) below Signal ({lastSignal:.3f})"

# Bollinger Bands signal
let lastPrice = closePrices[^1]
let lastUpper = bb.upper[^1]
let lastLower = bb.lower[^1]
if not lastUpper.isNaN and not lastLower.isNaN:
  if lastPrice > lastUpper:
    echo &"\n🔴 Bollinger Band Signal: Price above upper band"
    echo "   Potentially overbought"
  elif lastPrice < lastLower:
    echo &"\n🟢 Bollinger Band Signal: Price below lower band"
    echo "   Potentially oversold"
  else:
    echo &"\n⚪ Bollinger Band Signal: Price within bands"

# ============================================================================
# Example 5: Return on Investment
# ============================================================================

echo "\n" & "=" .repeat(70)
echo "Example 5: ROI Calculation"
echo repeat("=", 70)

let initialPrice = closePrices[0]
let finalPrice = closePrices[^1]
let totalROI = roi(initialPrice, finalPrice)

echo &"\nInvestment Performance:"
echo &"  Initial Price: ${initialPrice:.2f}"
echo &"  Final Price:   ${finalPrice:.2f}"
echo &"  ROI:          {totalROI:+.2f}%"

if totalROI > 0:
  echo &"\n✅ Profitable trade: ${initialPrice:.2f} → ${finalPrice:.2f}"
else:
  echo &"\n❌ Losing trade: ${initialPrice:.2f} → ${finalPrice:.2f}"

echo "\n" & "=" .repeat(70)
echo "Examples completed successfully!"
echo repeat("=", 70)
