# Reference Guide: Command-Line Interface

## Overview

The TzuTrader CLI provides a command-line interface for running backtests and scanning multiple symbols without writing code. It's particularly useful for quick parameter testing, batch processing historical data, and automating repetitive analysis tasks.

**Binary:** `tzutrader_cli`  
**Version:** 0.7.0

## When to Use the CLI

The CLI tool serves specific use cases where writing Nim code would be overhead:

- **Quick backtests:** Testing a strategy against a single symbol's historical data
- **Parameter exploration:** Trying different parameter values to see their effect
- **Multi-symbol scanning:** Running the same strategy across many symbols to find candidates
- **Batch processing:** Automating backtests in scripts or pipelines
- **Results export:** Generating JSON or CSV files for analysis in other tools

For more complex needs—custom strategies, advanced portfolio logic, or integration with other systems—writing Nim code using the library directly provides greater flexibility.

## Command Structure

```
tzutrader <command> <arguments> [options]
```

The CLI follows standard Unix conventions: positional arguments specify what to do, options modify how to do it.

## Commands

### backtest

Runs a backtest on a single symbol's historical data.

**Syntax:**

```bash
tzutrader backtest <csv_file> [options]
```

**Arguments:**

- `csv_file`: Path to CSV file containing OHLCV data

**Purpose:**

The backtest command loads historical data, applies a strategy, simulates trades, and reports performance metrics. It's the most straightforward way to evaluate a strategy's historical performance.

**Example:**

```bash
tzutrader backtest data/AAPL.csv --strategy=rsi --initial-cash=10000
```

This runs an RSI strategy backtest on Apple stock data with $10,000 starting capital.

### scan

Runs backtests across multiple symbols, ranks results, and optionally filters by performance criteria.

**Syntax:**

```bash
tzutrader scan <csv_dir> <symbols> [options]
```

**Arguments:**

- `csv_dir`: Directory containing CSV files (one per symbol)
- `symbols`: Comma-separated list of symbols to scan

**File Naming:**

The scanner expects CSV files named `SYMBOL.csv` in the specified directory. For example, if you specify `AAPL,MSFT`, it looks for `data/AAPL.csv` and `data/MSFT.csv` in the directory.

**Purpose:**

Scanning helps identify which symbols work best with a given strategy. Rather than testing each symbol individually, the scan command automates the process and presents ranked results.

**Example:**

```bash
tzutrader scan data/ AAPL,MSFT,GOOG --strategy=macd --rank-by=sharpe
```

This scans three symbols using a MACD strategy and ranks them by Sharpe ratio.

### help

Displays usage information and available options.

**Syntax:**

```bash
tzutrader --help
```

### version

Shows the CLI version number.

**Syntax:**

```bash
tzutrader --version
```

## Common Options

These options apply to both `backtest` and `scan` commands.

### --strategy=<name>

Selects which pre-built strategy to use.

**Available strategies:**
- `rsi` (default)
- `macd`
- `crossover`
- `bollinger`

**Default:** `rsi`

**Example:**

```bash
tzutrader backtest data/AAPL.csv --strategy=macd
```

### --initial-cash=<amount>

Sets the starting capital for the portfolio.

**Type:** Float (dollars)  
**Default:** `100000.0`

**Example:**

```bash
tzutrader backtest data/AAPL.csv --initial-cash=50000
```

Larger initial capital allows buying more shares but doesn't inherently change percentage-based metrics like return or Sharpe ratio. However, it affects trade sizing if you're implementing position sizing rules.

### --commission=<rate>

Sets the commission rate as a decimal (not percentage).

**Type:** Float  
**Default:** `0.0`  
**Range:** 0.0 to 1.0

**Example:**

```bash
tzutrader backtest data/AAPL.csv --commission=0.001
```

A value of `0.001` means 0.1% commission on each trade. Commissions directly reduce profits and can significantly impact strategy performance, especially for strategies that trade frequently.

### --export=<file>

Exports backtest results to a file.

**Supported formats:**
- `.json`: Detailed JSON export with all metrics and trade history
- `.csv`: Tabular CSV format for spreadsheet analysis

**Example:**

```bash
tzutrader backtest data/AAPL.csv --export=results.json
```

### --verbose

Enables detailed progress output during backtest execution.

**Type:** Flag (no value required)  
**Default:** Off

**Example:**

```bash
tzutrader backtest data/AAPL.csv --verbose
```

Verbose mode shows each trade as it's executed, useful for understanding what the strategy is doing and debugging unexpected results.

## Strategy-Specific Options

### RSI Strategy Options

The RSI strategy buys when RSI falls below the oversold threshold and sells when it rises above the overbought threshold.

#### --rsi-period=<n>

Number of periods for RSI calculation.

**Type:** Integer  
**Default:** `14`  
**Typical range:** 9-21

**Example:**

```bash
tzutrader backtest data/AAPL.csv --strategy=rsi --rsi-period=10
```

Shorter periods make RSI more reactive but generate more false signals. Longer periods smooth the indicator but lag price changes.

#### --rsi-oversold=<n>

RSI value considered oversold (buy signal).

**Type:** Float  
**Default:** `30.0`  
**Range:** 0-100

**Example:**

```bash
tzutrader backtest data/AAPL.csv --strategy=rsi --rsi-oversold=25
```

Lower thresholds wait for more extreme conditions before buying, potentially missing some opportunities but reducing false signals.

#### --rsi-overbought=<n>

RSI value considered overbought (sell signal).

**Type:** Float  
**Default:** `70.0`  
**Range:** 0-100

**Example:**

```bash
tzutrader backtest data/AAPL.csv --strategy=rsi --rsi-overbought=75
```

### MACD Strategy Options

The MACD strategy generates buy signals when the MACD line crosses above the signal line and sell signals on downward crosses.

#### --macd-fast=<n>

Fast EMA period.

**Type:** Integer  
**Default:** `12`

#### --macd-slow=<n>

Slow EMA period.

**Type:** Integer  
**Default:** `26`

#### --macd-signal=<n>

Signal line EMA period.

**Type:** Integer  
**Default:** `9`

**Example:**

```bash
tzutrader backtest data/AAPL.csv --strategy=macd --macd-fast=10 --macd-slow=20 --macd-signal=8
```

The standard 12/26/9 parameters were designed for daily stock charts decades ago. Different timeframes and assets may benefit from different values.

### Crossover Strategy Options

The crossover strategy buys when a fast moving average crosses above a slow moving average and sells on downward crosses.

#### --ma-fast=<n>

Fast moving average period.

**Type:** Integer  
**Default:** `10`

**Example:**

```bash
tzutrader backtest data/AAPL.csv --strategy=crossover --ma-fast=20
```

#### --ma-slow=<n>

Slow moving average period.

**Type:** Integer  
**Default:** `30`

**Example:**

```bash
tzutrader backtest data/AAPL.csv --strategy=crossover --ma-fast=50 --ma-slow=200
```

The 50/200 combination is known as the "golden cross" setup when used with daily data.

### Bollinger Bands Strategy Options

The Bollinger Bands strategy buys when price touches the lower band and sells when it touches the upper band.

#### --bb-period=<n>

Period for the middle band (SMA) and standard deviation calculation.

**Type:** Integer  
**Default:** `20`

#### --bb-stddev=<n>

Number of standard deviations for the bands.

**Type:** Float  
**Default:** `2.0`

**Example:**

```bash
tzutrader backtest data/AAPL.csv --strategy=bollinger --bb-period=15 --bb-stddev=2.5
```

Wider bands (higher stddev) generate fewer signals but capture stronger moves. Narrower bands trade more frequently.

## Scan-Specific Options

These options only apply to the `scan` command.

### --rank-by=<metric>

Determines which performance metric to use for ranking results.

**Available metrics:**
- `return`: Total return percentage
- `sharpe`: Sharpe ratio (risk-adjusted return)
- `winrate`: Win rate percentage
- `profitfactor`: Profit factor (ratio of gross profit to gross loss)

**Default:** `return`

**Example:**

```bash
tzutrader scan data/ AAPL,MSFT,GOOG --rank-by=sharpe
```

**Choosing a Ranking Metric:**

- **Return:** Identifies the most profitable symbols but ignores risk
- **Sharpe:** Favors symbols with consistent returns relative to volatility
- **Win rate:** Shows which symbols had the highest percentage of winning trades
- **Profit factor:** Identifies symbols where winners significantly outweighed losers

No single metric tells the complete story. Review multiple metrics before drawing conclusions.

### --min-return=<pct>

Filters results to show only symbols with at least this return percentage.

**Type:** Float (percentage)  
**Default:** No minimum

**Example:**

```bash
tzutrader scan data/ AAPL,MSFT,GOOG --min-return=10.0
```

This shows only symbols that gained at least 10%.

### --min-sharpe=<ratio>

Filters results to show only symbols with at least this Sharpe ratio.

**Type:** Float  
**Default:** No minimum

**Example:**

```bash
tzutrader scan data/ AAPL,MSFT,GOOG --min-sharpe=1.0
```

A Sharpe ratio above 1.0 is generally considered acceptable for a strategy, though this depends on the strategy's holding period and asset class.

### --min-winrate=<pct>

Filters results to show only symbols with at least this win rate percentage.

**Type:** Float (percentage)  
**Default:** `0.0`

**Example:**

```bash
tzutrader scan data/ AAPL,MSFT,GOOG --min-winrate=60.0
```

### --max-drawdown=<pct>

Filters results to show only symbols with drawdowns smaller than this percentage.

**Type:** Float (percentage)  
**Default:** No maximum

**Example:**

```bash
tzutrader scan data/ AAPL,MSFT,GOOG --max-drawdown=20.0
```

Drawdown measures the largest peak-to-trough decline. Lower drawdowns indicate more stable equity curves but may also indicate less aggressive trading.

### --top=<n>

Limits output to the top N ranked results.

**Type:** Integer  
**Default:** `0` (show all)

**Example:**

```bash
tzutrader scan data/ AAPL,MSFT,GOOG --top=5
```

When scanning many symbols, `--top` helps focus on the best performers.

## Complete Usage Examples

### Simple Backtest

Test an RSI strategy with default parameters:

```bash
tzutrader backtest data/AAPL.csv
```

### Custom RSI Parameters

Test more aggressive RSI thresholds:

```bash
tzutrader backtest data/AAPL.csv --rsi-oversold=20 --rsi-overbought=80
```

### MACD with Commission

Test MACD strategy with realistic 0.1% commission:

```bash
tzutrader backtest data/AAPL.csv --strategy=macd --commission=0.001
```

### Crossover with Export

Test moving average crossover and export results:

```bash
tzutrader backtest data/AAPL.csv --strategy=crossover --ma-fast=50 --ma-slow=200 --export=results.json
```

### Basic Scan

Scan multiple symbols with MACD strategy:

```bash
tzutrader scan data/ AAPL,MSFT,GOOG,AMZN,TSLA --strategy=macd
```

### Filtered Scan

Find top performers meeting minimum criteria:

```bash
tzutrader scan data/ AAPL,MSFT,GOOG --min-return=5.0 --min-sharpe=0.5 --max-drawdown=15.0
```

### Comprehensive Scan with Export

Scan many symbols, rank by Sharpe ratio, get top 10, export to CSV:

```bash
tzutrader scan data/ AAPL,MSFT,GOOG,AMZN,TSLA,NVDA,META,NFLX,COST,AVGO \
  --strategy=macd \
  --rank-by=sharpe \
  --min-sharpe=0.5 \
  --top=10 \
  --export=top_performers.csv
```

## CSV File Requirements

The CLI expects CSV files in a specific format. See the [Data Management Reference](02_data.md) for complete specifications.

**Required columns:**
- `timestamp` or `date`
- `open`
- `high`
- `low`
- `close`
- `volume`

**Example format:**

```csv
timestamp,open,high,low,close,volume
1609459200,100.0,105.0,98.0,103.0,1000000
1609545600,103.0,107.0,101.0,106.0,1200000
```

Timestamps should be Unix timestamps (seconds since epoch) or dates in common formats (YYYY-MM-DD).

## Output Format

### Backtest Output

The backtest command displays a `BacktestReport` with:

- Strategy configuration
- Performance metrics (return, Sharpe ratio, max drawdown, etc.)
- Trade statistics (number of trades, win rate, profit factor)
- Equity curve summary

See [Backtesting Reference](06_backtesting.md) for detailed metric definitions.

### Scan Output

The scan command displays a summary table with one row per symbol:

```
Symbol  Return%  Sharpe  Trades  WinRate%  MaxDD%
------  -------  ------  ------  --------  ------
AAPL    15.3     1.45    42      58.3      -12.5
MSFT    12.7     1.32    38      60.5      -10.2
...
```

Results are sorted by the selected ranking metric.

## Export Formats

### JSON Export

JSON exports contain complete backtest details suitable for programmatic analysis:

```json
{
  "symbol": "AAPL",
  "strategy": "RSI Strategy",
  "initial_cash": 100000.0,
  "final_equity": 115300.0,
  "total_return": 15.3,
  "sharpe_ratio": 1.45,
  "max_drawdown": -12.5,
  "num_trades": 42,
  "win_rate": 58.3,
  "profit_factor": 1.82,
  "trades": [...]
}
```

See [Export Reference](08_exports.md) for complete schema.

### CSV Export

CSV exports provide tabular data for spreadsheet analysis:

**Backtest CSV:**

```csv
metric,value
symbol,AAPL
initial_cash,100000.0
final_equity,115300.0
total_return,15.3
sharpe_ratio,1.45
...
```

**Scan CSV:**

```csv
symbol,return,sharpe,trades,win_rate,max_drawdown
AAPL,15.3,1.45,42,58.3,-12.5
MSFT,12.7,1.32,38,60.5,-10.2
...
```

## Error Handling

The CLI exits with non-zero status codes on errors:

**Common errors:**
- File not found: Check CSV file paths
- Invalid CSV format: Verify column names and data types
- Unknown strategy: Check strategy name spelling
- Insufficient data: Ensure CSV has enough bars for indicator calculation

Error messages are printed to stderr and describe the issue.

## Performance Considerations

**Single backtest:** Typically completes in milliseconds to seconds depending on data size.

**Scanning:** Scales linearly with the number of symbols. Scanning 100 symbols takes approximately 100x as long as a single backtest.

**Memory usage:** Minimal. The CLI loads one symbol's data at a time, processes it, and moves to the next.

## Limitations

The CLI uses pre-built strategies and cannot execute custom strategy logic. For custom strategies:

1. Write a Nim strategy using the library (see [Strategy Reference](04_strategies.md))
2. Compile it into your own executable
3. Use the library's API directly

The CLI is a convenience tool for common use cases, not a replacement for programming when you need flexibility.

## Integration with Scripts

The CLI works well in shell scripts for batch processing:

**Bash example:**

```bash
#!/bin/bash

# Backtest multiple files
for file in data/*.csv; do
  echo "Testing $file..."
  tzutrader backtest "$file" --strategy=rsi --export="${file%.csv}_results.json"
done
```

**Parameter sweep example:**

```bash
#!/bin/bash

# Test multiple RSI periods
for period in 10 12 14 16 18 20; do
  tzutrader backtest data/AAPL.csv \
    --rsi-period=$period \
    --export="results_period_${period}.json"
done
```

Exit codes allow scripts to detect errors:

```bash
if tzutrader backtest data/AAPL.csv; then
  echo "Backtest succeeded"
else
  echo "Backtest failed"
fi
```

## See Also

- [User Guide: Workflows](../user_guide/08_workflows.md) - Practical CLI usage examples
- [Backtesting Reference](06_backtesting.md) - Understanding metrics
- [Scanner Reference](07_scanning.md) - Multi-symbol scanning API
- [Export Reference](08_exports.md) - File format specifications
