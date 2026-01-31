# Declarative Strategies Reference

This reference provides complete technical documentation for TzuTrader's declarative strategy system.

## YAML Schema

### Root Structure

```yaml
version: string              # Required: Schema version (currently "1.0")
metadata: MetadataYAML       # Required: Strategy metadata
indicators: seq[IndicatorYAML]  # Required: List of indicators
entry: RuleYAML              # Required: Entry conditions
exit: RuleYAML               # Required: Exit conditions
position_sizing: PositionSizingYAML  # Required: Position sizing strategy
```

### MetadataYAML

```yaml
name: string                 # Required: Strategy name
description: string          # Required: Brief description
author: string               # Optional: Author name
created: string              # Optional: Creation date (YYYY-MM-DD)
tags: seq[string]            # Optional: List of tags
```

**Validation Rules:**
- `name` cannot be empty
- `description` cannot be empty

### IndicatorYAML

```yaml
id: string                   # Required: Unique identifier
type: string                 # Required: Indicator type
params: Table[string, ParamValue]  # Required: Parameters
source: string               # Optional: Data source (open/high/low/close/volume)
output: string               # Optional: Output field selection
```

**Indicator Types:**

| Type | Description | Parameters |
|------|-------------|------------|
| `sma` | Simple Moving Average | `period: int` |
| `ema` | Exponential Moving Average | `period: int` |
| `dema` | Double EMA | `period: int` |
| `tema` | Triple EMA | `period: int` |
| `trima` | Triangular MA | `period: int` |
| `kama` | Kaufman Adaptive MA | `period: int, fast_sc: int, slow_sc: int` |
| `rsi` | Relative Strength Index | `period: int` |
| `roc` | Rate of Change | `period: int` |
| `mom` | Momentum | `period: int` |
| `cmo` | Chande Momentum Oscillator | `period: int` |
| `stochrsi` | Stochastic RSI | `period: int, k_period: int, d_period: int` |
| `ppo` | Percentage Price Oscillator | `fast: int, slow: int, signal: int` |
| `atr` | Average True Range | `period: int` |
| `natr` | Normalized ATR | `period: int` |
| `trange` | True Range | (no parameters) |
| `bollinger` | Bollinger Bands | `period: int, std_dev: float` |
| `stdev` | Standard Deviation | `period: int` |
| `mv` | Moving Variance | `period: int` |
| `obv` | On-Balance Volume | (no parameters) |
| `ad` | Accumulation/Distribution | (no parameters) |
| `mfi` | Money Flow Index | `period: int` |
| `macd` | MACD | `fast: int, slow: int, signal: int` |
| `stochastic` | Stochastic Oscillator | `k_period: int, d_period: int` |
| `cci` | Commodity Channel Index | `period: int` |
| `aroon` | Aroon Indicator | `period: int` |
| `expression` | Custom Expression | `expression: string` |

**Source Options:**
- `open` - Open price
- `high` - High price
- `low` - Low price
- `close` - Close price (default)
- `volume` - Trading volume

**Multi-Output Indicators:**

Some indicators have multiple outputs that can be selected:

| Indicator | Outputs |
|-----------|---------|
| `bollinger` | `middle`, `upper`, `lower` |
| `macd` | `macd`, `signal`, `histogram` |
| `stochastic` | `k`, `d` |
| `stochrsi` | `k`, `d` |
| `ppo` | `ppo`, `signal`, `histogram` |
| `aroon` | `up`, `down`, `oscillator` |

**Output Selection:**

```yaml
# Default output
- id: bb
  type: bollinger
  params:
    period: 20
    std_dev: 2.0
  output: middle  # Set default

# Override in conditions
conditions:
  left: bb.upper  # Dot notation overrides default
  operator: "<"
  right: price.close
```

**Validation Rules:**
- `id` must be unique across all indicators
- `id` cannot be empty
- `type` must be a supported indicator type
- All required parameters must be provided
- Parameters must be valid for the indicator type

### RuleYAML (Entry/Exit)

```yaml
conditions: ConditionYAML    # Required: Condition tree
```

### ConditionYAML

**Simple Condition:**

```yaml
left: string                 # Left operand (indicator or reference)
operator: ComparisonOp       # Comparison operator
right: string                # Right operand (indicator, reference, or literal)
```

**AND Condition:**

```yaml
operator: and
conditions: seq[ConditionYAML]  # List of conditions (all must be true)
```

**OR Condition:**

```yaml
operator: or
conditions: seq[ConditionYAML]  # List of conditions (at least one must be true)
```

**NOT Condition:**

```yaml
operator: not
condition: ConditionYAML     # Single condition to negate
```

**Comparison Operators:**

| Operator | Description | Example |
|----------|-------------|---------|
| `<` | Less than | `rsi_14 < 30` |
| `>` | Greater than | `rsi_14 > 70` |
| `<=` | Less than or equal | `price.close <= sma_20` |
| `>=` | Greater than or equal | `price.close >= sma_20` |
| `==` | Equal | `macd.histogram == 0` |
| `!=` | Not equal | `volume != 0` |
| `crosses_above` | Crosses above | `sma_fast crosses_above sma_slow` |
| `crosses_below` | Crosses below | `sma_fast crosses_below sma_slow` |

**Reference Types:**

1. **Indicator References**: Use indicator IDs
   ```yaml
   left: rsi_14
   ```

2. **Price References**: Use `price.` prefix
   ```yaml
   left: price.close
   left: price.open
   left: price.high
   left: price.low
   left: price.volume
   ```

3. **Literal Values**: Numeric strings
   ```yaml
   right: "30"
   right: "100.5"
   ```

4. **Indicator Output Fields**: Use dot notation
   ```yaml
   left: bb.upper
   left: macd.signal
   left: stoch.k
   ```

**Validation Rules:**
- All referenced indicators must be defined
- Special references (`price.*`) are always available
- AND/OR conditions must have at least one sub-condition
- NOT conditions must have exactly one sub-condition
- Circular references are not allowed

### PositionSizingYAML

**Fixed Size:**

```yaml
type: fixed
size: float                  # Number of shares/units
```

**Percentage of Capital:**

```yaml
type: percent
percent: float               # Percentage (0-100)
```

**Dynamic Expression:**

```yaml
type: dynamic
expression: string           # Mathematical expression
```

**Expression Syntax:**

Available variables:
- `capital` - Available capital
- `price` - Current price
- `volume` - Current volume
- Any indicator ID

Available operators:
- Arithmetic: `+`, `-`, `*`, `/`
- Functions: `abs()`, `sqrt()`, `max()`, `min()`

Example expressions:
```yaml
# Risk-based sizing
expression: "(capital * 0.02) / (atr_14 * 2)"

# Price-based sizing  
expression: "capital * 0.5 / price.close"

# Volatility-adjusted
expression: "if(atr_14 < 2.0, 200, 100)"
```

**Validation Rules:**
- `size` must be positive for fixed sizing
- `percent` must be between 0 and 100
- `expression` must be valid syntax
- Expression variables must reference defined indicators

## Batch Testing Schema

### BatchTestYAML

```yaml
version: string              # Required: Schema version
type: "batch_test"           # Required: Must be "batch_test"
data: DataSourceYAML         # Required: Data configuration
strategies: seq[StrategyConfigYAML]  # Required: Strategies to test
portfolio: PortfolioConfigYAML  # Required: Portfolio settings
output: OutputConfigYAML     # Optional: Output configuration
```

### DataSourceYAML

```yaml
source: string               # Required: "yahoo", "csv", or "coinbase"
symbols: seq[string]         # Required: List of symbols
start_date: string           # Required: Start date (YYYY-MM-DD)
end_date: string             # Required: End date (YYYY-MM-DD)
csv_path: string             # Optional: Path to CSV (for csv source)
```

**Validation Rules:**
- `source` must be one of: "yahoo", "csv", "coinbase"
- `symbols` cannot be empty
- `start_date` and `end_date` are required
- `csv_path` is required when `source` is "csv"

### StrategyConfigYAML

```yaml
file: string                 # Required: Path to strategy YAML
name: string                 # Required: Unique name for this configuration
overrides: seq[ParameterOverride]  # Optional: Parameter overrides
```

### ParameterOverride

```yaml
indicator_id:
  param_name: param_value
```

**Example:**

```yaml
strategies:
  - file: "strategies/rsi.yml"
    name: "RSI Default"
  
  - file: "strategies/rsi.yml"
    name: "RSI Aggressive"
    overrides:
      rsi_14:
        period: 10
        oversold: 25
```

**Validation Rules:**
- `file` must exist and be a valid strategy YAML
- `name` must be unique within the batch test
- Overridden indicators must exist in the strategy
- Overridden parameters must be valid for the indicator

### PortfolioConfigYAML

```yaml
initial_cash: float          # Required: Starting capital
commission: float            # Required: Commission rate (e.g., 0.001 = 0.1%)
```

**Validation Rules:**
- `initial_cash` must be positive
- `commission` must be between 0 and 1

### OutputConfigYAML

```yaml
comparison_report: string    # Optional: Path to comparison report
individual_results: string   # Optional: Directory for individual results
format: string               # Optional: "html", "csv", or "json"
```

## Expression Language

### Syntax

**Literals:**
```
42          # Integer
3.14        # Float
```

**References:**
```
indicator_id       # Indicator value
price.close        # Price reference
volume             # Current volume
```

**Arithmetic Operators:**
```
+, -, *, /         # Basic arithmetic
```

**Comparison Operators:**
```
<, >, <=, >=, ==, !=
```

**Logical Operators:**
```
and, or, not
```

**Functions:**
```
abs(x)             # Absolute value
sqrt(x)            # Square root
max(x, y)          # Maximum
min(x, y)          # Minimum
```

**Precedence** (highest to lowest):
1. Function calls
2. Multiplication, Division
3. Addition, Subtraction
4. Comparisons
5. NOT
6. AND
7. OR

**Examples:**

```yaml
# Moving average distance
expression: "price.close - sma_20"

# Volatility ratio
expression: "atr_14 / price.close * 100"

# Relative momentum
expression: "(price.close - sma_20) / sma_20 * 100"

# Volume surge detection
expression: "price.volume > vol_sma * 2"

# Complex calculation
expression: "abs(rsi_14 - 50) < 10 and price.volume > vol_sma"
```

### Error Handling

**Division by zero**: Returns `NaN`
**Undefined reference**: Validation error
**Invalid syntax**: Parse error

## CLI Commands

### Strategy Validation

```bash
tzu validate --strategy-file=<FILE> [--verbose]
```

**Checks:**
- YAML syntax
- Required fields present
- Indicator references valid
- No duplicate indicator IDs
- Valid parameter types

**Exit Codes:**
- `0` - Valid
- `1` - Validation failed or error

### Running Strategies

```bash
tzu --yaml-strategy=<FILE> \
    --symbol=<SYMBOL> \
    --start=<DATE> \
    [--endDate=<DATE>] \
    [--initialCash=<AMOUNT>] \
    [--commission=<RATE>] \
    [--verbose]
```

### Batch Testing

```bash
tzu batch --batch-file=<FILE> \
    [--output=<FILE>] \
    [--format=html|csv|json] \
    [--verbose]
```

**Report Formats:**

**HTML**: Interactive comparison report with:
- Configuration summary
- Summary statistics
- Sortable results table
- Color-coded performance metrics

**CSV**: Spreadsheet-friendly export with all metrics

**JSON**: Programmatic access to all results

### Batch Validation

```bash
tzu validate --batch-file=<FILE> [--verbose]
```

**Checks:**
- Batch YAML syntax
- Required sections present
- All referenced strategy files exist
- All referenced strategies are valid
- Data source configuration valid

## File Organization

### Recommended Structure

```
my_project/
├── strategies/
│   ├── mean_reversion/
│   │   ├── rsi.yml
│   │   ├── bollinger.yml
│   │   └── stochastic.yml
│   ├── trend_following/
│   │   ├── ma_cross.yml
│   │   ├── macd.yml
│   │   └── golden_cross.yml
│   └── hybrid/
│       └── rsi_volume.yml
├── batch_tests/
│   ├── compare_rsi.yml
│   ├── optimize_ma.yml
│   └── full_comparison.yml
└── results/
    ├── reports/
    └── individual/
```

### Naming Conventions

**Strategies:**
- Use descriptive names: `rsi_oversold_30.yml` not `strat1.yml`
- Include key parameters: `ma_cross_10_30.yml`
- Use lowercase with underscores

**Batch Tests:**
- Describe purpose: `compare_momentum_strategies.yml`
- Include date for experiments: `rsi_optimization_2024_01.yml`

**Indicator IDs:**
- Include indicator type and parameters: `rsi_14`, `sma_fast_10`
- Use consistent naming across strategies
- Avoid generic names like `ind1`, `ma`

## Error Messages

### Parse Errors

**YAML Syntax Error:**
```
✗ Parse Error: YAML syntax error at line 15: unexpected character
```
**Fix**: Check YAML indentation and syntax

**Missing Required Field:**
```
✗ Parse Error: Missing required 'indicators' section
```
**Fix**: Add the missing section to your YAML file

### Validation Errors

**Undefined Reference:**
```
✗ Validation Error: Indicator 'sma_20' referenced in entry conditions is not defined
```
**Fix**: Add the indicator to the `indicators` section or fix the reference

**Duplicate ID:**
```
✗ Validation Error: Duplicate indicator ID 'rsi_14' (must be unique)
```
**Fix**: Rename one of the duplicate indicators

**Invalid Parameter:**
```
✗ Validation Error: Invalid parameter 'periods' for indicator type 'rsi' (expected 'period')
```
**Fix**: Check the correct parameter name in the reference guide

**Empty Condition:**
```
✗ Validation Error: AND condition must have at least one sub-condition
```
**Fix**: Add at least one condition to the AND/OR block

### Runtime Errors

**File Not Found:**
```
✗ Error: Strategy file not found: strategies/missing.yml
```
**Fix**: Check the file path and ensure the file exists

**Data Fetch Error:**
```
✗ Error: Failed to fetch data for AAPL: Invalid symbol
```
**Fix**: Verify the symbol is correct and available from the data source

**Commission Rate Error:**
```
✗ Error: commission must be between 0 and 1 (e.g., 0.001 for 0.1%)
```
**Fix**: Use decimal format for commission (0.001 not 1)

## Performance Considerations

### Indicator Updates

Indicators are updated once per bar in the order they are defined. Dependencies are handled automatically:

```yaml
indicators:
  - id: sma_20        # Updated first
    type: sma
    params:
      period: 20
  
  - id: distance      # Can use sma_20 (defined above)
    type: expression
    expression: "price.close - sma_20"
```

### Expression Evaluation

Expressions are evaluated after all standard indicators:

1. Standard indicators update
2. Expression indicators evaluate
3. Conditions checked

**Optimization Tips:**
- Keep expressions simple
- Avoid redundant calculations
- Use standard indicators when possible

### Batch Testing

**Parallel Execution**: Currently sequential, but structure supports future parallelization

**Memory Usage**: Each strategy-symbol combination runs independently

**Optimization Strategies:**
- Test on smaller date ranges first
- Use fewer symbols for initial tests
- Validate strategies before batch testing

## Advanced Patterns

### Multi-Timeframe Analysis

Use indicators on different data sources:

```yaml
indicators:
  - id: fast_sma
    type: sma
    params:
      period: 10
    source: close
  
  - id: slow_sma
    type: sma
    params:
      period: 50
    source: close
```

### Confirmation Patterns

Require multiple confirmations:

```yaml
entry:
  conditions:
    operator: and
    conditions:
      # Price confirmation
      - left: price.close
        operator: ">"
        right: sma_200
      
      # Momentum confirmation
      - left: rsi_14
        operator: ">"
        right: "50"
      
      # Volume confirmation
      - left: price.volume
        operator: ">"
        right: vol_sma
      
      # Trend confirmation
      - left: macd.histogram
        operator: ">"
        right: "0"
```

### Risk Management

Combine position sizing with risk controls:

```yaml
position_sizing:
  type: dynamic
  expression: "min(capital * 0.02 / atr_14, capital * 0.1 / price.close)"
```

This limits position size by both volatility and maximum exposure.

### Strategy Families

Create strategy variants efficiently:

**Base Strategy** (`rsi_base.yml`):
```yaml
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
```

**Batch Test with Variations**:
```yaml
strategies:
  - file: "rsi_base.yml"
    name: "RSI Fast (7)"
    overrides:
      rsi_14:
        period: 7
  
  - file: "rsi_base.yml"
    name: "RSI Standard (14)"
  
  - file: "rsi_base.yml"
    name: "RSI Slow (21)"
    overrides:
      rsi_14:
        period: 21
```

## Limitations

### Current Limitations

1. **Single Timeframe**: Each strategy operates on one timeframe
2. **Single Symbol**: Strategies trade one symbol at a time
3. **Long Only**: No short selling support yet
4. **Sequential Execution**: Batch tests run sequentially
5. **No Stop Loss**: Must be implemented in exit conditions

### Future Enhancements

- Multi-timeframe support
- Portfolio-level strategies
- Short selling
- Parallel batch execution
- Risk management directives

## See Also

- [User Guide - Declarative Strategies](../user_guide/10_declarative.md)
- [CLI Reference](09_cli.md)
- [Examples Directory](https://github.com/jailop/tzutrader/tree/main/examples/declarative)
