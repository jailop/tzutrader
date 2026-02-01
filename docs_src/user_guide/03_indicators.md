# Understanding Technical Indicators

## What Technical Indicators Measure

Technical indicators are mathematical calculations based on price, volume, or other market data. They help traders identify patterns, trends, momentum, and potential trading opportunities that may not be obvious from price charts alone.

Indicators transform raw price data into actionable information. For example, instead of staring at hundreds of price bars trying to determine if momentum is building, an RSI indicator provides a single number between 0 and 100 that quantifies momentum.

Technical analysis assumes that price movements are not completely random and that historical patterns tend to repeat. Indicators attempt to identify these patterns mathematically.

## Indicator Categories

TzuTrader includes indicators across several categories:

### Trend Indicators

Trend indicators help identify the direction and strength of price movements. They answer the question: "Is the price generally going up, down, or sideways?"

Examples:

- Moving averages (SMA, EMA, WMA)
- MACD (Moving Average Convergence Divergence)

Use cases:

- Identifying trend direction
- Determining trend strength
- Spotting trend reversals

### Momentum Indicators

Momentum indicators measure the speed and strength of price changes. They help identify whether buying or selling pressure is building or waning.

Examples:

- RSI (Relative Strength Index)
- ROC (Rate of Change)

Use cases:

- Identifying overbought/oversold conditions
- Detecting divergences (price vs. momentum)
- Confirming trend strength

### Volatility Indicators

Volatility indicators measure how much and how quickly prices are changing. High volatility means prices are moving dramatically, while low volatility suggests stable prices.

Examples:

- ATR (Average True Range)
- Bollinger Bands
- Standard Deviation

Use cases:

- Setting stop-loss distances
- Adjusting position sizes
- Identifying breakout opportunities

### Volume Indicators

Volume indicators analyze trading activity. They help confirm price movements and identify potential reversals.

Examples:

- OBV (On-Balance Volume)
- AD (Accumulation/Distribution)
- MFI (Money Flow Index)

Use cases:

- Confirming price trends
- Detecting divergences
- Identifying accumulation/distribution

### Additional Indicators

TzuTrader includes 25 technical indicators across all major categories:

Advanced Moving Averages:

- TRIMA (Triangular MA) - Double-smoothed for minimal noise
- DEMA (Double Exponential MA) - Reduced lag
- TEMA (Triple Exponential MA) - Minimal lag
- KAMA (Kaufman Adaptive MA) - Adapts to market conditions

Advanced Momentum:

- STOCH (Stochastic Oscillator)
- CCI (Commodity Channel Index)
- CMO (Chande Momentum Oscillator)
- STOCHRSI (Stochastic RSI)
- MOM (Simple Momentum)

Volatility & Volume:

- TRANGE (True Range)
- NATR (Normalized ATR)
- AROON (Aroon Indicator)

Trend Analysis:

- ADX (Average Directional Index)
- PPO (Percentage Price Oscillator)

For complete details on all indicators, see the [Indicators Reference Guide](../reference_guide/03_indicators.md).

## Streaming Architecture

TzuTrader uses a streaming-only architecture where indicators update one data point at a time:

```nim
import tzutrader

var sma = newMA(period = 5)

# Process prices one at a time as they arrive
for price in incomingPrices:
  let currentSMA = sma.update(price)
  if not currentSMA.isNaN:
    echo "Current SMA: ", currentSMA
```

When to use (always!):

- Backtesting (process historical data sequentially)
- Live trading (process real-time data as it arrives)
- Analysis and research

Advantages:

- O(1) Memory: Constant memory usage, never grows
- O(1) Updates: Each new data point processed in constant time
- Unified API: Same code for backtesting and live trading
- Historical Access: Access previous values via `sma[-1]`, `sma[-2]`, etc.
- Production Ready: Can run indefinitely without memory issues
 
## Common Indicators Explained

This section explains the most fundamental indicators. TzuTrader provides 25 indicators in total—this section covers the essential ones to understand first. For complete coverage of all indicators, see the [Reference Guide](../reference_guide/03_indicators.md).

### Moving Averages

Moving averages smooth price data by calculating the average price over a specified period. As new prices arrive, old prices drop off, creating a "moving" average.

#### Simple Moving Average (SMA)

The arithmetic mean of the last N prices:

```nim
import tzutrader

var ma = newMA(period = 5)

# Update with prices as they arrive
for price in [100.0, 102.0, 104.0, 106.0, 108.0, 110.0]:
  let smaVal = ma.update(price)
  if not smaVal.isNaN:
    echo "SMA: ", smaVal

# After 5th price: SMA = (100 + 102 + 104 + 106 + 108) / 5 = 104.0
```

Characteristics:

- Treats all prices equally
- Smooth, but lags current price
- Easy to understand and interpret

Use cases:

- Identifying trend direction (price above MA = uptrend)
- Support and resistance levels
- Crossover strategies

#### Exponential Moving Average (EMA)

Gives more weight to recent prices:

```nim
var ema = newEMA(period = 5)

for price in prices:
  let emaVal = ema.update(price)
  if not emaVal.isNaN:
    echo "EMA: ", emaVal
```

Characteristics:

- More responsive to recent prices
- Less lag than SMA
- More complex calculation

Use cases:

- Faster trend identification
- Short-term trading
- MACD calculation

SMA vs EMA: SMA is simpler and smoother. EMA responds faster to price changes but can be more volatile. For long-term trends, SMA works well. For short-term trading, EMA may be preferable.

### RSI (Relative Strength Index)

RSI measures momentum on a scale of 0 to 100. It compares the magnitude of recent gains to recent losses.

```nim
import tzutrader

var rsi = newRSI(period = 14)

# Update with prices as they arrive
for price in [100.0, 102.0, 101.0, 103.0, 105.0, 104.0, 106.0, 108.0]:
  let rsiVal = rsi.update(open = price, close = price)
  if not rsiVal.isNaN:
    echo "RSI: ", rsiVal
```

Interpretation:

- Above 70: Overbought (may reverse downward)
- Below 30: Oversold (may reverse upward)
- 50: Neutral

Characteristics:

- Oscillates between 0 and 100
- Identifies momentum extremes
- Works best in ranging markets

Use cases:

- Mean reversion strategies (buy low, sell high)
- Divergence detection (price makes new high but RSI doesn't)
- Confirmation of trend strength

Limitations:

- Can stay overbought/oversold during strong trends
- Requires sufficient data (period + 1 bars minimum)
- Threshold levels (30/70) are conventional, not universal

### MACD (Moving Average Convergence Divergence)

MACD shows the relationship between two moving averages. It consists of three components:

1. MACD Line: Fast EMA minus slow EMA
2. Signal Line: EMA of the MACD line
3. Histogram: MACD line minus signal line

```nim
import tzutrader

var macd = newMACD(fast = 12, slow = 26, signal = 9)

for price in prices:
  let macdResult = macd.update(price)
  if not macdResult.macd.isNaN:
    echo "MACD: ", macdResult.macd
    echo "Signal: ", macdResult.signal
    echo "Histogram: ", macdResult.histogram
```

Interpretation:

- MACD crosses above signal: Bullish (potential buy)
- MACD crosses below signal: Bearish (potential sell)
- Histogram expanding: Trend strengthening
- Histogram contracting: Trend weakening

Use cases:

- Trend following strategies
- Crossover signals
- Momentum confirmation

Characteristics:

- Combines trend and momentum
- No upper/lower bounds
- Requires substantial historical data

### Bollinger Bands

Bollinger Bands plot a middle band (SMA) with upper and lower bands at N standard deviations away:

```nim
import tzutrader

let prices = @[/* ... */]
let (upper, middle, lower) = bollinger(prices, period = 20, stdDev = 2.0)
```

Interpretation:

- Price at upper band: Potentially overbought
- Price at lower band: Potentially oversold
- Bands narrow: Low volatility (squeeze)
- Bands wide: High volatility

Use cases:

- Mean reversion (buy at lower band, sell at upper band)
- Breakout detection (price moves outside bands)
- Volatility assessment

Characteristics:

- Adapts to volatility automatically
- Provides context (bands are relative to recent price action)
- Works in both trending and ranging markets

### Average True Range (ATR)

ATR measures volatility by calculating the average range of price movement:

```nim
import tzutrader

let data = readCSV("data/AAPL.csv")
let highs = data.mapIt(it.high)
let lows = data.mapIt(it.low)
let closes = data.mapIt(it.close)

let atrValues = atr(highs, lows, closes, period = 14)
```

Interpretation:

- Higher ATR = Higher volatility
- Lower ATR = Lower volatility

Use cases:

- Setting stop-loss distances (e.g., 2x ATR)
- Position sizing (reduce size when volatility increases)
- Identifying consolidation vs. breakout periods

Characteristics:

- Not directional (doesn't indicate trend)
- Absolute value (depends on price level)
- Smoothed, not reactive to single outliers

## Choosing Indicator Periods

Most indicators have a "period" parameter that controls how much historical data they use. Shorter periods are more responsive but noisier. Longer periods are smoother but lag more.

Common conventions:

- Short term: 5-20 periods
- Medium term: 20-50 periods
- Long term: 50-200 periods

Example:

- SMA(10) responds quickly but gives many signals
- SMA(200) is very smooth but slow to react

Guidance:

- Start with conventional values (RSI: 14, SMA: 50/200, MACD: 12/26/9)
- Match period to your trading timeframe (day traders use shorter periods)
- Avoid excessive optimization (testing hundreds of period combinations)

The "best" period depends on the market, timeframe, and strategy. No single value works universally.

## Avoiding Over-Optimization

It's tempting to test many indicator combinations and choose the one that performed best historically. This practice, called over-optimization or curve-fitting, creates strategies that work great on past data but fail on new data.

Warning signs:

- Testing 50+ parameter combinations
- Choosing parameters based solely on backtest results
- Complex rules added to handle specific historical events
- Strategy performs much better than simple buy-and-hold

Better approach:

- Use conventional indicator settings as a starting point
- Make small, logical adjustments if needed
- Test on out-of-sample data (data not used for development)
- Keep strategies simple

## Combining Indicators

Strategies often combine multiple indicators to confirm signals. For example:

- Use MACD for trend direction
- Use RSI to time entries
- Use ATR for stop-loss placement

However, more indicators don't guarantee better results. Each additional indicator adds complexity and can lead to fewer trading opportunities.

Guideline: Start with one or two indicators. Add more only if they clearly improve results and make logical sense together.

## Indicator Limitations

Technical indicators have inherent limitations:

1. Historical data only: Indicators use past prices to predict future movements, which isn't always reliable
2. Lag: Most indicators lag price, meaning signals occur after moves have started
3. False signals: No indicator is 100% accurate
4. Market regime dependence: Indicators that work in trending markets may fail in ranging markets
5. No context: Indicators don't know about earnings reports, economic data, or other fundamental factors

Indicators are tools for systematic decision-making, not crystal balls. They work best when combined with proper risk management and realistic expectations.

## Next Steps

Now that you understand how indicators work, the next chapter covers building trading strategies that use indicators to make buy and sell decisions.

## Key Takeaways

- Technical indicators transform price data into actionable signals
- Different indicator categories measure trends, momentum, volatility, and volume
- TzuTrader uses a streaming architecture - same code for backtesting and live trading
- Moving averages identify trends, RSI measures momentum, MACD combines both
- Bollinger Bands adapt to volatility, ATR measures it directly
- Start with conventional indicator periods and avoid over-optimization
- Indicators have limitations and should be combined with risk management
- More indicators don't necessarily mean better strategies
