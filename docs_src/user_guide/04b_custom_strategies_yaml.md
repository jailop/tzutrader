# Writing Custom Strategies with YAML

## Introduction

TzuTrader's **Declarative YAML System** allows you to create trading strategies using human-readable configuration files instead of programming. This approach is ideal for:

- Traders who want to backtest their ideas without learning Nim
- Quick prototyping and iteration
- Sharing strategies with others
- Version control and collaboration
- Testing parameter variations efficiently

**Important**: Like TzuTrader's built-in strategies, the YAML examples are **reference implementations** to demonstrate capabilities. You should create your own strategies tailored to your specific trading philosophy and risk tolerance.

## Why Use YAML vs Nim?

### Choose YAML When:
- You want to quickly test a trading idea
- You're not comfortable with programming
- You need to collaborate with non-programmers
- Your strategy can be expressed with built-in indicators and simple logic
- You want to optimize parameters using automated sweeps

### Choose Nim When:
- Your strategy requires complex custom logic
- You need state management across multiple timeframes
- You want maximum performance
- You need features not available in the declarative system
- You're building a production trading bot

For most retail traders testing their ideas, **YAML is the perfect starting point**.

## Your First YAML Strategy

Let's create a simple RSI mean reversion strategy step by step.

### Step 1: Create the File

Create a new file called `my_rsi_strategy.yml`:

```yaml
# Simple RSI Mean Reversion Strategy
# Buy when RSI < 30 (oversold), sell when RSI > 70 (overbought)

metadata:
  name: "My First RSI Strategy"
  description: "Buy oversold, sell overbought"
  author: "Your Name"
  created: "2024-01-15"
  tags:
    - rsi
    - mean-reversion
    - beginner

indicators:
  - id: rsi_14
    type: rsi
    params:
      period: 14

entry:
  conditions:
    left: rsi_14
    operator: "<"
    right: "30"

exit:
  conditions:
    left: rsi_14
    operator: ">"
    right: "70"

position_sizing:
  type: fixed
  size: 100
```

### Step 2: Test Your Strategy

Run a backtest using the CLI:

```bash
./tzu --yaml-strategy=my_rsi_strategy.yml \
      --symbol=AAPL \
      --start=2023-01-01 \
      --end=2024-01-01
```

### Step 3: Review Results

TzuTrader will display backtest metrics:

```
Strategy: My First RSI Strategy
Symbol: AAPL
Period: 2023-01-01 to 2024-01-01

Total Return: 15.3%
Sharpe Ratio: 1.45
Max Drawdown: -8.2%
Win Rate: 62.5%
Number of Trades: 24
```

That's it! You've created and backtested your first strategy.

## Strategy File Structure

Every YAML strategy file has five main sections:

### 1. Metadata Section

Information about your strategy:

```yaml
metadata:
  name: "Strategy Name"              # Required
  description: "What it does"        # Required
  author: "Your Name"                # Optional
  created: "2024-01-15"              # Optional
  tags:                              # Optional
    - tag1
    - tag2
```

### 2. Indicators Section

Technical indicators you want to calculate:

```yaml
indicators:
  - id: unique_name        # Your choice, used to reference the indicator
    type: indicator_type   # One of 30+ built-in types
    params:
      param1: value1
      param2: value2
```

### 3. Entry Section

When to enter a trade:

```yaml
entry:
  conditions:
    left: indicator_or_value
    operator: comparison_operator
    right: indicator_or_value
```

### 4. Exit Section

When to exit a trade:

```yaml
exit:
  conditions:
    left: indicator_or_value
    operator: comparison_operator
    right: indicator_or_value
```

### 5. Position Sizing Section

How much to trade:

```yaml
position_sizing:
  type: fixed          # or 'percent'
  size: 100            # shares (for fixed)
  # OR
  type: percent
  percent: 10.0        # percentage of capital
```

## Available Indicators

TzuTrader provides 30+ technical indicators. Here are the most commonly used:

### Momentum Oscillators

**RSI (Relative Strength Index)**
```yaml
- id: rsi_14
  type: rsi
  params:
    period: 14  # Common: 7, 14, 21
```

**Stochastic**
```yaml
- id: stoch_14_3
  type: stochastic
  params:
    period: 14
    smoothK: 3
    smoothD: 3
```

**CCI (Commodity Channel Index)**
```yaml
- id: cci_20
  type: cci
  params:
    period: 20
```

### Moving Averages

**SMA (Simple Moving Average)**
```yaml
- id: sma_50
  type: sma
  params:
    period: 50  # Common: 20, 50, 200
```

**EMA (Exponential Moving Average)**
```yaml
- id: ema_20
  type: ema
  params:
    period: 20
```

**DEMA (Double Exponential Moving Average)**
```yaml
- id: dema_20
  type: dema
  params:
    period: 20
```

**TEMA (Triple Exponential Moving Average)**
```yaml
- id: tema_20
  type: tema
  params:
    period: 20
```

### Trend Indicators

**MACD (Moving Average Convergence Divergence)**
```yaml
- id: macd_std
  type: macd
  params:
    fast: 12
    slow: 26
    signal: 9
```

MACD has multiple outputs you can reference:
- `macd_std` - MACD line
- `macd_std.signal` - Signal line
- `macd_std.histogram` - Histogram

**ADX (Average Directional Index)**
```yaml
- id: adx_14
  type: adx
  params:
    period: 14
```

### Volatility Indicators

**Bollinger Bands**
```yaml
- id: bb_20
  type: bollinger
  params:
    period: 20
    numStdDev: 2.0
```

Bollinger Bands have three bands you can reference:
- `bb_20.upper` - Upper band
- `bb_20.middle` - Middle band (SMA)
- `bb_20.lower` - Lower band

**ATR (Average True Range)**
```yaml
- id: atr_14
  type: atr
  params:
    period: 14
```

### Volume Indicators

**Volume SMA (for volume confirmation)**
```yaml
- id: vol_sma_20
  type: sma
  params:
    period: 20
  source: volume  # Apply SMA to volume instead of close
```

**OBV (On-Balance Volume)**
```yaml
- id: obv
  type: obv
  params: {}  # No parameters needed
```

### Price Action

You can reference raw price data directly:
- `open` - Opening price
- `high` - High price
- `low` - Low price
- `close` - Closing price
- `volume` - Trading volume

For a complete list of all 30+ indicators, see the [Reference Guide: Indicators](../reference_guide/03_indicators.md).

## Comparison Operators

Use these operators in your entry/exit conditions:

| Operator | Symbol | Example | Meaning |
|----------|--------|---------|---------|
| Less than | `<` | `rsi_14 < 30` | RSI below 30 |
| Greater than | `>` | `rsi_14 > 70` | RSI above 70 |
| Less or equal | `<=` | `close <= bb_20.lower` | Price at or below lower band |
| Greater or equal | `>=` | `close >= bb_20.upper` | Price at or above upper band |
| Equal | `==` | `adx_14 == 25` | ADX exactly 25 |
| Not equal | `!=` | `macd != 0` | MACD not zero |
| Crosses above | `crosses_above` | `ema_20 crosses_above ema_50` | Golden cross |
| Crosses below | `crosses_below` | `ema_20 crosses_below ema_50` | Death cross |

### Using Literal Values

The `right` side of a condition can be:
- **An indicator**: `rsi_14`, `sma_200`, `macd.signal`
- **A literal number** (in quotes): `"30"`, `"0"`, `"100"`
- **A price field**: `close`, `open`, `high`, `low`

```yaml
# Indicator vs literal
entry:
  conditions:
    left: rsi_14
    operator: "<"
    right: "30"        # Literal number

# Indicator vs indicator
entry:
  conditions:
    left: ema_20
    operator: ">"
    right: ema_50      # Another indicator
```

## Building More Complex Strategies

### Multiple Indicators

You can define as many indicators as you need:

```yaml
indicators:
  - id: rsi_14
    type: rsi
    params:
      period: 14
  
  - id: sma_50
    type: sma
    params:
      period: 50
  
  - id: sma_200
    type: sma
    params:
      period: 200
  
  - id: volume_avg
    type: sma
    params:
      period: 20
    source: volume
```

### Combining Multiple Conditions (AND)

Use `all:` to require **all** conditions to be true:

```yaml
# Entry requires RSI oversold AND price above 200-day SMA
entry:
  conditions:
    all:
      - left: rsi_14
        operator: "<"
        right: "30"
      - left: close
        operator: ">"
        right: sma_200
```

This only triggers when **both** conditions are met.

### Alternative Conditions (OR)

Use `any:` to trigger when **any** condition is true:

```yaml
# Exit when either RSI overbought OR MACD turns negative
exit:
  conditions:
    any:
      - left: rsi_14
        operator: ">"
        right: "70"
      - left: macd_12_26_9
        operator: "<"
        right: "0"
```

This triggers when **either** condition is met.

### Negating Conditions (NOT)

Use `not:` to invert a condition:

```yaml
# Entry when RSI NOT oversold
entry:
  conditions:
    not:
      left: rsi_14
      operator: "<"
      right: "30"
```

### Complex Logic

You can nest `all`, `any`, and `not` for sophisticated logic:

```yaml
# Entry when:
# (RSI oversold AND above 200-day SMA) OR (MACD crossover)
entry:
  conditions:
    any:
      - all:
          - left: rsi_14
            operator: "<"
            right: "30"
          - left: close
            operator: ">"
            right: sma_200
      - left: macd_12_26_9
        operator: crosses_above
        right: macd_12_26_9.signal
```

## Position Sizing Strategies

### Fixed Size

Trade a fixed number of shares:

```yaml
position_sizing:
  type: fixed
  size: 100  # Always trade 100 shares
```

**Good for**: Consistent risk per trade, simple strategies.

### Percentage of Capital

Trade a percentage of your current capital:

```yaml
position_sizing:
  type: percent
  percent: 10.0  # Use 10% of capital per trade
```

**Good for**: Adaptive position sizing, growing/shrinking with account.

**Example**: 
- With $10,000 capital and 10% sizing:
  - If stock is $50, buy 20 shares ($1,000)
  - If stock is $100, buy 10 shares ($1,000)

## Practical Strategy Examples

### Example 1: Simple Trend Following

```yaml
metadata:
  name: "EMA Crossover"
  description: "Buy when fast EMA crosses above slow EMA"

indicators:
  - id: ema_20
    type: ema
    params:
      period: 20
  - id: ema_50
    type: ema
    params:
      period: 50

entry:
  conditions:
    left: ema_20
    operator: crosses_above
    right: ema_50

exit:
  conditions:
    left: ema_20
    operator: crosses_below
    right: ema_50

position_sizing:
  type: percent
  percent: 15.0
```

### Example 2: Bollinger Band Mean Reversion

```yaml
metadata:
  name: "Bollinger Mean Reversion"
  description: "Buy at lower band, sell at upper band"

indicators:
  - id: bb_20
    type: bollinger
    params:
      period: 20
      numStdDev: 2.0

entry:
  conditions:
    left: close
    operator: "<="
    right: bb_20.lower

exit:
  conditions:
    left: close
    operator: ">="
    right: bb_20.upper

position_sizing:
  type: percent
  percent: 20.0
```

### Example 3: Multi-Indicator Confirmation

```yaml
metadata:
  name: "Triple Confirmation"
  description: "Requires RSI, MACD, and volume confirmation"

indicators:
  - id: rsi_14
    type: rsi
    params:
      period: 14
  
  - id: macd_std
    type: macd
    params:
      fast: 12
      slow: 26
      signal: 9
  
  - id: volume_avg
    type: sma
    params:
      period: 20
    source: volume

entry:
  conditions:
    all:  # All three must be true
      - left: rsi_14
        operator: "<"
        right: "30"
      - left: macd_std
        operator: ">"
        right: "0"
      - left: volume
        operator: ">"
        right: volume_avg

exit:
  conditions:
    any:  # Exit on either condition
      - left: rsi_14
        operator: ">"
        right: "70"
      - left: macd_std
        operator: "<"
        right: "0"

position_sizing:
  type: percent
  percent: 10.0
```

### Example 4: Trend Filter Strategy

Only trade mean reversion in an uptrend:

```yaml
metadata:
  name: "RSI with Trend Filter"
  description: "RSI mean reversion only when in uptrend"

indicators:
  - id: rsi_14
    type: rsi
    params:
      period: 14
  
  - id: sma_200
    type: sma
    params:
      period: 200

entry:
  conditions:
    all:
      - left: rsi_14
        operator: "<"
        right: "30"
      - left: close        # Above 200-day SMA = uptrend
        operator: ">"
        right: sma_200

exit:
  conditions:
    left: rsi_14
    operator: ">"
    right: "70"

position_sizing:
  type: fixed
  size: 100
```

## Testing Your Strategies

### Single Symbol Test

Test on one symbol:

```bash
./tzu --yaml-strategy=my_strategy.yml \
      --symbol=AAPL \
      --start=2023-01-01 \
      --end=2024-01-01
```

### Different Time Periods

Test different periods to validate robustness:

```bash
# Bull market (2020)
./tzu --yaml-strategy=my_strategy.yml --symbol=AAPL \
      --start=2020-01-01 --end=2020-12-31

# Bear market (2022)
./tzu --yaml-strategy=my_strategy.yml --symbol=AAPL \
      --start=2022-01-01 --end=2022-12-31

# Recent (2023)
./tzu --yaml-strategy=my_strategy.yml --symbol=AAPL \
      --start=2023-01-01 --end=2023-12-31
```

### Multiple Symbols

Test on different stocks to avoid overfitting:

```bash
./tzu --yaml-strategy=my_strategy.yml --symbol=AAPL
./tzu --yaml-strategy=my_strategy.yml --symbol=MSFT
./tzu --yaml-strategy=my_strategy.yml --symbol=GOOGL
```

## Batch Testing

Instead of running tests one at a time, use **batch testing** to compare multiple strategies or parameters simultaneously.

### Create a Batch Configuration

`compare_strategies.yml`:

```yaml
version: "1.0"

metadata:
  name: "Compare RSI Strategies"
  description: "Test different RSI thresholds"

data:
  source: yahoo
  symbols:
    - AAPL
    - MSFT
    - GOOGL
  start_date: "2023-01-01"
  end_date: "2024-01-01"

portfolio:
  initial_cash: 100000.0
  commission: 0.001
  min_commission: 1.0

strategies:
  - file: "my_rsi_strategy.yml"
    name: "RSI_Conservative"
    # Use default parameters
  
  - file: "my_rsi_strategy.yml"
    name: "RSI_Aggressive"
    overrides:
      conditions:
        entry:
          left: rsi_14
          operator: "<"
          right: "25"  # More aggressive entry
        exit:
          left: rsi_14
          operator: ">"
          right: "75"  # More aggressive exit

output:
  formats:
    - csv
  comparison_report: "results/comparison.csv"
  individual_results: "results/individual/"
```

### Run Batch Test

```bash
./tzu --batch=compare_strategies.yml
```

### Review Results

TzuTrader generates a comparison CSV:

| Strategy | Symbol | Return % | Sharpe | Max DD % | Trades |
|----------|--------|----------|--------|----------|--------|
| RSI_Conservative | AAPL | 15.3 | 1.45 | -8.2 | 24 |
| RSI_Aggressive | AAPL | 22.1 | 1.78 | -12.5 | 36 |
| RSI_Conservative | MSFT | 18.7 | 1.62 | -7.5 | 28 |
| RSI_Aggressive | MSFT | 24.3 | 1.85 | -11.2 | 42 |

See the [Batch Testing Guide](../reference_guide/10_declarative.md#batch-testing) for more details.

## Parameter Optimization (Sweep)

Automatically find the best parameters using **parameter sweep**.

### Create a Sweep Configuration

`optimize_rsi.yml`:

```yaml
version: "1.0"

metadata:
  name: "Optimize RSI Parameters"
  description: "Find optimal RSI period and thresholds"

base_strategy: "my_rsi_strategy.yml"

data:
  source: yahoo
  symbols:
    - AAPL
  start_date: "2023-01-01"
  end_date: "2024-01-01"

portfolio:
  initial_cash: 100000.0
  commission: 0.001

parameters:
  # Test different RSI periods
  - path: "indicators.rsi_14.period"
    range:
      type: list
      values: [10, 14, 20, 30]
  
  # Test different oversold thresholds
  - path: "conditions.entry.right"
    range:
      type: linear
      min: 20
      max: 40
      step: 5
  
  # Test different overbought thresholds
  - path: "conditions.exit.right"
    range:
      type: linear
      min: 60
      max: 80
      step: 5

output:
  best_results: "results/best_params.csv"
  full_results: "results/all_params.csv"
```

This tests **4 × 5 × 5 = 100** parameter combinations.

### Run Parameter Sweep

```bash
./tzu --sweep=optimize_rsi.yml
```

### Review Optimization Results

TzuTrader shows the best parameter combinations:

```
============================================================
Top 10 Parameter Combinations by Total Return
============================================================

1. Sweep_42 on AAPL
   Return: 28.50%, Sharpe: 2.15, Drawdown: -8.20%
   Parameters:
     indicators.rsi_14.period: 20
     conditions.entry.right: 30
     conditions.exit.right: 70

2. Sweep_17 on AAPL
   Return: 25.30%, Sharpe: 1.98, Drawdown: -9.50%
   Parameters:
     indicators.rsi_14.period: 14
     conditions.entry.right: 25
     conditions.exit.right: 75
...
```

See the [Parameter Sweep Guide](../reference_guide/10_declarative.md#parameter-sweep) for more details.

## Best Practices

### 1. Start Simple

Begin with a single indicator and simple conditions:

```yaml
# Good: Start simple
indicators:
  - id: rsi_14
    type: rsi
    params:
      period: 14

entry:
  conditions:
    left: rsi_14
    operator: "<"
    right: "30"
```

Avoid adding complexity until you understand how each piece works.

### 2. Use Descriptive IDs

Choose clear, meaningful indicator IDs:

```yaml
# Good: Clear and descriptive
- id: rsi_14
- id: sma_short_20
- id: sma_long_200
- id: macd_standard

# Bad: Unclear
- id: ind1
- id: x
- id: temp
```

### 3. Test on Multiple Timeframes

```bash
# Short term (6 months)
./tzu --yaml-strategy=my_strategy.yml --symbol=AAPL \
      --start=2023-07-01 --end=2024-01-01

# Medium term (1 year)
./tzu --yaml-strategy=my_strategy.yml --symbol=AAPL \
      --start=2023-01-01 --end=2024-01-01

# Long term (2 years)
./tzu --yaml-strategy=my_strategy.yml --symbol=AAPL \
      --start=2022-01-01 --end=2024-01-01
```

### 4. Test on Multiple Symbols

Avoid overfitting to a single stock:

```bash
# Tech stocks
./tzu --yaml-strategy=my_strategy.yml --symbol=AAPL
./tzu --yaml-strategy=my_strategy.yml --symbol=MSFT
./tzu --yaml-strategy=my_strategy.yml --symbol=GOOGL

# Different sectors
./tzu --yaml-strategy=my_strategy.yml --symbol=JPM   # Finance
./tzu --yaml-strategy=my_strategy.yml --symbol=XOM   # Energy
./tzu --yaml-strategy=my_strategy.yml --symbol=JNJ   # Healthcare
```

### 5. Use Batch Testing for Comparison

Instead of running tests individually, use batch testing:

```yaml
# batch_test.yml
data:
  symbols:
    - AAPL
    - MSFT
    - GOOGL
    - JPM
    - XOM
    - JNJ

strategies:
  - file: "my_strategy.yml"
    name: "Original"
  - file: "my_strategy_v2.yml"
    name: "Updated"
```

```bash
./tzu --batch=batch_test.yml
```

### 6. Document Your Strategy

Use the metadata section to document your thinking:

```yaml
metadata:
  name: "Conservative RSI Mean Reversion"
  description: |
    Buy when RSI drops below 25 (extreme oversold) and price is above 200-day SMA.
    Only trade in uptrends to avoid catching falling knives.
    Exit at RSI 75 to capture full mean reversion move.
  author: "John Trader"
  created: "2024-01-15"
  tags:
    - rsi
    - mean-reversion
    - trend-filter
    - conservative
```

### 7. Be Realistic About Parameters

Don't use nonsensical values:

```yaml
# Good: Reasonable RSI parameters
- id: rsi_14
  type: rsi
  params:
    period: 14      # Standard

entry:
  conditions:
    left: rsi_14
    operator: "<"
    right: "30"     # Traditional oversold level

# Bad: Extreme values
- id: rsi_weird
  type: rsi
  params:
    period: 200     # Too long for RSI

entry:
  conditions:
    left: rsi_weird
    operator: "<"
    right: "5"      # Almost never triggers
```

### 8. Validate with Out-of-Sample Data

After optimizing, test on fresh data:

```bash
# Optimize on 2023 data
./tzu --sweep=optimize_2023.yml

# Test winner on 2024 data (out-of-sample)
./tzu --yaml-strategy=optimized_strategy.yml \
      --symbol=AAPL \
      --start=2024-01-01 \
      --end=2024-12-31
```

If performance degrades significantly, you likely overfit.

## Common Mistakes

### Mistake 1: Too Many Conditions

```yaml
# Bad: Too restrictive
entry:
  conditions:
    all:
      - left: rsi_14
        operator: "<"
        right: "30"
      - left: stoch_14
        operator: "<"
        right: "20"
      - left: cci_20
        operator: "<"
        right: "-100"
      - left: volume
        operator: ">"
        right: vol_avg
      - left: close
        operator: ">"
        right: sma_200
      - left: adx_14
        operator: ">"
        right: "25"
```

With 6 conditions using `all`, trades become extremely rare. Start with 2-3 key conditions.

### Mistake 2: Comparing Incompatible Indicators

```yaml
# Bad: Comparing RSI (0-100) with MACD (unbounded)
entry:
  conditions:
    left: rsi_14
    operator: ">"
    right: macd_12_26_9  # Wrong scale
```

Compare indicators with similar ranges or use literal thresholds.

### Mistake 3: Forgetting Quotes on Literal Numbers

```yaml
# Bad: Missing quotes
entry:
  conditions:
    left: rsi_14
    operator: "<"
    right: 30  # Error: will be interpreted as indicator ID

# Good: Use quotes for literals
entry:
  conditions:
    left: rsi_14
    operator: "<"
    right: "30"  # Correct
```

### Mistake 4: Wrong Indicator ID References

```yaml
indicators:
  - id: rsi_14  # Defined with this ID
    type: rsi
    params:
      period: 14

entry:
  conditions:
    left: rsi  # Bad: Doesn't match the defined ID
    operator: "<"
    right: "30"

# Should be:
entry:
  conditions:
    left: rsi_14  # Must match the 'id' field exactly
    operator: "<"
    right: "30"
```

### Mistake 5: Using Crosses Wrong

```yaml
# Bad: Using crosses_above with a literal
entry:
  conditions:
    left: ema_20
    operator: crosses_above
    right: "50"  # Can't cross a static value

# Good: Use crosses_above with another indicator
entry:
  conditions:
    left: ema_20
    operator: crosses_above
    right: ema_50  # Cross between two moving values
```

## Troubleshooting

### Error: "Indicator not found"

**Problem**: You referenced an indicator ID that doesn't exist.

```yaml
indicators:
  - id: rsi_14
    type: rsi
    params:
      period: 14

entry:
  conditions:
    left: rsi_20  # Wrong! No indicator with this ID
```

**Solution**: Use the exact ID you defined:

```yaml
entry:
  conditions:
    left: rsi_14  # Matches the ID
```

### Error: "Invalid parameter type"

**Problem**: Parameter has wrong type.

```yaml
# Bad
- id: rsi_14
  type: rsi
  params:
    period: "14"  # String instead of int
```

**Solution**: Remove quotes from numbers:

```yaml
# Good
- id: rsi_14
  type: rsi
  params:
    period: 14  # Integer
```

### Error: "Missing required field"

**Problem**: You forgot a required section.

```yaml
metadata:
  name: "My Strategy"

indicators:
  - id: rsi_14
    type: rsi
    params:
      period: 14

# Missing entry, exit, and position_sizing!
```

**Solution**: Include all required sections:

```yaml
metadata: {...}
indicators: [...]
entry: {...}     # Required
exit: {...}      # Required
position_sizing: {...}  # Required
```

### No Trades Generated

**Problem**: Your conditions are too restrictive or never true.

**Solutions**:
1. Simplify conditions (remove some from `all:`)
2. Widen thresholds (e.g., RSI < 35 instead of < 25)
3. Check if indicators have enough history (some need many bars)
4. Verify data quality and date range

### Too Many Trades

**Problem**: Your conditions trigger too frequently.

**Solutions**:
1. Add more filters (use `all:` to require multiple conditions)
2. Make thresholds more extreme (e.g., RSI < 25 instead of < 35)
3. Add trend filter to avoid choppy markets
4. Increase position size and trade less frequently

## Next Steps

### Learn More

- **[Reference: Declarative System](../reference_guide/10_declarative.md)** - Complete technical reference
- **[Reference: Indicators](../reference_guide/03_indicators.md)** - All 30+ indicators documented
- **[User Guide: Workflows](08_workflows.md)** - Complete workflow examples

### Example Strategies

Explore the example strategies in `examples/yaml_strategies/`:

- `rsi_simple.yml` - Basic RSI strategy (start here)
- `rsi_trend_filter.yml` - RSI with trend confirmation
- `macd_crossover.yml` - MACD crossover strategy
- `bollinger_mean_reversion.yml` - Bollinger Bands strategy
- `multi_indicator.yml` - Multiple indicator confirmation
- And 10+ more examples

### Try Batch Testing

Test multiple variations efficiently:

```bash
./tzu --batch=examples/batch/basic_batch.yml
```

See `examples/batch/README.md` for more examples.

### Try Parameter Optimization

Find optimal parameters automatically:

```bash
./tzu --sweep=examples/sweep/rsi_optimization.yml
```

See `examples/sweep/README.md` for more examples.

### When to Switch to Nim

If you find yourself wanting to:
- Implement complex custom logic
- Manage state across bars in sophisticated ways
- Optimize performance for production
- Create reusable strategy components

Then it's time to learn Nim and read the [Writing Custom Strategies with Nim](04a_custom_strategies_nim.md) guide.

## Summary

YAML strategies in TzuTrader provide a powerful yet accessible way to backtest trading ideas:

- ✅ No programming required
- ✅ 30+ built-in technical indicators
- ✅ Simple and complex condition logic
- ✅ Flexible position sizing
- ✅ Batch testing for comparison
- ✅ Automated parameter optimization
- ✅ Clear validation and error messages

**Remember**: Built-in and example strategies are reference implementations. Always develop and validate your own strategies that align with your trading philosophy and risk tolerance.

Start simple, test thoroughly, and iterate based on results. Happy trading!
