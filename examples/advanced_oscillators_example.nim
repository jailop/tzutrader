## Advanced Oscillators and Trend Indicators Example
##
## Demonstrates the advanced indicators using streaming architecture:
## - STOCH (Stochastic Oscillator) - Momentum oscillator
## - CCI (Commodity Channel Index) - Volatility-based oscillator
## - MFI (Money Flow Index) - Volume-weighted momentum
## - ADX (Average Directional Index) - Trend strength indicator
##
## All indicators follow O(1) streaming updates with circular buffers.

import std/[strformat, strutils]

import ../src/tzutrader/indicators

# Generate sample data with a clear trend
proc generateTrendingData(count: int): seq[tuple[high, low, close, volume: float64]] =
  result = @[]
  for i in 0..<count:
    let base = 100.0 + float64(i) * 0.5  # Uptrend
    let noise = float64(i mod 3) - 1.0   # Small oscillation
    result.add((
      high: base + 5.0 + noise,
      low: base - 5.0 + noise,
      close: base + noise,
      volume: 1000.0 + float64(i) * 10.0
    ))

echo "Phase 9.1 Indicators Demo"
echo "=" .repeat(60)
echo ""

# Create indicators
var stoch = newSTOCH(kPeriod = 14, dPeriod = 3, memSize = 5)
var cci = newCCI(period = 20, memSize = 5)
var mfi = newMFI(period = 14, memSize = 5)
var adx = newADX(period = 14, memSize = 5)

# Generate data
let data = generateTrendingData(50)

echo "Streaming data through all Phase 9.1 indicators..."
echo ""

# Process each bar
for i, bar in data:
  let stochResult = stoch.update(bar.high, bar.low, bar.close)
  let cciValue = cci.update(bar.high, bar.low, bar.close)
  let mfiValue = mfi.update(bar.high, bar.low, bar.close, bar.volume)
  let adxResult = adx.update(bar.high, bar.low, bar.close)
  
  # Print every 10th bar after warmup
  if i >= 20 and i mod 10 == 0:
    echo &"Bar {i:2d}: Close={bar.close:6.2f}"
    
    if not stochResult.k.isNaN:
      echo &"  STOCH: %K={stochResult.k:6.2f}  %D={stochResult.d:6.2f}"
      if stochResult.k > 80.0:
        echo "         → Overbought condition"
      elif stochResult.k < 20.0:
        echo "         → Oversold condition"
    
    if not cciValue.isNaN:
      echo &"  CCI:   {cciValue:6.2f}"
      if cciValue > 100.0:
        echo "         → Above +100 (overbought)"
      elif cciValue < -100.0:
        echo "         → Below -100 (oversold)"
    
    if not mfiValue.isNaN:
      echo &"  MFI:   {mfiValue:6.2f}"
      if mfiValue > 80.0:
        echo "         → Overbought (high buying pressure)"
      elif mfiValue < 20.0:
        echo "         → Oversold (high selling pressure)"
    
    if not adxResult.adx.isNaN:
      echo &"  ADX:   {adxResult.adx:6.2f}  +DI={adxResult.plusDI:6.2f}  -DI={adxResult.minusDI:6.2f}"
      if adxResult.adx > 40.0:
        echo "         → Strong trend"
      elif adxResult.adx > 20.0:
        echo "         → Moderate trend"
      else:
        echo "         → Weak/no trend"
      
      if adxResult.plusDI > adxResult.minusDI:
        echo "         → Upward direction (+DI > -DI)"
      else:
        echo "         → Downward direction (-DI > +DI)"
    
    echo ""

echo "=" .repeat(60)
echo ""
echo "Indicator Interpretations:"
echo ""
echo "STOCH (Stochastic Oscillator):"
echo "  - %K > 80: Overbought (possible reversal down)"
echo "  - %K < 20: Oversold (possible reversal up)"
echo "  - %K crossing above %D: Bullish signal"
echo "  - %K crossing below %D: Bearish signal"
echo ""
echo "CCI (Commodity Channel Index):"
echo "  - CCI > +100: Overbought zone"
echo "  - CCI < -100: Oversold zone"
echo "  - Can extend beyond ±100 (unbounded)"
echo ""
echo "MFI (Money Flow Index):"
echo "  - MFI > 80: Overbought (strong buying pressure)"
echo "  - MFI < 20: Oversold (strong selling pressure)"
echo "  - Combines price and volume for better signals"
echo ""
echo "ADX (Average Directional Movement Index):"
echo "  - ADX < 20: Weak or no trend"
echo "  - ADX 20-40: Moderate trend"
echo "  - ADX > 40: Strong trend"
echo "  - +DI > -DI: Uptrend"
echo "  - -DI > +DI: Downtrend"
echo ""
echo "Accessing Historical Values:"
echo "  - indicator[0] = current value"
echo "  - indicator[-1] = previous value"
echo "  - indicator[-2] = two bars ago"
echo "  (Requires memSize > 1 in constructor)"
