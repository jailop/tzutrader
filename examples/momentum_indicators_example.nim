## Additional Momentum Indicators Example
##
## Demonstrates Phase 9.4 indicators - advanced momentum measurements:
## - STOCHRSI (Stochastic RSI) - More sensitive overbought/oversold indicator
## - PPO (Percentage Price Oscillator) - MACD as percentage for cross-asset comparison
## - CMO (Chande Momentum Oscillator) - Alternative to RSI using sums instead of averages
## - MOM (Momentum) - Simple but effective current vs N periods ago
##
## Shows how these momentum indicators complement each other for trading signals.

import std/[strformat, strutils, math]

import ../src/tzutrader/indicators

# ============================================================================
# Section 1: Momentum (MOM) - The Foundation
# ============================================================================

echo "=" .repeat(70)
echo "Section 1: MOM (Momentum) - Current Price vs N Periods Ago"
echo "=" .repeat(70)
echo ""

echo "Momentum is the simplest momentum indicator: Current - Price[N]"
echo "Positive = upward momentum, Negative = downward momentum"
echo ""

# Create momentum indicators with different periods
var mom5 = newMOM(period = 5)
var mom10 = newMOM(period = 10)

# Generate trending then ranging data
let trendData = @[
  100.0, 102.0, 104.0, 106.0, 108.0,  # Uptrend
  110.0, 112.0, 114.0, 116.0, 118.0,
  120.0, 122.0, 124.0, 126.0, 128.0,
  130.0, 130.5, 131.0, 130.5, 130.0,  # Start ranging
  130.5, 129.5, 130.0, 130.5, 129.5,
  130.0, 129.0, 131.0, 130.0, 129.5
]

echo "Bar    Price     MOM(5)    MOM(10)   Interpretation"
echo "-" .repeat(70)

for i, price in trendData:
  let mom5Val = mom5.update(price)
  let mom10Val = mom10.update(price)
  
  var interp = ""
  if classify(mom5Val) != fcNan:
    if mom5Val > 5.0:
      interp = "Strong uptrend"
    elif mom5Val > 0.0:
      interp = "Weak uptrend"
    elif mom5Val > -5.0:
      interp = "Ranging/Weak down"
    else:
      interp = "Downtrend"
  else:
    interp = "Warming up..."
  
  if classify(mom5Val) != fcNan:
    echo &"{i+1:<6} {price:<9.2f} {mom5Val:>7.2f}   {mom10Val:>7.2f}    {interp}"

echo ""
echo "Key Insights:"
echo "  • Bars 1-15: Positive momentum (10-12 points per period)"
echo "  • Bars 16-30: Near-zero momentum (ranging market)"
echo "  • Longer periods (MOM10) smooth out noise vs shorter (MOM5)"
echo "  • Simple but effective - foundation for ROC and other indicators"
echo ""

# ============================================================================
# Section 2: CMO (Chande Momentum Oscillator)
# ============================================================================

echo "=" .repeat(70)
echo "Section 2: CMO - Momentum Using Sum of Gains/Losses"
echo "=" .repeat(70)
echo ""

echo "CMO = ((Sum Gains - Sum Losses) / (Sum Gains + Sum Losses)) * 100"
echo "Range: -100 to +100 (vs RSI 0 to 100)"
echo "Similar to RSI but uses sums instead of averages"
echo ""

# Create CMO and RSI for comparison
var cmo = newCMO(period = 14)
var rsi = newRSI(period = 14)

# Generate data with clear phases
type PriceBar = tuple[open, close: float64]

let cmoData: seq[PriceBar] = @[
  # Phase 1: Uptrend (bars 1-10)
  (100.0, 102.0), (102.0, 104.0), (104.0, 106.0), (106.0, 108.0), (108.0, 110.0),
  (110.0, 112.0), (112.0, 114.0), (114.0, 116.0), (116.0, 118.0), (118.0, 120.0),
  # Phase 2: Ranging (bars 11-15)
  (120.0, 119.0), (119.0, 121.0), (121.0, 120.0), (120.0, 121.0), (121.0, 120.0),
  # Phase 3: Downtrend (bars 16-25)
  (120.0, 118.0), (118.0, 116.0), (116.0, 114.0), (114.0, 112.0), (112.0, 110.0),
  (110.0, 108.0), (108.0, 106.0), (106.0, 104.0), (104.0, 102.0), (102.0, 100.0)
]

echo "Bar    Close     CMO       RSI      Phase"
echo "-" .repeat(70)

for i, bar in cmoData:
  let cmoVal = cmo.update(bar.close)
  let rsiVal = rsi.update(bar.open, bar.close)
  
  var phase = ""
  if i < 10:
    phase = "Uptrend"
  elif i < 15:
    phase = "Ranging"
  else:
    phase = "Downtrend"
  
  if classify(cmoVal) != fcNan:
    echo &"{i+1:<6} {bar.close:<9.2f} {cmoVal:>7.1f}   {rsiVal:>7.1f}    {phase}"

echo ""
echo "Key Insights:"
echo "  • CMO range: -100 to +100 (symmetric around 0)"
echo "  • RSI range: 0 to 100 (50 is neutral)"
echo "  • CMO > +50 = strong bullish, < -50 = strong bearish"
echo "  • More sensitive than RSI to momentum changes"
echo "  • Both show similar trends but CMO centered at 0"
echo ""

# ============================================================================
# Section 3: PPO (Percentage Price Oscillator)
# ============================================================================

echo "=" .repeat(70)
echo "Section 3: PPO - MACD as Percentage"
echo "=" .repeat(70)
echo ""

echo "PPO = ((Fast EMA - Slow EMA) / Slow EMA) * 100"
echo "Like MACD but expressed as percentage - better for cross-asset comparison"
echo ""

# Compare PPO and MACD on different price levels
type Asset = object
  name: string
  prices: seq[float64]

let lowPriced = Asset(
  name: "Stock A ($10)",
  prices: @[10.0, 10.5, 11.0, 11.5, 12.0, 12.5, 13.0, 13.5, 14.0, 14.5,
            15.0, 15.5, 16.0, 16.5, 17.0, 17.5, 18.0, 18.5, 19.0, 19.5,
            20.0, 20.2, 20.4, 20.6, 20.8, 21.0, 21.0, 21.0, 21.0, 21.0]
)

let highPriced = Asset(
  name: "Stock B ($200)",
  prices: @[200.0, 210.0, 220.0, 230.0, 240.0, 250.0, 260.0, 270.0, 280.0, 290.0,
            300.0, 310.0, 320.0, 330.0, 340.0, 350.0, 360.0, 370.0, 380.0, 390.0,
            400.0, 404.0, 408.0, 412.0, 416.0, 420.0, 420.0, 420.0, 420.0, 420.0]
)

var ppoA = newPPO(fastPeriod = 5, slowPeriod = 10, signalPeriod = 3)
var macdA = newMACD(shortPeriod = 5, longPeriod = 10, diffPeriod = 3)

var ppoB = newPPO(fastPeriod = 5, slowPeriod = 10, signalPeriod = 3)
var macdB = newMACD(shortPeriod = 5, longPeriod = 10, diffPeriod = 3)

echo "Stock A (Low Priced):              Stock B (High Priced):"
echo "Price   MACD    PPO      |      Price   MACD     PPO"
echo "-" .repeat(70)

for i in 0..<lowPriced.prices.len:
  let priceA = lowPriced.prices[i]
  let priceB = highPriced.prices[i]
  
  let macdValA = macdA.update(priceA)
  let ppoValA = ppoA.update(priceA)
  
  let macdValB = macdB.update(priceB)
  let ppoValB = ppoB.update(priceB)
  
  if i >= 10 and i mod 5 == 0:
    echo &"{priceA:<7.2f} {macdValA.macd:>6.2f}  {ppoValA.ppo:>6.2f}%  |  {priceB:<7.2f} {macdValB.macd:>7.2f}  {ppoValB.ppo:>6.2f}%"

echo ""
echo "Key Insights:"
echo "  • MACD absolute values differ (~1.0 vs ~20.0) due to price difference"
echo "  • PPO values are similar (~5%) - comparable momentum!"
echo "  • PPO histogram works like MACD histogram for signals"
echo "  • Better for: portfolio comparison, multi-asset strategies"
echo ""

# ============================================================================
# Section 4: StochRSI (Stochastic RSI)
# ============================================================================

echo "=" .repeat(70)
echo "Section 4: STOCHRSI - Stochastic Applied to RSI"
echo "=" .repeat(70)
echo ""

echo "StochRSI applies Stochastic oscillator formula to RSI values"
echo "More sensitive than RSI - useful for finding oversold in uptrends"
echo ""

# Create both indicators
var stochRsi = newSTOCHRSI(rsiPeriod = 14, period = 14, kPeriod = 3, dPeriod = 3)
var standardRsi = newRSI(period = 14)

# Generate data with clear overbought/oversold periods
let stochData: seq[PriceBar] = @[
  # Uptrend to establish baseline
  (100.0, 102.0), (102.0, 104.0), (104.0, 106.0), (106.0, 108.0), (108.0, 110.0),
  (110.0, 112.0), (112.0, 114.0), (114.0, 116.0), (116.0, 118.0), (118.0, 120.0),
  (120.0, 122.0), (122.0, 124.0), (124.0, 126.0), (126.0, 128.0), (128.0, 130.0),
  # Pullback in uptrend (RSI stays high, StochRSI drops)
  (130.0, 129.0), (129.0, 128.0), (128.0, 127.0), (127.0, 126.0), (126.0, 125.0),
  # Resume uptrend
  (125.0, 127.0), (127.0, 129.0), (129.0, 131.0), (131.0, 133.0), (133.0, 135.0),
  (135.0, 137.0), (137.0, 139.0), (139.0, 141.0), (141.0, 143.0), (143.0, 145.0),
  # Another pullback
  (145.0, 144.0), (144.0, 143.0), (143.0, 142.0), (142.0, 141.0), (141.0, 140.0),
  # Final push
  (140.0, 142.0), (142.0, 144.0), (144.0, 146.0), (146.0, 148.0), (148.0, 150.0)
]

echo "Bar    Close     RSI      StochK   StochD   Signal"
echo "-" .repeat(70)

for i, bar in stochData:
  let rsiVal = standardRsi.update(bar.open, bar.close)
  let stochVal = stochRsi.update(bar.open, bar.close)
  
  var signal = ""
  if classify(stochVal.k) != fcNan:
    if stochVal.k < 20:
      signal = "OVERSOLD - Buy opportunity"
    elif stochVal.k > 80:
      signal = "OVERBOUGHT - Take profits"
    elif stochVal.k < 30 and rsiVal > 50:
      signal = "Pullback in uptrend - Buy"
    else:
      signal = ""
  
  if i >= 15 and i mod 5 == 0:
    if classify(stochVal.k) != fcNan:
      echo &"{i+1:<6} {bar.close:<9.2f} {rsiVal:>6.1f}   {stochVal.k:>6.1f}   {stochVal.d:>6.1f}    {signal}"

echo ""
echo "Key Insights:"
echo "  • StochRSI more sensitive than RSI (oscillates faster)"
echo "  • Good for finding oversold in strong uptrends (RSI stays >50)"
echo "  • Can give false signals - use with trend confirmation"
echo "  • %K crosses above %D = buy signal, below = sell signal"
echo ""

# ============================================================================
# Section 5: Combining All Four Indicators
# ============================================================================

echo "=" .repeat(70)
echo "Section 5: Combined Momentum Analysis"
echo "=" .repeat(70)
echo ""

echo "Using all 4 momentum indicators together for comprehensive signals"
echo ""

# Create all indicators
var comboMOM = newMOM(period = 10)
var comboCMO = newCMO(period = 14)
var comboPPO = newPPO(fastPeriod = 12, slowPeriod = 26, signalPeriod = 9)
var comboStochRSI = newSTOCHRSI(rsiPeriod = 14, period = 14, kPeriod = 3, dPeriod = 3)

# Generate complete market cycle
let cycleData: seq[PriceBar] = @[
  # Accumulation phase (bars 1-10)
  (100.0, 100.5), (100.5, 101.0), (101.0, 101.5), (101.5, 102.0), (102.0, 102.5),
  (102.5, 103.0), (103.0, 103.5), (103.5, 104.0), (104.0, 104.5), (104.5, 105.0),
  # Markup phase (bars 11-25)
  (105.0, 107.0), (107.0, 109.0), (109.0, 111.0), (111.0, 113.0), (113.0, 115.0),
  (115.0, 117.0), (117.0, 119.0), (119.0, 121.0), (121.0, 123.0), (123.0, 125.0),
  (125.0, 127.0), (127.0, 129.0), (129.0, 131.0), (131.0, 133.0), (133.0, 135.0),
  # Distribution phase (bars 26-35)
  (135.0, 135.5), (135.5, 135.0), (135.0, 136.0), (136.0, 135.5), (135.5, 136.5),
  (136.5, 136.0), (136.0, 136.5), (136.5, 135.5), (135.5, 136.0), (136.0, 135.0),
  # Markdown phase (bars 36-45)
  (135.0, 133.0), (133.0, 131.0), (131.0, 129.0), (129.0, 127.0), (127.0, 125.0),
  (125.0, 123.0), (123.0, 121.0), (121.0, 119.0), (119.0, 117.0), (117.0, 115.0)
]

echo "Trading Signals from Combined Analysis:"
echo ""
echo "Bar   Price    MOM     CMO    PPO%   StochK | Phase & Signal"
echo "-" .repeat(75)

for i, bar in cycleData:
  let momVal = comboMOM.update(bar.close)
  let cmoVal = comboCMO.update(bar.close)
  let ppoVal = comboPPO.update(bar.close)
  let stochVal = comboStochRSI.update(bar.open, bar.close)
  
  var phase = ""
  var signal = ""
  
  if i < 10:
    phase = "ACCUMULATION"
    if classify(momVal) != fcNan and momVal > 0 and cmoVal > 0:
      signal = "→ Building position"
  elif i < 25:
    phase = "MARKUP"
    if classify(stochVal.k) != fcNan:
      if stochVal.k < 30:
        signal = "→ Buy the dip"
      elif stochVal.k > 70 and ppoVal.ppo > 3.0:
        signal = "→ Ride the trend"
  elif i < 35:
    phase = "DISTRIBUTION"
    if classify(momVal) != fcNan and momVal < 1.0 and cmoVal < 10.0:
      signal = "→ WARNING: Momentum fading"
  else:
    phase = "MARKDOWN"
    if classify(stochVal.k) != fcNan and stochVal.k > 70:
      signal = "→ Bear rally - avoid"
    elif ppoVal.ppo < -2.0:
      signal = "→ Confirmed downtrend"
  
  if i >= 10 and i mod 5 == 0:
    if classify(momVal) != fcNan:
      echo &"{i+1:<5} {bar.close:<7.2f} {momVal:>6.1f}  {cmoVal:>6.1f}  {ppoVal.ppo:>6.2f}  {stochVal.k:>6.1f} | {phase} {signal}"

echo ""
echo "=" .repeat(70)
echo "Trading Strategy Insights"
echo "=" .repeat(70)
echo ""

echo "1. ENTRY SIGNALS (All must confirm):"
echo "   • MOM > 0 (positive momentum)"
echo "   • CMO > 0 (more gains than losses)"
echo "   • PPO > 0 (fast EMA above slow)"
echo "   • StochRSI 20-40 (pullback in uptrend)"
echo ""

echo "2. STRONG TREND (Hold position):"
echo "   • MOM increasing"
echo "   • CMO > +50"
echo "   • PPO histogram expanding"
echo "   • StochRSI 40-80 (healthy range)"
echo ""

echo "3. WARNING SIGNS (Tighten stops):"
echo "   • MOM flattening or declining"
echo "   • CMO dropping below +20"
echo "   • PPO histogram shrinking"
echo "   • StochRSI > 80 (overbought)"
echo ""

echo "4. EXIT SIGNALS (Take profits/cut losses):"
echo "   • MOM < 0 (momentum reversal)"
echo "   • CMO < -20 (more losses than gains)"
echo "   • PPO crosses below signal"
echo "   • StochRSI %K crosses below %D"
echo ""

echo "5. INDICATOR STRENGTHS:"
echo "   • MOM: Simple, objective momentum direction"
echo "   • CMO: Symmetric scale, good for extremes"
echo "   • PPO: Cross-asset comparison, portfolio level"
echo "   • StochRSI: Early warnings in trends, mean reversion"
echo ""

echo "=" .repeat(70)
echo "Additional Momentum Indicators Example Complete!"
echo "=" .repeat(70)
echo ""
echo "Next Steps:"
echo "  • Backtest these combinations on historical data"
echo "  • Adjust parameters for different timeframes"
echo "  • Combine with volume indicators (from Phase 9.3)"
echo "  • Add risk management rules (stops, position sizing)"
echo ""
echo "Phase 9.4 completes the indicator library - 25/25 indicators! 🎉"
echo ""
