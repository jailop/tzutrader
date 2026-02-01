## Advanced Moving Averages Example
##
## Demonstrates Phase 9.2 indicators - advanced moving averages with different
## lag characteristics and adaptive behavior:
## - TRIMA (Triangular Moving Average) - Double-smoothed, minimal noise
## - DEMA (Double Exponential Moving Average) - Reduced lag
## - TEMA (Triple Exponential Moving Average) - Minimal lag
## - KAMA (Kaufman Adaptive Moving Average) - Adapts to market conditions
##
## Compares lag characteristics and demonstrates when to use each type.

import std/[strformat, strutils, math]

import ../src/tzutrader/indicators

# ============================================================================
# Section 1: Basic Moving Average Comparison
# ============================================================================

echo "=" .repeat(70)
echo "Section 1: Moving Average Lag Comparison"
echo "=" .repeat(70)
echo ""

# Create all moving average types with same period
var sma = newSMA(10)
var ema = newEMA(10)
var trima = newTRIMA(10)
var dema = newDEMA(10)
var tema = newTEMA(10)

# Generate trending data to show lag differences
let trendingData = @[
  100.0, 102.0, 104.0, 106.0, 108.0, 110.0, 112.0, 114.0, 116.0, 118.0,
  120.0, 122.0, 124.0, 126.0, 128.0, 130.0, 132.0, 134.0, 136.0, 138.0,
  140.0, 142.0, 144.0, 146.0, 148.0, 150.0
]

echo "Trending market (consistent uptrend):"
echo "Bar    Price      SMA(10)    EMA(10)    TRIMA(10)  DEMA(10)   TEMA(10)"
echo "-" .repeat(80)

for i, price in trendingData:
  let smaVal = sma.update(price)
  let emaVal = ema.update(price)
  let trimaVal = trima.update(price)
  let demaVal = dema.update(price)
  let temaVal = tema.update(price)
  
  # Print every 5th bar and last 3
  if i mod 5 == 0 or i >= trendingData.len - 3:
    let smaStr = if smaVal.isNaN: "N/A" else: &"{smaVal:>7.2f}"
    let emaStr = if emaVal.isNaN: "N/A" else: &"{emaVal:>7.2f}"
    let trimaStr = if trimaVal.isNaN: "N/A" else: &"{trimaVal:>7.2f}"
    let demaStr = if demaVal.isNaN: "N/A" else: &"{demaVal:>7.2f}"
    let temaStr = if temaVal.isNaN: "N/A" else: &"{temaVal:>7.2f}"
    echo &"{i:<6} ${price:<9.2f} {smaStr}  {emaStr}  {trimaStr}  {demaStr}  {temaStr}"

echo ""
echo "Lag characteristics in uptrend:"
echo "  - SMA: Highest lag (slowest to follow price)"
echo "  - TRIMA: Very smooth but high lag"
echo "  - EMA: Moderate lag"
echo "  - DEMA: Lower lag than EMA"
echo "  - TEMA: Minimal lag (closest to price)"

# ============================================================================
# Section 2: Response to Sudden Price Change
# ============================================================================

echo ""
echo "=" .repeat(70)
echo "Section 2: Response to Sudden Price Changes"
echo "=" .repeat(70)
echo ""

# Reset indicators
sma = newSMA(10)
ema = newEMA(10)
dema = newDEMA(10)
tema = newTEMA(10)

# Stable price then sudden jump
let jumpData = @[
  100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0,
  100.0, 100.0, 150.0,  # Sudden 50% jump
  150.0, 150.0, 150.0
]

echo "Price with sudden jump (100 -> 150):"
echo "Bar    Price      SMA(10)    EMA(10)    DEMA(10)   TEMA(10)   Gap%"
echo "-" .repeat(75)

for i, price in jumpData:
  let smaVal = sma.update(price)
  let emaVal = ema.update(price)
  let demaVal = dema.update(price)
  let temaVal = tema.update(price)
  
  # Show around the jump
  if i >= 9:
    var gaps: string
    if not temaVal.isNaN:
      let temaGap = abs(price - temaVal) / price * 100.0
      gaps = &"{temaGap:>5.1f}%"
    else:
      gaps = "N/A"
    
    let smaStr = if smaVal.isNaN: "N/A" else: &"{smaVal:>7.2f}"
    let emaStr = if emaVal.isNaN: "N/A" else: &"{emaVal:>7.2f}"
    let demaStr = if demaVal.isNaN: "N/A" else: &"{demaVal:>7.2f}"
    let temaStr = if temaVal.isNaN: "N/A" else: &"{temaVal:>7.2f}"
    echo &"{i:<6} ${price:<9.2f} {smaStr}  {emaStr}  {demaStr}  {temaStr}  {gaps}"

echo ""
echo "Response speed (lower gap = faster response):"
echo "  - TEMA: Fastest to follow price change"
echo "  - DEMA: Fast response"
echo "  - EMA: Moderate response"
echo "  - SMA: Slowest response"

# ============================================================================
# Section 3: Adaptive KAMA in Different Market Conditions
# ============================================================================

echo ""
echo "=" .repeat(70)
echo "Section 3: KAMA - Adaptive Behavior"
echo "=" .repeat(70)
echo ""

echo "3a. KAMA in Trending Market:"
echo "-" .repeat(40)

var kamaTrend = newKAMA(period = 10, fastPeriod = 2, slowPeriod = 30)
var emaTrend = newEMA(10)

# Strong trend
for i in 0..<20:
  let price = 100.0 + float64(i) * 3.0  # Strong uptrend
  discard kamaTrend.update(price)
  discard emaTrend.update(price)

echo "Bar    Price      KAMA(10)   EMA(10)"
echo "-" .repeat(45)
for i in 0..<5:
  let price = 100.0 + float64(20 + i) * 3.0
  let kamaVal = kamaTrend.update(price)
  let emaVal = emaTrend.update(price)
  
  let kamaStr = if kamaVal.isNaN: "N/A" else: &"{kamaVal:>7.2f}"
  let emaStr = if emaVal.isNaN: "N/A" else: &"{emaVal:>7.2f}"
  echo &"{20 + i:<6} ${price:<9.2f} {kamaStr}  {emaStr}"

echo ""
echo "In trending market: KAMA behaves like fast EMA (responsive)"
echo ""

echo "3b. KAMA in Choppy/Sideways Market:"
echo "-" .repeat(40)

var kamaChop = newKAMA(period = 10, fastPeriod = 2, slowPeriod = 30)
var emaChop = newEMA(10)

# Choppy sideways movement
let choppyData = @[
  100.0, 103.0, 98.0, 102.0, 97.0, 104.0, 99.0, 101.0, 96.0, 103.0,
  100.0, 102.0, 98.0, 101.0, 99.0, 103.0, 97.0, 102.0, 100.0, 101.0
]

for price in choppyData:
  discard kamaChop.update(price)
  discard emaChop.update(price)

echo "Bar    Price      KAMA(10)   EMA(10)    KAMA Smoother?"
echo "-" .repeat(60)

for i in 0..<5:
  let price = choppyData[choppyData.len - 5 + i]
  let kamaVal = kamaChop.update(price)
  let emaVal = emaChop.update(price)
  
  let kamaStr = if kamaVal.isNaN: "N/A" else: &"{kamaVal:>7.2f}"
  let emaStr = if emaVal.isNaN: "N/A" else: &"{emaVal:>7.2f}"
  
  var smoother = ""
  if not kamaVal.isNaN and not emaVal.isNaN:
    let kamaDeviation = abs(price - kamaVal)
    let emaDeviation = abs(price - emaVal)
    if kamaDeviation < emaDeviation:
      smoother = "Yes (more stable)"
    else:
      smoother = "Similar"
  
  echo &"{20 + i:<6} ${price:<9.2f} {kamaStr}  {emaStr}  {smoother}"

echo ""
echo "In choppy market: KAMA is smoother (filters noise)"
echo "  - High efficiency = trending (KAMA fast)"
echo "  - Low efficiency = choppy (KAMA slow)"

# ============================================================================
# Section 4: Practical Usage Guidelines
# ============================================================================

echo ""
echo "=" .repeat(70)
echo "Section 4: When to Use Each Moving Average"
echo "=" .repeat(70)
echo ""

echo "SMA (Simple Moving Average):"
echo "  Use when: Need stable, easy-to-understand average"
echo "  Best for: Long-term trend identification, support/resistance"
echo "  Pros: Simple, stable"
echo "  Cons: Highest lag, equal weight to all data"
echo ""

echo "EMA (Exponential Moving Average):"
echo "  Use when: Need balance between responsiveness and stability"
echo "  Best for: General trend following, most common choice"
echo "  Pros: More weight to recent data, faster than SMA"
echo "  Cons: Still has moderate lag"
echo ""

echo "TRIMA (Triangular Moving Average):"
echo "  Use when: Need maximum smoothing to filter noise"
echo "  Best for: Very noisy markets, identifying underlying trend"
echo "  Pros: Very smooth, filters noise well"
echo "  Cons: Highest lag, slow to react"
echo ""

echo "DEMA (Double Exponential Moving Average):"
echo "  Use when: Need faster response than EMA"
echo "  Best for: Short to medium-term trading, catching trend changes"
echo "  Pros: Less lag than EMA, more responsive"
echo "  Cons: Can be whipsawed in choppy markets"
echo ""

echo "TEMA (Triple Exponential Moving Average):"
echo "  Use when: Need minimal lag for quick entries/exits"
echo "  Best for: Short-term trading, scalping, quick trend changes"
echo "  Pros: Minimal lag, very responsive"
echo "  Cons: Most sensitive to noise, can give false signals"
echo ""

echo "KAMA (Kaufman Adaptive Moving Average):"
echo "  Use when: Market conditions vary (trending vs. choppy)"
echo "  Best for: All market conditions, adaptive strategies"
echo "  Pros: Automatically adapts, responsive in trends, stable in chop"
echo "  Cons: More complex, needs proper parameter tuning"

# ============================================================================
# Section 5: Crossover Strategy Comparison
# ============================================================================

echo ""
echo "=" .repeat(70)
echo "Section 5: MA Crossover Strategies"
echo "=" .repeat(70)
echo ""

# Fast and slow MAs of different types
var fastEMA = newEMA(5)
var slowEMA = newEMA(20)
var fastDEMA = newDEMA(5)
var slowDEMA = newDEMA(20)

let crossoverData = @[
  100.0, 102.0, 104.0, 103.0, 105.0, 107.0, 106.0, 108.0, 110.0, 112.0,
  114.0, 116.0, 118.0, 120.0, 122.0, 124.0, 126.0, 128.0, 130.0, 132.0,
  134.0, 136.0, 138.0, 140.0, 142.0
]

echo "Comparing EMA(5/20) vs DEMA(5/20) crossovers:"
echo "Bar    Price      Fast EMA   Slow EMA   EMA Signal | Fast DEMA  Slow DEMA  DEMA Signal"
echo "-" .repeat(95)

var prevEMAFast, prevEMASlow, prevDEMAFast, prevDEMASlow: float64

for i, price in crossoverData:
  let emaF = fastEMA.update(price)
  let emaS = slowEMA.update(price)
  let demaF = fastDEMA.update(price)
  let demaS = slowDEMA.update(price)
  
  if i >= 15:  # Show last part
    var emaSignal = "    -"
    var demaSignal = "    -"
    
    if not (prevEMAFast.isNaN or prevEMASlow.isNaN or emaF.isNaN or emaS.isNaN):
      if prevEMAFast <= prevEMASlow and emaF > emaS:
        emaSignal = "  BUY"
      elif prevEMAFast >= prevEMASlow and emaF < emaS:
        emaSignal = " SELL"
    
    if not (prevDEMAFast.isNaN or prevDEMASlow.isNaN or demaF.isNaN or demaS.isNaN):
      if prevDEMAFast <= prevDEMASlow and demaF > demaS:
        demaSignal = "  BUY"
      elif prevDEMAFast >= prevDEMASlow and demaF < demaS:
        demaSignal = " SELL"
    
    let emaFStr = if emaF.isNaN: "N/A" else: &"{emaF:>7.2f}"
    let emaSStr = if emaS.isNaN: "N/A" else: &"{emaS:>7.2f}"
    let demaFStr = if demaF.isNaN: "N/A" else: &"{demaF:>7.2f}"
    let demaSStr = if demaS.isNaN: "N/A" else: &"{demaS:>7.2f}"
    
    echo &"{i:<6} ${price:<9.2f} {emaFStr}  {emaSStr}  {emaSignal}    | {demaFStr}  {demaSStr}  {demaSignal}"
  
  prevEMAFast = emaF
  prevEMASlow = emaS
  prevDEMAFast = demaF
  prevDEMASlow = demaS

echo ""
echo "DEMA crossovers typically occur earlier than EMA crossovers"
echo "  - Pro: Earlier entry/exit signals"
echo "  - Con: More prone to false signals"

# ============================================================================
# Summary
# ============================================================================

echo ""
echo "=" .repeat(70)
echo "Summary: Phase 9.2 Advanced Moving Averages"
echo "=" .repeat(70)
echo ""

echo "Implemented Indicators (4 new):"
echo "  1. TRIMA - Triangular MA (double-smoothed)"
echo "  2. DEMA - Double Exponential MA (reduced lag)"
echo "  3. TEMA - Triple Exponential MA (minimal lag)"
echo "  4. KAMA - Kaufman Adaptive MA (market-adaptive)"
echo ""

echo "Total Indicators Now: 19 out of 25 (76% complete)"
echo ""

echo "Key Takeaways:"
echo "  • Lag decreases: SMA > TRIMA > EMA > DEMA > TEMA"
echo "  • Smoothing increases: TEMA < DEMA < EMA < SMA < TRIMA"
echo "  • KAMA adapts: Fast in trends, slow in chop"
echo "  • Choose based on: market conditions, trading timeframe, and risk tolerance"
echo ""

echo "=" .repeat(70)
