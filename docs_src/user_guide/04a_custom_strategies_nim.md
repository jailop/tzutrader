# Writing Custom Strategies with Nim

## Introduction

While TzuTrader includes 16 pre-built strategies, they are **reference examples** to help you understand how strategies work. As a retail or small investor, you'll likely want to create strategies tailored to your specific trading ideas, risk tolerance, and market conditions.

This guide teaches you how to write custom trading strategies in Nim, even if you're not an expert programmer.

!!! tip "When to Use Nim vs YAML"
    - **Use Nim** when you need: complex logic, custom calculations, state management, or integration with other code
    - **Use YAML** when you need: simple indicator-based rules without programming (see [Writing Custom Strategies with YAML](04b_custom_strategies_yaml.md))

!!! info "New to Nim?"
    Nim is a modern language with Python-like syntax but C-like performance. If you can read Python, you can read Nim! The examples in this guide are designed to be self-explanatory. For more about why TzuTrader uses Nim, see **[Why Nim?](../about_nim.md)**

## What is a Strategy?

A trading strategy in TzuTrader is a Nim object that:

1. **Analyzes market data** - Looks at prices, volumes, and technical indicators
2. **Generates signals** - Decides whether to Buy, Sell, or Stay (do nothing)
3. **Manages state** - Remembers previous conditions across multiple bars

Every strategy implements the `Strategy` interface, which provides a standard way to process market data and generate trading signals.

## The Strategy Interface

All strategies must provide two core methods:

```nim
type
  Strategy* = ref object of RootObj
    ## Base strategy type - inherit from this

method update*(s: Strategy, bar: OHLCV): void {.base.} =
  ## Update indicators with new market data
  ## Called once per bar before signal generation
  discard

method signal*(s: Strategy, bar: OHLCV): Signal {.base.} =
  ## Generate trading signal based on current conditions
  ## Returns: Buy, Sell, or Stay signal
  discard
```

**Key concepts:**

- `update()` - Called first to update indicators with new data
- `signal()` - Called second to generate Buy/Sell/Stay decision
- Both receive the current bar (timestamp, open, high, low, close, volume)

## Your First Custom Strategy

Let's build a simple momentum strategy: buy when price closes above yesterday's high, sell when it closes below yesterday's low.

### Step 1: Define the Strategy Type

```nim
import tzutrader

type
  MomentumBreakoutStrategy* = ref object of Strategy
    ## Buys on upward breakouts, sells on downward breakouts
    prevHigh: float64      # Yesterday's high
    prevLow: float64       # Yesterday's low
    initialized: bool      # Have we seen at least one bar?
```

**What this does:**

- Inherits from `Strategy` to get the standard interface
- Stores `prevHigh` and `prevLow` to remember yesterday's range
- Uses `initialized` flag to skip the first bar (no "yesterday" yet)

### Step 2: Create a Constructor

```nim
proc newMomentumBreakoutStrategy*(): MomentumBreakoutStrategy =
  ## Create a new momentum breakout strategy
  result = MomentumBreakoutStrategy(
    prevHigh: 0.0,
    prevLow: 0.0,
    initialized: false
  )
```

**What this does:**

- Creates and initializes a new strategy instance
- Sets default values for all fields
- The `*` makes it publicly available to other modules

### Step 3: Implement update()

```nim
method update*(s: MomentumBreakoutStrategy, bar: OHLCV) =
  ## Update with new bar data
  if s.initialized:
    # Remember today's high/low for tomorrow's signals
    s.prevHigh = bar.high
    s.prevLow = bar.low
  else:
    # First bar: initialize but don't generate signals yet
    s.prevHigh = bar.high
    s.prevLow = bar.low
    s.initialized = true
```

**What this does:**

- Stores current bar's high/low for the next bar's signal
- On first bar, just initializes values without trading

### Step 4: Implement signal()

```nim
method signal*(s: MomentumBreakoutStrategy, bar: OHLCV): Signal =
  ## Generate trading signal
  
  # Don't trade on first bar
  if not s.initialized:
    return Signal(position: Stay, price: bar.close, 
                  timestamp: bar.timestamp, reason: "Initializing")
  
  # Buy on upward breakout
  if bar.close > s.prevHigh:
    return Signal(
      position: Buy,
      price: bar.close,
      timestamp: bar.timestamp,
      reason: "Breakout: close " & $bar.close & " > prev high " & $s.prevHigh
    )
  
  # Sell on downward breakout
  elif bar.close < s.prevLow:
    return Signal(
      position: Sell,
      price: bar.close,
      timestamp: bar.timestamp,
      reason: "Breakdown: close " & $bar.close & " < prev low " & $s.prevLow
    )
  
  # No signal - price within yesterday's range
  else:
    return Signal(
      position: Stay,
      price: bar.close,
      timestamp: bar.timestamp,
      reason: "No breakout"
    )
```

**What this does:**

- Compares current close to yesterday's high/low range
- Returns Buy signal when price breaks above
- Returns Sell signal when price breaks below
- Returns Stay when price is within range
- Includes reason for debugging and analysis

### Step 5: Test Your Strategy

```nim
# Load data
let data = readCSV("data/AAPL.csv")

# Create strategy
let strategy = newMomentumBreakoutStrategy()

# Run backtest
let report = quickBacktest(
  symbol = "AAPL",
  strategy = strategy,
  data = data,
  initialCash = 100000.0,
  commission = 0.001  # 0.1% commission
)

# Display results
echo report.summary()
```

**Output:**
```
Backtest Report: AAPL
Total Return:     15.23%
Sharpe Ratio:     1.42
Max Drawdown:     -12.34%
Win Rate:         52.10%
Total Trades:     87
```

## Complete Example

Here's the full strategy code in one file:

```nim
import tzutrader

type
  MomentumBreakoutStrategy* = ref object of Strategy
    prevHigh: float64
    prevLow: float64
    initialized: bool

proc newMomentumBreakoutStrategy*(): MomentumBreakoutStrategy =
  result = MomentumBreakoutStrategy(
    prevHigh: 0.0,
    prevLow: 0.0,
    initialized: false
  )

method update*(s: MomentumBreakoutStrategy, bar: OHLCV) =
  if s.initialized:
    s.prevHigh = bar.high
    s.prevLow = bar.low
  else:
    s.prevHigh = bar.high
    s.prevLow = bar.low
    s.initialized = true

method signal*(s: MomentumBreakoutStrategy, bar: OHLCV): Signal =
  if not s.initialized:
    return Signal(position: Stay, price: bar.close, 
                  timestamp: bar.timestamp, reason: "Initializing")
  
  if bar.close > s.prevHigh:
    return Signal(position: Buy, price: bar.close,
                  timestamp: bar.timestamp,
                  reason: "Breakout: " & $bar.close & " > " & $s.prevHigh)
  
  elif bar.close < s.prevLow:
    return Signal(position: Sell, price: bar.close,
                  timestamp: bar.timestamp,
                  reason: "Breakdown: " & $bar.close & " < " & $s.prevLow)
  
  else:
    return Signal(position: Stay, price: bar.close,
                  timestamp: bar.timestamp, reason: "No breakout")

# Test it
when isMainModule:
  let data = readCSV("data/AAPL.csv")
  let strategy = newMomentumBreakoutStrategy()
  let report = quickBacktest("AAPL", strategy, data, 100000.0, 0.001)
  echo report.summary()
```

Save this as `momentum_strategy.nim` and run:
```bash
nim c -r momentum_strategy.nim
```

## Using Technical Indicators

Most strategies use technical indicators like RSI, MACD, or moving averages. TzuTrader provides 40+ indicators that integrate seamlessly with strategies.

### Example: RSI with Custom Thresholds

Let's create a more flexible RSI strategy with configurable parameters:

```nim
import tzutrader

type
  CustomRSIStrategy* = ref object of Strategy
    rsi: RSI                    # The RSI indicator
    oversold: float64          # Buy threshold (e.g., 25)
    overbought: float64        # Sell threshold (e.g., 75)
    period: int                # RSI calculation period

proc newCustomRSIStrategy*(
  period: int = 14,
  oversold: float64 = 30.0,
  overbought: float64 = 70.0
): CustomRSIStrategy =
  ## Create RSI strategy with custom parameters
  result = CustomRSIStrategy(
    rsi: newRSI(period),
    oversold: oversold,
    overbought: overbought,
    period: period
  )

method update*(s: CustomRSIStrategy, bar: OHLCV) =
  ## Update RSI indicator with new price
  s.rsi.update(bar.close)

method signal*(s: CustomRSIStrategy, bar: OHLCV): Signal =
  ## Generate signal based on RSI thresholds
  
  # Get current RSI value
  let rsiValue = s.rsi.getValue()
  
  # Generate signals
  if rsiValue < s.oversold:
    return Signal(
      position: Buy,
      price: bar.close,
      timestamp: bar.timestamp,
      reason: "RSI oversold: " & $rsiValue & " < " & $s.oversold
    )
  
  elif rsiValue > s.overbought:
    return Signal(
      position: Sell,
      price: bar.close,
      timestamp: bar.timestamp,
      reason: "RSI overbought: " & $rsiValue & " > " & $s.overbought
    )
  
  else:
    return Signal(
      position: Stay,
      price: bar.close,
      timestamp: bar.timestamp,
      reason: "RSI neutral: " & $rsiValue
    )

# Test with different parameters
when isMainModule:
  let data = readCSV("data/AAPL.csv")
  
  # Conservative (wide thresholds)
  let conservative = newCustomRSIStrategy(14, 25.0, 75.0)
  let report1 = quickBacktest("AAPL", conservative, data, 100000.0, 0.001)
  echo "Conservative: ", report1.summary()
  
  # Aggressive (narrow thresholds)
  let aggressive = newCustomRSIStrategy(14, 35.0, 65.0)
  let report2 = quickBacktest("AAPL", aggressive, data, 100000.0, 0.001)
  echo "Aggressive: ", report2.summary()
```

**Key points:**

- Indicators are created in the constructor
- `update()` feeds data to the indicator
- `signal()` reads indicator values with `getValue()`
- Parameters make the strategy flexible and testable

## Multi-Indicator Strategies

Real trading strategies often combine multiple indicators for confirmation. Here's how to build a strategy that uses both RSI and MACD:

```nim
import tzutrader

type
  RSIMACDStrategy* = ref object of Strategy
    rsi: RSI
    macd: MACD
    rsiOversold: float64
    rsiOverbought: float64

proc newRSIMACDStrategy*(
  rsiPeriod: int = 14,
  rsiOversold: float64 = 30.0,
  rsiOverbought: float64 = 70.0,
  macdFast: int = 12,
  macdSlow: int = 26,
  macdSignal: int = 9
): RSIMACDStrategy =
  result = RSIMACDStrategy(
    rsi: newRSI(rsiPeriod),
    macd: newMACD(macdFast, macdSlow, macdSignal),
    rsiOversold: rsiOversold,
    rsiOverbought: rsiOverbought
  )

method update*(s: RSIMACDStrategy, bar: OHLCV) =
  ## Update both indicators
  s.rsi.update(bar.close)
  s.macd.update(bar.close)

method signal*(s: RSIMACDStrategy, bar: OHLCV): Signal =
  ## Require both RSI and MACD confirmation
  
  let rsiValue = s.rsi.getValue()
  let macdLine = s.macd.getValue("macd")
  let signalLine = s.macd.getValue("signal")
  
  # Buy: RSI oversold AND MACD bullish crossover
  if rsiValue < s.rsiOversold and macdLine > signalLine:
    return Signal(
      position: Buy,
      price: bar.close,
      timestamp: bar.timestamp,
      reason: "RSI oversold (" & $rsiValue & ") + MACD bullish"
    )
  
  # Sell: RSI overbought AND MACD bearish crossover
  elif rsiValue > s.rsiOverbought and macdLine < signalLine:
    return Signal(
      position: Sell,
      price: bar.close,
      timestamp: bar.timestamp,
      reason: "RSI overbought (" & $rsiValue & ") + MACD bearish"
    )
  
  else:
    return Signal(
      position: Stay,
      price: bar.close,
      timestamp: bar.timestamp,
      reason: "No confirmation"
    )
```

**Benefits of multi-indicator strategies:**

- Reduces false signals (confirmation required)
- Combines different market perspectives (momentum + trend)
- More robust across different market conditions

## State Management

Some strategies need to track conditions across multiple bars. Here's a strategy that only trades after seeing 3 consecutive higher closes:

```nim
import tzutrader

type
  ThreeBarMomentumStrategy* = ref object of Strategy
    consecutiveBars: int      # Count of higher closes
    prevClose: float64        # Previous bar's close

proc newThreeBarMomentumStrategy*(): ThreeBarMomentumStrategy =
  result = ThreeBarMomentumStrategy(
    consecutiveBars: 0,
    prevClose: 0.0
  )

method update*(s: ThreeBarMomentumStrategy, bar: OHLCV) =
  ## Track consecutive higher/lower closes
  
  if s.prevClose > 0:  # Not first bar
    if bar.close > s.prevClose:
      s.consecutiveBars += 1
    elif bar.close < s.prevClose:
      s.consecutiveBars -= 1
    else:
      s.consecutiveBars = 0  # Reset on equal close
  
  s.prevClose = bar.close

method signal*(s: ThreeBarMomentumStrategy, bar: OHLCV): Signal =
  ## Trade only after strong momentum
  
  if s.consecutiveBars >= 3:
    return Signal(
      position: Buy,
      price: bar.close,
      timestamp: bar.timestamp,
      reason: "Strong uptrend: " & $s.consecutiveBars & " higher closes"
    )
  
  elif s.consecutiveBars <= -3:
    return Signal(
      position: Sell,
      price: bar.close,
      timestamp: bar.timestamp,
      reason: "Strong downtrend: " & $s.consecutiveBars & " lower closes"
    )
  
  else:
    return Signal(
      position: Stay,
      price: bar.close,
      timestamp: bar.timestamp,
      reason: "Weak momentum: " & $s.consecutiveBars & " bars"
    )
```

**State management tips:**

- Store necessary data in strategy object fields
- Update state in `update()` method
- Use state in `signal()` to make decisions
- Remember to reset state when needed

## Advanced: Using Volume

Volume can confirm price movements. Here's a strategy that requires high volume for signals:

```nim
import tzutrader

type
  VolumeConfirmedStrategy* = ref object of Strategy
    sma: SMA                  # Moving average of price
    volumeSMA: SMA            # Moving average of volume
    multiplier: float64       # Volume threshold multiplier

proc newVolumeConfirmedStrategy*(
  period: int = 20,
  volumeMultiplier: float64 = 1.5
): VolumeConfirmedStrategy =
  result = VolumeConfirmedStrategy(
    sma: newSMA(period),
    volumeSMA: newSMA(period),
    multiplier: volumeMultiplier
  )

method update*(s: VolumeConfirmedStrategy, bar: OHLCV) =
  ## Update both price and volume moving averages
  s.sma.update(bar.close)
  s.volumeSMA.update(bar.volume)

method signal*(s: VolumeConfirmedStrategy, bar: OHLCV): Signal =
  ## Trade only with volume confirmation
  
  let priceMA = s.sma.getValue()
  let volumeMA = s.volumeSMA.getValue()
  let highVolume = bar.volume > (volumeMA * s.multiplier)
  
  # Buy: price above MA with high volume
  if bar.close > priceMA and highVolume:
    return Signal(
      position: Buy,
      price: bar.close,
      timestamp: bar.timestamp,
      reason: "Breakout with volume: " & $bar.volume & " > " & $volumeMA
    )
  
  # Sell: price below MA with high volume
  elif bar.close < priceMA and highVolume:
    return Signal(
      position: Sell,
      price: bar.close,
      timestamp: bar.timestamp,
      reason: "Breakdown with volume: " & $bar.volume & " > " & $volumeMA
    )
  
  else:
    return Signal(
      position: Stay,
      price: bar.close,
      timestamp: bar.timestamp,
      reason: "Low volume or no trend"
    )
```

## Strategy Reset

When running multiple backtests with the same strategy instance, call `reset()` to clear state:

```nim
method reset*(s: Strategy) {.base.} =
  ## Override this to reset strategy state
  discard

# Example implementation:
method reset*(s: CustomRSIStrategy) =
  s.rsi.reset()  # Reset indicator
```

This is automatically called by the backtesting engine when needed.

## Best Practices

### 1. Keep Strategies Simple

```nim
# Good: Clear, focused logic
if rsi < 30:
  return buySignal()

# Avoid: Too many conditions
if rsi < 30 and macd > signal and volume > avgVolume and 
   price > sma20 and price < sma50 and ...
```

### 2. Use Meaningful Reasons

```nim
# Good: Descriptive reason
reason: "RSI oversold: 28.5 < 30.0"

# Avoid: Generic reason
reason: "Buy signal"
```

### 3. Handle Edge Cases

```nim
# Check for invalid indicator values
let rsiValue = s.rsi.getValue()
if rsiValue.isNaN or rsiValue < 0:
  return Signal(position: Stay, ...)
```

### 4. Test Thoroughly

```nim
# Test with different:
# - Time periods (bull/bear markets)
# - Symbols (stocks, crypto, commodities)
# - Parameters (optimize thresholds)
# - Commissions (realistic costs)

let symbols = @["AAPL", "MSFT", "GOOGL"]
for symbol in symbols:
  let data = readCSV("data/" & symbol & ".csv")
  let report = quickBacktest(symbol, strategy, data, 100000.0, 0.001)
  echo symbol, ": ", report.totalReturn
```

### 5. Document Your Strategy

```nim
## Custom Momentum Strategy
## 
## Entry: Price breaks above yesterday's high
## Exit: Price breaks below yesterday's low
## 
## Best for: Trending markets with clear breakouts
## Avoid: Choppy, range-bound markets
## 
## Parameters: None (pure price action)
```

## Common Pitfalls

### ❌ Looking into the Future

```nim
# WRONG: Using future data (bar.close not yet available)
if s.nextBar.close > bar.close:
  return buySignal()

# CORRECT: Only use current and past data
if bar.close > s.prevClose:
  return buySignal()
```

### ❌ Forgetting to Update Indicators

```nim
# WRONG: Signal without updating
method signal*(s: Strategy, bar: OHLCV): Signal =
  return Signal(...)  # RSI never updated!

# CORRECT: Update in update() method
method update*(s: Strategy, bar: OHLCV) =
  s.rsi.update(bar.close)  # Update before signal
```

### ❌ Not Handling Initialization

```nim
# WRONG: Using indicator before enough data
let rsiValue = s.rsi.getValue()  # Might be NaN on first bars

# CORRECT: Check if indicator is ready
if not s.rsi.isReady():
  return Signal(position: Stay, ...)
```

## Next Steps

- **Try the examples**: Modify the strategies above and test with your own data
- **Read pre-built strategies**: Check `src/tzutrader/strategy.nim` for more examples
- **Learn indicators**: See [Technical Indicators](03_indicators.md) for all available indicators
- **Try YAML strategies**: For simpler rules, see [Writing Custom Strategies with YAML](04b_custom_strategies_yaml.md)
- **Optimize parameters**: Use parameter sweeps to find best settings (see [CLI Reference](../reference_guide/09_cli.md))

## Summary

**Creating a custom strategy in Nim requires:**

1. Define a type inheriting from `Strategy`
2. Create a constructor (`newMyStrategy()`)
3. Implement `update()` to process new data
4. Implement `signal()` to generate Buy/Sell/Stay signals
5. Test with `quickBacktest()`

**Remember:**

- Pre-built strategies are just examples - customize them!
- Start simple, add complexity gradually
- Always test with realistic commissions
- Use meaningful signal reasons for debugging
- Combine indicators for confirmation

Happy trading! 🚀
