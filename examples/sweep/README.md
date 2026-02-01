# Parameter Sweep Examples

This directory contains example parameter sweep configurations for automated strategy optimization.

## What is Parameter Sweep?

Parameter sweep (also called parameter optimization or grid search) automatically tests all combinations of parameter values to find the optimal settings for a strategy. Instead of manually testing different RSI periods or threshold values, you define ranges and let TzuTrader test them all.

## Files

### `macd_simple.yml`
A minimal sweep for quick testing:
- Base strategy: MACD Crossover
- 2 parameters (fast, slow period)
- 9 combinations (3 × 3)
- Single symbol, 6 months of data
- Perfect for learning how sweeps work

**Usage:**
```bash
./tzu --sweep=examples/sweep/macd_simple.yml
```

### `rsi_optimization.yml`
A comprehensive RSI optimization:
- Base strategy: RSI Simple
- 3 parameters (period, oversold, overbought)
- 100 combinations (4 × 5 × 5)
- 1 year of data on AAPL
- Demonstrates linear and list-based ranges

**Usage:**
```bash
./tzu --sweep=examples/sweep/rsi_optimization.yml
```

## Parameter Sweep Configuration Format

```yaml
version: "1.0"

metadata:
  name: "Sweep Name"
  description: "What you're optimizing"

# Base strategy file to optimize
base_strategy: "path/to/strategy.yml"

# Data configuration
data:
  source: yahoo
  symbols:
    - SYMBOL1
    - SYMBOL2
  start_date: "YYYY-MM-DD"
  end_date: "YYYY-MM-DD"

# Portfolio settings
portfolio:
  initial_cash: 100000.0
  commission: 0.001

# Parameters to sweep
parameters:
  - path: "indicators.rsi_14.period"
    range:
      type: list  # Explicit values
      values: [10, 14, 20, 30]
  
  - path: "conditions.entry.right"
    range:
      type: linear  # Range with steps
      min: 20
      max: 40
      step: 5

# Output files
output:
  best_results: "best_params.csv"    # Top N results
  full_results: "all_params.csv"     # All results
```

## Parameter Paths

Parameter paths use dot notation to specify what to optimize:

### Indicator Parameters
```yaml
# Format: indicators.<indicator_id>.<param_name>
- path: "indicators.rsi_14.period"
- path: "indicators.sma_50.period"
- path: "indicators.macd.fast"
```

### Condition Values
```yaml
# Format: conditions.<entry|exit>.right
# (Changes the threshold value)
- path: "conditions.entry.right"   # Oversold threshold
- path: "conditions.exit.right"    # Overbought threshold
```

### Position Sizing
```yaml
# Format: position_sizing.<param>
- path: "position_sizing.percent"
```

## Range Types

### Linear Range
Test values from min to max with a fixed step:
```yaml
range:
  type: linear
  min: 10      # Start value
  max: 30      # End value
  step: 5      # Increment
# Generates: 10, 15, 20, 25, 30
```

### List Range
Test specific explicit values:
```yaml
range:
  type: list
  values: [10, 14, 20, 30, 50]
# Tests exactly these values
```

## Combination Count

The total number of tests = product of all parameter value counts.

**Examples:**
- 1 parameter with 5 values = 5 tests
- 2 parameters with 5 values each = 25 tests
- 3 parameters with 5 values each = 125 tests

**Execution time** ≈ combinations × symbols × ~2 seconds per test

## Output

Parameter sweeps generate two CSV files:

### Full Results (`all_params.csv`)
All combinations tested with their parameter values:
```
Strategy,Symbol,Total Return %,Sharpe,indicators.rsi_14.period,conditions.entry.right
Sweep_1,AAPL,15.2,1.45,10,20
Sweep_2,AAPL,18.5,1.62,10,25
...
```

### Best Results (`best_params.csv`)
Top 50 performing combinations:
```
Strategy,Symbol,Total Return %,Sharpe,indicators.rsi_14.period,conditions.entry.right
Sweep_42,AAPL,28.5,2.15,20,30
Sweep_17,AAPL,25.3,1.98,14,25
...
```

## Console Output

The sweep shows the best parameters directly:
```
============================================================
Top 10 Parameter Combinations by rmTotalReturn
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

## Best Practices

### 1. Start Small
Begin with coarse-grained sweeps to find promising regions:
```yaml
# Coarse sweep (9 tests)
- path: "indicators.rsi_14.period"
  range:
    type: list
    values: [10, 20, 30]
```

Then refine around the best results:
```yaml
# Fine-grained sweep (11 tests)
- path: "indicators.rsi_14.period"
  range:
    type: linear
    min: 18
    max: 22
    step: 1
```

### 2. Use Representative Data
- Include multiple market conditions (bull, bear, sideways)
- Use at least 1 year of data
- Test on multiple symbols if possible

### 3. Watch for Overfitting
- Don't use too many parameters (keep it under 3-4)
- Validate results on out-of-sample data
- Be skeptical of "too good" results

### 4. Consider Execution Time
```
Combinations × Symbols × 2 seconds = Total time

Examples:
- 10 × 1 × 2s = 20 seconds
- 100 × 1 × 2s = 3.3 minutes
- 100 × 3 × 2s = 10 minutes
- 1000 × 1 × 2s = 33 minutes
```

### 5. Reasonable Parameter Ranges
Don't test nonsensical values:
- RSI period: 5-50 (not 1-1000)
- Oversold: 20-40 (not 0-100)
- Position size: 1%-20% (not 100%)

## Tips

1. **Quick Test First**: Run `macd_simple.yml` to verify sweep works
2. **Start Coarse**: Test wider ranges with bigger steps initially
3. **Refine Iteratively**: Zoom in on promising parameter regions
4. **Multiple Symbols**: Test on 2-3 symbols to avoid symbol-specific optimization
5. **Save Results**: Keep the CSV files for later analysis
6. **Document Winners**: Note which parameter combinations work best

## Avoiding Overfitting

Parameter optimization can lead to overfitting (finding parameters that work great on historical data but fail in live trading). To mitigate:

1. **Use Walk-Forward Testing**: Optimize on one period, test on the next
2. **Multiple Symbols**: If it works on AAPL, MSFT, and GOOGL, it's more robust
3. **Simpler is Better**: Fewer parameters = less overfitting risk
4. **Out-of-Sample Testing**: Always test winners on fresh data
5. **Realistic Expectations**: If something seems too good, it probably is

## Example Workflow

### 1. Initial Exploration (Coarse Sweep)
```bash
# Test wide ranges to find promising areas
./tzu --sweep=examples/sweep/rsi_coarse.yml
```

### 2. Refinement (Fine Sweep)
```bash
# Zoom in on the best parameter region
./tzu --sweep=examples/sweep/rsi_fine.yml
```

### 3. Validation (Different Symbol)
```bash
# Test winners on a different symbol
./tzu --sweep=examples/sweep/rsi_validate.yml
```

### 4. Deploy Winner
```bash
# Use the best parameters in production
./tzu --strategy=strategies/rsi_optimized.yml --symbol=AAPL
```

## Common Use Cases

### Optimize Indicator Period
```yaml
parameters:
  - path: "indicators.rsi_14.period"
    range:
      type: linear
      min: 10
      max: 30
      step: 2
```

### Optimize Entry/Exit Thresholds
```yaml
parameters:
  - path: "conditions.entry.right"
    range:
      type: linear
      min: 20
      max: 40
      step: 5
  
  - path: "conditions.exit.right"
    range:
      type: linear
      min: 60
      max: 80
      step: 5
```

### Optimize Position Sizing
```yaml
parameters:
  - path: "position_sizing.percent"
    range:
      type: list
      values: [2, 5, 10, 15, 20]
```

## Troubleshooting

**Error: "Indicator not found"**
- Check the indicator ID matches the YAML file
- Path format: `indicators.<ID>.<param>`

**Too Slow**
- Reduce parameter combinations
- Use shorter date range for initial testing
- Use fewer symbols

**No Good Results**
- Try wider parameter ranges
- Check if the base strategy is sound
- Verify data quality

**All Results Look Too Good**
- Likely overfitting
- Test on different symbols/periods
- Simplify the parameter space

## Next Steps

1. Run `macd_simple.yml` to see how sweeps work
2. Modify the parameters to understand ranges
3. Create your own sweep for a strategy you care about
4. Compare results across different parameter settings
5. Validate winners on out-of-sample data before deploying
