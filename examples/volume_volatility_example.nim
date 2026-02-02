## Volume & Volatility Indicators Example
##
## Demonstrates Phase 9.3 indicators - volume and volatility analysis:
## - TRANGE (True Range) - Measures price volatility including gaps
## - NATR (Normalized ATR) - Volatility as percentage for cross-asset comparison
## - AD (Accumulation/Distribution) - Volume flow indicator
## - AROON (Aroon Indicator) - Identifies trend strength and reversals
##
## Shows how to combine these indicators for comprehensive market analysis.

import std/[strformat, strutils, math]

include ../src/tzutrader/indicators

echo "=".repeat(70)
echo "Section 1: True Range (TRANGE) - Volatility Measurement"
echo "=".repeat(70)
echo ""

echo "True Range captures the full extent of price movement, including gaps."
echo "Formula: max(High-Low, abs(High-PrevClose), abs(Low-PrevClose))"
echo ""

# Create TRANGE and ATR indicators
var trange = newTRANGE()
var atr = newATR(5) # 5-period ATR for smoothing

# Generate price data with a gap
type PriceBar = tuple[high, low, close: float64]

let priceData: seq[PriceBar] = @[
  (high: 102.0, low: 100.0, close: 101.0),
  (high: 103.0, low: 101.0, close: 102.5),
  (high: 104.0, low: 102.0, close: 103.0),
  (high: 103.5, low: 101.5, close: 102.0),       # Normal day
  (high: 108.0, low: 106.0, close: 107.5),       # Gap up (prev close 102.0)
  (high: 109.0, low: 107.0, close: 108.0),
  (high: 108.5, low: 106.5, close: 107.0),
  (high: 103.0, low: 101.0, close: 101.5),       # Gap down (prev close 107.0)
  (high: 102.0, low: 100.0, close: 101.0),
  (high: 103.0, low: 101.0, close: 102.0)
]

echo "Bar    High     Low    Close   |  TRange    ATR(5)   Notes"
echo "-".repeat(70)

for i, bar in priceData:
  let tr = trange.update(bar.high, bar.low, bar.close)
  let atrVal = atr.update(bar.high, bar.low, bar.close)

  var notes = ""
  if i == 4:
    notes = "Gap Up! TR captures gap"
  elif i == 7:
    notes = "Gap Down! TR captures gap"
  elif bar.high - bar.low > 2.5:
    notes = "Wide range"
  else:
    notes = "Normal range"

  if classify(tr) != fcNan:
    echo &"{i+1:<6} {bar.high:<8.2f} {bar.low:<6.2f} {bar.close:<7.2f} | {tr:>7.2f}  {atrVal:>7.2f}   {notes}"
  else:
    echo &"{i+1:<6} {bar.high:<8.2f} {bar.low:<6.2f} {bar.close:<7.2f} |    --       --      {notes}"

echo ""
echo "Key Insights:"
echo "  • Normal days: TR ≈ High - Low (around 2.0)"
echo "  • Gap up (bar 5): TR captures full move from prev close to high"
echo "  • Gap down (bar 8): TR captures full drop from prev close to low"
echo "  • ATR smooths TR over period, good for stop-loss sizing"
echo ""

echo "=".repeat(70)
echo "Section 2: NATR - Volatility as Percentage"
echo "=".repeat(70)
echo ""

echo "NATR expresses ATR as percentage of close price, enabling comparison"
echo "across different price levels and assets."
echo ""

# Simulate two assets: low-priced stock and high-priced stock
type AssetData = object
  name: string
  bars: seq[PriceBar]

let lowPricedStock = AssetData(
  name: "Stock A ($10)",
  bars: @[
    (10.5, 10.0, 10.2),
    (10.8, 10.2, 10.6),
    (11.0, 10.5, 10.8),
    (11.2, 10.6, 11.0),
    (11.5, 10.8, 11.2),
    (11.8, 11.0, 11.5),
    (12.0, 11.2, 11.8)
  ]
)

let highPricedStock = AssetData(
  name: "Stock B ($200)",
  bars: @[
    (210.0, 200.0, 204.0),
    (216.0, 204.0, 212.0),
    (220.0, 210.0, 216.0),
    (224.0, 212.0, 220.0),
    (230.0, 216.0, 224.0),
    (236.0, 220.0, 230.0),
    (240.0, 224.0, 236.0)
  ]
)

# Process both stocks
var natrA = newNATR(5)
var natrB = newNATR(5)
var atrA = newATR(5)
var atrB = newATR(5)

echo "Comparing volatility across different price levels:"
echo ""
echo "Stock A (Low Priced):                  Stock B (High Priced):"
echo "Close    ATR      NATR(%)      |       Close    ATR      NATR(%)"
echo "-".repeat(70)

for i in 0..<lowPricedStock.bars.len:
  let barA = lowPricedStock.bars[i]
  let barB = highPricedStock.bars[i]

  let atrValA = atrA.update(barA.high, barA.low, barA.close)
  let natrValA = natrA.update(barA.high, barA.low, barA.close)

  let atrValB = atrB.update(barB.high, barB.low, barB.close)
  let natrValB = natrB.update(barB.high, barB.low, barB.close)

  if classify(natrValA) != fcNan:
    echo &"{barA.close:<8.2f} {atrValA:<8.2f} {natrValA:<11.2f}  |       {barB.close:<8.2f} {atrValB:<8.2f} {natrValB:<8.2f}"

echo ""
echo "Key Insights:"
echo "  • ATR values differ greatly ($0.40 vs $8.00) due to price difference"
echo "  • NATR values are similar (~4%), showing comparable volatility"
echo "  • Use NATR for: portfolio risk comparison, position sizing, strategy parameters"
echo ""

echo "=".repeat(70)
echo "Section 3: AD (Accumulation/Distribution) - Volume Flow Analysis"
echo "=".repeat(70)
echo ""

echo "AD measures buying/selling pressure by combining price and volume."
echo "Rising AD = accumulation (buying pressure), Falling AD = distribution (selling)"
echo ""

# Create AD indicator
var ad = newAD()

# Simulate bullish accumulation period
let accumulationData = @[
  (high: 100.0, low: 98.0, close: 99.0, volume: 10000.0), # Close mid-range
  (high: 101.0, low: 99.0, close: 100.5, volume: 12000.0), # Close near high
  (high: 102.0, low: 100.0, close: 101.8, volume: 15000.0), # Strong close
  (high: 103.0, low: 101.0, close: 102.7, volume: 18000.0), # Accumulation
  (high: 104.0, low: 102.0, close: 103.8, volume: 20000.0), # Continued buying
]

echo "Accumulation Phase (Bullish):"
echo "Bar    High     Low    Close   Volume    |    AD Line    Change    Interpretation"
echo "-".repeat(85)

var prevAD = 0.0
for i, (h, l, c, v) in accumulationData:
  let adVal = ad.update(h, l, c, v)
  let change = if i > 0: adVal - prevAD else: 0.0

  var interp = ""
  if c > (h + l) / 2:
    interp = "Close near high → Buying"
  elif c < (h + l) / 2:
    interp = "Close near low → Selling"
  else:
    interp = "Close mid-range → Neutral"

  echo &"{i+1:<6} {h:<8.2f} {l:<6.2f} {c:<7.2f} {v:<9.0f} | {adVal:>10.0f} {change:>9.0f}    {interp}"
  prevAD = adVal

echo ""

# Now simulate distribution phase
var ad2 = newAD()
let distributionData = @[
  (high: 104.0, low: 102.0, close: 103.0, volume: 20000.0),             # Start
  (high: 103.5, low: 101.0, close: 101.5, volume: 22000.0),             # Close near low
  (high: 102.0, low: 99.5, close: 100.0, volume: 25000.0),              # Selling pressure
  (high: 101.0, low: 98.0, close: 98.5, volume: 28000.0),               # Distribution
  (high: 100.0, low: 96.0, close: 96.5, volume: 30000.0),               # Heavy selling
]

echo "Distribution Phase (Bearish):"
echo "Bar    High     Low    Close   Volume    |    AD Line    Change    Interpretation"
echo "-".repeat(85)

prevAD = 0.0
for i, (h, l, c, v) in distributionData:
  let adVal = ad2.update(h, l, c, v)
  let change = if i > 0: adVal - prevAD else: 0.0

  var interp = ""
  if c > (h + l) / 2:
    interp = "Close near high → Buying"
  elif c < (h + l) / 2:
    interp = "Close near low → Selling"
  else:
    interp = "Close mid-range → Neutral"

  echo &"{i+1:<6} {h:<8.2f} {l:<6.2f} {c:<7.2f} {v:<9.0f} | {adVal:>10.0f} {change:>9.0f}    {interp}"
  prevAD = adVal

echo ""
echo "Key Insights:"
echo "  • Accumulation: AD rises as price closes near high → buying pressure"
echo "  • Distribution: AD falls as price closes near low → selling pressure"
echo "  • Divergences: Price ↑ but AD ↓ warns of weakness (distribution)"
echo "  • Best used with price trend confirmation"
echo ""

echo "=".repeat(70)
echo "Section 4: AROON - Trend Strength and Reversals"
echo "=".repeat(70)
echo ""

echo "Aroon measures time since highest high / lowest low."
echo "  • Aroon Up > 70: Strong uptrend (recent new highs)"
echo "  • Aroon Down > 70: Strong downtrend (recent new lows)"
echo "  • Both < 50: Ranging / consolidation"
echo "  • Oscillator: Up - Down (positive = uptrend, negative = downtrend)"
echo ""

# Create Aroon indicator
var aroon = newAROON(14)

# Generate trending data
let trendData = @[
  # Initial consolidation (bars 1-7)
  (high: 100.5, low: 99.0),
  (high: 101.0, low: 99.5),
  (high: 100.8, low: 99.0),
  (high: 101.2, low: 99.5),
  (high: 100.5, low: 98.5),
  (high: 101.0, low: 99.0),
  (high: 100.8, low: 99.5),
  # Start of uptrend (bars 8-14)
  (high: 102.0, low: 100.0),
  (high: 103.5, low: 101.5),
  (high: 105.0, low: 103.0),
  (high: 106.5, low: 104.5),
  (high: 108.0, low: 106.0),
  (high: 109.5, low: 107.5),
  (high: 111.0, low: 109.0),
  # Consolidation at top (bars 15-18)
  (high: 111.5, low: 109.5),
  (high: 111.2, low: 109.0),
  (high: 111.5, low: 109.5),
  (high: 111.0, low: 109.0),
  # Start of downtrend (bars 19-25)
  (high: 109.5, low: 107.0),
  (high: 108.0, low: 105.5),
  (high: 106.5, low: 104.0),
  (high: 105.0, low: 102.5),
  (high: 103.5, low: 101.0),
  (high: 102.0, low: 99.5),
  (high: 100.5, low: 98.0),
]

echo "Bar    High     Low     | Aroon Up  Aroon Dn  Oscillator |  Market Phase"
echo "-".repeat(80)

for i, (h, l) in trendData:
  let aroonResult = aroon.update(h, l)

  if classify(aroonResult.up) != fcNan:
    var phase = ""
    if aroonResult.up > 70:
      phase = "UPTREND (new highs)"
    elif aroonResult.down > 70:
      phase = "DOWNTREND (new lows)"
    elif aroonResult.up > 50 and aroonResult.down < 50:
      phase = "Bullish bias"
    elif aroonResult.down > 50 and aroonResult.up < 50:
      phase = "Bearish bias"
    else:
      phase = "Ranging / Consolidation"

    echo &"{i+1:<6} {h:<8.2f} {l:<7.2f} | {aroonResult.up:>8.1f}  {aroonResult.down:>8.1f}  {aroonResult.oscillator:>10.1f} |  {phase}"
  else:
    echo &"{i+1:<6} {h:<8.2f} {l:<7.2f} |    --        --          --        |  Warming up..."

echo ""
echo "Key Insights:"
echo "  • Bars 1-7: Both Aroon values moderate → ranging market"
echo "  • Bars 8-14: Aroon Up climbs to >90 → strong uptrend developing"
echo "  • Bars 15-18: Both moderate → consolidation at top"
echo "  • Bars 19-25: Aroon Down rises to >90 → trend reversal to downtrend"
echo ""

echo "=".repeat(70)
echo "Section 5: Combined Analysis - Volume, Volatility & Trend"
echo "=".repeat(70)
echo ""

echo "Combining indicators for comprehensive market analysis:"
echo ""

# Reset indicators for combined analysis
var combinedATR = newATR(5)
var combinedNATR = newNATR(5)
var combinedAD = newAD()
var combinedAroon = newAROON(10)

# Generate comprehensive scenario
type FullBar = tuple[high, low, close, volume: float64]

let fullScenario: seq[FullBar] = @[
  # Phase 1: Low volatility accumulation (bars 1-5)
  (100.5, 99.5, 100.0, 5000.0),
  (100.8, 99.8, 100.5, 5500.0),
  (101.0, 100.0, 100.8, 6000.0),
  (101.5, 100.5, 101.2, 7000.0),
  (102.0, 101.0, 101.8, 8000.0),
  # Phase 2: Breakout with increasing volatility (bars 6-10)
  (104.0, 101.5, 103.5, 15000.0),
  (106.0, 103.0, 105.5, 20000.0),
  (108.5, 105.0, 108.0, 25000.0),
  (111.0, 107.5, 110.5, 30000.0),
  (113.5, 110.0, 113.0, 28000.0),
  # Phase 3: Distribution at top (bars 11-13)
  (114.0, 111.0, 111.5, 22000.0),
  (113.0, 109.5, 110.0, 25000.0),
  (111.5, 108.0, 108.5, 28000.0),
]

echo "Market Phases Analysis:"
echo ""
echo "Bar    Close   Volume  |  ATR   NATR%  | AroonUp AroonDn |   AD      | Signal"
echo "-".repeat(90)

var prevADVal = 0.0
for i, bar in fullScenario:
  let atrVal = combinedATR.update(bar.high, bar.low, bar.close)
  let natrVal = combinedNATR.update(bar.high, bar.low, bar.close)
  let adVal = combinedAD.update(bar.high, bar.low, bar.close, bar.volume)
  let aroonVal = combinedAroon.update(bar.high, bar.low)

  var signal = ""

  # Determine market phase and signal
  if i < 5:
    signal = "Accumulation phase"
  elif i >= 5 and i < 10:
    if classify(aroonVal.up) != fcNan and aroonVal.up > 70:
      signal = "BREAKOUT - Strong uptrend"
  elif i >= 10:
    let adChange = adVal - prevADVal
    if adChange < -50000:
      signal = "WARNING: Distribution"

  if classify(atrVal) != fcNan:
    echo &"{i+1:<6} {bar.close:<7.2f} {bar.volume:<7.0f} | {atrVal:>5.2f}  {natrVal:>5.2f}  | {aroonVal.up:>6.1f}  {aroonVal.down:>6.1f}  | {adVal:>8.0f}  | {signal}"
  else:
    echo &"{i+1:<6} {bar.close:<7.2f} {bar.volume:<7.0f} |   --    --    |   --     --    |    --     | Warmup"

  prevADVal = adVal

echo ""
echo "Trading Strategy Insights:"
echo ""
echo "Phase 1 (Bars 1-5): Accumulation"
echo "  • Low volatility (ATR ~0.5, NATR ~0.5%)"
echo "  • AD rising on low volume → smart money accumulating"
echo "  • Aroon neutral → consolidation"
echo "  → Strategy: Prepare for breakout, build position"
echo ""
echo "Phase 2 (Bars 6-10): Breakout & Trend"
echo "  • Volatility expansion (ATR →3.5, NATR →3%)"
echo "  • Aroon Up >90 → strong uptrend confirmed"
echo "  • AD surging → strong buying pressure"
echo "  → Strategy: Ride the trend, use ATR for stops"
echo ""
echo "Phase 3 (Bars 11-13): Distribution Warning"
echo "  • Price still high but AD declining → bearish divergence"
echo "  • Aroon Down starting to rise → trend weakening"
echo "  • Volume still elevated → smart money exiting"
echo "  → Strategy: Take profits, tighten stops, reduce exposure"
echo ""

echo "=".repeat(70)
echo "Section 6: Practical Trading Applications"
echo "=".repeat(70)
echo ""

echo "1. POSITION SIZING with ATR/NATR:"
echo "   • Risk per trade = Account * 0.02 (2% rule)"
echo "   • Stop distance = 2 * ATR (volatility-based stop)"
echo "   • Position size = Risk / Stop distance"
echo ""
echo "   Example: $10,000 account, 2% risk, ATR = $2.50"
echo "   • Risk = $10,000 * 0.02 = $200"
echo "   • Stop = 2 * $2.50 = $5.00 per share"
echo "   • Position = $200 / $5.00 = 40 shares"
echo ""

echo "2. TREND FOLLOWING with AROON:"
echo "   • Entry: Aroon Up crosses above 70 (new uptrend)"
echo "   • Exit: Aroon Down crosses above 70 (trend reversal)"
echo "   • Filter: Only trade when oscillator magnitude > 50"
echo ""

echo "3. VOLUME CONFIRMATION with AD:"
echo "   • Bullish signal: Price breakout + AD rising (volume supports)"
echo "   • Bearish warning: Price rising + AD falling (divergence)"
echo "   • Best for: Confirming breakouts and spotting reversals"
echo ""

echo "4. VOLATILITY BREAKOUT with NATR:"
echo "   • Monitor NATR baseline (e.g., 20-day average)"
echo "   • Signal: NATR expands >150% of baseline"
echo "   • Direction: Use Aroon or price action for direction"
echo "   • Stop: Use current ATR for stop placement"
echo ""

echo "=".repeat(70)
echo "Volume & Volatility Example Complete!"
echo "=".repeat(70)
echo ""
echo "Next Steps:"
echo "  • Combine with trend indicators (MACD, Moving Averages)"
echo "  • Add momentum confirmation (RSI, Stochastic)"
echo "  • Backtest strategies with historical data"
echo "  • Adjust parameters for different timeframes and assets"
echo ""
