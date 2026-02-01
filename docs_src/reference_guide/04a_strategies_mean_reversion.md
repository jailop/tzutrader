# Reference Guide: Mean Reversion Strategies

## Overview

Mean reversion strategies assume that prices tend to return to an average level after extreme movements. These strategies buy when prices are "too low" and sell when prices are "too high" relative to some measure of fair value or average.

TzuTrader provides 6 mean reversion strategies, each using different methods to identify extremes:

1. RSI Strategy - Classic overbought/oversold based on momentum
2. Bollinger Bands Strategy - Volatility-adjusted price extremes
3. Stochastic Strategy - Position within recent price range
4. MFI Strategy - Volume-weighted momentum extremes
5. CCI Strategy - Statistical deviation from typical price
6. Filtered Mean Reversion - RSI with trend filter

Module: `tzutrader/strategy.nim`

## Stochastic Strategy

Mean reversion strategy using the Stochastic Oscillator to identify overbought/oversold conditions based on where price closes within its recent range.

Trading Logic:
- Buy: %K crosses above %D while both are in oversold zone
- Sell: %K crosses below %D while both are in overbought zone
- Stay: No crossover or values in neutral zone

Constructor:

```nim
proc newStochasticStrategy*(period: int = 14, kSmooth: int = 3, dSmooth: int = 3,
                           oversold: float64 = 20.0, overbought: float64 = 80.0,
                           symbol: string = ""): StochasticStrategy
```

Parameters:

| Parameter | Type | Default | Description | Typical Range |
|-----------|------|---------|-------------|---------------|
| `period` | int | 14 | Lookback period for high/low range | 9-21 |
| `kSmooth` | int | 3 | Smoothing period for %K line | 1-5 |
| `dSmooth` | int | 3 | Smoothing period for %D signal line | 3-5 |
| `oversold` | float64 | 20.0 | Buy threshold | 10-30 |
| `overbought` | float64 | 80.0 | Sell threshold | 70-90 |
| `symbol` | string | "" | Target symbol | — |

Type:

```nim
type
  StochasticStrategy* = ref object of Strategy
    period*: int
    kSmooth*: int
    dSmooth*: int
    oversold*: float64
    overbought*: float64
    stoch*: STOCH
    lastK*: float64
    lastD*: float64
```

Strategy Behavior:

The Stochastic compares the closing price to the recent price range. Values near 100 mean price is at the top of its range (overbought); values near 0 mean price is at the bottom (oversold). The strategy waits for both %K and %D to be in extreme zones and then trades on crossovers, providing confirmation.

Parameter Selection:

- Shorter periods (9-12): More sensitive, more trades, faster signals
- Longer periods (16-21): Smoother, fewer trades, more reliable extremes
- Higher smoothing (4-5): Reduces whipsaws but delays signals
- Tighter thresholds (30/70): Trade more frequently with less extreme moves
- Wider thresholds (10/90): Wait for very extreme conditions

Example:

```nim
import tzutrader

# Standard Stochastic (14,3,3 with 20/80 thresholds)
let standard = newStochasticStrategy()

# Fast Stochastic (shorter period, less smoothing)
let fast = newStochasticStrategy(
  period = 9,
  kSmooth = 1,
  dSmooth = 3,
  oversold = 20.0,
  overbought = 80.0
)

# Slow Stochastic (more smoothing, extreme thresholds)
let slow = newStochasticStrategy(
  period = 14,
  kSmooth = 5,
  dSmooth = 5,
  oversold = 10.0,
  overbought = 90.0
)

let data = readCSV("data/AAPL.csv")
let report = quickBacktest("AAPL", standard, data)

echo "Trades: ", report.totalTrades
echo "Win rate: ", report.winRate, "%"
```

## Money Flow Index (MFI) Strategy

Volume-weighted momentum strategy that combines price and volume to identify overbought/oversold conditions. Often called "volume-weighted RSI."

Trading Logic:
- Buy: MFI falls below oversold threshold
- Sell: MFI rises above overbought threshold
- Stay: MFI between thresholds

Constructor:

```nim
proc newMFIStrategy*(period: int = 14, oversold: float64 = 20.0,
                     overbought: float64 = 80.0, symbol: string = ""): MFIStrategy
```

Parameters:

| Parameter | Type | Default | Description | Typical Range |
|-----------|------|---------|-------------|---------------|
| `period` | int | 14 | MFI calculation period | 10-20 |
| `oversold` | float64 | 20.0 | Buy threshold | 10-30 |
| `overbought` | float64 | 80.0 | Sell threshold | 70-90 |
| `symbol` | string | "" | Target symbol | — |

Type:

```nim
type
  MFIStrategy* = ref object of Strategy
    period*: int
    oversold*: float64
    overbought*: float64
    mfi*: MFI
    lastSignal*: Position
```

Strategy Behavior:

MFI incorporates volume into momentum measurement. High prices with low volume produce lower MFI values (weak buying), while high prices with high volume produce higher MFI (strong buying). This makes MFI particularly effective at identifying when volume confirms or contradicts price action.

Compared to RSI:

- RSI uses only price data
- MFI weights by volume, capturing buying/selling pressure
- MFI more reliable in liquid markets with consistent volume
- MFI better at detecting accumulation/distribution phases

Example:

```nim
import tzutrader

# Standard MFI (14 period with 20/80 thresholds)
let standard = newMFIStrategy()

# Aggressive MFI (tighter thresholds, more trades)
let aggressive = newMFIStrategy(
  period = 14,
  oversold = 30.0,
  overbought = 70.0
)

# Conservative MFI (wait for extreme conditions)
let conservative = newMFIStrategy(
  period = 14,
  oversold = 10.0,
  overbought = 90.0
)

let data = readCSV("data/AAPL.csv")
let report = quickBacktest("AAPL", standard, data)
```

## Commodity Channel Index (CCI) Strategy

Statistical mean reversion strategy that measures how far the typical price deviates from its statistical average.

Trading Logic:
- Buy: CCI falls below oversold threshold
- Sell: CCI rises above overbought threshold
- Stay: CCI between thresholds

Constructor:

```nim
proc newCCIStrategy*(period: int = 20, oversold: float64 = -100.0,
                     overbought: float64 = 100.0, symbol: string = ""): CCIStrategy
```

Parameters:

| Parameter | Type | Default | Description | Typical Range |
|-----------|------|---------|-------------|---------------|
| `period` | int | 20 | CCI calculation period | 14-30 |
| `oversold` | float64 | -100.0 | Buy threshold | -150 to -50 |
| `overbought` | float64 | 100.0 | Sell threshold | +50 to +150 |
| `symbol` | string | "" | Target symbol | — |

Type:

```nim
type
  CCIStrategy* = ref object of Strategy
    period*: int
    oversold*: float64
    overbought*: float64
    cci*: CCI
    lastSignal*: Position
```

Strategy Behavior:

CCI is unbounded and can reach extreme values. The ±100 thresholds are chosen so approximately 70-80% of values fall within this range. When CCI exceeds these levels, price is statistically far from its mean and likely to revert.

Statistical Interpretation:

Unlike RSI (0-100 bounded), CCI can range from -∞ to +∞. Values beyond ±100 represent statistical outliers. The strategy assumes these outliers will revert to the mean.

Parameter Selection:

- Shorter periods (14-18): More responsive, more trades
- Longer periods (25-30): Smoother, fewer false signals
- Tighter thresholds (±75): Trade more moderate deviations
- Wider thresholds (±150): Wait for extreme statistical outliers

Example:

```nim
import tzutrader

# Standard CCI (20 period with ±100 thresholds)
let standard = newCCIStrategy()

# Tight CCI (trade moderate deviations)
let tight = newCCIStrategy(
  period = 20,
  oversold = -75.0,
  overbought = 75.0
)

# Extreme CCI (wait for statistical outliers)
let extreme = newCCIStrategy(
  period = 20,
  oversold = -150.0,
  overbought = 150.0
)

let data = readCSV("data/AAPL.csv")
let report = quickBacktest("AAPL", standard, data)
```

## Filtered Mean Reversion Strategy

Advanced mean reversion strategy that combines RSI with a trend filter to avoid counter-trend trades.

Trading Logic:
- Buy: RSI < oversold AND price > MA (oversold in uptrend)
- Sell: RSI > overbought AND price < MA (overbought in downtrend)
- Stay: RSI signal doesn't align with trend

Constructor:

```nim
proc newFilteredMeanReversionStrategy*(rsiPeriod: int = 14, maPeriod: int = 50,
                                       oversold: float64 = 30.0,
                                       overbought: float64 = 70.0,
                                       symbol: string = ""): FilteredMeanReversionStrategy
```

Parameters:

| Parameter | Type | Default | Description | Typical Range |
|-----------|------|---------|-------------|---------------|
| `rsiPeriod` | int | 14 | RSI calculation period | 9-21 |
| `maPeriod` | int | 50 | Moving average period for trend filter | 20-200 |
| `oversold` | float64 | 30.0 | RSI buy threshold | 20-35 |
| `overbought` | float64 | 70.0 | RSI sell threshold | 65-80 |
| `symbol` | string | "" | Target symbol | — |

Type:

```nim
type
  FilteredMeanReversionStrategy* = ref object of Strategy
    rsiPeriod*: int
    maPeriod*: int
    oversold*: float64
    overbought*: float64
    rsi*: RSI
    ma*: MA
    lastSignal*: Position
```

Strategy Behavior:

This strategy improves upon pure RSI by adding a trend filter. It only takes buy signals when price is above the moving average (uptrend) and only takes sell signals when price is below the moving average (downtrend). This dramatically reduces losing counter-trend trades.

Why Filter?

Pure RSI strategies suffer from taking counter-trend trades:
- Buying oversold conditions in downtrends (price continues falling)
- Selling overbought conditions in uptrends (price continues rising)

The trend filter ensures you're "buying dips" in uptrends and "selling rallies" in downtrends rather than fighting the overall trend.

Parameter Selection:

- Shorter MA (20-30): More responsive, more trades, tighter trend definition
- Medium MA (50): Balanced approach, standard trend filter
- Longer MA (100-200): Only trade in strong established trends
- RSI thresholds: Use standard 30/70 or experiment with 25/75 for more trades

Example:

```nim
import tzutrader

# Standard filtered mean reversion
let standard = newFilteredMeanReversionStrategy()

# Short-term (fast trend filter)
let shortTerm = newFilteredMeanReversionStrategy(
  rsiPeriod = 14,
  maPeriod = 20,
  oversold = 30.0,
  overbought = 70.0
)

# Long-term (only trade in strong trends)
let longTerm = newFilteredMeanReversionStrategy(
  rsiPeriod = 14,
  maPeriod = 200,
  oversold = 30.0,
  overbought = 70.0
)

let data = readCSV("data/AAPL.csv")
let report = quickBacktest("AAPL", standard, data)

echo "Filtered strategy trades: ", report.totalTrades
echo "Win rate: ", report.winRate, "%"
```

Comparison with Pure RSI:

```nim
# Compare filtered vs unfiltered
let pureRSI = newRSIStrategy(period = 14, oversold = 30.0, overbought = 70.0)
let filtered = newFilteredMeanReversionStrategy(rsiPeriod = 14, maPeriod = 50,
                                                oversold = 30.0, overbought = 70.0)

let data = readCSV("data/AAPL.csv")
let report1 = quickBacktest("AAPL", pureRSI, data)
let report2 = quickBacktest("AAPL", filtered, data)

echo "Pure RSI - Trades: ", report1.totalTrades, " Win Rate: ", report1.winRate, "%"
echo "Filtered - Trades: ", report2.totalTrades, " Win Rate: ", report2.winRate, "%"
```

Expected Results:

Filtered mean reversion typically shows:
- Fewer total trades (filter removes counter-trend signals)
- Higher win rate (only trades with the trend)
- Better risk-adjusted returns
- Fewer large losing trades

## Mean Reversion Strategy Comparison

| Strategy | Complexity | Signal Frequency | Volume Required | Best Timeframe |
|----------|------------|------------------|-----------------|----------------|
| RSI | Low | Medium | No | Days-Weeks |
| Bollinger | Low | Medium | No | Days-Weeks |
| Stochastic | Medium | High | No | Minutes-Days |
| MFI | Medium | Medium | Yes | Days-Weeks |
| CCI | Low | Medium | No | Days-Weeks |
| Filtered MR | High | Low | No | Days-Weeks |

When to Use Each:

- RSI: Default choice, works across most markets
- Bollinger Bands: Volatile markets, prefer volatility adaptation
- Stochastic: Short-term trading, need fast signals
- MFI: Liquid markets, volume is meaningful
- CCI: Commodity trading, statistical approach
- Filtered Mean Reversion: Want higher win rate, trending markets

## Common Patterns

All mean reversion strategies share common patterns:

### Preventing Signal Repetition

```nim
# Track last signal to avoid repeating
if rsiVal < oversold and lastSignal != Buy:
  position = Buy
  lastSignal = Buy
```

### Handling Initialization

```nim
# Check for NaN during warmup period
if not indicatorValue.isNaN:
  # Process signal logic
else:
  position = Stay  # Not enough data yet
```

### Dual Confirmation

```nim
# Stochastic waits for both lines in extreme zone
if kVal < oversold and dVal < oversold and kCrossedAboveD:
  position = Buy
```

## See Also

- [Trend Following Strategies](04b_strategies_trend.md) - Trend-based strategies
- [Hybrid Strategies](04c_strategies_hybrid.md) - Combined approach strategies
- [Indicators Reference](03_indicators.md) - Indicator details
- [User Guide: Strategies](../user_guide/04_strategies.md) - Conceptual introduction
