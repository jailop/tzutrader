# Building Trading Strategies

## What Makes a Trading Strategy

A trading strategy is a set of rules that determine when to buy, sell, or hold a security. These rules are based on market conditions, technical indicators, price patterns, or other factors.

A complete trading strategy specifies:
1. **Entry conditions**: When to open a position
2. **Exit conditions**: When to close a position
3. **Position sizing**: How much capital to allocate
4. **Risk management**: When to cut losses

In TzuTrader, strategies analyze market data and generate signals indicating whether to Buy, Sell, or Stay (do nothing). The backtesting engine then executes trades based on these signals.

## Strategy Signals

A signal is a trading recommendation produced by a strategy. It contains:

- **Position**: Buy, Sell, or Stay
- **Symbol**: Which security to trade
- **Price**: Current market price
- **Timestamp**: When the signal was generated
- **Reason**: Why the signal was generated (for analysis)

Example:
```
Signal(Buy AAPL @$150.25 at 2024-01-15 - RSI oversold: 28.5 < 30.0)
```

## Using Pre-built Strategies

TzuTrader includes four pre-built strategies that cover common trading approaches:

### RSI Strategy (Mean Reversion)

The RSI strategy trades based on overbought and oversold conditions:

```nim
import tzutrader

let strategy = newRSIStrategy(
  period = 14,        # Calculate RSI over 14 bars
  oversold = 30.0,    # Buy when RSI falls below 30
  overbought = 70.0   # Sell when RSI rises above 70
)
```

**Trading logic:**
- **Buy signal**: RSI drops below the oversold threshold (default 30)
- **Sell signal**: RSI rises above the overbought threshold (default 70)
- **Stay**: RSI is between thresholds

**When to use:**
- Range-bound markets (price oscillates without clear trend)
- Mean reversion opportunities (price tends to return to average)
- Shorter timeframes (minutes to days)

**Characteristics:**
- Generates frequent signals in volatile markets
- Can underperform in strong trends (price stays overbought/oversold)
- Simple to understand and implement

**Example:**
```nim
let data = readCSV("data/AAPL.csv")
let strategy = newRSIStrategy(period = 14, oversold = 30, overbought = 70)
let report = quickBacktest("AAPL", strategy, data, 100000.0, 0.001)
echo report.summary()
```

### Moving Average Crossover Strategy (Trend Following)

This strategy trades based on crossovers between fast and slow moving averages:

```nim
let strategy = newCrossoverStrategy(
  fastPeriod = 50,    # Fast moving average period
  slowPeriod = 200    # Slow moving average period
)
```

**Trading logic:**
- **Buy signal**: Fast MA crosses above slow MA (golden cross)
- **Sell signal**: Fast MA crosses below slow MA (death cross)
- **Stay**: No crossover occurred

**When to use:**
- Trending markets (price moves in one direction for extended periods)
- Longer timeframes (days to weeks)
- Following major trends

**Characteristics:**
- Generates infrequent signals (only at crossovers)
- Lags price movements (MAs use historical data)
- Works well in strong trends, poorly in choppy markets

**Common period combinations:**
- **50/200**: Classic long-term crossover
- **10/30**: Medium-term trading
- **5/20**: Short-term trading

**Example:**
```nim
let strategy = newCrossoverStrategy(fastPeriod = 50, slowPeriod = 200)
let report = quickBacktest("AAPL", strategy, data, 100000.0, 0.001)
```

### MACD Strategy (Momentum Shifts)

The MACD strategy trades when the MACD line crosses the signal line:

```nim
let strategy = newMACDStrategy(
  fastPeriod = 12,     # Fast EMA for MACD
  slowPeriod = 26,     # Slow EMA for MACD
  signalPeriod = 9     # Signal line EMA
)
```

**Trading logic:**
- **Buy signal**: MACD line crosses above signal line (bullish crossover)
- **Sell signal**: MACD line crosses below signal line (bearish crossover)
- **Stay**: No crossover occurred

**When to use:**
- Detecting momentum shifts
- Confirming trend changes
- Medium timeframes (hours to days)

**Characteristics:**
- More responsive than simple MA crossover
- Combines trend and momentum information
- Standard parameters (12/26/9) work across many markets

**Example:**
```nim
let strategy = newMACDStrategy(fastPeriod = 12, slowPeriod = 26, signalPeriod = 9)
let report = quickBacktest("AAPL", strategy, data, 100000.0, 0.001)
```

### Bollinger Bands Strategy (Mean Reversion)

This strategy trades when price touches the upper or lower Bollinger Band:

```nim
let strategy = newBollingerStrategy(
  period = 20,      # Middle band (SMA) period
  stdDev = 2.0      # Number of standard deviations for bands
)
```

**Trading logic:**
- **Buy signal**: Price touches or drops below lower band
- **Sell signal**: Price touches or rises above upper band
- **Stay**: Price is within bands

**When to use:**
- Range-bound markets
- Identifying extremes
- Mean reversion opportunities

**Characteristics:**
- Adapts to volatility automatically (bands widen in volatile markets)
- Works best in ranging markets
- Can generate false signals during breakouts

**Example:**
```nim
let strategy = newBollingerStrategy(period = 20, stdDev = 2.0)
let report = quickBacktest("AAPL", strategy, data, 100000.0, 0.001)
```

## Choosing the Right Strategy

Different market conditions favor different strategies:

### Trending Markets
- **Best**: Moving Average Crossover, MACD
- **Why**: These strategies ride trends and filter out noise
- **Avoid**: RSI, Bollinger Bands (give premature exit signals)

### Range-Bound Markets
- **Best**: RSI, Bollinger Bands
- **Why**: These strategies profit from price oscillations
- **Avoid**: Moving Average Crossover (generates false signals)

### High Volatility
- **Best**: Bollinger Bands, ATR-based strategies
- **Why**: These adapt to volatility
- **Considerations**: Wider stops, smaller positions

### Low Volatility
- **Best**: Breakout strategies, momentum indicators
- **Why**: Low volatility often precedes significant moves
- **Considerations**: May need patience for signals

No strategy works in all conditions. The market environment determines which approach is likely to succeed.

## Creating Custom Strategies

To create a custom strategy, inherit from the base `Strategy` class and implement the `onBar()` method:

```nim
import tzutrader
import std/strformat

type
  MyCustomStrategy* = ref object of Strategy
    # Add your strategy's state here
    threshold*: float64
    ma*: MA

proc newMyCustomStrategy*(threshold: float64, maPeriod: int = 20): MyCustomStrategy =
  result = MyCustomStrategy(
    name: "My Custom Strategy",
    threshold: threshold,
    ma: newMA(maPeriod)
  )

method onBar*(s: MyCustomStrategy, bar: OHLCV): Signal =
  ## Process one bar and generate signal
  # Update indicators
  let maVal = s.ma.update(bar.close)
  
  var position = Position.Stay
  var reason = ""
  
  # Your trading logic here
  if not maVal.isNaN:
    if bar.close > s.threshold and bar.close > maVal:
      position = Position.Buy
      reason = &"Price ${bar.close} above threshold ${s.threshold} and MA ${maVal}"
    elif bar.close < s.threshold or bar.close < maVal:
      position = Position.Sell
      reason = &"Price ${bar.close} below threshold ${s.threshold} or MA ${maVal}"
  
  result = Signal(
    position: position,
    symbol: s.symbol,
    timestamp: bar.timestamp,
    price: bar.close,
    reason: reason
  )
```

**Key points:**
- Store strategy parameters and indicators in the type definition
- Implement `onBar()` to process each bar
- Update indicators inside `onBar()` as data arrives
- Always return a `Signal` with position, price, and reason
- Use streaming indicators (newMA, newRSI, etc.)

### Example: Dual RSI Strategy

A more practical custom strategy that uses two RSI periods:

```nim
import tzutrader
import std/strformat

type
  DualRSIStrategy* = ref object of Strategy
    shortPeriod*: int
    longPeriod*: int
    shortRSI*: RSI
    longRSI*: RSI

proc newDualRSIStrategy*(shortPeriod: int = 7, longPeriod: int = 21): DualRSIStrategy =
  result = DualRSIStrategy(
    name: "Dual RSI Strategy",
    shortPeriod: shortPeriod,
    longPeriod: longPeriod,
    shortRSI: newRSI(shortPeriod),
    longRSI: newRSI(longPeriod)
  )

method onBar*(s: DualRSIStrategy, bar: OHLCV): Signal =
  let shortVal = s.shortRSI.update(bar.close)
  let longVal = s.longRSI.update(bar.close)
  
  var position = Position.Stay
  var reason = ""
  
  if not shortVal.isNaN and not longVal.isNaN:
    if shortVal < 30.0 and longVal < 40.0:
      position = Position.Buy
      reason = &"Both RSIs oversold: short={shortVal:.1f}, long={longVal:.1f}"
    elif shortVal > 70.0 and longVal > 60.0:
      position = Position.Sell
      reason = &"Both RSIs overbought: short={shortVal:.1f}, long={longVal:.1f}"
  
  result = Signal(
    position: position,
    symbol: s.symbol,
    timestamp: bar.timestamp,
    price: bar.close,
    reason: reason
  )

method reset*(s: DualRSIStrategy) =
  s.shortRSI = newRSI(s.shortPeriod)
  s.longRSI = newRSI(s.longPeriod)
  s.history = @[]
```

This strategy only generates signals when both short-term and long-term RSI agree, potentially reducing false signals.

## Strategy Development Tips

### Start Simple

Begin with straightforward logic. Add complexity only if it clearly improves results. Simple strategies are:
- Easier to understand
- Less likely to overfit
- More robust across different markets

### Use Meaningful Reasons

Always provide descriptive reasons in your signals:

```nim
# Good
reason = &"Golden cross: fast MA ({fastMA:.2f}) > slow MA ({slowMA:.2f})"

# Bad
reason = "Buy signal"
```

Good reasons help you understand why the strategy made decisions and identify issues during analysis.

### Test Incrementally

Don't write a complete complex strategy and then test it. Instead:
1. Start with basic logic
2. Backtest and verify it works
3. Add one feature
4. Backtest again
5. Repeat

This makes it easier to identify what helps and what doesn't.

### Consider Edge Cases

Handle situations where indicators aren't ready:

```nim
if not rsiValue.isNaN:
  # Use RSI value
else:
  # Not enough data yet
  position = Stay
```

### Avoid Look-Ahead Bias

Only use information available at the time of the decision. For example, don't use today's close price to make decisions earlier in the day.

## Next Steps

Now that you understand how to build strategies, the next chapter covers portfolio management - how strategies interact with capital allocation, position sizing, and performance tracking.

## Key Takeaways

- A trading strategy defines rules for when to buy, sell, or hold
- TzuTrader includes four pre-built strategies: RSI, MA Crossover, MACD, and Bollinger Bands
- Choose strategies that match market conditions (trending vs ranging)
- TzuTrader uses streaming architecture - same code for backtesting and live trading
- Create custom strategies by inheriting from the Strategy base class and implementing `onBar()`
- Start simple and add complexity only when justified
- Test incrementally and handle edge cases properly
- Avoid look-ahead bias in your trading logic
