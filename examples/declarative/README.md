# TzuTrader Declarative Strategy Examples

This directory contains example YAML strategy files demonstrating the declarative strategy system.

## Basic Examples

### `simple_rsi.yml`
Basic RSI oversold/overbought strategy. Good starting point for beginners.
- **Type**: Mean Reversion
- **Indicators**: RSI (14)
- **Entry**: RSI < 30
- **Exit**: RSI > 70

### `simple_ma_cross.yml`
Moving average crossover strategy. Classic trend-following approach.
- **Type**: Trend Following
- **Indicators**: SMA(10), SMA(30)
- **Entry**: Fast MA crosses above slow MA
- **Exit**: Fast MA crosses below slow MA

### `bollinger_reversal.yml`
Bollinger Bands mean reversion strategy.
- **Type**: Mean Reversion
- **Indicators**: Bollinger Bands (20, 2.0)
- **Entry**: Price touches lower band
- **Exit**: Price reaches upper band

### `macd_crossover.yml`
MACD signal line crossover strategy.
- **Type**: Trend Following
- **Indicators**: MACD (12, 26, 9)
- **Entry**: MACD line crosses above signal line
- **Exit**: MACD line crosses below signal line

## Intermediate Examples

### `rsi_volume_filter.yml`
RSI strategy with volume confirmation to reduce false signals.
- **Type**: Filtered Mean Reversion
- **Indicators**: RSI (14), SMA on volume (20)
- **Entry**: RSI < 30 AND volume > average
- **Exit**: RSI > 70
- **Features**: Multi-indicator, volume analysis

### `stochastic_strategy.yml`
Stochastic oscillator with crossover confirmation.
- **Type**: Mean Reversion
- **Indicators**: Stochastic (14, 3)
- **Entry**: K < 20 AND K crosses above D
- **Exit**: K > 80 OR K crosses below D
- **Features**: Complex exit conditions

### `golden_cross_enhanced.yml`
Enhanced golden cross with multiple confirmation indicators.
- **Type**: Trend Following
- **Indicators**: Multiple SMAs, RSI
- **Features**: Multi-indicator confirmation, complex AND/OR logic

## Advanced Examples

### `mean_reversion_volatility.yml`
Mean reversion strategy filtered by volatility conditions.
- **Type**: Volatility-Filtered Mean Reversion
- **Indicators**: RSI, Bollinger Bands, ATR
- **Features**: Multiple indicators, volatility analysis

### `phase3_showcase.yml`
Comprehensive demonstration of Phase 3 features.
- **Features**: 
  - Expression-based custom indicators
  - NOT logic
  - Indicator-to-indicator comparisons
  - Complex nested conditions

## Batch Testing

### `batch_test_example.yml`
Example batch test configuration for comparing multiple strategies.
- **Strategies**: 4 different configurations
- **Symbols**: AAPL, MSFT, GOOGL
- **Features**: Parameter overrides, comparison reports

## Usage

### Validate a Strategy

```bash
tzu validate --strategy-file=examples/declarative/simple_rsi.yml --verbose
```

### Run a Single Strategy

```bash
tzu --yaml-strategy=examples/declarative/simple_rsi.yml \
    --symbol=AAPL \
    --start=2023-01-01 \
    --endDate=2024-01-01 \
    --initialCash=100000 \
    --verbose
```

### Run a Batch Test

```bash
tzu batch --batch-file=examples/declarative/batch_test_example.yml --verbose
```

## Strategy Structure

All strategies follow this structure:

```yaml
version: "1.0"

metadata:
  name: "Strategy Name"
  description: "What the strategy does"
  author: "Your Name"
  tags:
    - tag1
    - tag2

indicators:
  - id: indicator_id
    type: indicator_type
    params:
      param1: value1
      param2: value2
    source: close  # Optional: open, high, low, close, volume
    output: field  # Optional: for multi-output indicators

entry:
  conditions:
    left: indicator_or_reference
    operator: comparison_operator
    right: value_or_indicator

exit:
  conditions:
    # Same structure as entry

position_sizing:
  type: fixed|percent|dynamic
  # Type-specific parameters
```

## Available Indicators

- **Trend**: sma, ema, dema, tema, trima, kama
- **Momentum**: rsi, roc, mom, cmo, stochrsi, ppo
- **Volatility**: atr, natr, bollinger, stdev
- **Volume**: obv, ad, mfi
- **Oscillators**: macd, stochastic, cci, aroon
- **Custom**: expression (Phase 3)

## Available Operators

- **Comparison**: `<`, `>`, `<=`, `>=`, `==`, `!=`
- **Crossover**: `crosses_above`, `crosses_below`
- **Logic**: `and`, `or`, `not` (Phase 3)

## Special References

- `price.open` - Open price
- `price.high` - High price
- `price.low` - Low price
- `price.close` - Close price
- `price.volume` - Volume

## Tips

1. **Start Simple**: Begin with basic strategies like `simple_rsi.yml`
2. **Validate First**: Always run `tzu validate` before backtesting
3. **Use Verbose Mode**: Add `--verbose` to see detailed execution
4. **Test Multiple Symbols**: Use batch testing to find robust strategies
5. **Adjust Parameters**: Use parameter overrides in batch tests to optimize

## Further Reading

- User Guide: `docs/user_guide.md`
- Reference Guide: `docs/reference_guide.md`
- Design Document: `tmp/design.md`
