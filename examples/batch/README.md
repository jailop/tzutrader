# Batch Testing Examples

This directory contains example batch test configurations for TzuTrader Phase 4.

## What is Batch Testing?

Batch testing allows you to run multiple strategy variants on multiple symbols in a single command, making it easy to compare performance across different parameters and market conditions.

## Files

### `quick_test.yml`
A minimal batch test for quick validation:
- Single symbol (AAPL)
- Single strategy (RSI Simple)
- 6 months of data
- Perfect for testing that batch functionality works

**Usage:**
```bash
./tzu --batch=examples/batch/quick_test.yml
```

### `basic_batch.yml`
A comprehensive comparison of multiple strategies:
- 3 symbols (AAPL, MSFT, GOOGL)
- 5 strategy variants (RSI variations, MACD, Bollinger)
- 1 year of data (2023)
- Demonstrates parameter overrides

**Usage:**
```bash
./tzu --batch=examples/batch/basic_batch.yml
```

## Batch Configuration Format

A batch test YAML file has the following structure:

```yaml
version: "1.0"

metadata:
  name: "Batch Test Name"
  description: "What this batch test does"
  author: "Your Name"

data:
  source: yahoo  # or csv
  symbols:
    - SYMBOL1
    - SYMBOL2
  start_date: "YYYY-MM-DD"
  end_date: "YYYY-MM-DD"

portfolio:
  initial_cash: 100000.0
  commission: 0.001
  min_commission: 1.0
  risk_free_rate: 0.02

strategies:
  - file: "path/to/strategy.yml"
    name: "Variant_Name"
    overrides:  # Optional parameter overrides
      indicators:
        indicator_id:
          params:
            param_name: new_value
      conditions:
        entry:
          # Override entry condition
        exit:
          # Override exit condition
      position_sizing:
        type: percent
        percent: 5.0

output:
  formats:
    - csv
    - json  # Future
    - html  # Future
  comparison_report: "results.csv"
  individual_results: "results/"  # Directory for individual CSVs
```

## Parameter Overrides

Parameter overrides allow you to test variations of a base strategy without creating separate YAML files:

### Override Indicator Parameters
```yaml
overrides:
  indicators:
    rsi_14:
      params:
        period: 21  # Change RSI period from 14 to 21
```

### Override Entry/Exit Conditions
```yaml
overrides:
  conditions:
    entry:
      left: "rsi_14"
      operator: "<"
      right: "25"  # More aggressive entry threshold
    exit:
      left: "rsi_14"
      operator: ">"
      right: "75"  # More aggressive exit threshold
```

### Override Position Sizing
```yaml
overrides:
  position_sizing:
    type: percent
    percent: 10.0  # Use 10% of capital per trade
```

## Output

Batch tests generate comparison reports in the specified formats:

### CSV Output
The CSV report contains one row per strategy-symbol combination:

| Strategy | Symbol | Start Date | End Date | Total Return % | Sharpe Ratio | Max Drawdown % | Win Rate % | Num Trades |
|----------|--------|------------|----------|----------------|--------------|----------------|------------|------------|
| RSI_Simple | AAPL | 2023-01-01 | 2024-01-01 | 15.3 | 1.45 | -8.2 | 62.5 | 24 |
| RSI_Aggressive | AAPL | 2023-01-01 | 2024-01-01 | 22.1 | 1.78 | -12.5 | 58.3 | 36 |
| ... | ... | ... | ... | ... | ... | ... | ... | ... |

## Tips

1. **Start Small**: Begin with `quick_test.yml` to verify everything works
2. **Use Overrides**: Test parameter variations without creating new files
3. **Compare Apples to Apples**: Use the same data period and portfolio settings for fair comparison
4. **Watch Commission**: Commission settings can significantly impact results
5. **Multiple Symbols**: Test on multiple symbols to avoid overfitting to a single stock

## Next Steps

- Try the quick test to verify batch functionality works
- Modify `basic_batch.yml` with your own symbols and date ranges
- Create your own batch configurations to compare different strategies
- Check out `examples/phase4/parameter_sweep.yml` for automated parameter optimization (coming soon)

## Troubleshooting

**Error: "Failed to fetch data"**
- Check your internet connection
- Verify symbol tickers are correct
- Try a different date range (some symbols have limited history)

**Error: "Failed to parse strategy file"**
- Verify the strategy file path is correct relative to project root
- Check that the strategy YAML is valid

**Slow execution**
- Batch tests with many combinations can take time
- Use `--verbose` to see progress
- Consider reducing the date range or number of symbols for initial testing
