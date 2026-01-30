# Reference Guide: Technical Indicators

## Overview

Technical indicators are mathematical calculations applied to price and volume data to identify patterns and potential trading opportunities. TzuTrader provides pure Nim implementations of commonly used indicators using a **streaming-only architecture**.

**Module:** `tzutrader/indicators.nim`

## Streaming Architecture

TzuTrader uses a streaming-only design where indicators update incrementally as new data arrives:

**Streaming Objects:** All indicators maintain internal state and update one data point at a time. This design provides:
- **O(1) Memory**: Constant memory usage regardless of data size
- **O(1) Updates**: Each new data point is processed in constant time
- **Unified API**: Same code works for backtesting and live trading
- **Historical Access**: Circular buffers allow access to previous values via `indicator[0]` (current), `indicator[-1]` (previous), etc.

This architecture is ideal for both backtesting historical data and running live trading bots, as the same indicator instance can process data indefinitely without memory growth.

## Moving Averages

Moving averages smooth price data to reveal trends by reducing noise. They form the foundation of many trading strategies and serve as dynamic support and resistance levels.

### Simple Moving Average (SMA)

The SMA calculates the arithmetic mean of prices over a specified period. Each value in the period carries equal weight.

**Formula:**

$$\text{SMA}_t = \frac{1}{n} \sum_{i=0}^{n-1} P_{t-i}$$

where $P_t$ is the price at time $t$ and $n$ is the period length.

**API:**

```nim
type MA* = ref object of Indicator[float64]

proc newMA*(period: int, memSize: int = 1): MA
proc update*(ma: MA, value: float64): float64
```

**Parameters:**
- `period`: Number of periods to average
- `memSize`: Size of circular buffer for historical access (default 1)

**Returns:** Current SMA value (NaN until `period` values received)

**Access:** Use `ma[0]` for current value, `ma[-1]` for previous, etc.

**Usage Characteristics:**

SMAs respond slowly to price changes because all values in the window have equal weight. A 20-period SMA considers the price from 20 bars ago as important as yesterday's price. This lag makes SMAs smooth but sometimes too slow for fast-moving markets.

**Example:**

```nim
import tzutrader/indicators

var ma = newMA(period = 5)

# Update with new prices as they arrive
for price in [100.0, 102.0, 101.0, 103.0, 105.0, 104.0, 106.0]:
  let smaVal = ma.update(price)
  if not smaVal.isNaN:
    echo "SMA: ", smaVal

# Access historical values if memSize > 1
# ma[0]  = current SMA
# ma[-1] = previous SMA
```

### Exponential Moving Average (EMA)

The EMA gives greater weight to recent prices, making it more responsive to new information than the SMA. This responsiveness comes at the cost of being more sensitive to short-term fluctuations.

**Formula:**

$$\text{EMA}_t = P_t \cdot k + \text{EMA}_{t-1} \cdot (1 - k)$$

where:

$$k = \frac{2}{n + 1}$$

The initial EMA value is calculated as an SMA.

**API:**

```nim
type EMA* = ref object of Indicator[float64]

proc newEMA*(period: int, alpha: float64 = 2.0, memSize: int = 1): EMA
proc update*(ema: EMA, value: float64): float64
```

**Parameters:**
- `period`: Number of periods
- `alpha`: Smoothing factor coefficient (default 2.0, used in k calculation)
- `memSize`: Size of circular buffer for historical access (default 1)

**Usage Characteristics:**

The multiplier $k$ determines responsiveness. A 10-period EMA has $k = 0.1818$, meaning the most recent price contributes about 18% to the new EMA value. Shorter periods create higher multipliers and more reactive EMAs.

EMAs are particularly useful in trending markets where staying close to current prices matters. However, they generate more false signals in choppy markets than SMAs.

### Weighted Moving Average (WMA)

The WMA assigns linearly increasing weights to more recent prices. The most recent price receives weight $n$, the previous price receives $n-1$, and so on.

**Formula:**

$$\text{WMA}_t = \frac{\sum_{i=0}^{n-1} P_{t-i} \cdot (n - i)}{\sum_{i=1}^{n} i}$$

The denominator simplifies to $\frac{n(n+1)}{2}$.

**API:**

```nim
type WMA* = ref object of Indicator[float64]

proc newWMA*(period: int, memSize: int = 1): WMA
proc update*(wma: WMA, value: float64): float64
```

**Parameters:**
- `period`: Number of periods for weighted average
- `memSize`: Size of circular buffer (default 1)

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

**API:**

```nim
type RSI* = ref object of Indicator[float64]

proc newRSI*(period: int = 14, memSize: int = 1): RSI
proc update*(rsi: RSI, open, close: float64): float64
```

**Parameters:**
- `period`: Lookback period (default 14)
- `memSize`: Size of circular buffer (default 1)
- `open`: Opening price for the bar
- `close`: Closing price for the bar

**Interpretation:**

Traditional interpretations suggest values above 70 indicate overbought conditions and values below 30 indicate oversold conditions. However, markets can remain overbought or oversold for extended periods during strong trends.

RSI works better for identifying divergences—when price makes a new high but RSI doesn't, or vice versa—than as absolute buy/sell signals.

**Example:**

```nim
import tzutrader/indicators

var rsi = newRSI(period = 14)

for bar in data:
  let rsiVal = rsi.update(bar.open, bar.close)
  if not rsiVal.isNaN:
    echo "RSI: ", rsiVal
```

# Values are NaN until sufficient data accumulates
# RSI ranges from 0 to 100
```

### Rate of Change (ROC)

ROC measures the percentage change in price over a specified period. It's one of the simplest momentum indicators.

**Formula:**

$$\text{ROC}_t = \frac{P_t - P_{t-n}}{P_{t-n}} \times 100$$

**API:**

```nim
type ROC* = ref object of Indicator[float64]

proc newROC*(period: int = 12, memSize: int = 1): ROC
proc update*(roc: ROC, value: float64): float64
```

**Parameters:**
- `period`: Lookback period (default 12)
- `memSize`: Size of circular buffer (default 1)

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

**API:**

```nim
type MACD* = ref object of Indicator[MACDResult]

proc newMACD*(fast: int = 12, slow: int = 26, signal: int = 9, memSize: int = 1): MACD
proc update*(macd: MACD, value: float64): MACDResult
```

**Parameters:**
- `fast`: Fast EMA period (default 12)
- `slow`: Slow EMA period (default 26)
- `signal`: Signal line period (default 9)
- `memSize`: Size of circular buffer (default 1)

**Returns:** `MACDResult` tuple with `(macd, signal, histogram)` fields

**Interpretation:**

Crossovers between the MACD line and signal line generate trading signals. When the MACD line crosses above the signal line, it suggests upward momentum. Crosses below suggest downward momentum.

The histogram visualizes the distance between the lines. Growing histogram values indicate strengthening momentum, shrinking values suggest weakening momentum.

**Usage Characteristics:**

MACD works well in trending markets but generates numerous false signals in sideways markets. The standard 12/26/9 parameters were chosen decades ago for daily charts and may not be optimal for all timeframes or markets.

### Parabolic Stop and Reverse (PSAR)

PSAR provides both trend direction and trailing stop levels. The indicator "stops and reverses" when price crosses the PSAR level, flipping to the opposite side of price.

**Formulas:**

The PSAR calculation is iterative and depends on whether in an uptrend or downtrend:

**Uptrend (PSAR below price):**

$$\text{PSAR}_{t+1} = \text{PSAR}_t + AF \times (EP - \text{PSAR}_t)$$

**Downtrend (PSAR above price):**

$$\text{PSAR}_{t+1} = \text{PSAR}_t - AF \times (\text{PSAR}_t - EP)$$

where:
- $AF$ = Acceleration Factor (starts at initial value, increases each time a new extreme is reached)
- $EP$ = Extreme Point (highest high in uptrend, lowest low in downtrend)

**API:**

```nim
type
  PSARResult* = object
    sar*: float64       # Current PSAR value
    isLong*: bool       # True if in uptrend, false if in downtrend
    ep*: float64        # Current extreme point
    af*: float64        # Current acceleration factor

  PSAR* = ref object of Indicator[PSARResult]

proc newPSAR*(acceleration: float64 = 0.02, maxAcceleration: float64 = 0.2, 
              memSize: int = 1): PSAR
proc update*(psar: PSAR, high, low: float64): PSARResult
```

**Parameters:**
- `acceleration`: Initial and increment value for AF (default 0.02)
- `maxAcceleration`: Maximum AF value (default 0.2)
- `memSize`: Size of circular buffer for historical access (default 1)
- `high, low`: High and low prices for the bar

**Returns:** `PSARResult` with fields:
- `sar`: The SAR value (stop level)
- `isLong`: True if currently in uptrend (PSAR below price)
- `ep`: Current extreme point tracked
- `af`: Current acceleration factor

**Interpretation:**

PSAR serves two purposes:
1. **Trend direction**: PSAR below price = uptrend; PSAR above price = downtrend
2. **Stop placement**: PSAR value provides a trailing stop level

**Trading Signals:**
- Price crosses above PSAR → Enter long (or exit short)
- Price crosses below PSAR → Enter short (or exit long)

**Acceleration Mechanism:**

The AF starts at the initial value (typically 0.02) and increases by the same amount each time a new extreme is reached:
- **Uptrend**: AF increases when price makes a new high
- **Downtrend**: AF increases when price makes a new low
- AF caps at maxAcceleration (typically 0.2)

This causes PSAR to accelerate toward price as the trend matures, tightening the trailing stop.

**Usage Characteristics:**

PSAR excels in trending markets but generates excessive whipsaws in ranging markets. It's always in the market (either bullish or bearish), making it suitable for:
- Trailing stop placement
- Trend identification
- Always-in-market strategies

The indicator handles gaps properly by adjusting the SAR calculation to prevent it from appearing inside the price bar.

**Example:**

```nim
import tzutrader/indicators

var psar = newPSAR(acceleration = 0.02, maxAcceleration = 0.2)

for bar in data:
  let result = psar.update(bar.high, bar.low)
  
  echo "SAR: ", result.sar
  echo "Trend: ", if result.isLong: "Uptrend" else: "Downtrend"
  echo "Extreme Point: ", result.ep
  echo "Acceleration: ", result.af
  
  # Check for SAR flip (trend reversal)
  if result.isLong and bar.low < result.sar:
    echo "Trend flipped to downtrend"
  elif not result.isLong and bar.high > result.sar:
    echo "Trend flipped to uptrend"
```

**Parameter Selection:**

- **Lower acceleration** (0.01): Slower tightening, wider stops, longer trades
- **Standard acceleration** (0.02): Balanced approach (Wilder's original)
- **Higher acceleration** (0.03-0.05): Faster tightening, tighter stops, shorter trades
- **Lower maxAcceleration** (0.1): More conservative maximum tightening
- **Higher maxAcceleration** (0.3): More aggressive trailing

**Using as Trailing Stop:**

```nim
var position = "none"
var entry_price = 0.0
var stop_level = 0.0

for bar in data:
  let result = psar.update(bar.high, bar.low)
  
  if position == "none":
    if bar.close > result.sar:  # PSAR flipped bullish
      position = "long"
      entry_price = bar.close
      echo "Enter long at ", entry_price
  elif position == "long":
    stop_level = result.sar
    echo "Trailing stop at ", stop_level
    
    if bar.low < stop_level:  # Stop hit
      echo "Exit long at ", stop_level
      echo "Profit: ", stop_level - entry_price
      position = "none"
```

**Comparison with Fixed Stops:**

Traditional fixed stops (e.g., -2% from entry) don't adapt to:
- Market volatility
- Trend strength
- Time in trade

PSAR stops adapt to all three, tightening as the trend ages and volatility changes.

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

**API:**

```nim
type ATR* = ref object of Indicator[float64]

proc newATR*(period: int = 14, memSize: int = 1): ATR
proc update*(atr: ATR, high, low, close: float64): float64
```

**Parameters:**
- `period`: Smoothing period (default 14)
- `memSize`: Size of circular buffer (default 1)
- `high, low, close`: OHLC values for the bar

**Usage Characteristics:**

ATR measures volatility in absolute price units, not percentages. A stock trading at $100 with an ATR of $2 has similar volatility to a $50 stock with an ATR of $1.

Traders use ATR primarily for position sizing and stop-loss placement. Higher ATR values suggest wider stops are needed to avoid getting stopped out by normal volatility.

**Example:**

```nim
var atr = newATR(period = 14)

for bar in data:
  let atrVal = atr.update(bar.high, bar.low, bar.close)
  if not atrVal.isNaN:
    echo "ATR: ", atrVal
```
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

**API:**

```nim
type BollingerBands* = ref object of Indicator[BBResult]

proc newBollingerBands*(period: int = 20, stdDev: float64 = 2.0, memSize: int = 1): BollingerBands
proc update*(bb: BollingerBands, value: float64): BBResult
```

**Parameters:**
- `period`: SMA period (default 20)
- `stdDev`: Number of standard deviations for bands (default 2.0)
- `memSize`: Size of circular buffer (default 1)

**Returns:** `BBResult` tuple with `(upper, middle, lower)` fields

**Usage Characteristics:**

Bollinger Bands adapt to changing volatility. When bands are wide, the market is volatile. When bands are narrow (a "squeeze"), volatility is low and often precedes significant moves.

Prices touching or exceeding the bands doesn't automatically signal reversal. In strong trends, prices can walk along the upper or lower band for extended periods.

**Example:**

```nim
import tzutrader/indicators

var bb = newBollingerBands(period = 20, stdDev = 2.0)

for price in prices:
  let bands = bb.update(price)
  if not bands.middle.isNaN:
    echo "Upper: ", bands.upper, " Middle: ", bands.middle, " Lower: ", bands.lower
```

### Standard Deviation

Standard deviation measures dispersion around the mean price. It's a fundamental statistical measure used in many technical indicators.

**Formula:**

$$\sigma_t = \sqrt{\frac{1}{n} \sum_{i=0}^{n-1} (P_{t-i} - \bar{P})^2}$$

where $\bar{P}$ is the mean price over the period.

**API:**

```nim
type STDDEV* = ref object of Indicator[float64]

proc newSTDDEV*(period: int, memSize: int = 1): STDDEV
proc update*(sd: STDDEV, value: float64): float64
```

**Parameters:**
- `period`: Lookback period
- `memSize`: Size of circular buffer (default 1)

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

**API:**

```nim
type OBV* = ref object of Indicator[float64]

proc newOBV*(memSize: int = 1): OBV
proc update*(obv: OBV, close, volume: float64): float64
```

**Parameters:**
- `close`: Closing price
- `volume`: Trading volume
- `memSize`: Size of circular buffer (default 1)

**Interpretation:**

OBV's absolute value is meaningless—what matters is its direction and divergences from price. Rising OBV during a price uptrend confirms strength. Rising OBV during a price downtrend suggests accumulation and potential reversal.

**Example:**

```nim
import tzutrader/indicators

var obv = newOBV()

for bar in data:
  let obvVal = obv.update(bar.close, bar.volume)
  echo "OBV: ", obvVal
```

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
- All indicators use fixed-size circular buffers
- Memory usage is O(1) - constant regardless of data stream length
- Typical memory per indicator: 100-1000 bytes

**Computational Speed:**
- Each update() call is O(1) - constant time
- Incremental calculations are highly efficient
- Suitable for both backtesting and live trading

**Streaming Architecture Benefits:**
- Same code for backtesting and live trading
- No memory growth over time
- Fast indicator updates
- Can run indefinitely

## Advanced Momentum & Trend Indicators

### Stochastic Oscillator

The Stochastic Oscillator compares the closing price to the price range over a period. It generates two lines: %K (fast) and %D (slow signal line). Values range from 0 to 100.

**Formula:**

$$\%K = 100 \times \frac{\text{Close} - \text{Lowest Low}}{\text{Highest High} - \text{Lowest Low}}$$

$$\%D = \text{SMA}(\%K, d)$$

**API:**

```nim
type STOCH* = ref object of Indicator[STOCHResult]

proc newSTOCH*(period: int = 14, kSmooth: int = 3, dSmooth: int = 3, memSize: int = 1): STOCH
proc update*(stoch: STOCH, high, low, close: float64): STOCHResult
```

**Parameters:**
- `period`: Lookback period for %K (default 14)
- `kSmooth`: Smoothing for %K (default 3)
- `dSmooth`: Smoothing for %D signal line (default 3)
- `memSize`: Size of circular buffer (default 1)
- `high, low, close`: OHLC values

**Returns:** `STOCHResult` tuple with `(k, d)` fields

**Interpretation:**

- **Overbought:** %K > 80 suggests selling pressure may emerge
- **Oversold:** %K < 20 suggests buying pressure may emerge
- **Crossovers:** %K crossing above %D signals potential buy, crossing below signals potential sell
- **Divergence:** Price makes new high but %K doesn't confirm → potential reversal

**Example:**

```nim
import tzutrader

let data = readCSV("data/AAPL.csv")
let high = data.mapIt(it.high)
let low = data.mapIt(it.low)
let close = data.mapIt(it.close)

let (k, d) = stochastic(high, low, close, kPeriod = 14, dPeriod = 3)

# Check for oversold condition
if k[^1] < 20 and k[^1] > k[^2]:  # %K below 20 and rising
  echo "Potential buy signal"
```

**Characteristics:**

The Stochastic is a momentum oscillator that works best in ranging markets. In strong trends, it can remain overbought or oversold for extended periods. Many traders use it for timing entries in established trends rather than as a standalone signal.

### Commodity Channel Index (CCI)

CCI measures how far the typical price deviates from its average. Positive values indicate prices above average; negative values indicate below average.

**Formula:**

$$\text{Typical Price} = \frac{\text{High} + \text{Low} + \text{Close}}{3}$$

$$\text{CCI} = \frac{\text{TP} - \text{SMA}(\text{TP})}{0.015 \times \text{Mean Deviation}}$$

where Mean Deviation is the average absolute deviation from the SMA.

**API:**

```nim
type CCI* = ref object of Indicator[float64]

proc newCCI*(period: int = 20, memSize: int = 1): CCI
proc update*(cci: CCI, high, low, close: float64): float64
```

**Parameters:**
- `period`: Lookback period (default 20)
- `memSize`: Size of circular buffer (default 1)
- `high, low, close`: OHLC values

**Interpretation:**

- **Overbought:** CCI > +100 suggests overextension
- **Oversold:** CCI < -100 suggests oversold conditions
- **Trend:** CCI crossing above 0 signals potential uptrend, below 0 signals downtrend
- **Extremes:** CCI beyond ±200 indicates very strong moves

**Example:**

```nim
import tzutrader

var cci = newCCI(period = 20)

for bar in data:
  let cciVal = cci.update(bar.high, bar.low, bar.close)
  if not cciVal.isNaN:
    echo "CCI: ", cciVal
```
let high = data.mapIt(it.high)
let low = data.mapIt(it.low)
let close = data.mapIt(it.close)

let cciValues = cci(high, low, close, period = 20)

# Mean reversion strategy
if cciValues[^1] < -100:
  echo "Oversold - potential bounce"
elif cciValues[^1] > 100:
  echo "Overbought - potential pullback"
```

**Characteristics:**

CCI is unbounded and can reach extreme values. The 0.015 constant in the formula is chosen so that approximately 70-80% of CCI values fall between -100 and +100. CCI works well for identifying cyclical turns in commodities and stocks.

### Money Flow Index (MFI)

MFI combines price and volume to measure buying and selling pressure. It's often called "volume-weighted RSI" because it applies RSI logic to money flow rather than just price.

**Formula:**

$$\text{Typical Price} = \frac{\text{High} + \text{Low} + \text{Close}}{3}$$

$$\text{Money Flow} = \text{Typical Price} \times \text{Volume}$$

$$\text{Positive MF} = \sum \text{MF when price rises}$$

$$\text{Negative MF} = \sum \text{MF when price falls}$$

$$\text{Money Ratio} = \frac{\text{Positive MF}}{\text{Negative MF}}$$

$$\text{MFI} = 100 - \frac{100}{1 + \text{Money Ratio}}$$

**API:**

```nim
type MFI* = ref object of Indicator[float64]

proc newMFI*(period: int = 14, memSize: int = 1): MFI
proc update*(mfi: MFI, high, low, close, volume: float64): float64
```

**Parameters:**
- `period`: Lookback period (default 14)
- `memSize`: Size of circular buffer (default 1)
- `high, low, close`: OHLC values
- `volume`: Trading volume

**Returns:** MFI value (0-100)

**Interpretation:**

- **Overbought:** MFI > 80 suggests distribution (selling)
- **Oversold:** MFI < 20 suggests accumulation (buying)
- **Divergence:** Price makes new high but MFI doesn't → bearish; price makes new low but MFI doesn't → bullish
- **Failure Swings:** MFI crosses 80 or 20 but fails to confirm trend → potential reversal

**Example:**

```nim
import tzutrader

var mfi = newMFI(period = 14)

for bar in data:
  let mfiVal = mfi.update(bar.high, bar.low, bar.close, bar.volume)
  if not mfiVal.isNaN:
    echo "MFI: ", mfiVal
```
let low = data.mapIt(it.low)
let close = data.mapIt(it.close)
let volume = data.mapIt(it.volume)

let mfiValues = mfi(high, low, close, volume, period = 14)

# Volume confirmation strategy
if mfiValues[^1] < 20 and close[^1] > close[^2]:
  echo "Strong buying on low MFI - bullish"
elif mfiValues[^1] > 80 and close[^1] < close[^2]:
  echo "Selling pressure confirmed - bearish"
```

**Characteristics:**

MFI is particularly useful for identifying when volume confirms or contradicts price action. High prices with low MFI suggest weak uptrends (few buyers); low prices with high MFI suggest strong underlying demand.

### Average Directional Movement Index (ADX)

ADX measures trend strength without indicating direction. It's part of the Directional Movement system that includes +DI and -DI to show trend direction.

**Formula:**

The calculation is complex, involving multiple steps:

1. Calculate True Range (TR) as covered in ATR
2. Calculate directional movements:
   - $+DM = \text{High}_t - \text{High}_{t-1}$ (if positive and greater than $-DM$, else 0)
   - $-DM = \text{Low}_{t-1} - \text{Low}_t$ (if positive and greater than $+DM$, else 0)
3. Smooth DM values over period
4. Calculate directional indicators:
   - $+DI = 100 \times \frac{\text{Smoothed }+DM}{ATR}$
   - $-DI = 100 \times \frac{\text{Smoothed }-DM}{ATR}$
5. Calculate DX:
   - $DX = 100 \times \frac{|+DI - -DI|}{+DI + -DI}$
6. ADX is the smoothed average of DX

**API:**

```nim
type ADX* = ref object of Indicator[ADXResult]

proc newADX*(period: int = 14, memSize: int = 1): ADX
proc update*(adx: ADX, high, low, close: float64): ADXResult
```

**Parameters:**
- `period`: Lookback period (default 14)
- `memSize`: Size of circular buffer (default 1)
- `high, low, close`: OHLC values

**Returns:** `ADXResult` tuple with `(adx, plusDI, minusDI)` fields

**Interpretation:**

**ADX (Trend Strength):**
- **ADX < 20:** Weak or absent trend, range-bound market
- **ADX 20-25:** Trend developing
- **ADX 25-50:** Strong trend
- **ADX > 50:** Very strong trend (rare)

**Directional Indicators:**
- **+DI > -DI:** Uptrend
- **+DI < -DI:** Downtrend
- **+DI and -DI crossing:** Potential trend reversal

**Example:**

```nim
import tzutrader

var adx = newADX(period = 14)

for bar in data:
  let adxResult = adx.update(bar.high, bar.low, bar.close)
  if not adxResult.adx.isNaN:
    echo "ADX: ", adxResult.adx, " +DI: ", adxResult.plusDI, " -DI: ", adxResult.minusDI
```
let lastIdx = adxValues.len - 1
if adxValues[lastIdx] > 25:
  if plusDI[lastIdx] > minusDI[lastIdx]:
    echo "Strong uptrend - consider long positions"
  else:
    echo "Strong downtrend - consider short positions"
else:
  echo "Weak trend - avoid trend-following strategies"
```

**Characteristics:**

ADX is a lagging indicator that excels at identifying when a trend exists but not predicting reversals. Rising ADX indicates strengthening trend (regardless of direction); falling ADX indicates weakening trend or consolidation. Many traders use ADX > 25 as a filter to avoid ranging markets.

**Usage Notes:**

- ADX values above 25 suggest trending conditions where trend-following strategies work well
- ADX below 20 suggests mean-reversion strategies may perform better
- ADX doesn't predict trend direction—use +DI/-DI for that
- Extreme ADX readings (>50) often precede trend exhaustion

## Advanced Moving Averages

This section covers specialized moving averages that reduce lag or adapt to market conditions.

### Triangular Moving Average (TRIMA)

TRIMA applies double smoothing, creating a moving average of a moving average. This produces exceptionally smooth output with minimal noise.

**Formula:**

TRIMA is the SMA of an SMA. For period N:
- First, calculate SMA with period ceil((N+1)/2)
- Then, calculate SMA of those values with period floor((N+1)/2) + 1

**Streaming Type:**

```nim
type TRIMA* = ref object of Indicator[float64]

proc newTRIMA*(period: int, memSize: int = 1): TRIMA
proc update*(trima: TRIMA, value: float64): float64
```

**Characteristics:**

TRIMA is the smoothest of the moving averages but also the laggiest. The double smoothing eliminates most noise but makes it slow to react to price changes. Use TRIMA when smoothness is more important than responsiveness.

**Use cases:**
- Long-term trend identification
- Noise reduction in volatile markets
- Baseline for other calculations requiring stable values

### Double Exponential Moving Average (DEMA)

DEMA reduces lag compared to a standard EMA by using a combination of single and double-smoothed EMAs.

**Formula:**

$$\text{DEMA} = 2 \times \text{EMA}_1 - \text{EMA}_2$$

where EMA₁ is the EMA of price and EMA₂ is the EMA of EMA₁.

**Streaming Type:**

```nim
type DEMA* = ref object of Indicator[float64]

proc newDEMA*(period: int, memSize: int = 1): DEMA
proc update*(dema: DEMA, value: float64): float64
```

**Characteristics:**

DEMA responds faster than EMA while maintaining reasonable smoothness. It's not twice as fast as EMA despite the name—the improvement is more modest but noticeable.

**Use cases:**
- Short to medium-term trend following
- Crossover strategies requiring faster signals
- Dynamic support/resistance levels

### Triple Exponential Moving Average (TEMA)

TEMA extends the DEMA concept with triple smoothing for even less lag.

**Formula:**

$$\text{TEMA} = 3 \times \text{EMA}_1 - 3 \times \text{EMA}_2 + \text{EMA}_3$$

where each EMA is calculated from the previous one.

**Streaming Type:**

```nim
type TEMA* = ref object of Indicator[float64]

proc newTEMA*(period: int, memSize: int = 1): TEMA
proc update*(tema: TEMA, value: float64): float64
```

**Characteristics:**

TEMA provides the fastest response of the exponential moving averages while maintaining smooth output. However, the faster response means it generates more whipsaw signals in choppy markets.

**Use cases:**
- Short-term trading where timing is critical
- Fast-moving markets
- When lag reduction is paramount

**EMA vs DEMA vs TEMA:**
- EMA: Standard responsiveness, good for most situations
- DEMA: 30-40% less lag than EMA, good balance
- TEMA: 50-60% less lag than EMA, very responsive

### Kaufman Adaptive Moving Average (KAMA)

KAMA automatically adjusts its smoothing constant based on market volatility. During trending periods, it becomes more responsive. During choppy periods, it smooths more aggressively.

**Formula:**

$$\text{KAMA}_t = \text{KAMA}_{t-1} + SC \times (P_t - \text{KAMA}_{t-1})$$

where SC (smoothing constant) is calculated based on the Efficiency Ratio (ER):

$$\text{ER} = \frac{|\text{Change}|}{|\text{Volatility}|}$$

**Streaming Type:**

```nim
type KAMA* = ref object of Indicator[float64]

proc newKAMA*(period: int = 10, fastPeriod: int = 2, slowPeriod: int = 30, memSize: int = 1): KAMA
proc update*(kama: KAMA, value: float64): float64
```

**Parameters:**
- `period`: Lookback for efficiency ratio calculation
- `fastPeriod`: Fastest smoothing constant
- `slowPeriod`: Slowest smoothing constant

**Characteristics:**

KAMA's adaptive nature makes it effective across different market conditions. In trends, it hugs price closely. In ranges, it flattens out, producing fewer false signals. This adaptability comes at the cost of complexity and requires more historical data for stable results.

**Use cases:**
- Multi-market strategies (one MA for all conditions)
- Reducing whipsaws in ranging markets
- When market regime changes frequently

## Volume & Volatility Indicators

This section covers indicators that analyze volatility and volume flow.

### True Range (TRANGE)

True Range measures the full extent of price movement, including gaps between bars.

**Formula:**

$$\text{TR} = \max(H - L, |H - C_{prev}|, |L - C_{prev}|)$$

where H is current high, L is current low, and C_prev is previous close.

**Streaming Type:**

```nim
type TRANGE* = ref object of Indicator[float64]

proc newTRANGE*(): TRANGE
proc update*(tr: TRANGE, high, low, close: float64): float64
```

**Characteristics:**

True Range is the foundation for ATR and other volatility indicators. Unlike simple range (high - low), TR captures overnight gaps and intraday volatility, providing a complete picture of price movement.

**Use cases:**
- Component for ATR calculation
- Volatility spikes detection
- Understanding full price range per bar

### Normalized Average True Range (NATR)

NATR expresses ATR as a percentage of current price, enabling volatility comparison across different assets and price levels.

**Formula:**

$$\text{NATR} = \frac{\text{ATR}}{\text{Close}} \times 100$$

**Streaming Type:**

```nim
type NATR* = ref object of Indicator[float64]

proc newNATR*(period: int = 14, memSize: int = 1): NATR
proc update*(natr: NATR, high, low, close: float64): float64
```

**Characteristics:**

NATR solves the problem of comparing volatility across assets with different price levels. A $5 move in a $50 stock is much more significant than a $5 move in a $500 stock. NATR captures this by expressing volatility in percentage terms.

**Use cases:**
- Portfolio risk management
- Position sizing across multiple assets
- Volatility filters for multi-asset strategies
- Comparing trading opportunities across price levels

**Interpretation:**
- NATR < 2%: Low volatility
- NATR 2-5%: Normal volatility
- NATR > 5%: High volatility

### Accumulation/Distribution (AD)

AD measures buying and selling pressure by examining where prices close within the daily range and weighting by volume.

**Formula:**

$$\text{CLV} = \frac{(C - L) - (H - C)}{H - L}$$

$$\text{AD}_t = \text{AD}_{t-1} + \text{CLV} \times V$$

where CLV is the Close Location Value and V is volume.

**Streaming Type:**

```nim
type AD* = ref object of Indicator[float64]

proc newAD*(): AD
proc update*(ad: AD, high, low, close, volume: float64): float64
```

**Characteristics:**

AD is a cumulative indicator that tracks the flow of volume. When prices close near the high of the day, it adds to AD (accumulation). When prices close near the low, it subtracts from AD (distribution). The absolute value matters less than the trend direction.

**Use cases:**
- Confirming price trends (AD rises with price in uptrend)
- Detecting divergences (price rises but AD falls = warning)
- Identifying accumulation vs distribution phases
- Volume-based trend confirmation

**Interpretation:**
- AD rising: Accumulation (buying pressure)
- AD falling: Distribution (selling pressure)
- AD flat while price moves: Weak trend
- Divergence between AD and price: Potential reversal

### Aroon Indicator

Aroon measures time elapsed since the highest high and lowest low, identifying trend strength and potential reversals.

**Formula:**

$$\text{Aroon Up} = \frac{n - \text{periods since high}}{n} \times 100$$

$$\text{Aroon Down} = \frac{n - \text{periods since low}}{n} \times 100$$

$$\text{Aroon Oscillator} = \text{Aroon Up} - \text{Aroon Down}$$

**Streaming Type:**

```nim
type
  AroonResult* = object
    up*: float64
    down*: float64
    oscillator*: float64

  AROON* = ref object of Indicator[AroonResult]

proc newAROON*(period: int = 25, memSize: int = 1): AROON
proc update*(aroon: AROON, high, low: float64): AroonResult
```

**Characteristics:**

Aroon is unique in measuring time rather than price. A value of 100 means a new high/low just occurred. A value of 0 means the high/low occurred N periods ago. This time-based approach makes Aroon effective at identifying trend starts and exhaustion.

**Use cases:**
- Identifying trend strength (Aroon Up > 70 = strong uptrend)
- Detecting consolidation (both Aroon Up and Down < 50)
- Spotting reversals (Aroon Down crosses above 70 after uptrend)
- Trend confirmation

**Interpretation:**
- **Aroon Up > 70:** Strong uptrend (recent new highs)
- **Aroon Down > 70:** Strong downtrend (recent new lows)
- **Both < 50:** Ranging market, no clear trend
- **Oscillator > 0:** Bullish bias
- **Oscillator < 0:** Bearish bias

## Additional Momentum Indicators

This section covers additional advanced momentum measurements.

### Stochastic RSI (STOCHRSI)

STOCHRSI applies the Stochastic oscillator formula to RSI values, creating a more sensitive momentum indicator.

**Formula:**

First calculate RSI, then:

$$\text{StochRSI} = \frac{\text{RSI} - \text{RSI}_{\text{low}}}{\text{RSI}_{\text{high}} - \text{RSI}_{\text{low}}}$$

The result is smoothed with moving averages to produce %K and %D lines.

**Streaming Type:**

```nim
type STOCHRSI* = ref object of Indicator[StochResult]

proc newSTOCHRSI*(rsiPeriod: int = 14, period: int = 14, kPeriod: int = 3, dPeriod: int = 3, memSize: int = 1): STOCHRSI
proc update*(stochRsi: STOCHRSI, openPrice, closePrice: float64): StochResult
```

**Parameters:**
- `rsiPeriod`: Period for RSI calculation
- `period`: Lookback for Stochastic calculation
- `kPeriod`: Smoothing period for %K
- `dPeriod`: Smoothing period for %D

**Characteristics:**

STOCHRSI oscillates between 0 and 100 but moves faster than standard RSI. This sensitivity makes it useful for catching pullbacks in strong trends but also generates more false signals. It's particularly effective when RSI remains elevated (>50) during uptrends—STOCHRSI can still identify oversold conditions for entry.

**Use cases:**
- Finding entries during strong trends
- More sensitive overbought/oversold signals
- Short-term momentum trading
- Identifying pullbacks in trends

**Interpretation:**
- **%K < 20:** Oversold, potential buy
- **%K > 80:** Overbought, potential sell
- **%K crosses above %D:** Bullish signal
- **%K crosses below %D:** Bearish signal

### Percentage Price Oscillator (PPO)

PPO expresses MACD as a percentage, enabling comparison across assets with different price levels.

**Formula:**

$$\text{PPO} = \frac{\text{EMA}_{\text{fast}} - \text{EMA}_{\text{slow}}}{\text{EMA}_{\text{slow}}} \times 100$$

**Streaming Type:**

```nim
type
  PPOResult* = object
    ppo*: float64
    signal*: float64
    histogram*: float64

  PPO* = ref object of Indicator[PPOResult]

proc newPPO*(fastPeriod: int = 12, slowPeriod: int = 26, signalPeriod: int = 9, memSize: int = 1): PPO
proc update*(ppo: PPO, value: float64): PPOResult
```

**Characteristics:**

PPO works identically to MACD but normalizes values to percentages. This makes PPO more suitable for portfolio-level strategies or comparing momentum across different assets. A 2% PPO means roughly the same thing for a $10 stock and a $1000 stock.

**Use cases:**
- Multi-asset momentum strategies
- Portfolio-level momentum signals
- Comparing relative momentum across assets
- When MACD's absolute values aren't comparable

**Interpretation:**
- **PPO > 0:** Bullish momentum (fast EMA above slow)
- **PPO < 0:** Bearish momentum
- **PPO crosses above signal:** Buy signal
- **PPO crosses below signal:** Sell signal
- **Histogram expanding:** Momentum strengthening

### Chande Momentum Oscillator (CMO)

CMO measures momentum using the sum of gains versus losses rather than averages, providing a different perspective than RSI.

**Formula:**

$$\text{CMO} = \frac{\text{Sum of Gains} - \text{Sum of Losses}}{\text{Sum of Gains} + \text{Sum of Losses}} \times 100$$

**Streaming Type:**

```nim
type CMO* = ref object of Indicator[float64]

proc newCMO*(period: int = 14, memSize: int = 1): CMO
proc update*(cmo: CMO, close: float64): float64
```

**Characteristics:**

CMO ranges from -100 to +100, with zero as neutral. Unlike RSI which uses averages (smoothing the calculation), CMO uses raw sums, making it more responsive to momentum changes. The symmetric range around zero also makes interpretation intuitive—positive values are bullish, negative are bearish.

**Use cases:**
- Alternative to RSI with less smoothing
- Momentum extremes detection
- Mean reversion strategies
- Divergence analysis

**Interpretation:**
- **CMO > +50:** Strong upward momentum
- **CMO < -50:** Strong downward momentum
- **CMO between -20 and +20:** Weak momentum
- **Extreme readings (±80):** Potential exhaustion

### Momentum (MOM)

MOM is the simplest momentum indicator: current price minus price N periods ago.

**Formula:**

$$\text{MOM}_t = P_t - P_{t-n}$$

**Streaming Type:**

```nim
type MOM* = ref object of Indicator[float64]

proc newMOM*(period: int = 10, memSize: int = 1): MOM
proc update*(mom: MOM, price: float64): float64
```

**Characteristics:**

Despite its simplicity, MOM effectively captures momentum direction and magnitude. Positive values indicate upward momentum; negative indicate downward. The absolute value shows momentum strength. MOM forms the basis for more complex indicators like ROC (which expresses MOM as a percentage).

**Use cases:**
- Simple momentum confirmation
- Foundation for custom indicators
- Straightforward trend strength measurement
- When simplicity and transparency are priorities

**Interpretation:**
- **MOM > 0:** Upward momentum
- **MOM < 0:** Downward momentum
- **MOM increasing:** Accelerating momentum
- **MOM decreasing:** Decelerating momentum
- **MOM crossing zero:** Potential trend change

**MOM vs ROC:** MOM shows absolute point change while ROC shows percentage change. Use MOM when comparing the same asset over time. Use ROC when comparing different assets or the same asset at different price levels.

## Complete Indicator Summary

TzuTrader now provides 26 technical indicators across five categories:

**Trend Indicators:**
- MA (SMA), EMA, WMA, TRIMA, DEMA, TEMA, KAMA, MACD, PSAR

**Momentum Indicators:**
- RSI, ROC, STOCH, CMO, MOM, STOCHRSI

**Volatility Indicators:**
- ATR, STDEV, BB, TRANGE, NATR

**Volume Indicators:**
- OBV, MFI, AD

**Trend Strength:**
- CCI, ADX, AROON, PPO

All indicators follow the streaming-only architecture for O(1) memory usage and support real-time applications.

## See Also

- [Strategy Reference](04_strategies.md) - Using indicators in strategies
- [User Guide: Technical Indicators](../user_guide/03_indicators.md) - Conceptual introduction
- [Backtesting Engine](06_backtesting.md) - Testing indicator-based strategies
- [User Guide: Creating Strategies](../user_guide/04_strategies.md) - Practical indicator usage
