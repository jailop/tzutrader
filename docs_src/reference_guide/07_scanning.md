# Reference Guide: Multi-Symbol Scanning

## Overview

The scanner module runs a strategy across multiple symbols and ranks the results. Instead of testing one symbol at a time, scanning automates batch backtesting to identify which symbols work best with a given strategy.

Scanning answers questions like: "Which tech stocks does my RSI strategy perform best on?" or "Does this MACD setup work better on volatile or stable stocks?"

**Module:** `tzutrader/scanner.nim`

## Why Scan Multiple Symbols

### Finding Strategy-Symbol Fit

Not all strategies work equally well on all symbols. A mean-reversion strategy might excel on range-bound stocks but fail on strong trends. Scanning reveals which symbols fit your strategy's assumptions.

### Diversification

Rather than trading a single symbol, identifying multiple candidates allows portfolio diversification. If one symbol underperforms, others may compensate.

### Robustness Testing

If a strategy only works on one or two symbols out of dozens tested, it likely overfits those specific cases. Strategies that perform well across many symbols demonstrate robustness.

### Comparative Analysis

Scanning provides relative performance context. A 15% return might seem good until you see that the same strategy returned 40% on a different symbol.

## Scanner Type

### Structure

```nim
type
  Scanner* = object
    strategy*: Strategy
    symbols*: seq[string]
    initialCash*: float64
    commission*: float64
    verbose*: bool
```

**Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `strategy` | Strategy | Strategy to test on all symbols |
| `symbols` | seq[string] | Symbols to scan |
| `initialCash` | float64 | Starting capital per backtest |
| `commission` | float64 | Commission rate |
| `verbose` | bool | Print progress messages |

### Constructor

```nim
proc newScanner*(strategy: Strategy, symbols: seq[string],
                 initialCash: float64 = 100000.0,
                 commission: float64 = 0.0,
                 verbose: bool = false): Scanner
```

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `strategy` | Strategy | — | Strategy instance to test |
| `symbols` | seq[string] | — | Symbol list to scan |
| `initialCash` | float64 | 100000.0 | Capital per backtest ($) |
| `commission` | float64 | 0.0 | Commission rate (decimal) |
| `verbose` | bool | false | Enable progress output |

**Example:**

```nim
import tzutrader

let strategy = newRSIStrategy(period = 14)
let symbols = @["AAPL", "MSFT", "GOOG", "AMZN", "TSLA"]

let scanner = newScanner(
  strategy = strategy,
  symbols = symbols,
  initialCash = 100000.0,
  commission = 0.001,  # 0.1%
  verbose = true
)
```

## Running Scans

### From Data Tables

```nim
proc scan*(scanner: Scanner, dataMap: Table[string, seq[OHLCV]]): seq[ScanResult]
```

Scans symbols using pre-loaded data.

**Parameters:**
- `dataMap`: Table mapping symbols to their OHLCV sequences

**Returns:** Sequence of `ScanResult`, one per successfully scanned symbol

**Process:**

1. For each symbol in the scanner's symbol list:
2. Check if data exists in dataMap
3. Skip if data missing or empty
4. Run backtest using quickBacktest
5. Generate signals using strategy.analyze
6. Add ScanResult to output

**Example:**

```nim
import tzutrader, std/tables

# Load data for multiple symbols
var dataMap = initTable[string, seq[OHLCV]]()
dataMap["AAPL"] = readCSV("data/AAPL.csv")
dataMap["MSFT"] = readCSV("data/MSFT.csv")
dataMap["GOOG"] = readCSV("data/GOOG.csv")

# Scan
let scanner = newScanner(strategy, @["AAPL", "MSFT", "GOOG"])
let results = scanner.scan(dataMap)

echo "Scanned ", results.len, " symbols"
```

### From CSV Directory

```nim
proc scanFromCSV*(scanner: Scanner, csvDir: string): seq[ScanResult]
```

Scans symbols by automatically loading CSV files from a directory.

**Parameters:**
- `csvDir`: Directory containing CSV files

**File naming convention:** Files must be named `{SYMBOL}.csv`

**Process:**

1. For each symbol in the scanner's symbol list:
2. Construct file path: `csvDir/{symbol}.csv`
3. Check if file exists
4. Load CSV data
5. Add to data map
6. Call `scan()` with the loaded data

**Example:**

```nim
import tzutrader

let scanner = newScanner(
  strategy = newMACDStrategy(),
  symbols = @["AAPL", "MSFT", "GOOG", "AMZN"],
  verbose = true
)

# Looks for data/AAPL.csv, data/MSFT.csv, etc.
let results = scanner.scanFromCSV("data/")

echo results.summary()
```

**Error handling:**

Missing files or read errors are logged if `verbose = true` but don't stop the scan. Symbols with errors are simply excluded from results.

## ScanResult Type

Each scanned symbol produces a `ScanResult`:

```nim
type
  ScanResult* = object
    symbol*: string
    report*: BacktestReport
    signals*: seq[Signal]
```

**Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `symbol` | string | Symbol that was scanned |
| `report` | BacktestReport | Complete backtest results |
| `signals` | seq[Signal] | All signals generated |

The `report` field contains all metrics from the backtest. See [Backtesting Reference](06_backtesting.md) for complete `BacktestReport` specification.

**Example:**

```nim
for result in results:
  echo result.symbol, ":"
  echo "  Return: ", result.report.totalReturn, "%"
  echo "  Sharpe: ", result.report.sharpeRatio
  echo "  Trades: ", result.report.totalTrades
  echo "  Signals generated: ", result.signals.len
```

## Ranking Results

### RankBy Enum

```nim
type
  RankBy* = enum
    TotalReturn
    AnnualizedReturn
    SharpeRatio
    WinRate
    ProfitFactor
    MaxDrawdown
    TotalTrades
```

**Ranking metrics:**

- `TotalReturn`: Total percentage return (higher is better)
- `AnnualizedReturn`: Annualized return percentage (higher is better)
- `SharpeRatio`: Risk-adjusted return (higher is better)
- `WinRate`: Winning trade percentage (higher is better)
- `ProfitFactor`: Gross profit / gross loss ratio (higher is better)
- `MaxDrawdown`: Peak-to-trough decline (lower is better, inverted for ranking)
- `TotalTrades`: Number of trades (neutral, for filtering active strategies)

### Ranking Function

```nim
proc rankBy*(results: var seq[ScanResult], metric: RankBy, ascending: bool = false)
```

Sorts results by the specified metric **in place**.

**Parameters:**
- `results`: Scan results to rank (modified)
- `metric`: Which metric to rank by
- `ascending`: If `true`, rank low to high; if `false` (default), rank high to low

**Default behavior:** Higher values rank first (descending) except for `MaxDrawdown` where lower values rank first.

**Example:**

```nim
import tzutrader

var results = scanner.scanFromCSV("data/")

# Rank by total return (highest first)
results.rankBy(TotalReturn)
echo "Top performer: ", results[0].symbol, 
     " with ", results[0].report.totalReturn, "% return"

# Rank by Sharpe ratio (best risk-adjusted returns first)
results.rankBy(SharpeRatio)
echo "Best Sharpe: ", results[0].symbol,
     " with Sharpe ratio ", results[0].report.sharpeRatio

# Rank by max drawdown (lowest drawdown first)
results.rankBy(MaxDrawdown)
echo "Lowest drawdown: ", results[0].symbol,
     " with ", results[0].report.maxDrawdown, "% max DD"
```

### Selecting Top N

```nim
proc topN*(results: seq[ScanResult], n: int): seq[ScanResult]
```

Returns the first N results (assumes results are already ranked).

**Parameters:**
- `results`: Ranked scan results
- `n`: Number of results to return

**Returns:** Slice of top N results

**Example:**

```nim
# Get top 5 by return
results.rankBy(TotalReturn)
let top5 = results.topN(5)

echo "Top 5 performers:"
for i, result in top5:
  echo i+1, ". ", result.symbol, ": ", result.report.totalReturn, "%"
```

## Filtering Results

```nim
proc filter*(results: seq[ScanResult],
             minReturn: float64 = NegInf,
             minSharpe: float64 = NegInf,
             minWinRate: float64 = 0.0,
             minTrades: int = 0,
             maxDrawdown: float64 = Inf): seq[ScanResult]
```

Filters results by performance criteria.

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `minReturn` | float64 | -∞ | Minimum total return (%) |
| `minSharpe` | float64 | -∞ | Minimum Sharpe ratio |
| `minWinRate` | float64 | 0.0 | Minimum win rate (%) |
| `minTrades` | int | 0 | Minimum number of trades |
| `maxDrawdown` | float64 | +∞ | Maximum drawdown (%) |

**Returns:** New sequence containing only results meeting all criteria

**Example:**

```nim
import tzutrader

let results = scanner.scanFromCSV("data/")

# Filter for quality results
let filtered = results.filter(
  minReturn = 10.0,      # At least 10% return
  minSharpe = 1.0,       # Sharpe ≥ 1.0
  minWinRate = 50.0,     # Win rate ≥ 50%
  minTrades = 20,        # At least 20 trades
  maxDrawdown = -20.0    # Max drawdown ≤ -20%
)

echo "Symbols meeting criteria: ", filtered.len
```

**Combining filter and rank:**

```nim
# Filter first, then rank the survivors
var results = scanner.scanFromCSV("data/")
results = results.filter(minReturn = 5.0, minSharpe = 0.5)
results.rankBy(ProfitFactor)

echo "Top 10 by profit factor (after filtering):"
for result in results.topN(10):
  echo result.symbol, ": PF=", result.report.profitFactor
```

## Result Summaries

### Summary Table

```nim
proc summary*(results: seq[ScanResult]): string
```

Generates a formatted table summarizing all results.

**Output format:**

```
==============================================================================
SCAN RESULTS SUMMARY
==============================================================================
Symbol      | Return     | Annual     | Sharpe   | Win%    | PF     | DD%     | Trades
------------------------------------------------------------------------------
AAPL        |     15.30% |     12.50% |     1.45 |  58.30% |   1.82 | -12.50% |      42
MSFT        |     12.70% |     10.20% |     1.32 |  60.50% |   1.65 | -10.20% |      38
GOOG        |      8.50% |      7.10% |     0.95 |  52.00% |   1.25 |  -8.50% |      35
==============================================================================
Total symbols scanned: 3
Average Return: 12.17%
Average Sharpe: 1.24
Average Win Rate: 56.93%
```

**Example:**

```nim
let results = scanner.scanFromCSV("data/")
results.rankBy(TotalReturn)

echo results.summary()
```

### Compact Display

```nim
proc `$`*(scanResult: ScanResult): string
```

One-line summary for a single result:

```nim
for result in results:
  echo result  # Uses $ operator
# Output: AAPL: Return=+15.30% Sharpe=1.45 Trades=42 WinRate=58.3% MaxDD=-12.50%
```

## Common Scanning Patterns

### Basic Symbol Ranking

```nim
import tzutrader

let strategy = newRSIStrategy()
let symbols = @["AAPL", "MSFT", "GOOG", "AMZN", "TSLA", 
                "NVDA", "META", "NFLX", "COST", "AVGO"]

let scanner = newScanner(strategy, symbols)
var results = scanner.scanFromCSV("data/")

# Rank and display top 5
results.rankBy(TotalReturn)
echo results.topN(5).summary()
```

### Quality Filter

```nim
# Find symbols with consistent, profitable performance
let filtered = results.filter(
  minReturn = 5.0,       # Profitable
  minSharpe = 0.8,       # Decent risk-adjusted returns
  minWinRate = 45.0,     # Not too dependent on few big winners
  minTrades = 15,        # Enough trades for statistical significance
  maxDrawdown = -25.0    # Manageable drawdowns
)

echo "Quality candidates: ", filtered.len, " symbols"
```

### Multi-Strategy Comparison

```nim
# Test multiple strategies on the same symbols
let strategies = @[
  newRSIStrategy(period = 14),
  newMACDStrategy(),
  newCrossoverStrategy(fastPeriod = 50, slowPeriod = 200)
]

for strategy in strategies:
  let scanner = newScanner(strategy, symbols)
  var results = scanner.scanFromCSV("data/")
  results.rankBy(SharpeRatio)
  
  echo strategy.name, ":"
  echo results.topN(3).summary()
  echo ""
```

### Parameter Sweep Across Symbols

```nim
# Find which RSI period works best across a symbol basket
for period in [10, 12, 14, 16, 18, 20]:
  let strategy = newRSIStrategy(period = period)
  let scanner = newScanner(strategy, symbols)
  var results = scanner.scanFromCSV("data/")
  
  let avgReturn = results.mapIt(it.report.totalReturn).sum() / results.len.float64
  echo "RSI(", period, ") average return: ", avgReturn, "%"
```

### Identifying Outliers

```nim
# Find symbols where strategy performs exceptionally well or poorly
results.rankBy(TotalReturn)

let best = results[0]
let worst = results[^1]

echo "Best: ", best.symbol, " (+", best.report.totalReturn, "%)"
echo "Worst: ", worst.symbol, " (", worst.report.totalReturn, "%)"
echo "Spread: ", best.report.totalReturn - worst.report.totalReturn, " percentage points"
```

## Performance Considerations

### Parallel Execution

The current scanner implementation runs backtests sequentially. Each symbol is independent, making scanning a good candidate for parallelization. Future versions may add parallel execution.

**Current workaround for faster scans:**

Split symbols across multiple scanner instances and run in separate processes, then combine results.

### Memory Usage

The scanner stores complete backtest reports and signals for all symbols. For large symbol lists (hundreds) with long histories (years of daily data), memory usage can be significant.

**Memory reduction strategies:**

- Scan in batches (process 50 symbols at a time)
- Discard signal sequences if not needed for analysis
- Use streaming CSV reads for individual backtests

### Typical Scan Performance

Approximate timings (single-threaded, modern hardware):

- **10 symbols, 1 year daily data:** ~1 second
- **100 symbols, 5 years daily data:** ~30-60 seconds
- **500 symbols, 10 years daily data:** ~5-10 minutes

Actual timing depends on strategy complexity (indicator calculations) and data volume.

## Integration with CLI

The CLI tool provides convenient access to scanning:

```bash
tzutrader scan data/ AAPL,MSFT,GOOG \
  --strategy=rsi \
  --rank-by=sharpe \
  --min-return=5.0 \
  --top=10 \
  --export=scan_results.csv
```

See [CLI Reference](09_cli.md) for complete command options.

## Scan Result Export

Results can be exported to JSON or CSV for further analysis:

```nim
import tzutrader

let results = scanner.scanFromCSV("data/")
results.rankBy(TotalReturn)

# Export to JSON
results.exportJson("scan_results.json")

# Export to CSV
results.exportCsv("scan_results.csv")
```

See [Export Reference](08_exports.md) for export format specifications.

## Interpreting Scan Results

### What Good Results Look Like

- **Consistency:** Multiple symbols show positive returns
- **Sharpe ratios > 1.0:** Risk-adjusted returns are reasonable
- **Trade counts:** Enough trades for statistical significance (20+)
- **Win rates:** Typically 40-60% for trend strategies, 50-70% for mean reversion
- **Drawdowns:** Manageable relative to returns

### Red Flags

- **Single winner:** Only one symbol profitable suggests overfitting
- **Extreme metrics:** 100% win rate or 10+ Sharpe ratio indicates bugs
- **No trades:** Strategy never triggered signals (parameters too conservative)
- **Excessive trades:** Hundreds of trades suggest overtrading costs
- **Huge variations:** 50% return on one symbol, -30% on another suggests randomness

### Using Scan Results

Scanning identifies candidates, but:

1. **Verify on out-of-sample data:** Test top performers on recent data not included in scan
2. **Understand why it works:** Investigate what market conditions favor the strategy
3. **Check robustness:** Small parameter changes shouldn't drastically alter results
4. **Consider transaction costs:** High-frequency strategies need lower commissions
5. **Diversify:** Trade multiple symbols from scan results, not just #1

## See Also

- [Backtesting Reference](06_backtesting.md) - Understanding backtest reports
- [CLI Reference](09_cli.md) - Using the scan command
- [Export Reference](08_exports.md) - Exporting scan results
- [User Guide: Comparing Strategies](../user_guide/07_scanning.md) - Conceptual introduction
- [User Guide: Best Practices](../user_guide/10_best_practices.md) - Avoiding overfitting
