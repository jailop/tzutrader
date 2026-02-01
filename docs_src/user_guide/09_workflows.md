# Advanced Workflows

## Parameter Optimization

Parameter optimization involves testing different parameter values to
find the combination that produces the best results. While this can
improve performance, it carries significant risk of overfitting.

### The Dangers of Optimization

Testing many parameter combinations will eventually find settings that
performed well historically, but this doesn't guarantee future
performance:

```nim
# DON'T do this naively
var bestReturn = -999999.0
var bestPeriod = 0

# Testing 50 different periods
for period in 5..55:
  let strategy = newRSIStrategy(period = period, oversold = 30, overbought = 70)
  let report = quickBacktest("AAPL", strategy, data, 100000.0, 0.001)
  
  if report.totalReturn > bestReturn:
    bestReturn = report.totalReturn
    bestPeriod = period

# This "best" period is probably overfit to historical data
echo "Best period: ", bestPeriod, " with ", bestReturn, "% return"
```

The problem: you tested 50 variations and picked the best one for this
specific dataset. It likely won't perform as well on new data.

### Responsible Optimization Approach

If you must optimize, follow these guidelines:

1. Use Out-of-Sample Testing

Split data into in-sample (for optimization) and out-of-sample (for validation):

```nim
let allData = readCSV("data/AAPL.csv")

# Split: first 70% for optimization, last 30% for validation
let splitPoint = int(allData.len.float64 * 0.7)
let inSampleData = allData[0..<splitPoint]
let outSampleData = allData[splitPoint..^1]

# Optimize on in-sample data
var bestPeriod = 14
var bestReturn = -999999.0

for period in [10, 12, 14, 16, 18, 20]:  # Test fewer values
  let strategy = newRSIStrategy(period = period, oversold = 30, overbought = 70)
  let report = quickBacktest("AAPL", strategy, inSampleData, 100000.0, 0.001)
  
  if report.totalReturn > bestReturn:
    bestReturn = report.totalReturn
    bestPeriod = period

# Validate on out-of-sample data
let finalStrategy = newRSIStrategy(period = bestPeriod, oversold = 30, overbought = 70)
let outSampleReport = quickBacktest("AAPL", finalStrategy, outSampleData, 100000.0, 0.001)

echo "In-sample return: ", bestReturn, "%"
echo "Out-of-sample return: ", outSampleReport.totalReturn, "%"

# If out-of-sample is much worse, the parameters are overfit
```

2. Limit Parameter Space

Test fewer values, focusing on reasonable ranges:

```nim
# Good: test a few logical values
let rsiPeriods = @[7, 14, 21]        # 3 values
let oversoldLevels = @[25.0, 30.0]   # 2 values
let overboughtLevels = @[70.0, 75.0] # 2 values

# Total combinations: 3 × 2 × 2 = 12

# Bad: test everything
for period in 5..50:              # 46 values
  for oversold in [20.0, 22.0, 24.0, 26.0, 28.0, 30.0]:  # 6 values
    for overbought in [70.0, 72.0, 74.0, 76.0, 78.0, 80.0]:  # 6 values
      # Total combinations: 46 × 6 × 6 = 1,656 tests!
      # Almost guaranteed to overfit
```

3. Optimize on Multiple Symbols

Instead of optimizing for one symbol, optimize for average performance across many:

```nim
let symbols = @["AAPL", "MSFT", "GOOG", "AMZN", "TSLA"]
var dataDict = initTable[string, seq[OHLCV]]()

for symbol in symbols:
  dataDict[symbol] = readCSV("data/" & symbol & ".csv")

# Test each parameter across all symbols
var bestAvgReturn = -999999.0
var bestPeriod = 14

for period in [10, 14, 18]:
  var totalReturn = 0.0
  
  for symbol, data in dataDict:
    let strategy = newRSIStrategy(period = period, oversold = 30, overbought = 70)
    let report = quickBacktest(symbol, strategy, data, 100000.0, 0.001)
    totalReturn += report.totalReturn
  
  let avgReturn = totalReturn / symbols.len.float64
  
  if avgReturn > bestAvgReturn:
    bestAvgReturn = avgReturn
    bestPeriod = period

echo "Best period across all symbols: ", bestPeriod
```

This reduces overfitting to any single symbol's characteristics.

### Walk-Forward Testing

Walk-forward testing simulates how you would actually use a strategy:
optimize on past data, trade on new data, re-optimize periodically.

```nim
# Example structure (simplified)
let allData = readCSV("data/AAPL.csv")
let chunkSize = 250  # ~1 year of daily data
let testSize = 60    # ~3 months

var equity = 100000.0

# Walk forward through history
var i = 0
while i + chunkSize + testSize < allData.len:
  # Optimization window
  let trainData = allData[i..<(i + chunkSize)]
  
  # Find best parameter on training data
  var bestPeriod = 14
  var bestReturn = -999999.0
  
  for period in [10, 14, 18]:
    let strategy = newRSIStrategy(period = period, oversold = 30, overbought = 70)
    let report = quickBacktest("AAPL", strategy, trainData, 100000.0, 0.001)
    
    if report.totalReturn > bestReturn:
      bestReturn = report.totalReturn
      bestPeriod = period
  
  # Test on next period
  let testData = allData[(i + chunkSize)..<(i + chunkSize + testSize)]
  let strategy = newRSIStrategy(period = bestPeriod, oversold = 30, overbought = 70)
  let report = quickBacktest("AAPL", strategy, testData, equity, 0.001)
  
  equity = report.finalValue
  echo "Period ", i, ": used period=", bestPeriod, " -> ", report.totalReturn, "%"
  
  # Move forward
  i += testSize

echo "Final equity: $", equity
```

Walk-forward testing is more realistic but computationally expensive.

## Batch Processing with the CLI

The CLI tool enables automated workflows without writing code each time.

### Processing Multiple Symbols

Create a shell script for batch backtesting:

```bash
#!/bin/bash
# batch_backtest.sh

SYMBOLS="AAPL MSFT GOOG AMZN TSLA NVDA META NFLX AMD INTC"
STRATEGY="rsi"
OUTPUT_DIR="results"

mkdir -p $OUTPUT_DIR

for symbol in $SYMBOLS; do
  echo "Testing $symbol..."
  ./tzutrader_cli backtest data/${symbol}.csv \
    --strategy=$STRATEGY \
    --initial-cash=100000 \
    --commission=0.001 \
    --export=${OUTPUT_DIR}/${symbol}_${STRATEGY}.json
done

echo "All backtests complete. Results in $OUTPUT_DIR/"
```

Run it:
```bash
chmod +x batch_backtest.sh
./batch_backtest.sh
```

### Comparing Multiple Strategies

Test different strategies on the same data:

```bash
#!/bin/bash
# compare_strategies.sh

SYMBOL="AAPL"
STRATEGIES="rsi macd crossover bollinger"

for strategy in $STRATEGIES; do
  echo "Testing $strategy on $SYMBOL..."
  ./tzutrader_cli backtest data/${SYMBOL}.csv \
    --strategy=$strategy \
    --initial-cash=100000 \
    --commission=0.001 \
    --export=results/${SYMBOL}_${strategy}.json
done
```

### Parameter Sweeps

Test different parameter values systematically:

```bash
#!/bin/bash
# rsi_parameter_sweep.sh

SYMBOL="AAPL"

for period in 10 12 14 16 18 20; do
  for oversold in 25 30 35; do
    for overbought in 65 70 75; do
      echo "Testing RSI($period, $oversold, $overbought)..."
      
      ./tzutrader_cli backtest data/${SYMBOL}.csv \
        --strategy=rsi \
        --rsi-period=$period \
        --rsi-oversold=$oversold \
        --rsi-overbought=$overbought \
        --export=results/rsi_${period}_${oversold}_${overbought}.json
    done
  done
done

echo "Parameter sweep complete. Analyze results/ directory."
```

Warning: This approach generates many results. Be careful about overfitting.

## Exporting for Further Analysis

Export backtest results for analysis in spreadsheets or other tools.

### JSON Export

JSON preserves complete structure:

```nim
import tzutrader
import tzutrader/exports

let strategy = newRSIStrategy(period = 14, oversold = 30, overbought = 70)
let report = quickBacktest("AAPL", strategy, data, 100000.0, 0.001)

# Export complete report
exportJson(report, "backtest_report.json")

# Export trade log
exportTradeLog(report.tradeLog, "trade_log.json")
```

The JSON file can be imported into Python, R, or other analysis tools.

### CSV Export

CSV is easier to import into spreadsheets:

```nim
import tzutrader/exports

# Export backtest report
exportCsv(report, "backtest_report.csv")

# Export trade log as CSV
exportTradeLogCsv(report.tradeLog, "trade_log.csv")
```

### Scan Results Export

Export scanner results for comparison:

```nim
let scanner = newScanner(strategy, symbols)
let results = scanner.scanFromCSV("data/")

# Export to CSV for spreadsheet analysis
exportCsv(results, "scan_results.csv")

# Or JSON for programmatic analysis
exportJson(results, "scan_results.json")
```

### Using CLI for Export

All CLI commands support the `--export` flag:

```bash
# Export single backtest
./tzutrader_cli backtest data/AAPL.csv --strategy=rsi --export=report.json
./tzutrader_cli backtest data/AAPL.csv --strategy=rsi --export=report.csv

# Export scan results
./tzutrader_cli scan data/ AAPL,MSFT,GOOG --strategy=rsi --export=scan.csv
```

## Analysis in External Tools

### Python Analysis

Load and analyze TzuTrader JSON results in Python:

```python
import json
import pandas as pd

# Load backtest report
with open('backtest_report.json', 'r') as f:
    report = json.load(f)

print(f"Total Return: {report['totalReturn']}%")
print(f"Sharpe Ratio: {report['sharpeRatio']}")
print(f"Max Drawdown: {report['maxDrawdown']}%")

# Load trade log
with open('trade_log.json', 'r') as f:
    trades = json.load(f)

df = pd.DataFrame(trades)
df['date'] = pd.to_datetime(df['entryTime'], unit='s')
df['return'] = (df['exitPrice'] - df['entryPrice']) / df['entryPrice'] * 100

# Analyze
print(f"Average winning trade: {df[df['return'] > 0]['return'].mean():.2f}%")
print(f"Average losing trade: {df[df['return'] < 0]['return'].mean():.2f}%")

# Plot equity curve
import matplotlib.pyplot as plt
plt.plot(report['equityCurve'])
plt.title('Equity Curve')
plt.xlabel('Bar')
plt.ylabel('Portfolio Value ($)')
plt.show()
```

### Spreadsheet Analysis

Import CSV exports directly into Excel or Google Sheets:

1. Open spreadsheet application
2. Import/Open the CSV file
3. Create pivot tables for analysis
4. Generate charts for visualization

CSV columns include:
- Symbol
- Total Return
- Annualized Return
- Sharpe Ratio
- Max Drawdown
- Total Trades
- Win Rate
- Profit Factor

## Combining Multiple Data Sources

Merge data from different timeframes or sources:

```nim
import tzutrader
import std/algorithm

# Load daily data
let daily = readCSV("data/AAPL_daily.csv")

# Load minute data (if available)
let minute = readCSV("data/AAPL_1min.csv")

# Combine and sort by timestamp
var combined = daily & minute
combined.sort(proc(a, b: OHLCV): int = cmp(a.timestamp, b.timestamp))

# Save combined dataset
writeCSV(combined, "data/AAPL_combined.csv")
```

This allows testing strategies across different granularities.

## Automated Report Generation

Generate summary reports automatically:

```nim
import tzutrader
import std/times, std/strformat

proc generateReport(symbols: seq[string], strategy: Strategy): string =
  result = &"# Backtest Report\n"
  result &= &"Generated: {now()}\n"
  result &= &"Strategy: {strategy.name}\n\n"
  
  let scanner = newScanner(strategy, symbols)
  let results = scanner.scanFromCSV("data/")
  
  result &= &"## Summary\n"
  result &= &"Symbols tested: {symbols.len}\n"
  
  var profitable = 0
  for r in results:
    if r.report.totalReturn > 0: profitable.inc
  
  result &= &"Profitable: {profitable}/{symbols.len}\n\n"
  
  result &= &"## Top Performers\n"
  let ranked = scanner.rankBy(results, RankBy.SharpeRatio)
  for i in 0..<min(5, ranked.len):
    let r = ranked[i]
    result &= &"{r.symbol}: {r.report.totalReturn:.2f}% return, "
    result &= &"Sharpe {r.report.sharpeRatio:.2f}\n"
  
  return result

# Generate report
let symbols = @["AAPL", "MSFT", "GOOG", "AMZN", "TSLA"]
let strategy = newRSIStrategy(period = 14, oversold = 30, overbought = 70)
let reportText = generateReport(symbols, strategy)

# Save to markdown file
writeFile("backtest_report.md", reportText)
```

## Continuous Testing

Set up periodic backtests to monitor strategy performance over time:

```bash
#!/bin/bash
# continuous_test.sh

# Run weekly backtests
while true; do
  DATE=$(date +%Y%m%d)
  
  echo "Running backtest for $DATE..."
  ./tzutrader_cli scan data/ AAPL,MSFT,GOOG,AMZN,TSLA \
    --strategy=rsi \
    --export=results/scan_${DATE}.csv
  
  echo "Backtest complete. Results saved to results/scan_${DATE}.csv"
  
  # Wait 7 days (604800 seconds)
  sleep 604800
done
```

This helps track whether a strategy's edge is degrading over time.

## Next Steps

The final chapter covers best practices for strategy development,
testing methodology, and considerations for moving from backtesting to
live trading.

## Key Takeaways

- Parameter optimization is risky - use out-of-sample testing and limit
  parameter space
- Test parameters across multiple symbols to reduce overfitting
- Walk-forward testing simulates realistic parameter adaptation
- Use CLI batch scripts for automated testing workflows
- Export results to JSON or CSV for analysis in external tools
- Python, R, and spreadsheets can perform additional analysis on
  exported data
- Automated report generation streamlines repeated testing
- Continuous testing helps monitor strategy performance over time
- Always validate optimized parameters on unseen data before deployment
- Simpler approaches with fewer parameters are generally more robust
