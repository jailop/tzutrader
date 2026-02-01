# Reference Guide: Trend Following Strategies

## Overview

Trend following strategies attempt to capture sustained directional moves in price. These strategies assume that prices in motion tend to continue in motion, and they profit by riding trends while using various methods to confirm trend direction and strength.

TzuTrader provides 7 trend following strategies, each using different methods to identify and follow trends:

1. Moving Average Crossover - Golden/death cross signals
2. MACD Strategy - Momentum-based trend detection
3. KAMA Strategy - Adaptive moving average
4. Aroon Strategy - Time-based trend identification
5. Parabolic SAR - Trailing stop trend follower
6. Triple MA Strategy - Multi-timeframe confirmation
7. ADX Trend Strategy - Strength-filtered trends

Module: `tzutrader/strategy.nim`

## KAMA Strategy

Adaptive trend following strategy using the Kaufman Adaptive Moving Average, which adjusts its responsiveness based on market efficiency.

Trading Logic:
- Buy: Price crosses above KAMA
- Sell: Price crosses below KAMA
- Stay: No crossover

Constructor:

```nim
proc newKAMAStrategy*(period: int = 10, fastPeriod: int = 2, slowPeriod: int = 30,
                      symbol: string = ""): KAMAStrategy
```

Parameters:

| Parameter | Type | Default | Description | Typical Range |
|-----------|------|---------|-------------|---------------|
| `period` | int | 10 | Efficiency ratio lookback period | 5-20 |
| `fastPeriod` | int | 2 | Fast smoothing constant | 2-5 |
| `slowPeriod` | int | 30 | Slow smoothing constant | 20-50 |
| `symbol` | string | "" | Target symbol | — |

Type:

```nim
type
  KAMAStrategy* = ref object of Strategy
    period*: int
    fastPeriod*: int
    slowPeriod*: int
    kama*: KAMA
    lastPriceAbove*: bool
```

Strategy Behavior:

KAMA automatically adapts its smoothing based on market efficiency. In trending markets with directional price movement, KAMA becomes more responsive (follows price closely). In choppy, ranging markets, KAMA smooths more aggressively (reduces false signals).

Efficiency Ratio:

KAMA calculates an "efficiency ratio" comparing net price change to total price movement:
- High efficiency (trending): Net change ≈ total movement → KAMA responsive
- Low efficiency (ranging): Net change << total movement → KAMA smooth

Compared to Fixed-Period MAs:

- Fixed MAs use the same smoothing regardless of conditions
- KAMA adapts: fast in trends, slow in ranges
- KAMA reduces whipsaws in choppy markets
- KAMA requires more historical data for stable results

Parameter Selection:

- Shorter period (5-8): More responsive efficiency calculation
- Longer period (15-20): Smoother efficiency measurement
- Faster fastPeriod (2): More aggressive in trends
- Slower slowPeriod (40-50): More conservative in ranges

Example:

```nim
import tzutrader

# Standard KAMA (10,2,30)
let standard = newKAMAStrategy()

# Aggressive KAMA (responds faster)
let aggressive = newKAMAStrategy(
  period = 8,
  fastPeriod = 2,
  slowPeriod = 20
)

# Conservative KAMA (smoother)
let conservative = newKAMAStrategy(
  period = 15,
  fastPeriod = 3,
  slowPeriod = 40
)

let data = readCSV("data/AAPL.csv")
let report = quickBacktest("AAPL", standard, data)

echo "Trades: ", report.totalTrades
echo "Win rate: ", report.winRate, "%"
```

## Aroon Strategy

Trend identification strategy using the Aroon indicator, which measures time since recent highs and lows to identify trend strength and direction.

Trading Logic:
- Buy: Aroon Up crosses above threshold while Aroon Down < 50
- Sell: Aroon Down crosses above threshold while Aroon Up < 50
- Stay: No clear trend signal

Constructor:

```nim
proc newAroonStrategy*(period: int = 25, threshold: float64 = 70.0,
                       symbol: string = ""): AroonStrategy
```

Parameters:

| Parameter | Type | Default | Description | Typical Range |
|-----------|------|---------|-------------|---------------|
| `period` | int | 25 | Lookback period for highs/lows | 14-50 |
| `threshold` | float64 | 70.0 | Minimum strength for signal | 50-90 |
| `symbol` | string | "" | Target symbol | — |

Type:

```nim
type
  AroonStrategy* = ref object of Strategy
    period*: int
    threshold*: float64
    aroon*: AROON
    lastSignal*: Position
```

Strategy Behavior:

Aroon is unique because it measures time rather than price. An Aroon Up value of 100 means a new high just occurred; 0 means the high occurred N periods ago. This time-based approach excels at identifying when trends are starting or ending.

Aroon Indicator Values:

- Aroon Up = 100: New high just occurred (strong uptrend potential)
- Aroon Down = 100: New low just occurred (strong downtrend potential)
- Both near 50: No clear trend, consolidation
- Both near 0: Price stuck in middle of range

Signal Generation:

The strategy waits for one Aroon line to cross above the threshold (indicating trend strength) while the opposite line is below 50 (confirming no counter-trend). This ensures clear directional signals.

Parameter Selection:

- Shorter period (14-20): More sensitive to recent highs/lows
- Longer period (30-50): Identifies longer-term trends
- Lower threshold (50-60): More signals, earlier entries
- Higher threshold (80-90): Fewer signals, stronger confirmation

Example:

```nim
import tzutrader

# Standard Aroon (25 period, 70 threshold)
let standard = newAroonStrategy()

# Sensitive Aroon (shorter period, lower threshold)
let sensitive = newAroonStrategy(
  period = 14,
  threshold = 60.0
)

# Strict Aroon (longer period, higher threshold)
let strict = newAroonStrategy(
  period = 50,
  threshold = 85.0
)

let data = readCSV("data/AAPL.csv")
let report = quickBacktest("AAPL", standard, data)
```

## Parabolic SAR Strategy

Trend following strategy using the Parabolic Stop and Reverse indicator, which provides both entry signals and trailing stop levels.

Trading Logic:
- Buy: SAR flips from above to below price (SAR crosses below)
- Sell: SAR flips from below to above price (SAR crosses above)
- Stay: No SAR flip

Constructor:

```nim
proc newParabolicSARStrategy*(acceleration: float64 = 0.02,
                              maxAcceleration: float64 = 0.2,
                              symbol: string = ""): ParabolicSARStrategy
```

Parameters:

| Parameter | Type | Default | Description | Typical Range |
|-----------|------|---------|-------------|---------------|
| `acceleration` | float64 | 0.02 | Initial acceleration factor | 0.01-0.05 |
| `maxAcceleration` | float64 | 0.2 | Maximum acceleration factor | 0.1-0.3 |
| `symbol` | string | "" | Target symbol | — |

Type:

```nim
type
  ParabolicSARStrategy* = ref object of Strategy
    acceleration*: float64
    maxAcceleration*: float64
    psar*: PSAR
    lastSARBelow*: bool
```

Strategy Behavior:

Parabolic SAR is always in the market - either long or short. The SAR (Stop and Reverse) value provides a trailing stop level that accelerates as the trend continues. When price crosses the SAR, the position flips and the SAR jumps to the other side of price.

Acceleration Mechanism:

- SAR starts with the initial acceleration factor
- Each time a new extreme is reached, acceleration increases by the step
- Acceleration caps at maxAcceleration
- This causes SAR to accelerate toward price as trends mature

Parabolic SAR Characteristics:

- Always provides a stop level (trailing stop)
- Accelerates with trend age
- SAR never reverses direction until price crosses it
- Gaps between bars are handled properly
- Works best in strong trending markets

Parameter Selection:

- Lower acceleration (0.01-0.015): Slower, wider stops, longer trades
- Standard acceleration (0.02): Balanced approach
- Higher acceleration (0.03-0.05): Faster, tighter stops, shorter trades
- Lower maxAcceleration (0.1): More conservative trailing
- Higher maxAcceleration (0.3): More aggressive trailing

Example:

```nim
import tzutrader

# Standard PSAR (0.02, 0.2)
let standard = newParabolicSARStrategy()

# Conservative PSAR (slower acceleration)
let conservative = newParabolicSARStrategy(
  acceleration = 0.01,
  maxAcceleration = 0.1
)

# Aggressive PSAR (faster acceleration)
let aggressive = newParabolicSARStrategy(
  acceleration = 0.03,
  maxAcceleration = 0.3
)

let data = readCSV("data/AAPL.csv")
let report = quickBacktest("AAPL", standard, data)

echo "PSAR always in market, trades: ", report.totalTrades
```

Using SAR for Stops:

```nim
# Access current SAR value for stop placement
for bar in data:
  let signal = strategy.onBar(bar)
  if signal.position == Buy:
    let sarValue = strategy.psar[0].sar
    echo "Buy at ", bar.close, " with stop at ", sarValue
```

## Triple MA Strategy

Multi-timeframe trend confirmation strategy using three moving averages that must align for signals.

Trading Logic:
- Buy: Fast MA > Mid MA > Slow MA (all aligned upward)
- Sell: Fast MA < Mid MA < Slow MA (all aligned downward)
- Stay: MAs not fully aligned

Constructor:

```nim
proc newTripleMAStrategy*(fastPeriod: int = 10, midPeriod: int = 20,
                         slowPeriod: int = 50, symbol: string = ""): TripleMAStrategy
```

Parameters:

| Parameter | Type | Default | Description | Typical Range |
|-----------|------|---------|-------------|---------------|
| `fastPeriod` | int | 10 | Fast MA period | 5-20 |
| `midPeriod` | int | 20 | Middle MA period | 10-50 |
| `slowPeriod` | int | 50 | Slow MA period | 30-200 |
| `symbol` | string | "" | Target symbol | — |

Type:

```nim
type
  TripleMAStrategy* = ref object of Strategy
    fastPeriod*: int
    midPeriod*: int
    slowPeriod*: int
    fastMA*: MA
    midMA*: MA
    slowMA*: MA
    lastSignal*: Position
```

Strategy Behavior:

The Triple MA strategy requires all three moving averages to align before generating a signal. This triple confirmation dramatically reduces false signals but also lags price more than single or dual MA strategies.

Alignment Concept:

In a confirmed uptrend:
- Fast MA (10) follows price closely
- Mid MA (20) confirms short-term trend
- Slow MA (50) confirms longer-term trend
- When Fast > Mid > Slow, all timeframes agree: strong uptrend

Compared to Dual MA Crossover:

- Dual MA: 2 MAs must align (faster signals, more false positives)
- Triple MA: 3 MAs must align (slower signals, higher quality)
- Triple MA trades less frequently but with more conviction
- Triple MA better for position trading, worse for active trading

Parameter Selection:

Common combinations:
- Short-term: 5/10/20 (more responsive, more trades)
- Medium-term: 10/20/50 (balanced approach, default)
- Long-term: 20/50/200 (very conservative, few high-quality signals)
- Aggressive: 5/15/30 (faster signals)

Spacing matters:
- Tight spacing (10/15/20): Faster alignment, more trades
- Wide spacing (10/30/100): Slower alignment, stronger confirmation

Example:

```nim
import tzutrader

# Standard Triple MA (10,20,50)
let standard = newTripleMAStrategy()

# Short-term Triple MA
let shortTerm = newTripleMAStrategy(
  fastPeriod = 5,
  midPeriod = 10,
  slowPeriod = 20
)

# Long-term Triple MA
let longTerm = newTripleMAStrategy(
  fastPeriod = 20,
  midPeriod = 50,
  slowPeriod = 200
)

let data = readCSV("data/AAPL.csv")
let report = quickBacktest("AAPL", standard, data)

echo "Triple MA high-conviction trades: ", report.totalTrades
echo "Win rate: ", report.winRate, "%"
```

Monitoring Alignment:

```nim
# Check MA alignment without full signal
for bar in data:
  let fastVal = strategy.fastMA.update(bar.close)
  let midVal = strategy.midMA.update(bar.close)
  let slowVal = strategy.slowMA.update(bar.close)
  
  if not fastVal.isNaN and not midVal.isNaN and not slowVal.isNaN:
    if fastVal > midVal and midVal > slowVal:
      echo "Full uptrend alignment at ", bar.timestamp
    elif fastVal < midVal and midVal < slowVal:
      echo "Full downtrend alignment at ", bar.timestamp
    else:
      echo "Partial or no alignment"
```

## ADX Trend Strategy

Strength-filtered trend following strategy that only trades when the ADX indicator shows sufficient trend strength.

Trading Logic:
- Buy: ADX > threshold AND +DI > -DI (strong uptrend)
- Sell: ADX > threshold AND -DI > +DI (strong downtrend)
- Stay: ADX below threshold (weak/no trend)

Constructor:

```nim
proc newADXTrendStrategy*(adxPeriod: int = 14, adxThreshold: float64 = 25.0,
                         diPeriod: int = 14, symbol: string = ""): ADXTrendStrategy
```

Parameters:

| Parameter | Type | Default | Description | Typical Range |
|-----------|------|---------|-------------|---------------|
| `adxPeriod` | int | 14 | ADX calculation period | 10-20 |
| `adxThreshold` | float64 | 25.0 | Minimum ADX for trend | 20-40 |
| `diPeriod` | int | 14 | Directional indicator period | 10-20 |
| `symbol` | string | "" | Target symbol | — |

Type:

```nim
type
  ADXTrendStrategy* = ref object of Strategy
    adxPeriod*: int
    adxThreshold*: float64
    diPeriod*: int
    adx*: ADX
    lastSignal*: Position
```

Strategy Behavior:

ADX measures trend strength without indicating direction. The strategy uses ADX to filter out weak trends and ranging markets, only trading when ADX exceeds the threshold. The +DI and -DI lines then determine the direction.

ADX Interpretation:

- ADX < 20: Weak or absent trend, ranging market → stay out
- ADX 20-25: Trend developing → consider signals
- ADX 25-40: Strong trend → trade with confidence
- ADX > 40: Very strong trend → watch for exhaustion

Directional Indicators:

- +DI > -DI: Uptrend (bullish)
- -DI > +DI: Downtrend (bearish)
- Both DI values show the relative strength of up vs down moves

Why Filter by ADX:

Trend following strategies perform poorly in ranging markets. By requiring ADX > threshold, the strategy avoids:
- Choppy, sideways price action
- Whipsaws from false breakouts
- Weak trends that don't follow through

Trade less, but trade better.

Parameter Selection:

- Lower threshold (20): More trades, catches developing trends, more false signals
- Standard threshold (25): Balanced approach, proven historically
- Higher threshold (30-40): Fewer trades, only very strong trends, higher quality

- Shorter periods (10-12): More responsive, faster signals
- Standard periods (14): Classic Wilder settings
- Longer periods (18-20): Smoother, more reliable but laggier

Example:

```nim
import tzutrader

# Standard ADX Trend (14 period, 25 threshold)
let standard = newADXTrendStrategy()

# Aggressive ADX (lower threshold, more trades)
let aggressive = newADXTrendStrategy(
  adxPeriod = 14,
  adxThreshold = 20.0,
  diPeriod = 14
)

# Strict ADX (only very strong trends)
let strict = newADXTrendStrategy(
  adxPeriod = 14,
  adxThreshold = 35.0,
  diPeriod = 14
)

let data = readCSV("data/AAPL.csv")
let report = quickBacktest("AAPL", standard, data)

echo "ADX filtered trades: ", report.totalTrades
echo "Win rate: ", report.winRate, "%"
```

Combining with Other Strategies:

```nim
# Use ADX as a filter for another strategy
let macdStrategy = newMACDStrategy()
let adxFilter = newADX(period = 14)

for bar in data:
  let adxResult = adxFilter.update(bar.high, bar.low, bar.close)
  
  if not adxResult.adx.isNaN and adxResult.adx > 25.0:
    # Only process MACD signals when ADX shows trend
    let signal = macdStrategy.onBar(bar)
    if signal.position != Stay:
      echo "Filtered signal: ", signal.reason
```

## Trend Following Strategy Comparison

| Strategy | Lag | Signal Frequency | Works in Ranges | Provides Stops | Complexity |
|----------|-----|------------------|-----------------|----------------|------------|
| MA Crossover | High | Low | No | No | Low |
| MACD | Medium | Medium | No | No | Low |
| KAMA | Medium | Medium | Better | No | Medium |
| Aroon | Low | Medium | No | No | Medium |
| Parabolic SAR | Low | High | No | Yes | Low |
| Triple MA | Very High | Very Low | No | No | Low |
| ADX Trend | Medium | Low | Excellent | No | Medium |

When to Use Each:

- MA Crossover: Classic approach, well-understood, reliable
- MACD: More responsive than MA, good momentum indication
- KAMA: Markets that alternate between trending and ranging
- Aroon: Catching trend starts early, time-based signals
- Parabolic SAR: Need built-in trailing stops, always-in-market approach
- Triple MA: High-conviction long-term position trading
- ADX Trend: Must avoid ranging markets, quality over quantity

## Common Patterns

All trend following strategies share common patterns:

### Crossover Detection

```nim
# Track previous state to detect crossovers
let currentAbove = fastMA > slowMA
if currentAbove != lastFastAbove:
  # Crossover occurred
  if currentAbove:
    position = Buy  # Golden cross
  else:
    position = Sell  # Death cross
lastFastAbove = currentAbove
```

### Multiple Confirmation

```nim
# Require multiple conditions before signaling
if adx > threshold and plusDI > minusDI and price > ma:
  position = Buy  # Trend + direction + price all confirm
```

### Preventing Signal Spam

```nim
# Only signal on state changes
if position != lastSignal:
  lastSignal = position
  return Signal(...)
else:
  return Signal(position: Stay, ...)
```

## Performance Considerations

Trend Following Challenges:

1. Lag: All trend indicators lag price by design
2. Whipsaws: Ranging markets generate false signals
3. Late entry: Often enter after move has begun
4. Early exit: Can exit before trend fully completes

Mitigation Strategies:

- Use ADX filter to avoid ranging markets
- Combine multiple timeframes (Triple MA)
- Accept lag as cost of confirmation
- Use adaptive indicators (KAMA)
- Implement proper stops (Parabolic SAR)

## See Also

- [Mean Reversion Strategies](04a_strategies_mean_reversion.md) - Counter-trend strategies
- [Hybrid Strategies](04c_strategies_hybrid.md) - Combined approach strategies
- [Indicators Reference](03_indicators.md) - Indicator details
- [User Guide: Strategies](../user_guide/04_strategies.md) - Conceptual introduction
