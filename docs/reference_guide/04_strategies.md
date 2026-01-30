# Reference Guide: Trading Strategies

## Overview

Strategies in TzuTrader analyze market data and generate trading signals. The framework provides a base `Strategy` class for building custom strategies and includes four pre-built strategies for common trading approaches.

A strategy's core responsibility is simple: given market data, decide whether to buy, sell, or stay out. TzuTrader handles everything else—executing trades, managing positions, tracking performance.

**Module:** `tzutrader/strategy.nim`

## Strategy Fundamentals

### The Strategy Interface

All strategies inherit from the base `Strategy` class and implement three key methods:

```nim
method analyze*(s: Strategy, data: seq[OHLCV]): seq[Signal]
method onBar*(s: Strategy, bar: OHLCV): Signal
method reset*(s: Strategy)
```

**Two execution modes:**

- **Batch mode** (`analyze`): Process entire historical dataset at once
- **Streaming mode** (`onBar`): Process bars one at a time as they arrive

Most backtesting uses batch mode. Streaming mode is for live trading or when simulating real-time conditions where future bars aren't available.

### Base Strategy Type

```nim
type
  Strategy* = ref object of RootObj
    name*: string
    symbol*: string
    history*: seq[OHLCV]
```

**Fields:**
- `name`: Human-readable strategy identifier
- `symbol`: Target symbol (optional, can trade multiple symbols)
- `history`: Bar history maintained by streaming mode

### Method Specifications

#### analyze (Batch Mode)

```nim
method analyze*(s: Strategy, data: seq[OHLCV]): seq[Signal]
```

**Purpose:** Analyze complete historical data and generate signals for all bars.

**Parameters:**
- `data`: Full OHLCV sequence in chronological order

**Returns:** Signal sequence with one entry per bar (same length as input)

**Use cases:**
- Historical backtesting
- Parameter optimization (faster than streaming)
- Analyzing completed data

**Example:**

```nim
let strategy = newRSIStrategy()
let data = readCSV("data/AAPL.csv")
let signals = strategy.analyze(data)

for signal in signals:
  if signal.position != Stay:
    echo signal.timestamp.fromUnix.format("yyyy-MM-dd"), ": ", signal.reason
```

#### onBar (Streaming Mode)

```nim
method onBar*(s: Strategy, bar: OHLCV): Signal
```

**Purpose:** Process a single bar and generate a signal without knowing future bars.

**Parameters:**
- `bar`: Current OHLCV bar

**Returns:** Single signal for the bar

**Use cases:**
- Live trading
- Real-time simulation
- Testing strategy behavior bar-by-bar

**State management:** Strategies maintain internal state (indicator values, last signals, etc.) across `onBar` calls. Call `reset()` before starting a new sequence.

**Example:**

```nim
let strategy = newMACDStrategy()
strategy.reset()

for bar in data:
  let signal = strategy.onBar(bar)
  if signal.position == Buy:
    echo "BUY signal at ", bar.close
```

#### reset

```nim
method reset*(s: Strategy)
```

**Purpose:** Clear strategy state for starting fresh.

**When to call:**
- Before beginning a new streaming session
- Between backtests using the same strategy instance
- When switching symbols

**What gets reset:**
- Indicator states
- Bar history
- Last signal tracking
- Any accumulated state

## Pre-Built Strategies

TzuTrader includes four battle-tested strategies covering the main trading approaches: mean reversion, trend following, momentum, and volatility-based trading.

### RSI Strategy

Mean reversion strategy using the Relative Strength Index.

**Trading Logic:**
- **Buy:** RSI falls below oversold threshold
- **Sell:** RSI rises above overbought threshold
- **Stay:** RSI between thresholds

**Constructor:**

```nim
proc newRSIStrategy*(period: int = 14, oversold: float64 = 30.0, 
                     overbought: float64 = 70.0, symbol: string = ""): RSIStrategy
```

**Parameters:**

| Parameter | Type | Default | Description | Typical Range |
|-----------|------|---------|-------------|---------------|
| `period` | int | 14 | RSI calculation period | 9-21 |
| `oversold` | float64 | 30.0 | Buy threshold | 20-35 |
| `overbought` | float64 | 70.0 | Sell threshold | 65-80 |
| `symbol` | string | "" | Target symbol | — |

**Type:**

```nim
type
  RSIStrategy* = ref object of Strategy
    period*: int
    oversold*: float64
    overbought*: float64
    rsiIndicator*: RSI
    lastSignal*: Position
```

**Strategy Behavior:**

The RSI strategy assumes markets oscillate around a mean. When RSI drops below 30 (default), the market is "oversold" and likely to bounce back—time to buy. When RSI exceeds 70, the market is "overbought" and likely to retreat—time to sell.

**Signal Generation:**

Signals are generated only when RSI crosses thresholds. The `lastSignal` field prevents repeated signals at the same threshold. You get one buy signal when entering oversold territory, not continuous buy signals while remaining oversold.

**Parameter Selection:**

- **Shorter periods** (9-12): More responsive, more trades, more false signals
- **Longer periods** (16-21): Smoother, fewer trades, fewer false signals
- **Tighter thresholds** (25/75): Trade more frequently with smaller moves
- **Wider thresholds** (20/80): Wait for extreme conditions, trade less

**Example:**

```nim
import tzutrader

# Conservative RSI strategy (wait for extremes)
let conservative = newRSIStrategy(
  period = 14,
  oversold = 20.0,
  overbought = 80.0
)

# Aggressive RSI strategy (trade more often)
let aggressive = newRSIStrategy(
  period = 10,
  oversold = 35.0,
  overbought = 65.0
)

let data = readCSV("data/AAPL.csv")
let reportConservative = quickBacktest("AAPL", conservative, data)
let reportAggressive = quickBacktest("AAPL", aggressive, data)

echo "Conservative: ", reportConservative.totalTrades, " trades, ", 
     reportConservative.totalReturn, "% return"
echo "Aggressive: ", reportAggressive.totalTrades, " trades, ", 
     reportAggressive.totalReturn, "% return"
```

### Moving Average Crossover Strategy

Trend-following strategy based on two moving averages.

**Trading Logic:**
- **Buy:** Fast MA crosses above slow MA (golden cross)
- **Sell:** Fast MA crosses below slow MA (death cross)
- **Stay:** No crossover

**Constructor:**

```nim
proc newCrossoverStrategy*(fastPeriod: int = 50, slowPeriod: int = 200,
                           symbol: string = ""): CrossoverStrategy
```

**Parameters:**

| Parameter | Type | Default | Description | Typical Range |
|-----------|------|---------|-------------|---------------|
| `fastPeriod` | int | 50 | Fast MA period | 10-100 |
| `slowPeriod` | int | 200 | Slow MA period | 50-300 |
| `symbol` | string | "" | Target symbol | — |

**Type:**

```nim
type
  CrossoverStrategy* = ref object of Strategy
    fastPeriod*: int
    slowPeriod*: int
    fastMA*: SMA
    slowMA*: SMA
    lastFastAbove*: bool
```

**Strategy Behavior:**

The crossover strategy identifies trend changes. When the fast MA (which responds quickly to price) crosses above the slow MA (which changes gradually), it suggests an uptrend is beginning. The opposite crossing suggests a downtrend.

**Classic Combinations:**

- **50/200 (Golden Cross):** The most famous combination, used by institutions
- **10/30:** Shorter-term trading, more signals
- **20/50:** Medium-term trading, balanced
- **Fast/Slow ratio ~4x:** Provides clear separation

**Signal Generation:**

Crossovers are discrete events. You get one buy signal when the cross occurs, not continuous signals while fast remains above slow. The `lastFastAbove` field tracks the relationship state.

**Lag Consideration:**

Moving averages lag price by design. By the time a crossover occurs, the trend may already be well underway. The strategy sacrifices early entry for confirmation that a trend exists.

**Example:**

```nim
import tzutrader

# Short-term trading (faster signals)
let shortTerm = newCrossoverStrategy(fastPeriod = 20, slowPeriod = 50)

# Long-term position trading (fewer, stronger signals)
let longTerm = newCrossoverStrategy(fastPeriod = 50, slowPeriod = 200)

let data = readCSV("data/AAPL.csv")
let report = quickBacktest("AAPL", longTerm, data)

echo "Trades: ", report.totalTrades
echo "Win rate: ", report.winRate, "%"
```

### MACD Strategy

Momentum strategy using Moving Average Convergence Divergence.

**Trading Logic:**
- **Buy:** MACD line crosses above signal line (bullish crossover)
- **Sell:** MACD line crosses below signal line (bearish crossover)
- **Stay:** No crossover

**Constructor:**

```nim
proc newMACDStrategy*(fastPeriod: int = 12, slowPeriod: int = 26,
                      signalPeriod: int = 9, symbol: string = ""): MACDStrategy
```

**Parameters:**

| Parameter | Type | Default | Description | Typical Range |
|-----------|------|---------|-------------|---------------|
| `fastPeriod` | int | 12 | Fast EMA period | 8-15 |
| `slowPeriod` | int | 26 | Slow EMA period | 20-30 |
| `signalPeriod` | int | 9 | Signal line period | 7-12 |
| `symbol` | string | "" | Target symbol | — |

**Type:**

```nim
type
  MACDStrategy* = ref object of Strategy
    fastPeriod*: int
    slowPeriod*: int
    signalPeriod*: int
    macdIndicator*: MACD
    lastMACDAbove*: bool
```

**Strategy Behavior:**

MACD captures momentum shifts by comparing two exponential moving averages. The MACD line (difference between fast and slow EMAs) represents momentum direction and strength. The signal line (EMA of MACD) smooths these movements. Crossovers indicate momentum changes.

**Compared to Crossover Strategy:**

While moving average crossovers directly compare price averages, MACD compares the *difference* between averages to a smoothed version of that difference. This makes MACD more responsive to acceleration and deceleration in price movement.

**Standard Parameters:**

The 12/26/9 combination was developed for daily stock charts in the 1970s. These parameters remain widely used, but different assets and timeframes may benefit from adjustment.

**Signal Generation:**

Like crossover strategies, MACD generates discrete signals at crossover points. The `lastMACDAbove` field prevents signal repetition.

**Example:**

```nim
import tzutrader

# Standard MACD
let standard = newMACDStrategy()

# Faster MACD (more responsive)
let fast = newMACDStrategy(fastPeriod = 8, slowPeriod = 17, signalPeriod = 9)

let data = readCSV("data/AAPL.csv")
let report = quickBacktest("AAPL", standard, data)

echo report
```

### Bollinger Bands Strategy

Mean reversion strategy using Bollinger Bands volatility envelopes.

**Trading Logic:**
- **Buy:** Price touches or falls below lower band
- **Sell:** Price touches or exceeds upper band
- **Stay:** Price within bands

**Constructor:**

```nim
proc newBollingerStrategy*(period: int = 20, stdDev: float64 = 2.0,
                           symbol: string = ""): BollingerStrategy
```

**Parameters:**

| Parameter | Type | Default | Description | Typical Range |
|-----------|------|---------|-------------|---------------|
| `period` | int | 20 | SMA period for middle band | 10-50 |
| `stdDev` | float64 | 2.0 | Standard deviations for bands | 1.5-2.5 |
| `symbol` | string | "" | Target symbol | — |

**Type:**

```nim
type
  BollingerStrategy* = ref object of Strategy
    period*: int
    stdDev*: float64
    lastPosition*: Position
```

**Strategy Behavior:**

Bollinger Bands create a volatility-adjusted envelope around a moving average. When price reaches the outer bands, it's statistically "far" from the mean and likely to revert. The bands expand during volatile periods and contract during quiet periods, automatically adjusting to market conditions.

**Statistical Interpretation:**

With 2 standard deviations, approximately 95% of price observations should fall within the bands. When price breaches a band, it's an outlier event—the strategy bets on regression to the mean.

**Volatility Adaptation:**

Unlike RSI thresholds (which are fixed numbers), Bollinger Bands adapt to the stock's current volatility. A volatile stock gets wider bands, a stable stock gets narrower bands. This makes the strategy work across different assets without parameter tuning.

**Streaming Limitation:**

The current implementation works best in batch mode because standard deviation requires a full window of data. The `onBar` method returns a stay signal and recommends using `analyze` instead.

**Example:**

```nim
import tzutrader

# Standard Bollinger (95% confidence)
let standard = newBollingerStrategy(period = 20, stdDev = 2.0)

# Tighter bands (trade more often, less extreme moves)
let tight = newBollingerStrategy(period = 20, stdDev = 1.5)

# Wider bands (wait for very extreme moves)
let wide = newBollingerStrategy(period = 20, stdDev = 2.5)

let data = readCSV("data/AAPL.csv")

for strategy in [standard, tight, wide]:
  let report = quickBacktest("AAPL", strategy, data)
  echo strategy.name, ": ", report.totalTrades, " trades"
```

## Building Custom Strategies

Create custom strategies by inheriting from `Strategy` and implementing the required methods.

### Basic Structure

```nim
import tzutrader

type
  MyStrategy* = ref object of Strategy
    # Your strategy-specific fields
    myParameter*: float64
    myIndicator*: SMA

proc newMyStrategy*(myParameter: float64): MyStrategy =
  result = MyStrategy(
    name: "My Custom Strategy",
    myParameter: myParameter,
    myIndicator: newSMA(20)
  )

method analyze*(s: MyStrategy, data: seq[OHLCV]): seq[Signal] =
  # Implement batch mode analysis
  result = @[]
  for bar in data:
    # Your logic here
    let signal = Signal(
      position: Stay,  # or Buy/Sell based on logic
      symbol: s.symbol,
      timestamp: bar.timestamp,
      price: bar.close,
      reason: "Your reasoning"
    )
    result.add(signal)

method onBar*(s: MyStrategy, bar: OHLCV): Signal =
  # Implement streaming mode
  # Update indicators, check conditions, return signal
  result = Signal(
    position: Stay,
    symbol: s.symbol,
    timestamp: bar.timestamp,
    price: bar.close,
    reason: "Your reasoning"
  )

method reset*(s: MyStrategy) =
  # Reset strategy state
  s.myIndicator = newSMA(20)
  s.history = @[]
```

### Example: Dual RSI Strategy

A custom strategy using two RSI periods for confirmation:

```nim
import tzutrader

type
  DualRSIStrategy* = ref object of Strategy
    shortPeriod*: int
    longPeriod*: int
    oversold*: float64
    overbought*: float64

proc newDualRSIStrategy*(shortPeriod: int = 7, longPeriod: int = 21,
                         oversold: float64 = 30.0, 
                         overbought: float64 = 70.0): DualRSIStrategy =
  result = DualRSIStrategy(
    name: "Dual RSI Strategy",
    shortPeriod: shortPeriod,
    longPeriod: longPeriod,
    oversold: oversold,
    overbought: overbought
  )

method analyze*(s: DualRSIStrategy, data: seq[OHLCV]): seq[Signal] =
  let closes = data.mapIt(it.close)
  let shortRSI = rsi(closes, s.shortPeriod)
  let longRSI = rsi(closes, s.longPeriod)
  
  result = @[]
  for i, bar in data:
    var position = Stay
    var reason = ""
    
    let shortVal = shortRSI[i]
    let longVal = longRSI[i]
    
    if not shortVal.isNaN and not longVal.isNaN:
      # Buy when BOTH RSIs are oversold
      if shortVal < s.oversold and longVal < s.oversold:
        position = Buy
        reason = &"Both RSIs oversold: {shortVal:.1f}, {longVal:.1f}"
      # Sell when BOTH RSIs are overbought
      elif shortVal > s.overbought and longVal > s.overbought:
        position = Sell
        reason = &"Both RSIs overbought: {shortVal:.1f}, {longVal:.1f}"
    
    result.add(Signal(
      position: position,
      symbol: s.symbol,
      timestamp: bar.timestamp,
      price: bar.close,
      reason: reason
    ))

method onBar*(s: DualRSIStrategy, bar: OHLCV): Signal =
  # For simplicity, just return Stay in streaming mode
  # Full implementation would maintain streaming RSI indicators
  result = Signal(
    position: Stay,
    symbol: s.symbol,
    timestamp: bar.timestamp,
    price: bar.close,
    reason: "Dual RSI requires batch mode"
  )

method reset*(s: DualRSIStrategy) =
  s.history = @[]

# Usage
let strategy = newDualRSIStrategy()
let data = readCSV("data/AAPL.csv")
let report = quickBacktest("AAPL", strategy, data)
echo report
```

### Custom Strategy Guidelines

**Keep it simple:** Complex strategies with many parameters often overfit historical data and fail in live trading.

**Handle NaN values:** Indicators return NaN when insufficient data exists. Check for NaN before making decisions.

**Provide reasons:** The `reason` field helps debug strategy behavior and understand why signals were generated.

**Test both modes:** Implement both `analyze` and `onBar` if you plan to use the strategy in live trading. If batch mode is sufficient, `onBar` can return a neutral signal.

**Use the indicator module:** Don't reimplement indicators. Use the tested implementations from `tzutrader/indicators`.

**State management:** Streaming mode requires careful state management. Reset clears all state.

## Signal Objects

Strategies return `Signal` objects describing what action to take:

```nim
type
  Signal* = object
    position*: Position  # Buy, Sell, or Stay
    symbol*: string      # Target symbol
    timestamp*: int64    # When signal generated
    price*: float64      # Price at signal time
    reason*: string      # Human-readable explanation
```

See [Core Types Reference](01_core.md) for complete Signal specification.

**Signal interpretation:**

- `Buy`: Enter or add to a long position
- `Sell`: Exit or reduce a long position (not short selling)
- `Stay`: No action, hold current state

## Performance Considerations

**Batch vs streaming performance:**

Batch mode (`analyze`) is faster for backtesting because:
- Indicators process entire arrays at once
- No repeated state management overhead
- Better CPU cache utilization

Streaming mode adds overhead from maintaining state and processing bars individually. Use streaming only when necessary (live trading, real-time simulation).

**Memory usage:**

Strategies maintain history in streaming mode. For memory-constrained environments, implement custom history management or use batch mode with data streaming.

## Common Strategy Patterns

### Combining Indicators

```nim
# Buy when RSI oversold AND price below lower Bollinger Band
if rsiVal < 30.0 and price <= lowerBand:
  position = Buy
```

### Confirmation Logic

```nim
# Buy when MACD crossover confirmed by volume
if macdCrossed and volume > avgVolume * 1.5:
  position = Buy
```

### Exit Conditions

```nim
# Exit when profit target reached or stop loss hit
if unrealizedPnL > profitTarget or unrealizedPnL < -stopLoss:
  position = Sell
```

### Position Tracking

```nim
# Only enter new positions, don't pyramid
if lastSignal != Buy and rsiVal < oversold:
  position = Buy
```

## See Also

- [Indicators Reference](03_indicators.md) - Using technical indicators
- [Backtesting Reference](06_backtesting.md) - Testing strategies
- [User Guide: Building Strategies](../user_guide/04_strategies.md) - Conceptual introduction
- [User Guide: Best Practices](../user_guide/09_best_practices.md) - Strategy development guidelines
