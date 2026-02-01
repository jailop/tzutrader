# Reference Guide: Hybrid & Volatility Strategies

## Overview

Hybrid strategies combine multiple technical analysis approaches to create more robust trading systems. These strategies use confirmation from different indicator types (trend + momentum, price + volume, etc.) to reduce false signals and improve reliability.

TzuTrader provides 3 hybrid/volatility strategies:

1. Keltner Channel Strategy - ATR-based volatility (dual mode: breakout/reversion)
2. Volume Breakout Strategy - Price movement + volume confirmation
3. Dual Momentum Strategy - ROC momentum + SMA trend filter

Module: `tzutrader/strategy.nim`

## Keltner Channel Strategy

Volatility-based strategy using ATR channels that can operate in two modes: breakout or mean reversion.

Trading Logic (Breakout Mode):
- Buy: Price breaks above upper band
- Sell: Price breaks below lower band
- Stay: Price within bands

Trading Logic (Reversion Mode):
- Buy: Price touches or falls below lower band
- Sell: Price touches or exceeds upper band
- Stay: Price within bands

Constructor:

```nim
type KeltnerMode* = enum
  kcBreakout,    ## Trade breakouts beyond bands
  kcReversion    ## Trade reversions at bands

proc newKeltnerStrategy*(period: int = 20, atrPeriod: int = 10,
                        multiplier: float64 = 2.0, mode: KeltnerMode = kcBreakout,
                        symbol: string = ""): KeltnerStrategy
```

Parameters:

| Parameter | Type | Default | Description | Typical Range |
|-----------|------|---------|-------------|---------------|
| `period` | int | 20 | Moving average period | 10-50 |
| `atrPeriod` | int | 10 | ATR calculation period | 10-20 |
| `multiplier` | float64 | 2.0 | ATR multiplier for bands | 1.5-3.0 |
| `mode` | KeltnerMode | kcBreakout | Trading mode (breakout/reversion) | — |
| `symbol` | string | "" | Target symbol | — |

Type:

```nim
type
  KeltnerStrategy* = ref object of Strategy
    period*: int
    atrPeriod*: int
    multiplier*: float64
    mode*: KeltnerMode
    ma*: MA
    atr*: ATR
    lastPosition*: Position
```

Strategy Behavior:

Keltner Channels consist of three lines:
- Middle line: Simple moving average (typically 20-period EMA)
- Upper band: Middle + (ATR × multiplier)
- Lower band: Middle - (ATR × multiplier)

The bands expand during volatile periods and contract during quiet periods, automatically adapting to market conditions.

Dual Mode Operation:

Breakout Mode:
- Assumes breakouts beyond bands indicate new trends
- Buys when price exceeds upper band (strength)
- Sells when price breaks lower band (weakness)
- Works best in low-volatility environments before trending moves

Reversion Mode:
- Assumes extreme prices revert to the mean
- Buys when price touches lower band (oversold)
- Sells when price touches upper band (overbought)
- Works best in high-volatility ranging markets

Keltner vs Bollinger Bands:

Both create volatility envelopes, but:
- Bollinger uses standard deviation (price volatility)
- Keltner uses ATR (true range volatility including gaps)
- Keltner typically smoother, fewer extreme breaches
- Keltner better handles gaps and limit moves

Parameter Selection:

- Shorter period (10-15): More responsive, tighter bands
- Longer period (30-50): Smoother, wider bands
- Higher multiplier (2.5-3.0): Wider bands, fewer touches, stronger signals
- Lower multiplier (1.5): Tighter bands, more touches, more trades
- Breakout mode: Use lower multiplier (1.5-2.0) to catch early breakouts
- Reversion mode: Use higher multiplier (2.5-3.0) for extreme conditions

Example:

```nim
import tzutrader

# Breakout mode (trade volatility expansions)
let breakout = newKeltnerStrategy(
  period = 20,
  atrPeriod = 10,
  multiplier = 2.0,
  mode = kcBreakout
)

# Mean reversion mode (fade extremes)
let reversion = newKeltnerStrategy(
  period = 20,
  atrPeriod = 10,
  multiplier = 2.5,
  mode = kcReversion
)

# Tight breakout (catch early moves)
let tightBreakout = newKeltnerStrategy(
  period = 20,
  atrPeriod = 10,
  multiplier = 1.5,
  mode = kcBreakout
)

let data = readCSV("data/AAPL.csv")

# Compare modes
let reportBreakout = quickBacktest("AAPL", breakout, data)
let reportReversion = quickBacktest("AAPL", reversion, data)

echo "Breakout mode - Trades: ", reportBreakout.totalTrades
echo "Reversion mode - Trades: ", reportReversion.totalTrades
```

Accessing Band Values:

```nim
# Monitor band levels
for bar in data:
  let signal = strategy.onBar(bar)
  
  let middleLine = strategy.ma[0]
  let atrValue = strategy.atr[0]
  
  if not middleLine.isNaN and not atrValue.isNaN:
    let upperBand = middleLine + (strategy.multiplier * atrValue)
    let lowerBand = middleLine - (strategy.multiplier * atrValue)
    let bandwidth = upperBand - lowerBand
    
    echo "Middle: ", middleLine
    echo "Upper: ", upperBand, " Lower: ", lowerBand
    echo "Bandwidth: ", bandwidth, " (", (bandwidth / middleLine * 100), "%)"
```

Strategy Selection by Market:

```nim
# Determine which mode based on volatility
let atr = newATR(period = 14)
var sumATR = 0.0
var count = 0

for bar in data:
  let atrVal = atr.update(bar.high, bar.low, bar.close)
  if not atrVal.isNaN:
    sumATR += atrVal
    count += 1

let avgATR = sumATR / count.float64
let normalizedATR = (avgATR / bar.close) * 100.0

if normalizedATR < 2.0:
  echo "Low volatility - use breakout mode"
  strategy = newKeltnerStrategy(mode = kcBreakout)
else:
  echo "High volatility - use reversion mode"
  strategy = newKeltnerStrategy(mode = kcReversion)
```

## Volume Breakout Strategy

Hybrid strategy that requires both price breakouts and volume confirmation, reducing false breakout signals.

Trading Logic:
- Buy: Price breaks above recent high AND volume > average volume × multiplier
- Sell: Price breaks below recent low AND volume > average volume × multiplier
- Stay: No breakout or insufficient volume

Constructor:

```nim
proc newVolumeBreakoutStrategy*(period: int = 20, volumePeriod: int = 20,
                                volumeMultiplier: float64 = 1.5,
                                symbol: string = ""): VolumeBreakoutStrategy
```

Parameters:

| Parameter | Type | Default | Description | Typical Range |
|-----------|------|---------|-------------|---------------|
| `period` | int | 20 | Lookback period for highs/lows | 10-50 |
| `volumePeriod` | int | 20 | Period for average volume | 10-50 |
| `volumeMultiplier` | float64 | 1.5 | Volume threshold multiplier | 1.2-2.5 |
| `symbol` | string | "" | Target symbol | — |

Type:

```nim
type
  VolumeBreakoutStrategy* = ref object of Strategy
    period*: int
    volumePeriod*: int
    volumeMultiplier*: float64
    highestHigh*: Highest
    lowestLow*: Lowest
    avgVolume*: MA
    lastSignal*: Position
```

Strategy Behavior:

Most breakout strategies fail because breakouts on low volume tend to reverse (false breakouts). This strategy solves this by requiring volume confirmation. A true breakout occurs when:

1. Price exceeds the recent high/low range
2. Volume significantly exceeds average (shows conviction)

Both conditions must be met simultaneously.

Volume Confirmation Theory:

- High volume breakout: Institutional participation, likely to continue
- Low volume breakout: Retail/technical traders, likely to fail
- Volume threshold ensures "real money" is driving the move
- Higher multipliers require stronger volume confirmation

Why Dual Confirmation Matters:

Single factor breakouts have ~40-50% success rates:
- Price breakout alone: Can be false breakout
- Volume spike alone: Can be single large trade, no follow-through

Combined: ~60-70% success rate when both confirm.

Parameter Selection:

- Shorter period (10-15): Tighter range, more breakout opportunities
- Longer period (30-50): Wider range, only significant breakouts
- Lower volume multiplier (1.2-1.3): More trades, earlier entries, more false signals
- Standard multiplier (1.5): Balanced confirmation
- Higher multiplier (2.0-2.5): Fewer trades, very strong confirmation, late entries

Example:

```nim
import tzutrader

# Standard volume breakout
let standard = newVolumeBreakoutStrategy()

# Aggressive (lower volume requirement)
let aggressive = newVolumeBreakoutStrategy(
  period = 15,
  volumePeriod = 15,
  volumeMultiplier = 1.3
)

# Conservative (strong volume confirmation)
let conservative = newVolumeBreakoutStrategy(
  period = 30,
  volumePeriod = 30,
  volumeMultiplier = 2.0
)

let data = readCSV("data/AAPL.csv")
let report = quickBacktest("AAPL", standard, data)

echo "Volume-confirmed breakouts: ", report.totalTrades
echo "Win rate: ", report.winRate, "%"
```

Analyzing Volume Patterns:

```nim
# Track volume vs breakouts
var breakoutsWithVolume = 0
var breakoutsWithoutVolume = 0

for bar in data:
  let high = strategy.highestHigh[0]
  let low = strategy.lowestLow[0]
  let avgVol = strategy.avgVolume[0]
  
  if not high.isNaN and not low.isNaN and not avgVol.isNaN:
    let volumeConfirmed = bar.volume > (avgVol * strategy.volumeMultiplier)
    
    if bar.high > high:
      if volumeConfirmed:
        breakoutsWithVolume += 1
        echo "Valid breakout with volume at ", bar.timestamp
      else:
        breakoutsWithoutVolume += 1
        echo "Breakout without volume (filtered) at ", bar.timestamp

echo "Volume confirmed: ", breakoutsWithVolume
echo "Volume rejected: ", breakoutsWithoutVolume
```

## Dual Momentum Strategy

Hybrid strategy combining rate-of-change momentum with moving average trend filtering.

Trading Logic:
- Buy: ROC > threshold AND price > MA (positive momentum in uptrend)
- Sell: ROC < -threshold AND price < MA (negative momentum in downtrend)
- Stay: Momentum and trend don't align

Constructor:

```nim
proc newDualMomentumStrategy*(rocPeriod: int = 12, maPeriod: int = 50,
                              threshold: float64 = 0.0,
                              symbol: string = ""): DualMomentumStrategy
```

Parameters:

| Parameter | Type | Default | Description | Typical Range |
|-----------|------|---------|-------------|---------------|
| `rocPeriod` | int | 12 | ROC calculation period | 9-20 |
| `maPeriod` | int | 50 | Moving average period | 20-200 |
| `threshold` | float64 | 0.0 | ROC threshold for signals | -2.0 to +2.0 |
| `symbol` | string | "" | Target symbol | — |

Type:

```nim
type
  DualMomentumStrategy* = ref object of Strategy
    rocPeriod*: int
    maPeriod*: int
    threshold*: float64
    roc*: ROC
    ma*: MA
    lastSignal*: Position
```

Strategy Behavior:

Dual Momentum combines two dimensions:
1. Momentum (ROC): Is price accelerating up or down?
2. Trend (MA): Is the overall trend up or down?

Signals only occur when both agree, ensuring you trade momentum in the direction of the trend rather than counter-trend momentum.

Why Two Confirmations:

Pure momentum strategies (ROC alone) suffer from:
- Taking counter-trend trades that get steamrolled
- Momentum spikes that don't follow through
- Trading noise instead of meaningful moves

The trend filter ensures momentum is moving with, not against, the bigger picture.

ROC Interpretation:

- ROC > 0: Price higher than N periods ago (positive momentum)
- ROC < 0: Price lower than N periods ago (negative momentum)
- ROC magnitude: Speed of price change
- Threshold: Minimum momentum required (reduces noise)

Parameter Selection:

- Shorter ROC (9-10): More responsive momentum
- Longer ROC (15-20): Smoother momentum, fewer whipsaws
- Shorter MA (20-30): Tighter trend definition, more trades
- Longer MA (100-200): Only trade in major trends
- Positive threshold (+1% to +2%): Require minimum upward momentum
- Zero threshold: Any momentum in trend direction qualifies

Example:

```nim
import tzutrader

# Standard dual momentum
let standard = newDualMomentumStrategy()

# Fast momentum, slow trend
let responsive = newDualMomentumStrategy(
  rocPeriod = 9,
  maPeriod = 50,
  threshold = 0.0
)

# Slow momentum, fast trend
let balanced = newDualMomentumStrategy(
  rocPeriod = 15,
  maPeriod = 30,
  threshold = 1.0  # Require 1% momentum
)

# Strong confirmation required
let strict = newDualMomentumStrategy(
  rocPeriod = 12,
  maPeriod = 100,
  threshold = 2.0  # Require 2% momentum
)

let data = readCSV("data/AAPL.csv")
let report = quickBacktest("AAPL", standard, data)

echo "Dual confirmation trades: ", report.totalTrades
echo "Win rate: ", report.winRate, "%"
```

Monitoring Alignment:

```nim
# Track when momentum and trend align
for bar in data:
  let rocVal = strategy.roc[0]
  let maVal = strategy.ma[0]
  
  if not rocVal.isNaN and not maVal.isNaN:
    let momentum = if rocVal > strategy.threshold: "Bullish" 
                   elif rocVal < -strategy.threshold: "Bearish"
                   else: "Neutral"
    
    let trend = if bar.close > maVal: "Uptrend"
                else: "Downtrend"
    
    echo "Momentum: ", momentum, " Trend: ", trend
    
    if momentum == "Bullish" and trend == "Uptrend":
      echo "Full bullish alignment"
    elif momentum == "Bearish" and trend == "Downtrend":
      echo "Full bearish alignment"
```

Comparing with Single-Factor:

```nim
# Compare dual momentum vs pure ROC
let pureROC = newROC(period = 12)
let dualMomentum = newDualMomentumStrategy(rocPeriod = 12, maPeriod = 50)

var pureSignals = 0
var dualSignals = 0
var alignedSignals = 0

for bar in data:
  let rocVal = pureROC.update(bar.close)
  let signal = dualMomentum.onBar(bar)
  
  if not rocVal.isNaN:
    if rocVal > 0.0:
      pureSignals += 1
      if signal.position == Buy:
        alignedSignals += 1
    elif rocVal < 0.0:
      pureSignals += 1
      if signal.position == Sell:
        alignedSignals += 1
  
  if signal.position != Stay:
    dualSignals += 1

echo "Pure ROC signals: ", pureSignals
echo "Dual momentum signals: ", dualSignals
echo "Aligned signals: ", alignedSignals
echo "Filter rate: ", (1.0 - dualSignals.float64 / pureSignals.float64) * 100.0, "%"
```

## Hybrid Strategy Comparison

| Strategy | Primary Signal | Filter/Confirmation | Mode Options | Complexity | Best For |
|----------|----------------|---------------------|--------------|------------|----------|
| Keltner | Price bands | ATR volatility | Breakout/Reversion | Medium | Volatility-driven markets |
| Volume Breakout | Price breakout | Volume surge | Single mode | Medium | Liquid, high-volume markets |
| Dual Momentum | ROC momentum | MA trend | Single mode | Medium | Trending markets with pullbacks |

Strategy Selection:

- Keltner (Breakout): Low volatility → breakout expected
- Keltner (Reversion): High volatility → mean reversion expected
- Volume Breakout: Need volume confirmation, liquid markets only
- Dual Momentum: Want momentum with trend, avoid counter-trend trades

## Benefits of Hybrid Approaches

Reduced False Signals:

Single-factor strategies produce many false signals:
- Price breakouts without volume often fail
- Momentum without trend often reverses
- Volatility expansion without direction is noise

Hybrid strategies filter these out.

Higher Win Rates:

By requiring multiple confirmations:
- Keltner: Price extreme + volatility adaptation
- Volume Breakout: Price move + volume conviction
- Dual Momentum: Momentum + trend alignment

Win rates typically improve 10-20% vs single-factor approaches.

Trade-offs:

- Fewer total trades (stricter requirements)
- Potentially later entries (waiting for confirmation)
- More complex to understand and tune
- Better risk-adjusted returns

## Common Patterns

### Dual Confirmation

```nim
# Require two independent conditions
if priceCondition and volumeCondition:
  position = Buy
elif negPriceCondition and volumeCondition:
  position = Sell
```

### Mode Selection

```nim
# Different logic based on mode
case mode:
of kcBreakout:
  if price > upperBand: position = Buy
of kcReversion:
  if price < lowerBand: position = Buy
```

### Threshold Tuning

```nim
# Adjustable sensitivity via thresholds
if momentum > threshold and trend == Uptrend:
  # Higher threshold = fewer but stronger signals
  position = Buy
```

## See Also

- [Mean Reversion Strategies](04a_strategies_mean_reversion.md) - Single-factor mean reversion
- [Trend Following Strategies](04b_strategies_trend.md) - Single-factor trend following
- [Indicators Reference](03_indicators.md) - Component indicators
- [User Guide: Strategies](../user_guide/04_strategies.md) - Conceptual introduction
