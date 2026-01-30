## Streaming Technical Indicators Example
##
## Demonstrates the streaming-only architecture for technical indicators.
## All indicators process data one bar at a time with O(1) memory usage.
##
## This example covers:
## - Basic streaming workflow
## - NaN warmup behavior
## - Multiple indicators on same data stream
## - Signal detection in real-time
## - Historical value access with circular buffers

import std/[strformat, strutils, math]

include ../src/tzutrader/core
include ../src/tzutrader/indicators

# ============================================================================
# Section 1: Basic Streaming - One Indicator at a Time
# ============================================================================

echo "=" .repeat(70)
echo "Section 1: Basic Streaming Indicators"
echo "=" .repeat(70)
echo ""

# Sample price data (e.g., stock prices)
# Generate OHLC bars for proper indicator calculation
var sampleBars: seq[tuple[open, high, low, close: float64]]
let basePrices = @[
  150.0, 152.0, 151.5, 153.0, 154.5, 155.0, 154.0, 156.0, 157.5, 158.0,
  159.0, 160.5, 161.0, 159.5, 160.0, 161.5, 163.0, 164.0, 165.5, 166.0,
  167.0, 168.5, 169.0, 170.0, 171.5, 172.0, 171.0, 172.5, 174.0, 175.0
]
for i, close in basePrices:
  let open = if i == 0: close else: basePrices[i-1]
  sampleBars.add((
    open: open,
    high: close + 1.5,
    low: close - 1.0,
    close: close
  ))

echo &"Processing {sampleBars.len} price bars..."
echo &"Price range: ${sampleBars[0].close:.2f} - ${sampleBars[^1].close:.2f}"
echo ""

# Create streaming indicators
var sma10 = newSMA(10)
var ema10 = newEMA(10)
var rsi14 = newRSI(14)

echo "Streaming prices through SMA(10), EMA(10), and RSI(14)..."
echo "Index    Price      SMA(10)    EMA(10)    RSI(14)"
echo "-" .repeat(60)

# Stream data through indicators
var smaValues, emaValues, rsiValues: seq[float64]
for i, bar in sampleBars:
  let smaVal = sma10.update(bar.close)
  let emaVal = ema10.update(bar.close)
  let rsiVal = rsi14.update(bar.open, bar.close)
  
  smaValues.add(smaVal)
  emaValues.add(emaVal)
  rsiValues.add(rsiVal)
  
  # Print every 5th value and last 3
  if i mod 5 == 0 or i >= sampleBars.len - 3:
    let smaStr = if smaVal.isNaN: "N/A" else: &"{smaVal:.2f}"
    let emaStr = if emaVal.isNaN: "N/A" else: &"{emaVal:.2f}"
    let rsiStr = if rsiVal.isNaN: "N/A" else: &"{rsiVal:.2f}"
    echo &"{i:<8} ${bar.close:<9.2f} {smaStr:<10} {emaStr:<10} {rsiStr:<10}"

echo ""
echo "Note: Indicators return NaN during warmup period until sufficient data."
echo "  - SMA(10) needs 10 bars"
echo "  - EMA(10) needs 10 bars"
echo "  - RSI(14) needs 15 bars (14 + 1 for change calculation)"

# ============================================================================
# Section 2: Multi-Bar Indicators (OHLC Data)
# ============================================================================

echo ""
echo "=" .repeat(70)
echo "Section 2: Multi-Bar Indicators (OHLC)"
echo "=" .repeat(70)
echo ""

# Generate OHLCV data
var ohlcvData = newSeq[tuple[high, low, close, volume: float64]](30)
for i in 0..<30:
  let closePrice = 100.0 + float(i) * 0.8
  ohlcvData[i] = (
    high: closePrice + 2.0,
    low: closePrice - 2.0,
    close: closePrice,
    volume: 1_000_000.0 + float(i) * 50_000.0
  )

echo "Creating indicators that use High/Low/Close/Volume data:"
echo ""

var atr14 = newATR(14, memSize = 3)
var stoch = newSTOCH(kPeriod = 14, dPeriod = 3, memSize = 3)
var mfi = newMFI(14, memSize = 3)

echo "Bar      Close      ATR(14)    STOCH %K   MFI(14)"
echo "-" .repeat(60)

for i, bar in ohlcvData:
  let atrVal = atr14.update(bar.high, bar.low, bar.close)
  let stochResult = stoch.update(bar.high, bar.low, bar.close)
  let mfiVal = mfi.update(bar.high, bar.low, bar.close, bar.volume)
  
  # Print last 5 bars
  if i >= ohlcvData.len - 5:
    let atrStr = if atrVal.isNaN: "N/A" else: &"{atrVal:.2f}"
    let stochStr = if stochResult.k.isNaN: "N/A" else: &"{stochResult.k:.2f}"
    let mfiStr = if mfiVal.isNaN: "N/A" else: &"{mfiVal:.2f}"
    echo &"{i:<8} ${bar.close:<9.2f} {atrStr:<10} {stochStr:<10} {mfiStr:<10}"

# ============================================================================
# Section 3: Complex Indicators (MACD, Bollinger Bands)
# ============================================================================

echo ""
echo "=" .repeat(70)
echo "Section 3: Complex Multi-Value Indicators"
echo "=" .repeat(70)
echo ""

# Reset for new stream
var macd = newMACD(memSize = 3)
var bb = newBollingerBands(20, 2.0, memSize = 3)

echo "MACD and Bollinger Bands require longer warmup periods."
echo ""
echo "Bar      Price      MACD       Signal     Histogram"
echo "-" .repeat(60)

var macdResults: seq[MACDResult]
for i, bar in sampleBars:
  let price = bar.close
  let macdResult = macd.update(price)
  macdResults.add(macdResult)
  
  # Print last 5 bars
  if i >= sampleBars.len - 5:
    if macdResult.macd.isNaN:
      echo &"{i:<8} ${price:<9.2f} N/A"
    else:
      echo &"{i:<8} ${price:<9.2f} {macdResult.macd:>9.3f}  {macdResult.signal:>9.3f}  {macdResult.hist:>9.3f}"

echo ""
echo "Bar      Price      BB Upper   BB Middle  BB Lower   Width"
echo "-" .repeat(70)

for i, bar in sampleBars:
  let price = bar.close
  let bbResult = bb.update(price)
  
  # Print last 5 bars
  if i >= sampleBars.len - 5:
    if bbResult.upper.isNaN:
      echo &"{i:<8} ${price:<9.2f} N/A"
    else:
      let width = bbResult.upper - bbResult.lower
      echo &"{i:<8} ${price:<9.2f} {bbResult.upper:>9.2f}  {bbResult.middle:>9.2f}  {bbResult.lower:>9.2f}  {width:>7.2f}"

# ============================================================================
# Section 4: Trading Signal Detection
# ============================================================================

echo ""
echo "=" .repeat(70)
echo "Section 4: Real-Time Signal Detection"
echo "=" .repeat(70)
echo ""

# RSI Signal Detection
let lastRSI = rsiValues[^1]
let lastPrice = sampleBars[^1].close

echo "RSI Signal Analysis:"
if not lastRSI.isNaN:
  echo &"  Current RSI: {lastRSI:.2f}"
  if lastRSI > 70:
    echo "  Status: OVERBOUGHT"
    echo "  Signal: Consider selling or waiting for pullback"
  elif lastRSI < 30:
    echo "  Status: OVERSOLD"
    echo "  Signal: Potential buying opportunity"
  else:
    echo "  Status: NEUTRAL"
    echo "  Signal: No strong signal"
else:
  echo "  Insufficient data for RSI calculation"

echo ""

# MACD Signal Detection
let lastMACD = macdResults[^1]
echo "MACD Signal Analysis:"
if not lastMACD.macd.isNaN and not lastMACD.signal.isNaN:
  echo &"  MACD Line: {lastMACD.macd:.3f}"
  echo &"  Signal Line: {lastMACD.signal:.3f}"
  echo &"  Histogram: {lastMACD.hist:.3f}"
  if lastMACD.macd > lastMACD.signal:
    echo "  Status: BULLISH (MACD above Signal)"
    echo "  Signal: Upward momentum"
  else:
    echo "  Status: BEARISH (MACD below Signal)"
    echo "  Signal: Downward momentum"
  
  # Check for crossover using historical values
  if macdResults.len >= 2:
    let prevMACD = macdResults[^2]
    if not prevMACD.macd.isNaN and not prevMACD.signal.isNaN:
      if prevMACD.macd <= prevMACD.signal and lastMACD.macd > lastMACD.signal:
        echo "  CROSSOVER: Bullish crossover detected!"
      elif prevMACD.macd >= prevMACD.signal and lastMACD.macd < lastMACD.signal:
        echo "  CROSSOVER: Bearish crossover detected!"
else:
  echo "  Insufficient data for MACD calculation"

echo ""

# Bollinger Bands Signal
let lastBB = bb[0]  # Access current value from circular buffer
echo "Bollinger Bands Signal Analysis:"
if not lastBB.upper.isNaN:
  echo &"  Price: ${lastPrice:.2f}"
  echo &"  Upper Band: ${lastBB.upper:.2f}"
  echo &"  Middle Band: ${lastBB.middle:.2f}"
  echo &"  Lower Band: ${lastBB.lower:.2f}"
  
  let bandWidth = lastBB.upper - lastBB.lower
  echo &"  Band Width: {bandWidth:.2f}"
  
  if lastPrice > lastBB.upper:
    echo "  Status: Price above upper band"
    echo "  Signal: Potentially overbought, may reverse"
  elif lastPrice < lastBB.lower:
    echo "  Status: Price below lower band"
    echo "  Signal: Potentially oversold, may reverse"
  else:
    let position = (lastPrice - lastBB.lower) / bandWidth * 100.0
    echo &"  Status: Price within bands ({position:.1f}% of width)"
    echo "  Signal: Normal trading range"
else:
  echo "  Insufficient data for Bollinger Bands calculation"

# ============================================================================
# Section 5: Circular Buffer Access (Historical Values)
# ============================================================================

echo ""
echo "=" .repeat(70)
echo "Section 5: Accessing Historical Values"
echo "=" .repeat(70)
echo ""

# Create indicator with larger memory buffer
var sma5 = newSMA(5, memSize = 10)  # Keep last 10 computed values

# Feed some data
let testPrices = @[10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0, 19.0, 20.0]
for price in testPrices:
  discard sma5.update(price)

echo "SMA(5) with memSize=10 allows historical value access:"
echo ""
echo "Index    Offset     Value"
echo "-" .repeat(35)
for i in 0..5:
  let val = sma5[-i]
  if val.isNaN:
    echo &"{i:<8} [{-i:<2}]       N/A"
  else:
    echo &"{i:<8} [{-i:<2}]       {val:.2f}"

echo ""
echo "Explanation:"
echo "  - sma5[0]  = current value (most recent)"
echo "  - sma5[-1] = previous value (1 bar ago)"
echo "  - sma5[-2] = value from 2 bars ago"
echo "  - etc."
echo ""
echo "This is useful for detecting crossovers and patterns:"
echo "  if sma5[0] > ema5[0] and sma5[-1] <= ema5[-1]:"
echo "    # SMA crossed above EMA (Golden Cross)"

# ============================================================================
# Section 6: Volume-Weighted Indicators
# ============================================================================

echo ""
echo "=" .repeat(70)
echo "Section 6: Volume-Weighted Indicators"
echo "=" .repeat(70)
echo ""

var obv = newOBV(memSize = 5)

echo "On-Balance Volume (OBV) - cumulative volume flow:"
echo ""
echo "Bar      Close      Volume         OBV"
echo "-" .repeat(50)

for i in 0..<min(10, ohlcvData.len):
  let bar = ohlcvData[i]
  let obvVal = obv.update(bar.close, bar.volume)
  
  if i >= 5:  # Skip warmup
    echo &"{i:<8} ${bar.close:<9.2f} {bar.volume:>12.0f}  {obvVal:>12.0f}"

echo ""
echo "OBV Interpretation:"
echo "  - Rising OBV = Accumulation (buying pressure)"
echo "  - Falling OBV = Distribution (selling pressure)"
echo "  - OBV divergence from price can signal reversals"

# ============================================================================
# Section 7: Rate of Change & Momentum
# ============================================================================

echo ""
echo "=" .repeat(70)
echo "Section 7: Momentum & Rate of Change"
echo "=" .repeat(70)
echo ""

var roc10 = newROC(10, memSize = 3)
var roi = newROI(memSize = 3)

echo "ROC(10) and ROI calculation:"
echo ""
echo "Bar      Price      ROC(10)%   ROI%"
echo "-" .repeat(45)

for i, bar in sampleBars:
  let price = bar.close
  let rocVal = roc10.update(price)
  let roiVal = roi.update(price)
  
  if i >= sampleBars.len - 5:
    let rocStr = if rocVal.isNaN: "N/A" else: &"{rocVal:+.2f}%"
    let roiStr = if roiVal.isNaN: "N/A" else: &"{roiVal:+.2f}%"
    echo &"{i:<8} ${price:<9.2f} {rocStr:<10} {roiStr:<10}"

echo ""
echo "Difference between ROC and ROI:"
echo "  - ROC(10): Percentage change from 10 bars ago"
echo "  - ROI: Percentage change from first value (initial investment)"

# ============================================================================
# Summary
# ============================================================================

echo ""
echo "=" .repeat(70)
echo "Summary: TzuTrader Streaming Architecture"
echo "=" .repeat(70)
echo ""
echo "Key Principles:"
echo ""
echo "1. Streaming-Only Design:"
echo "   - Process one data point at a time"
echo "   - O(1) memory per indicator (constant)"
echo "   - No batch processing, no historical data storage"
echo ""
echo "2. Indicator Creation:"
echo "   - var myIndicator = newXXX(period, memSize=1)"
echo "   - memSize controls circular buffer size for historical access"
echo ""
echo "3. Update Pattern:"
echo "   - let value = indicator.update(price)"
echo "   - let value = indicator.update(high, low, close)  # Multi-bar"
echo "   - Returns NaN during warmup period"
echo ""
echo "4. Composability:"
echo "   - Indicators can use other indicators"
echo "   - Example: MACD uses EMA, Bollinger Bands use SMA + STDEV"
echo "   - Each maintains its own circular buffer"
echo ""
echo "5. Historical Access:"
echo "   - indicator[0]  = current value"
echo "   - indicator[-1] = previous value"
echo "   - indicator[-N] = N bars ago (if memSize allows)"
echo ""
echo "6. Memory Efficiency:"
echo "   - Only computed values stored (not raw prices)"
echo "   - Circular buffers reuse memory"
echo "   - Can run indefinitely without memory growth"
echo ""
echo "Available Indicators (15 total):"
echo "  Moving Averages: MA/SMA, EMA, MV, STDEV"
echo "  Momentum: ROI, RSI, ROC"
echo "  Oscillators: STOCH, CCI, MFI"
echo "  Trend: MACD, ADX"
echo "  Volatility: ATR, BollingerBands"
echo "  Volume: OBV"
echo ""
echo "=" .repeat(70)
