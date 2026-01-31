# Declarative Strategies

!!! info "YAML-Based Strategy Definition"
    TzuTrader supports declarative strategies defined in YAML files, allowing you to create and test trading strategies without writing Nim code.

## Overview

Declarative strategies provide a simplified way to define trading logic through configuration files. This approach offers several advantages:

- **No coding required**: Define strategies in YAML
- **Quick iteration**: Test strategy variants easily
- **Version control friendly**: Track strategy changes in git
- **Batch testing**: Compare multiple strategies at once
- **Parameter optimization**: Test different parameter combinations

## Quick Start

### Your First Declarative Strategy

Create a file named `my_first_strategy.yml`:

```yaml
version: "1.0"

metadata:
  name: "My First RSI Strategy"
  description: "Buy when oversold, sell when overbought"
  author: "Your Name"
  tags:
    - rsi
    - mean_reversion

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
  size: 100.0
```

### Validate the Strategy

Before running, validate your strategy:

```bash
tzu validate --strategy-file=my_first_strategy.yml --verbose
```

### Run a Backtest

Test your strategy on historical data:

```bash
tzu --yaml-strategy=my_first_strategy.yml \
    --symbol=AAPL \
    --start=2023-01-01 \
    --endDate=2024-01-01 \
    --initialCash=100000 \
    --verbose

# Short form also works:
tzu -y my_first_strategy.yml -s AAPL --start=2023-01-01 -e 2024-01-01 -i 100000
```

## Strategy Structure

### Metadata

Provide information about your strategy:

```yaml
metadata:
  name: "Strategy Name"          # Required: Short name
  description: "What it does"    # Required: Brief description  
  author: "Your Name"             # Optional
  created: "2024-01-31"           # Optional
  tags:                           # Optional
    - tag1
    - tag2
```

### Indicators

Define the technical indicators your strategy uses:

```yaml
indicators:
  - id: unique_id                 # Required: Unique identifier
    type: indicator_type          # Required: See available indicators below
    params:                       # Required: Indicator-specific parameters
      param1: value1
      param2: value2
    source: close                 # Optional: open, high, low, close, volume
    output: field                 # Optional: For multi-output indicators
```

**Example**: Multiple indicators

```yaml
indicators:
  - id: rsi_14
    type: rsi
    params:
      period: 14
  
  - id: sma_fast
    type: sma
    params:
      period: 10
  
  - id: sma_slow
    type: sma
    params:
      period: 30
```

### Entry and Exit Rules

Define when to enter and exit positions:

**Simple Condition:**

```yaml
entry:
  conditions:
    left: rsi_14
    operator: "<"
    right: "30"
```

**Multiple Conditions (AND):**

```yaml
entry:
  conditions:
    operator: and
    conditions:
      - left: rsi_14
        operator: "<"
        right: "30"
      - left: price.close
        operator: ">"
        right: sma_slow
```

**Alternative Conditions (OR):**

```yaml
exit:
  conditions:
    operator: or
    conditions:
      - left: rsi_14
        operator: ">"
        right: "70"
      - left: price.close
        operator: "<"
        right: sma_fast
```

**Negation (NOT):**

```yaml
entry:
  conditions:
    operator: not
    condition:
      left: rsi_14
      operator: ">"
      right: "70"
```

### Position Sizing

Control how much to invest in each trade:

**Fixed Size:**

```yaml
position_sizing:
  type: fixed
  size: 100.0        # Buy/sell 100 shares
```

**Percentage of Capital:**

```yaml
position_sizing:
  type: percent
  percent: 90        # Use 90% of available capital
```

**Dynamic (Expression-based):**

```yaml
position_sizing:
  type: dynamic
  expression: "capital * 0.5 / price.close"
```

## Available Indicators

### Trend Indicators

- **sma** - Simple Moving Average
  ```yaml
  params:
    period: 20
  ```

- **ema** - Exponential Moving Average
  ```yaml
  params:
    period: 20
  ```

- **dema** - Double Exponential Moving Average
  ```yaml
  params:
    period: 20
  ```

- **tema** - Triple Exponential Moving Average
  ```yaml
  params:
    period: 20
  ```

- **kama** - Kaufman Adaptive Moving Average
  ```yaml
  params:
    period: 10
    fast_sc: 2
    slow_sc: 30
  ```

### Momentum Indicators

- **rsi** - Relative Strength Index
  ```yaml
  params:
    period: 14
  ```

- **roc** - Rate of Change
  ```yaml
  params:
    period: 12
  ```

- **mom** - Momentum
  ```yaml
  params:
    period: 10
  ```

- **cmo** - Chande Momentum Oscillator
  ```yaml
  params:
    period: 14
  ```

### Volatility Indicators

- **atr** - Average True Range
  ```yaml
  params:
    period: 14
  ```

- **natr** - Normalized ATR
  ```yaml
  params:
    period: 14
  ```

- **bollinger** - Bollinger Bands
  ```yaml
  params:
    period: 20
    std_dev: 2.0
  output: middle  # or upper, lower
  ```

### Volume Indicators

- **obv** - On-Balance Volume
  ```yaml
  params: {}
  ```

- **ad** - Accumulation/Distribution
  ```yaml
  params: {}
  ```

- **mfi** - Money Flow Index
  ```yaml
  params:
    period: 14
  ```

### Oscillators

- **macd** - Moving Average Convergence Divergence
  ```yaml
  params:
    fast: 12
    slow: 26
    signal: 9
  output: macd  # or signal, histogram
  ```

- **stochastic** - Stochastic Oscillator
  ```yaml
  params:
    k_period: 14
    d_period: 3
  output: k  # or d
  ```

- **cci** - Commodity Channel Index
  ```yaml
  params:
    period: 20
  ```

### Custom Indicators (Expression-based)

Create custom indicators using mathematical expressions:

```yaml
indicators:
  - id: price_momentum
    type: expression
    expression: "(price.close - sma_20) / sma_20 * 100"
  
  - id: volume_ratio
    type: expression
    expression: "price.volume / vol_sma"
```

## Comparison Operators

- `<` - Less than
- `>` - Greater than
- `<=` - Less than or equal
- `>=` - Greater than or equal
- `==` - Equal
- `!=` - Not equal
- `crosses_above` - Value crosses above another (e.g., golden cross)
- `crosses_below` - Value crosses below another (e.g., death cross)

## Special References

Access price and volume data directly:

- `price.open` - Opening price
- `price.high` - High price
- `price.low` - Low price
- `price.close` - Closing price
- `price.volume` - Trading volume

## Example Strategies

### Moving Average Crossover

```yaml
version: "1.0"

metadata:
  name: "Golden Cross Strategy"
  description: "Buy when fast MA crosses above slow MA"

indicators:
  - id: sma_fast
    type: sma
    params:
      period: 50
  
  - id: sma_slow
    type: sma
    params:
      period: 200

entry:
  conditions:
    left: sma_fast
    operator: "crosses_above"
    right: sma_slow

exit:
  conditions:
    left: sma_fast
    operator: "crosses_below"
    right: sma_slow

position_sizing:
  type: percent
  percent: 95
```

### RSI with Volume Confirmation

```yaml
version: "1.0"

metadata:
  name: "RSI + Volume Filter"
  description: "RSI strategy with volume confirmation"

indicators:
  - id: rsi_14
    type: rsi
    params:
      period: 14
  
  - id: vol_sma
    type: sma
    params:
      period: 20
    source: volume

entry:
  conditions:
    operator: and
    conditions:
      - left: rsi_14
        operator: "<"
        right: "30"
      - left: price.volume
        operator: ">"
        right: vol_sma

exit:
  conditions:
    left: rsi_14
    operator: ">"
    right: "70"

position_sizing:
  type: percent
  percent: 80
```

### Bollinger Bands Mean Reversion

```yaml
version: "1.0"

metadata:
  name: "Bollinger Reversal"
  description: "Buy at lower band, sell at upper band"

indicators:
  - id: bb
    type: bollinger
    params:
      period: 20
      std_dev: 2.0

entry:
  conditions:
    left: price.close
    operator: "<"
    right: bb.lower

exit:
  conditions:
    left: price.close
    operator: ">"
    right: bb.upper

position_sizing:
  type: percent
  percent: 90
```

## Batch Testing

Test multiple strategies or parameter variations at once:

### Create a Batch Test File

```yaml
# batch_test.yml
version: "1.0"
type: batch_test

data:
  source: yahoo
  symbols:
    - AAPL
    - MSFT
    - GOOGL
  start_date: "2023-01-01"
  end_date: "2024-01-01"

strategies:
  - file: "strategies/rsi.yml"
    name: "RSI Conservative"
  
  - file: "strategies/rsi.yml"
    name: "RSI Aggressive"
    overrides:
      rsi_14:
        period: 10

portfolio:
  initial_cash: 100000.0
  commission: 0.001

output:
  comparison_report: "results/comparison.html"
  format: "html"
```

### Run the Batch Test

```bash
tzu batch --batch-file=batch_test.yml --verbose
```

This will:
1. Test each strategy on each symbol
2. Generate a comparison report
3. Show summary statistics

### Parameter Overrides

Test variations without creating new files:

```yaml
strategies:
  - file: "base_strategy.yml"
    name: "Fast RSI"
    overrides:
      rsi_14:
        period: 7
  
  - file: "base_strategy.yml"
    name: "Slow RSI"
    overrides:
      rsi_14:
        period: 21
```

## Advanced Features

### Nested Conditions

Combine multiple logical operators:

```yaml
entry:
  conditions:
    operator: and
    conditions:
      - operator: or
        conditions:
          - left: rsi_14
            operator: "<"
            right: "30"
          - left: rsi_14
            operator: "<"
            right: "20"
      - left: price.close
        operator: ">"
        right: sma_200
```

### Indicator-to-Indicator Comparisons

Compare indicators directly:

```yaml
entry:
  conditions:
    operator: and
    conditions:
      - left: sma_fast
        operator: ">"
        right: sma_slow
      - left: price.close
        operator: ">"
        right: sma_fast
```

### Multi-Output Indicators

Select specific outputs from indicators:

```yaml
indicators:
  - id: bb
    type: bollinger
    params:
      period: 20
      std_dev: 2.0
    output: upper  # Default output

entry:
  conditions:
    left: price.close
    operator: "<"
    right: bb.lower  # Override with dot notation
```

## Tips and Best Practices

1. **Start Simple**: Begin with basic strategies and add complexity gradually
2. **Validate First**: Always run `tzu validate` before backtesting
3. **Use Descriptive IDs**: Name indicators clearly (e.g., `rsi_14` not `r1`)
4. **Test Multiple Symbols**: Use batch testing to find robust strategies
5. **Version Control**: Keep strategies in git to track changes
6. **Document Parameters**: Use comments to explain parameter choices
7. **Avoid Overfitting**: Test on different time periods and symbols

## Common Pitfalls

!!! warning "Avoid These Mistakes"
    - **Duplicate indicator IDs**: Each indicator must have a unique ID
    - **Undefined references**: All indicators used in conditions must be defined
    - **Wrong output fields**: Check multi-output indicator field names
    - **Missing required fields**: All strategies need metadata, indicators, entry, exit, and position_sizing
    - **Invalid operators**: Use only supported comparison operators

## Getting Help

- **Validation errors**: Run with `--verbose` for detailed messages
- **Example strategies**: See `examples/declarative/` directory
- **Reference guide**: Check the declarative strategies reference section
- **Community**: Ask questions on the project forum

## Next Steps

- Try the [example strategies](https://github.com/jailop/tzutrader/tree/main/examples/declarative)
- Learn about [batch testing](#batch-testing) for strategy optimization
- Read the [reference guide](../reference_guide/10_declarative.md) for complete details
- Explore [advanced features](#advanced-features) for complex strategies
