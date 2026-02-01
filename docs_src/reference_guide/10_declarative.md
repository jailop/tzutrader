# Declarative YAML Interface Reference

## Overview

The TzuTrader Declarative System allows you to define trading strategies using YAML configuration files instead of programming. This reference guide provides complete technical specifications for all features.

**Related Guides:**
- **User Guide**: [Writing Custom Strategies with YAML](../user_guide/04b_custom_strategies_yaml.md) - Tutorial and examples
- **User Guide**: [Writing Custom Strategies with Nim](../user_guide/04a_custom_strategies_nim.md) - Programming approach

## System Architecture

The declarative system consists of several modules:

```
src/tzutrader/declarative/
├── schema.nim              # Type definitions
├── parser.nim              # YAML parsing
├── validator.nim           # Validation and error checking
├── strategy_builder.nim    # Strategy construction
├── expression.nim          # Custom indicator expressions
├── position_sizing.nim     # Position sizing strategies
├── risk_management.nim     # Stop loss / take profit
├── batch_runner.nim        # Batch testing
├── sweep_generator.nim     # Parameter combination generation
└── sweep_runner.nim        # Parameter sweep execution
```

## Strategy YAML Schema

### Complete Strategy Format

```yaml
# Metadata Section (required)
metadata:
  name: "Strategy Name"                 # Required
  description: "Strategy description"   # Required
  author: "Author Name"                 # Optional
  created: "YYYY-MM-DD"                 # Optional
  tags:                                 # Optional
    - tag1
    - tag2

# Indicators Section (required)
indicators:
  - id: unique_identifier               # Required, your choice
    type: indicator_type                # Required, from supported list
    params:                             # Required (can be empty {})
      param_name: param_value
    source: close                       # Optional: open/high/low/close/volume
    output: output_name                 # Optional: for multi-output indicators

# Entry Conditions (required)
entry:
  conditions:
    # Simple condition
    left: indicator_or_value
    operator: comparison_operator
    right: indicator_or_value
    
    # OR compound condition
    all:  # All conditions must be true (AND)
      - left: ...
        operator: ...
        right: ...
      - left: ...
        operator: ...
        right: ...
    
    # OR compound condition
    any:  # Any condition must be true (OR)
      - left: ...
        operator: ...
        right: ...
    
    # NOT condition
    not:
      left: ...
      operator: ...
      right: ...

# Exit Conditions (required)
exit:
  conditions:
    # Same structure as entry

# Position Sizing (required)
position_sizing:
  type: fixed | percent
  size: number              # For 'fixed' type
  percent: number           # For 'percent' type
```

## Supported Indicators

### Moving Averages

#### SMA - Simple Moving Average
```yaml
- id: sma_20
  type: sma
  params:
    period: 20  # Required: number of periods
```
**Output**: Single value (the moving average)
**Range**: Follows price

#### EMA - Exponential Moving Average
```yaml
- id: ema_20
  type: ema
  params:
    period: 20    # Required: number of periods
    alpha: 2.0    # Optional: smoothing factor (default: 2.0)
```
**Output**: Single value
**Range**: Follows price

#### DEMA - Double Exponential Moving Average
```yaml
- id: dema_20
  type: dema
  params:
    period: 20  # Required
```
**Output**: Single value
**Range**: Follows price
**Use**: Less lag than EMA

#### TEMA - Triple Exponential Moving Average
```yaml
- id: tema_20
  type: tema
  params:
    period: 20  # Required
```
**Output**: Single value
**Range**: Follows price
**Use**: Even less lag than DEMA

#### TRIMA - Triangular Moving Average
```yaml
- id: trima_20
  type: trima
  params:
    period: 20  # Required
```
**Output**: Single value
**Range**: Follows price
**Use**: Double-smoothed moving average

#### KAMA - Kaufman Adaptive Moving Average
```yaml
- id: kama_10
  type: kama
  params:
    period: 10        # Required: efficiency ratio period
    fastPeriod: 2     # Optional: fast EMA period (default: 2)
    slowPeriod: 30    # Optional: slow EMA period (default: 30)
```
**Output**: Single value
**Range**: Follows price
**Use**: Adapts to market volatility

### Momentum Oscillators

#### RSI - Relative Strength Index
```yaml
- id: rsi_14
  type: rsi
  params:
    period: 14  # Required: lookback period
```
**Output**: Single value
**Range**: 0 to 100
**Common thresholds**: Oversold < 30, Overbought > 70

#### Stochastic Oscillator
```yaml
- id: stoch_14_3
  type: stochastic
  params:
    kPeriod: 14   # Required: %K period
    dPeriod: 3    # Required: %D period (SMA of %K)
```
**Outputs**:
- `stoch_14_3` - %K line
- `stoch_14_3.d` - %D line

**Range**: 0 to 100
**Common thresholds**: Oversold < 20, Overbought > 80

#### StochRSI - Stochastic RSI
```yaml
- id: stochrsi
  type: stochrsi
  params:
    rsiPeriod: 14   # Required: RSI period
    period: 14      # Required: Stochastic period
    kPeriod: 3      # Required: %K smoothing
    dPeriod: 3      # Required: %D smoothing
```
**Outputs**:
- `stochrsi` - %K line
- `stochrsi.d` - %D line

**Range**: 0 to 100
**Use**: More sensitive than regular Stochastic

#### CCI - Commodity Channel Index
```yaml
- id: cci_20
  type: cci
  params:
    period: 20  # Required
```
**Output**: Single value
**Range**: Unbounded (typically -200 to +200)
**Common thresholds**: Oversold < -100, Overbought > +100

#### MFI - Money Flow Index
```yaml
- id: mfi_14
  type: mfi
  params:
    period: 14  # Required
```
**Output**: Single value
**Range**: 0 to 100
**Use**: Volume-weighted RSI
**Common thresholds**: Oversold < 20, Overbought > 80

#### CMO - Chande Momentum Oscillator
```yaml
- id: cmo_14
  type: cmo
  params:
    period: 14  # Required
```
**Output**: Single value
**Range**: -100 to +100
**Use**: Similar to RSI but unbounded

#### MOM - Momentum
```yaml
- id: mom_10
  type: mom
  params:
    period: 10  # Required
```
**Output**: Single value
**Range**: Unbounded
**Use**: Rate of price change

### Trend Indicators

#### MACD - Moving Average Convergence Divergence
```yaml
- id: macd_std
  type: macd
  params:
    fast: 12     # Required: fast EMA period
    slow: 26     # Required: slow EMA period
    signal: 9    # Required: signal line period
```
**Outputs**:
- `macd_std` - MACD line (fast EMA - slow EMA)
- `macd_std.signal` - Signal line (EMA of MACD)
- `macd_std.histogram` - Histogram (MACD - signal)

**Range**: Unbounded
**Common signals**: Line crossovers, zero crossovers

#### PPO - Percentage Price Oscillator
```yaml
- id: ppo
  type: ppo
  params:
    fastPeriod: 12      # Required
    slowPeriod: 26      # Required
    signalPeriod: 9     # Required
```
**Outputs**:
- `ppo` - PPO line
- `ppo.signal` - Signal line
- `ppo.histogram` - Histogram

**Range**: Percentage
**Use**: MACD in percentage terms

#### ADX - Average Directional Index
```yaml
- id: adx_14
  type: adx
  params:
    period: 14  # Required
```
**Output**: Single value
**Range**: 0 to 100
**Use**: Trend strength (not direction)
**Common thresholds**: Weak < 25, Strong > 25

#### AROON - Aroon Indicator
```yaml
- id: aroon_25
  type: aroon
  params:
    period: 25  # Required
```
**Outputs**:
- `aroon_25` - Aroon Up
- `aroon_25.down` - Aroon Down

**Range**: 0 to 100
**Use**: Identify trend changes

#### PSAR - Parabolic SAR
```yaml
- id: psar
  type: psar
  params:
    acceleration: 0.02  # Optional: acceleration factor (default: 0.02)
    maximum: 0.20       # Optional: maximum acceleration (default: 0.20)
```
**Output**: Single value
**Range**: Price level
**Use**: Trailing stop and reverse

### Volatility Indicators

#### Bollinger Bands
```yaml
- id: bb_20
  type: bollinger
  params:
    period: 20        # Required: SMA period
    numStdDev: 2.0    # Required: number of standard deviations
```
**Outputs**:
- `bb_20.upper` - Upper band
- `bb_20.middle` - Middle band (SMA)
- `bb_20.lower` - Lower band

**Range**: Price levels
**Use**: Volatility and overbought/oversold

#### ATR - Average True Range
```yaml
- id: atr_14
  type: atr
  params:
    period: 14  # Required
```
**Output**: Single value
**Range**: Positive (price units)
**Use**: Volatility measurement, stop loss placement

#### NATR - Normalized ATR
```yaml
- id: natr_14
  type: natr
  params:
    period: 14  # Required
```
**Output**: Single value
**Range**: Percentage
**Use**: ATR normalized by price

#### STDEV - Standard Deviation
```yaml
- id: stdev_20
  type: stdev
  params:
    period: 20  # Required
```
**Output**: Single value
**Range**: Positive
**Use**: Volatility measurement

#### TRANGE - True Range
```yaml
- id: trange
  type: trange
  params: {}  # No parameters
```
**Output**: Single value
**Range**: Positive
**Use**: Single-bar volatility

#### MV - Variance
```yaml
- id: mv_20
  type: mv
  params:
    period: 20  # Required
```
**Output**: Single value
**Range**: Positive
**Use**: Statistical variance

### Volume Indicators

#### OBV - On-Balance Volume
```yaml
- id: obv
  type: obv
  params: {}  # No parameters
```
**Output**: Cumulative value
**Range**: Unbounded (cumulative)
**Use**: Volume flow confirmation

#### AD - Accumulation/Distribution
```yaml
- id: ad
  type: ad
  params: {}  # No parameters
```
**Output**: Cumulative value
**Range**: Unbounded (cumulative)
**Use**: Volume-price relationship

#### Volume SMA
```yaml
- id: vol_sma_20
  type: sma
  params:
    period: 20
  source: volume  # Apply to volume instead of price
```
**Output**: Single value
**Range**: Volume units
**Use**: Average volume comparison

### Price Data

You can reference raw price data directly without defining indicators:

- `open` - Opening price
- `high` - High price
- `low` - Low price
- `close` - Closing price
- `volume` - Trading volume

Example:
```yaml
entry:
  conditions:
    left: close
    operator: ">"
    right: open  # Close above open (bullish candle)
```

## Comparison Operators

### Basic Comparisons

| Operator | Symbol | Description | Example |
|----------|--------|-------------|---------|
| Less than | `<` | Left < Right | `rsi_14 < "30"` |
| Greater than | `>` | Left > Right | `rsi_14 > "70"` |
| Less or equal | `<=` | Left ≤ Right | `close <= bb_20.lower` |
| Greater or equal | `>=` | Left ≥ Right | `close >= bb_20.upper` |
| Equal | `==` | Left = Right | `adx_14 == "25"` |
| Not equal | `!=` | Left ≠ Right | `macd != "0"` |

### Crossover Operators

| Operator | Symbol | Description | Example |
|----------|--------|-------------|---------|
| Crosses above | `crosses_above` | Left crosses above Right | `ema_20 crosses_above ema_50` |
| Crosses below | `crosses_below` | Left crosses below Right | `ema_20 crosses_below ema_50` |

**Crossover Detection**:
- Requires indicator values from current and previous bar
- `crosses_above`: Previous (Left < Right) AND Current (Left > Right)
- `crosses_below`: Previous (Left > Right) AND Current (Left < Right)

**Valid crossover operands**: Only use with indicators or price fields, not with literal values.

## Condition Logic

### Simple Conditions

```yaml
conditions:
  left: indicator_or_value
  operator: comparison_operator
  right: indicator_or_value
```

**Left side**: Indicator ID, price field (open/high/low/close/volume), or sub-field (e.g., `macd.signal`)

**Operator**: Any comparison operator

**Right side**: Indicator ID, price field, sub-field, or literal value in quotes (e.g., `"30"`)

### Compound Conditions: AND

Use `all:` to require **all** conditions to be true:

```yaml
conditions:
  all:
    - left: rsi_14
      operator: "<"
      right: "30"
    - left: close
      operator: ">"
      right: sma_200
    - left: volume
      operator: ">"
      right: vol_avg
```

All three conditions must be true for entry/exit.

### Compound Conditions: OR

Use `any:` to trigger when **any** condition is true:

```yaml
conditions:
  any:
    - left: rsi_14
      operator: ">"
      right: "70"
    - left: macd
      operator: "<"
      right: "0"
```

Either condition triggers entry/exit.

### Compound Conditions: NOT

Use `not:` to negate a condition:

```yaml
conditions:
  not:
    left: rsi_14
    operator: "<"
    right: "30"
```

Triggers when RSI is NOT oversold.

### Nested Logic

Combine `all`, `any`, and `not` for complex logic:

```yaml
# Entry when (RSI oversold AND in uptrend) OR MACD bullish crossover
conditions:
  any:
    - all:
        - left: rsi_14
          operator: "<"
          right: "30"
        - left: close
          operator: ">"
          right: sma_200
    - left: macd
      operator: crosses_above
      right: macd.signal
```

## Position Sizing

### Fixed Size

Trade a fixed number of shares:

```yaml
position_sizing:
  type: fixed
  size: 100
```

**Use case**: Simple strategies, consistent position sizes

**Example**: Always buy/sell 100 shares regardless of price or capital

### Percentage of Capital

Trade a percentage of current portfolio equity:

```yaml
position_sizing:
  type: percent
  percent: 10.0
```

**Use case**: Adaptive position sizing, risk management

**Calculation**: 
```
shares = floor(equity * (percent / 100) / price)
```

**Example**: With $10,000 equity and 10% sizing:
- Stock at $50: buy 20 shares ($1,000)
- Stock at $100: buy 10 shares ($1,000)

## Batch Testing

Batch testing allows you to run multiple strategy variants on multiple symbols in a single command.

### Batch Configuration Format

```yaml
version: "1.0"

metadata:
  name: "Batch Test Name"
  description: "Description of what you're testing"
  author: "Your Name"

data:
  source: yahoo  # Data source: yahoo, csv, or coinbase
  symbols:
    - SYMBOL1
    - SYMBOL2
    - SYMBOL3
  start_date: "YYYY-MM-DD"
  end_date: "YYYY-MM-DD"

portfolio:
  initial_cash: 100000.0       # Required
  commission: 0.001            # Required (e.g., 0.001 = 0.1%)
  min_commission: 1.0          # Optional
  risk_free_rate: 0.02         # Optional (for Sharpe ratio)

strategies:
  - file: "path/to/strategy.yml"
    name: "Variant_Name"
    overrides:  # Optional
      # Override parameters (see below)

output:
  formats:
    - csv
  comparison_report: "results/comparison.csv"
  individual_results: "results/individual/"
```

### Parameter Overrides

Override specific parameters without creating new files:

#### Override Indicator Parameters

```yaml
overrides:
  indicators:
    rsi_14:  # Indicator ID to override
      params:
        period: 21  # New period value
```

#### Override Entry/Exit Conditions

```yaml
overrides:
  conditions:
    entry:
      left: rsi_14
      operator: "<"
      right: "25"  # More aggressive threshold
    exit:
      left: rsi_14
      operator: ">"
      right: "75"  # More aggressive threshold
```

#### Override Position Sizing

```yaml
overrides:
  position_sizing:
    type: percent
    percent: 15.0  # Larger position size
```

### Example Batch Configuration

```yaml
version: "1.0"

metadata:
  name: "RSI Parameter Comparison"
  description: "Compare different RSI thresholds"

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

strategies:
  - file: "rsi_simple.yml"
    name: "RSI_Conservative"
    # Use default parameters
  
  - file: "rsi_simple.yml"
    name: "RSI_Moderate"
    overrides:
      conditions:
        entry:
          left: rsi_14
          operator: "<"
          right: "35"
        exit:
          left: rsi_14
          operator: ">"
          right: "65"
  
  - file: "rsi_simple.yml"
    name: "RSI_Aggressive"
    overrides:
      conditions:
        entry:
          left: rsi_14
          operator: "<"
          right: "25"
        exit:
          left: rsi_14
          operator: ">"
          right: "75"

output:
  formats:
    - csv
  comparison_report: "results/rsi_comparison.csv"
```

### Running Batch Tests

```bash
./tzu --batch=batch_config.yml
```

### Batch Test Output

#### Console Summary

```
Batch Test: RSI Parameter Comparison
Total combinations: 9 (3 strategies × 3 symbols)
Running...

Completed 9 of 9 tests (100%)

Top 10 by Total Return:
  1. RSI_Aggressive on MSFT: 28.56% (Sharpe: 1.85)
  2. RSI_Moderate on AAPL: 22.14% (Sharpe: 1.62)
  3. RSI_Aggressive on AAPL: 20.89% (Sharpe: 1.52)
  ...
```

#### CSV Report

`results/rsi_comparison.csv`:

| Strategy | Symbol | Start | End | Total Return % | Sharpe | Max DD % | Trades |
|----------|--------|-------|-----|----------------|--------|----------|--------|
| RSI_Conservative | AAPL | 2023-01-01 | 2024-01-01 | 15.3 | 1.45 | -8.2 | 24 |
| RSI_Moderate | AAPL | 2023-01-01 | 2024-01-01 | 22.1 | 1.62 | -10.5 | 32 |
| RSI_Aggressive | AAPL | 2023-01-01 | 2024-01-01 | 20.9 | 1.52 | -12.5 | 48 |
| ... | ... | ... | ... | ... | ... | ... | ... |

## Parameter Sweep (Grid Search)

Parameter sweep automatically tests all combinations of parameter values to find optimal settings.

### Sweep Configuration Format

```yaml
version: "1.0"

metadata:
  name: "Sweep Name"
  description: "What you're optimizing"

base_strategy: "path/to/strategy.yml"

data:
  source: yahoo
  symbols:
    - SYMBOL1
  start_date: "YYYY-MM-DD"
  end_date: "YYYY-MM-DD"

portfolio:
  initial_cash: 100000.0
  commission: 0.001

parameters:
  - path: "indicators.indicator_id.param_name"
    range:
      type: list | linear
      # For list type:
      values: [value1, value2, value3]
      # For linear type:
      min: minimum_value
      max: maximum_value
      step: step_size

output:
  best_results: "best_params.csv"   # Top 50 results
  full_results: "all_params.csv"    # All results
```

### Parameter Paths

Use dot notation to specify what to optimize:

#### Indicator Parameters

```yaml
# Format: indicators.<indicator_id>.<param_name>
- path: "indicators.rsi_14.period"
- path: "indicators.sma_50.period"
- path: "indicators.macd_std.fast"
- path: "indicators.bb_20.numStdDev"
```

#### Condition Thresholds

```yaml
# Format: conditions.<entry|exit>.right
# (Changes the threshold value on the right side)
- path: "conditions.entry.right"
- path: "conditions.exit.right"
```

#### Position Sizing

```yaml
# Format: position_sizing.<param>
- path: "position_sizing.size"     # For fixed sizing
- path: "position_sizing.percent"  # For percent sizing
```

### Range Types

#### List Range

Test specific explicit values:

```yaml
range:
  type: list
  values: [10, 14, 20, 30, 50]
```

**Generates**: Exactly 5 test values

**Use case**: Non-linear values, specific candidates

#### Linear Range

Test values from min to max with a fixed step:

```yaml
range:
  type: linear
  min: 10
  max: 30
  step: 5
```

**Generates**: [10, 15, 20, 25, 30] - 5 values

**Use case**: Evenly spaced parameter ranges

### Combination Count

Total tests = **product of all parameter value counts**

**Examples**:
- 1 parameter with 5 values = **5 tests**
- 2 parameters with 5 values each = **25 tests**
- 3 parameters with 5 values each = **125 tests**
- 4 parameters with 4 values each = **256 tests**

**Execution time** ≈ combinations × symbols × ~2 seconds per test

### Example Sweep Configuration

```yaml
version: "1.0"

metadata:
  name: "Optimize RSI Strategy"
  description: "Find optimal RSI period and thresholds"

base_strategy: "rsi_simple.yml"

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
  best_results: "results/best_rsi_params.csv"
  full_results: "results/all_rsi_params.csv"
```

**This configuration tests**: 4 × 5 × 5 = **100 combinations**

### Running Parameter Sweeps

```bash
./tzu --sweep=sweep_config.yml
```

### Sweep Output

#### Console Summary

```
Parameter Sweep: Optimize RSI Strategy
Base Strategy: rsi_simple.yml
Total combinations: 100

Running sweep on AAPL...
Progress: 100/100 (100%)

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

#### Best Results CSV

`results/best_rsi_params.csv` (Top 50 combinations):

| Strategy | Symbol | Return % | Sharpe | Max DD % | Trades | rsi.period | entry.right | exit.right |
|----------|--------|----------|--------|----------|--------|------------|-------------|------------|
| Sweep_42 | AAPL | 28.50 | 2.15 | -8.20 | 36 | 20 | 30 | 70 |
| Sweep_17 | AAPL | 25.30 | 1.98 | -9.50 | 42 | 14 | 25 | 75 |
| ... | ... | ... | ... | ... | ... | ... | ... | ... |

#### Full Results CSV

`results/all_rsi_params.csv` (All 100 combinations):

Contains all tested combinations with their results.

## CLI Usage

### Single Strategy

```bash
./tzu --strategy=path/to/strategy.yml \
      --symbol=AAPL \
      --start=2023-01-01 \
      --end=2024-01-01
```

**Options**:
- `--strategy=FILE` - Path to YAML strategy file
- `--symbol=SYMBOL` - Stock symbol to test
- `--start=DATE` - Start date (YYYY-MM-DD)
- `--end=DATE` - End date (YYYY-MM-DD)
- `--initial-cash=AMOUNT` - Starting capital (default: 10000)
- `--commission=RATE` - Commission rate (default: 0.001)
- `--verbose` - Show detailed output

### Batch Testing

```bash
./tzu --batch=path/to/batch_config.yml
```

**Options**:
- `--batch=FILE` - Path to batch configuration file
- `--verbose` - Show detailed progress

### Parameter Sweep

```bash
./tzu --sweep=path/to/sweep_config.yml
```

**Options**:
- `--sweep=FILE` - Path to sweep configuration file
- `--verbose` - Show detailed progress

## Error Messages

The declarative system provides detailed error messages with source location information.

### Validation Errors

**Missing required field**:
```
Error: Missing required field 'metadata.name'
  in file: my_strategy.yml
```

**Invalid parameter type**:
```
Error: Parameter 'period' must be an integer, got string
  in file: my_strategy.yml
  at line: 18
  indicator: rsi_14
```

**Unknown indicator type**:
```
Error: Unknown indicator type: 'rsi2'
  in file: my_strategy.yml
  at line: 16
  Did you mean: 'rsi'?
```

**Invalid operator**:
```
Error: Unknown comparison operator: '>=='
  in file: my_strategy.yml
  at line: 25
  Valid operators: <, >, <=, >=, ==, !=, crosses_above, crosses_below
```

### Runtime Errors

**Indicator not found**:
```
Error: Indicator 'rsi_20' not defined
  in file: my_strategy.yml
  at line: 25
  Available indicators: rsi_14, sma_50, macd_std
```

**Invalid condition reference**:
```
Error: Cannot resolve reference 'macd.invalid'
  in file: my_strategy.yml
  at line: 30
  Valid outputs for macd: (no suffix), .signal, .histogram
```

**Crossover with literal**:
```
Error: Operator 'crosses_above' requires indicator on both sides
  in file: my_strategy.yml
  at line: 28
  Found: ema_20 crosses_above "50"
  Hint: Use '>' for comparisons with literals
```

## Best Practices

### Strategy Design

1. **Start simple**: Begin with 1-2 indicators and simple conditions
2. **Test incrementally**: Add complexity gradually
3. **Use descriptive IDs**: `rsi_14` not `ind1`
4. **Document metadata**: Include clear name and description

### Parameter Selection

1. **Reasonable ranges**: RSI 10-30, not 1-1000
2. **Standard values first**: RSI 14, MA 20/50/200
3. **Avoid extreme thresholds**: RSI < 5 rarely triggers
4. **Consider market context**: Different values for different regimes

### Testing Strategy

1. **Multiple timeframes**: Test 6-month, 1-year, 2-year periods
2. **Multiple symbols**: Test on 3-5 stocks from different sectors
3. **Out-of-sample validation**: Optimize on one period, test on another
4. **Walk-forward testing**: Rolling optimization and validation

### Batch Testing

1. **Use overrides**: Test parameter variations without file duplication
2. **Compare fairly**: Same data period and portfolio settings
3. **Look at multiple metrics**: Return, Sharpe, drawdown, win rate
4. **Export results**: Keep CSV files for later analysis

### Parameter Optimization

1. **Coarse then fine**: Start with wide ranges, narrow down
2. **Limit combinations**: Keep under 500 for reasonable execution time
3. **Watch for overfitting**: Too many parameters = curve fitting
4. **Validate winners**: Test optimized parameters on fresh data
5. **Multiple symbols**: If it works on AAPL, MSFT, and GOOGL, it's more robust

### Avoiding Overfitting

1. **Fewer parameters**: 2-3 parameters maximum
2. **Reasonable ranges**: Don't test nonsensical values
3. **Multiple markets**: Optimize and validate on different symbols
4. **Simple strategies**: Complex ≠ better
5. **Realistic expectations**: 100% return with 0% drawdown = overfit

## Performance Considerations

### Execution Speed

- **Single backtest**: ~2 seconds for 1 year of daily data
- **Batch test (10 variants × 3 symbols)**: ~60 seconds
- **Parameter sweep (100 combinations)**: ~3.5 minutes

### Memory Usage

- **Single strategy**: < 10 MB
- **Batch test (50 combinations)**: < 50 MB
- **Large sweep (1000 combinations)**: < 100 MB

### Optimization Tips

1. **Use list ranges for non-linear values**: More targeted than linear
2. **Reduce date range for initial testing**: 6 months instead of 5 years
3. **Start with coarse sweep**: Find promising region quickly
4. **Use multiple sweep stages**: Coarse → fine-grained
5. **Test one symbol first**: Validate before expanding to multiple symbols

## Troubleshooting

### No Trades Generated

**Causes**:
- Conditions too restrictive (too many `all:` conditions)
- Thresholds too extreme (RSI < 10)
- Insufficient data history (indicators need warmup period)
- Indicator never crosses threshold

**Solutions**:
- Simplify conditions (remove some from `all:`)
- Widen thresholds (RSI < 35 instead of < 25)
- Use longer date range (1+ years)
- Check indicator values are in expected range

### Too Many Trades

**Causes**:
- Conditions too loose
- No trend filter in choppy market
- Thresholds too wide

**Solutions**:
- Add more filters (use `all:` with multiple conditions)
- Add trend filter (e.g., only trade when above 200-day SMA)
- Narrow thresholds

### Poor Performance

**Causes**:
- Strategy not suited for symbol or timeframe
- Overfitting to specific market condition
- Parameters need optimization
- Missing risk management

**Solutions**:
- Test on multiple symbols and timeframes
- Simplify strategy
- Use parameter sweep to find better settings
- Consider adding stop loss / take profit (future feature)

### Sweep Takes Too Long

**Causes**:
- Too many parameter combinations
- Long date range
- Multiple symbols

**Solutions**:
- Reduce parameter ranges (coarse sweep first)
- Use shorter date range for initial testing
- Start with single symbol
- Use list range with fewer specific values

## Advanced Topics

### Multi-Symbol Sweep

Test parameter optimization across multiple symbols:

```yaml
data:
  symbols:
    - AAPL
    - MSFT
    - GOOGL

parameters:
  - path: "indicators.rsi_14.period"
    range:
      type: list
      values: [10, 14, 20]
```

This tests 3 periods × 3 symbols = **9 combinations**

Results show which parameters work well across all symbols.

### Two-Stage Optimization

**Stage 1: Coarse Search**
```yaml
parameters:
  - path: "indicators.rsi_14.period"
    range:
      type: list
      values: [10, 20, 30]  # Wide spacing
```

Finds promising region (e.g., period 20 works best).

**Stage 2: Fine Search**
```yaml
parameters:
  - path: "indicators.rsi_14.period"
    range:
      type: linear
      min: 18
      max: 22
      step: 1  # Fine spacing
```

Refines optimal value (e.g., period 19 is best).

### Combining Batch and Sweep

Use batch testing to compare:
- Strategy A (optimized)
- Strategy B (optimized)
- Strategy C (default parameters)

This shows whether optimization helps and which strategy is fundamentally better.

## Future Enhancements

Planned features for the declarative system:

1. **Risk Management** (Phase 3)
   - Stop loss configuration
   - Take profit targets
   - Position sizing based on ATR

2. **Custom Expressions** (Phase 3)
   - Define custom indicators with formulas
   - `formula: "(rsi_14 + rsi_21) / 2"`

3. **Walk-Forward Testing** (Phase 5)
   - Automated rolling optimization
   - Out-of-sample validation

4. **HTML Reports** (Phase 5)
   - Interactive visualizations
   - Equity curves
   - Trade analysis

## See Also

- [User Guide: Custom Strategies with YAML](../user_guide/04b_custom_strategies_yaml.md)
- [User Guide: Custom Strategies with Nim](../user_guide/04a_custom_strategies_nim.md)
- [Reference: Indicators](03_indicators.md)
- [Reference: CLI Tool](09_cli.md)
- [User Guide: Workflows](../user_guide/09_workflows.md)

## Summary

The TzuTrader Declarative System provides:

- ✅ 30+ built-in technical indicators
- ✅ Flexible condition logic (AND/OR/NOT)
- ✅ Two position sizing methods
- ✅ Comprehensive validation with clear errors
- ✅ Batch testing for strategy comparison
- ✅ Parameter sweep for optimization
- ✅ CSV export for analysis
- ✅ Zero programming required

Whether you're a trader testing ideas or a developer prototyping strategies, the declarative system provides a powerful, flexible, and user-friendly interface.
