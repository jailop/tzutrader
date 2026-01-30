# Reference Guide: Technical Indicators

## Overview

Technical indicators are mathematical calculations applied to price and volume data to identify patterns and potential trading opportunities. TzuTrader provides pure Nim implementations of commonly used indicators, offering both batch processing for historical analysis and streaming calculation for real-time applications.

**Module:** `tzutrader/indicators.nim`

## Understanding Indicator Modes

TzuTrader implements indicators in two complementary ways:

**Batch Functions:** Process entire sequences at once. These are useful during backtesting when you have complete historical data and need to calculate an indicator across all periods. They return a sequence of values with NaN for periods where insufficient data exists.

**Streaming Objects:** Update incrementally as new data arrives. These maintain internal state and are suitable for live trading applications or memory-constrained environments where storing full sequences is impractical.

Most traders will use batch functions for backtesting and streaming objects when moving to live trading. The calculations are identical—only the execution model differs.

## Moving Averages

Moving averages smooth price data to reveal trends by reducing noise. They form the foundation of many trading strategies and serve as dynamic support and resistance levels.

### Simple Moving Average (SMA)

The SMA calculates the arithmetic mean of prices over a specified period. Each value in the period carries equal weight.

**Formula:**

$$\text{SMA}_t = \frac{1}{n} \sum_{i=0}^{n-1} P_{t-i}$$

where $P_t$ is the price at time $t$ and $n$ is the period length.

**Batch Function:**

```nim
proc sma*(data: seq[float64], period: int): seq[float64]
```

**Parameters:**
- `data`: Price series (typically close prices)
- `period`: Number of periods to average

**Returns:** Sequence of SMA values, NaN for first `period - 1` values

**Streaming Type:**

```nim
type SMA* = ref object of IndicatorBase

proc newSMA*(period: int): SMA
proc update*(sma: SMA, value: float64): float64
proc current*(sma: SMA): float64
```

**Usage Characteristics:**

SMAs respond slowly to price changes because all values in the window have equal weight. A 20-period SMA considers the price from 20 bars ago as important as yesterday's price. This lag makes SMAs smooth but sometimes too slow for fast-moving markets.

**Example:**

```nim
import tzutrader/indicators

let closes = @[100.0, 102.0, 101.0, 103.0, 105.0, 104.0, 106.0]
let sma5 = sma(closes, 5)

# First 4 values are NaN (insufficient data)
# sma5[4] = (100 + 102 + 101 + 103 + 105) / 5 = 102.2
```

### Exponential Moving Average (EMA)

The EMA gives greater weight to recent prices, making it more responsive to new information than the SMA. This responsiveness comes at the cost of being more sensitive to short-term fluctuations.

**Formula:**

$$\text{EMA}_t = P_t \cdot k + \text{EMA}_{t-1} \cdot (1 - k)$$

where:

$$k = \frac{2}{n + 1}$$

The initial EMA value is calculated as an SMA.

**Batch Function:**

```nim
proc ema*(data: seq[float64], period: int): seq[float64]
```

**Streaming Type:**

```nim
type EMA* = ref object of IndicatorBase

proc newEMA*(period: int): EMA
proc update*(ema: EMA, value: float64): float64
proc current*(ema: EMA): float64
```

**Usage Characteristics:**

The multiplier $k$ determines responsiveness. A 10-period EMA has $k = 0.1818$, meaning the most recent price contributes about 18% to the new EMA value. Shorter periods create higher multipliers and more reactive EMAs.

EMAs are particularly useful in trending markets where staying close to current prices matters. However, they generate more false signals in choppy markets than SMAs.

### Weighted Moving Average (WMA)

The WMA assigns linearly increasing weights to more recent prices. The most recent price receives weight $n$, the previous price receives $n-1$, and so on.

**Formula:**

$$\text{WMA}_t = \frac{\sum_{i=0}^{n-1} P_{t-i} \cdot (n - i)}{\sum_{i=1}^{n} i}$$

The denominator simplifies to $\frac{n(n+1)}{2}$.

**Batch Function:**

```nim
proc wma*(data: seq[float64], period: int): seq[float64]
```

**Usage Characteristics:**

WMAs fall between SMAs and EMAs in responsiveness. They're less common in practice but useful when you want gradual rather than exponential emphasis on recent prices.

## Momentum Indicators

Momentum indicators measure the rate of price change, helping identify when moves are accelerating or decelerating. They often work best in conjunction with trend indicators.

### Relative Strength Index (RSI)

RSI measures the magnitude of recent price changes to evaluate overbought or oversold conditions. It oscillates between 0 and 100.

**Formula:**

$$\text{RSI} = 100 - \frac{100}{1 + \text{RS}}$$

where:

$$\text{RS} = \frac{\text{Average Gain}}{\text{Average Loss}}$$

The average gain and average loss are calculated using exponential smoothing:

$$
\begin{align}
\text{Avg Gain}_t &= \frac{\text{Avg Gain}_{t-1} \cdot (n-1) + \text{Gain}_t}{n} \\
\text{Avg Loss}_t &= \frac{\text{Avg Loss}_{t-1} \cdot (n-1) + \text{Loss}_t}{n}
\end{align}
$$

**Batch Function:**

```nim
proc rsi*(data: seq[float64], period: int = 14): seq[float64]
```

**Streaming Type:**

```nim
type RSI* = ref object of IndicatorBase

proc newRSI*(period: int = 14): RSI
proc update*(rsi: RSI, price: float64): float64
proc current*(rsi: RSI): float64
```

**Interpretation:**

Traditional interpretations suggest values above 70 indicate overbought conditions and values below 30 indicate oversold conditions. However, markets can remain overbought or oversold for extended periods during strong trends.

RSI works better for identifying divergences—when price makes a new high but RSI doesn't, or vice versa—than as absolute buy/sell signals.

**Example:**

```nim
import tzutrader/indicators

let closes = @[44.0, 44.5, 45.0, 45.5, 45.0, 44.5, 44.0, 43.5, 43.0,
               42.5, 43.0, 43.5, 44.0, 44.5, 45.0, 45.5]
let rsi14 = rsi(closes, 14)

# Values are NaN until sufficient data accumulates
# RSI ranges from 0 to 100
```

### Rate of Change (ROC)

ROC measures the percentage change in price over a specified period. It's one of the simplest momentum indicators.

**Formula:**

$$\text{ROC}_t = \frac{P_t - P_{t-n}}{P_{t-n}} \times 100$$

**Batch Function:**

```nim
proc roc*(data: seq[float64], period: int = 12): seq[float64]
```

**Returns:** Percentage change values, NaN for first `period` values

**Usage Characteristics:**

ROC is unbounded—it can range from -100% (price went to zero) to infinity. Positive values indicate upward momentum, negative values indicate downward momentum. The magnitude indicates strength.

ROC tends to oscillate around zero in ranging markets and trend away from zero in directional markets.

## Trend Indicators

Trend indicators attempt to identify and confirm the direction of price movement. They typically lag price but offer confirmation once a trend establishes.

### Moving Average Convergence Divergence (MACD)

MACD uses the relationship between two exponential moving averages to identify trend changes. It consists of three components: the MACD line, signal line, and histogram.

**Formulas:**

$$\text{MACD Line} = \text{EMA}_{12} - \text{EMA}_{26}$$

$$\text{Signal Line} = \text{EMA}_9(\text{MACD Line})$$

$$\text{Histogram} = \text{MACD Line} - \text{Signal Line}$$

**Batch Function:**

```nim
proc macd*(data: seq[float64], fastPeriod: int = 12, slowPeriod: int = 26, 
          signalPeriod: int = 9): tuple[macd, signal, histogram: seq[float64]]
```

**Streaming Type:**

```nim
type MACD* = ref object of IndicatorBase

proc newMACD*(fastPeriod: int = 12, slowPeriod: int = 26, 
              signalPeriod: int = 9): MACD
proc update*(macd: MACD, price: float64): tuple[macd, signal, histogram: float64]
proc current*(macd: MACD): tuple[macd, signal, histogram: float64]
```

**Interpretation:**

Crossovers between the MACD line and signal line generate trading signals. When the MACD line crosses above the signal line, it suggests upward momentum. Crosses below suggest downward momentum.

The histogram visualizes the distance between the lines. Growing histogram values indicate strengthening momentum, shrinking values suggest weakening momentum.

**Usage Characteristics:**

MACD works well in trending markets but generates numerous false signals in sideways markets. The standard 12/26/9 parameters were chosen decades ago for daily charts and may not be optimal for all timeframes or markets.

## Volatility Indicators

Volatility indicators measure the magnitude of price fluctuations, helping traders assess risk and adjust position sizing accordingly.

### Average True Range (ATR)

ATR quantifies market volatility by measuring the average range of price movement over a period. Unlike simple range calculations, ATR accounts for gaps between bars.

**True Range Formula:**

$$\text{TR}_t = \max(\text{TR}_1, \text{TR}_2, \text{TR}_3)$$

where:

$$
\begin{align}
\text{TR}_1 &= \text{high}_t - \text{low}_t \\
\text{TR}_2 &= |\text{high}_t - \text{close}_{t-1}| \\
\text{TR}_3 &= |\text{low}_t - \text{close}_{t-1}|
\end{align}
$$

**ATR Formula:**

ATR is an exponential moving average of the true range:

$$\text{ATR}_t = \frac{\text{ATR}_{t-1} \cdot (n-1) + \text{TR}_t}{n}$$

**Batch Function:**

```nim
proc atr*(high, low, close: seq[float64], period: int = 14): seq[float64]
```

**Streaming Type:**

```nim
type ATR* = ref object of IndicatorBase

proc newATR*(period: int = 14): ATR
proc update*(atr: ATR, high, low, close: float64): float64
proc current*(atr: ATR): float64
```

**Usage Characteristics:**

ATR measures volatility in absolute price units, not percentages. A stock trading at $100 with an ATR of $2 has similar volatility to a $50 stock with an ATR of $1.

Traders use ATR primarily for position sizing and stop-loss placement. Higher ATR values suggest wider stops are needed to avoid getting stopped out by normal volatility.

**Example:**

```nim
import tzutrader/indicators

let highs = @[102.0, 104.0, 103.0, 105.0, 107.0]
let lows = @[98.0, 100.0, 99.0, 101.0, 103.0]
let closes = @[100.0, 102.0, 101.0, 103.0, 105.0]

let atr14 = atr(highs, lows, closes, 14)
```

### Bollinger Bands

Bollinger Bands create a volatility envelope around a moving average using standard deviations. They expand during volatile periods and contract during quiet periods.

**Formulas:**

$$\text{Middle Band} = \text{SMA}_n(P)$$

$$\text{Upper Band} = \text{SMA}_n(P) + k \cdot \sigma_n$$

$$\text{Lower Band} = \text{SMA}_n(P) - k \cdot \sigma_n$$

where $\sigma_n$ is the standard deviation over $n$ periods and $k$ is typically 2.

**Batch Function:**

```nim
proc bollinger*(data: seq[float64], period: int = 20, stdDev: float64 = 2.0): 
    tuple[upper, middle, lower: seq[float64]]
```

**Usage Characteristics:**

Bollinger Bands adapt to changing volatility. When bands are wide, the market is volatile. When bands are narrow (a "squeeze"), volatility is low and often precedes significant moves.

Prices touching or exceeding the bands doesn't automatically signal reversal. In strong trends, prices can walk along the upper or lower band for extended periods.

**Example:**

```nim
import tzutrader/indicators

let closes = @[100.0, 102.0, 101.0, 103.0, 105.0, 104.0, 106.0, 
               108.0, 107.0, 109.0, 111.0, 110.0, 112.0]
let (upper, middle, lower) = bollinger(closes, period = 10, stdDev = 2.0)

# middle is the 10-period SMA
# upper and lower are 2 standard deviations away
```

### Standard Deviation

Standard deviation measures dispersion around the mean price. It's a fundamental statistical measure used in many technical indicators.

**Formula:**

$$\sigma_t = \sqrt{\frac{1}{n} \sum_{i=0}^{n-1} (P_{t-i} - \bar{P})^2}$$

where $\bar{P}$ is the mean price over the period.

**Batch Function:**

```nim
proc stddev*(data: seq[float64], period: int): seq[float64]
```

**Usage Characteristics:**

Higher standard deviation indicates greater price dispersion and uncertainty. Lower values suggest stability.

Standard deviation is rarely used alone but serves as a component in Bollinger Bands, Keltner Channels, and other volatility-based indicators.

## Volume Indicators

Volume indicators incorporate trading volume to confirm price movements or identify divergences between price and volume.

### On-Balance Volume (OBV)

OBV tracks cumulative volume flow to identify buying and selling pressure. It adds volume on up days and subtracts volume on down days.

**Formula:**

$$
\text{OBV}_t = \begin{cases}
\text{OBV}_{t-1} + V_t & \text{if } P_t > P_{t-1} \\
\text{OBV}_{t-1} - V_t & \text{if } P_t < P_{t-1} \\
\text{OBV}_{t-1} & \text{if } P_t = P_{t-1}
\end{cases}
$$

**Batch Function:**

```nim
proc obv*(close, volume: seq[float64]): seq[float64]
```

**Streaming Type:**

```nim
type OBV* = ref object of IndicatorBase

proc newOBV*(): OBV
proc update*(obv: OBV, close, volume: float64): float64
proc current*(obv: OBV): float64
```

**Interpretation:**

OBV's absolute value is meaningless—what matters is its direction and divergences from price. Rising OBV during a price uptrend confirms strength. Rising OBV during a price downtrend suggests accumulation and potential reversal.

**Example:**

```nim
import tzutrader/indicators

let closes = @[100.0, 102.0, 101.0, 103.0, 105.0]
let volumes = @[1000.0, 1200.0, 900.0, 1500.0, 1300.0]

let obvValues = obv(closes, volumes)
# obvValues[0] = 1000.0 (initial)
# obvValues[1] = 2200.0 (price up, add volume)
# obvValues[2] = 1300.0 (price down, subtract volume)
# obvValues[3] = 2800.0 (price up, add volume)
# obvValues[4] = 4100.0 (price up, add volume)
```

## Utility Functions

### Return on Investment (ROI)

Calculates percentage return between two values.

**Formula:**

$$\text{ROI} = \frac{\text{final} - \text{initial}}{\text{initial}} \times 100$$

**Function:**

```nim
proc roi*(initial, final: float64): float64
```

**Returns:** Percentage gain or loss, NaN if initial is zero

## NaN Handling

Indicators return NaN (Not a Number) when insufficient data exists for calculation. This typically occurs during the first `period - 1` bars when warming up.

**Checking for NaN:**

```nim
import tzutrader/indicators

proc isNaN*(x: float64): bool
```

**Converting NaN to Zero:**

```nim
proc nanToZero*(x: float64): float64
```

**In Practice:**

Strategies must handle NaN values appropriately. Common approaches include:
- Wait until all indicators return valid values before generating signals
- Use default values (like `nanToZero`) with caution, as zero might not be meaningful
- Track initialization state explicitly

## Streaming Indicator Base Type

All streaming indicators inherit from `IndicatorBase`:

```nim
type
  IndicatorBase* = ref object of RootObj
    period*: int
    values*: Deque[float64]
    initialized*: bool
```

**Common Methods:**

```nim
proc addValue*(ind: IndicatorBase, value: float64)
proc isFull*(ind: IndicatorBase): bool
```

These methods manage the rolling window of values. User code typically doesn't need to call them directly—use the indicator-specific `update()` method instead.

## Performance Considerations

**Memory Usage:**
- Batch functions allocate full result sequences
- Streaming indicators maintain only the rolling window (typically 10-100 values)
- Use streaming for memory-constrained environments

**Computational Speed:**
- Batch functions are vectorized where possible
- Streaming calculations are incremental and efficient
- Both approaches are suitable for production use

**Choosing Between Modes:**
- Use batch mode for backtesting with historical data
- Use streaming mode for live trading or when processing very large datasets incrementally
- Results are numerically identical (within floating-point precision)

## See Also

- [Strategy Reference](04_strategies.md) - Using indicators in strategies
- [User Guide: Technical Indicators](../user_guide/03_indicators.md) - Conceptual introduction
- [User Guide: Creating Strategies](../user_guide/04_strategies.md) - Practical indicator usage
