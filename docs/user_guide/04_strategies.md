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

**Note:** Bollinger strategy uses batch mode internally because it needs the full history to calculate standard deviations properly.

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

## Strategy Modes: Batch vs Streaming

Strategies can operate in two modes:

### Batch Mode (analyze method)

Process all historical data at once:

```nim
let strategy = newRSIStrategy(period = 14, oversold = 30, overbought = 70)
let data = readCSV("data/AAPL.csv")

# Analyze all bars, get all signals
let signals = strategy.analyze(data)

for i, signal in signals:
  if signal.position != Stay:
    echo "Bar ", i, ": ", signal.position, " at $", signal.price
```

**Use for:**
- Backtesting
- Research and analysis
- Batch processing

### Streaming Mode (onBar method)

Process data one bar at a time:

```nim
let strategy = newRSIStrategy(period = 14, oversold = 30, overbought = 70)

for bar in dataStream:
  let signal = strategy.onBar(bar)
  if signal.position == Buy:
    echo "Buy signal at $", bar.close
  elif signal.position == Sell:
    echo "Sell signal at $", bar.close
```

**Use for:**
- Live trading bots
- Real-time monitoring
- Processing data as it arrives

Both modes should produce the same signals for the same data. Use batch mode for backtesting simplicity, streaming mode for live trading realism.

## Creating Custom Strategies

To create a custom strategy, inherit from the base `Strategy` class and implement the required methods:

```nim
import tzutrader
import std/strformat

type
  MyCustomStrategy* = ref object of Strategy
    # Add your strategy's state here
    threshold*: float64

proc newMyCustomStrategy*(threshold: float64): MyCustomStrategy =
  result = MyCustomStrategy(
    name: "My Custom Strategy",
    threshold: threshold,
    history: @[]
  )

method analyze*(s: MyCustomStrategy, data: seq[OHLCV]): seq[Signal] =
  ## Batch mode: analyze all data
  result = @[]
  
  for bar in data:
    var position = Position.Stay
    var reason = ""
    
    # Your trading logic here
    if bar.close > s.threshold:
      position = Position.Buy
      reason = &"Price ${bar.close} above threshold ${s.threshold}"
    elif bar.close < s.threshold:
      position = Position.Sell
      reason = &"Price ${bar.close} below threshold ${s.threshold}"
    
    result.add(Signal(
      position: position,
      symbol: s.symbol,
      timestamp: bar.timestamp,
      price: bar.close,
      reason: reason
    ))

method onBar*(s: MyCustomStrategy, bar: OHLCV): Signal =
  ## Streaming mode: process one bar
  s.history.add(bar)
  
  var position = Position.Stay
  var reason = ""
  
  # Your trading logic here
  if bar.close > s.threshold:
    position = Position.Buy
    reason = &"Price ${bar.close} above threshold ${s.threshold}"
  elif bar.close < s.threshold:
    position = Position.Sell
    reason = &"Price ${bar.close} below threshold ${s.threshold}"
  
  result = Signal(
    position: position,
    symbol: s.symbol,
    timestamp: bar.timestamp,
    price: bar.close,
    reason: reason
  )

method reset*(s: MyCustomStrategy) =
  ## Reset strategy state
  s.history = @[]
```

**Key points:**
- Store strategy parameters in the type definition
- Implement `analyze()` for batch mode
- Implement `onBar()` for streaming mode
- Use `reset()` to clear state between runs
- Store historical bars in `history` if needed
- Always return a `Signal` with position, price, and reason

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
    longRSI: newRSI(longPeriod),
    history: @[]
  )

method analyze*(s: DualRSIStrategy, data: seq[OHLCV]): seq[Signal] =
  let prices = data.mapIt(it.close)
  let shortRSI = rsi(prices, s.shortPeriod)
  let longRSI = rsi(prices, s.longPeriod)
  
  result = @[]
  for i, bar in data:
    var position = Position.Stay
    var reason = ""
    
    if not shortRSI[i].isNaN and not longRSI[i].isNaN:
      # Buy when both RSIs are oversold
      if shortRSI[i] < 30.0 and longRSI[i] < 40.0:
        position = Position.Buy
        reason = &"Both RSIs oversold: short={shortRSI[i]:.1f}, long={longRSI[i]:.1f}"
      # Sell when both RSIs are overbought
      elif shortRSI[i] > 70.0 and longRSI[i] > 60.0:
        position = Position.Sell
        reason = &"Both RSIs overbought: short={shortRSI[i]:.1f}, long={longRSI[i]:.1f}"
    
    result.add(Signal(
      position: position,
      symbol: s.symbol,
      timestamp: bar.timestamp,
      price: bar.close,
      reason: reason
    ))

method onBar*(s: DualRSIStrategy, bar: OHLCV): Signal =
  s.history.add(bar)
  
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
- Use batch mode for backtesting, streaming mode for live trading
- Create custom strategies by inheriting from the Strategy base class
- Start simple and add complexity only when justified
- Test incrementally and handle edge cases properly
- Avoid look-ahead bias in your trading logic
