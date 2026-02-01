# Comparing Strategies Across Symbols

## Why Scan Multiple Symbols

Testing a strategy on a single symbol provides limited information. The strategy might work well on that particular security due to luck or unique characteristics, but fail on others.

Scanning multiple symbols helps you:
- **Identify robust strategies**: Strategies that work across many symbols are more likely to continue working
- **Avoid overfitting**: A strategy tuned to one symbol may not generalize
- **Find best opportunities**: Compare which symbols work best with your strategy
- **Understand limitations**: See where and why a strategy fails
- **Build confidence**: Consistent performance across symbols is more convincing than one good result

## The Scanner Module

TzuTrader's Scanner module automates testing a strategy across multiple symbols:

```nim
import tzutrader

# Create a scanner with your strategy
let strategy = newRSIStrategy(period = 14, oversold = 30, overbought = 70)
let scanner = newScanner(strategy, @["AAPL", "MSFT", "GOOG", "TSLA"])

# Scan all symbols (assumes CSV files in data/ directory)
let results = scanner.scanFromCSV("data/", initialCash = 100000.0, commission = 0.001)

# View summary
echo scanner.summary(results)
```

The scanner runs the same strategy on each symbol and collects all backtest reports.

## Setting Up a Scanner

### Basic Setup

Create a scanner with a strategy and symbol list:

```nim
import tzutrader

let strategy = newMACDStrategy(fastPeriod = 12, slowPeriod = 26, signalPeriod = 9)
let symbols = @["AAPL", "MSFT", "GOOG", "AMZN", "TSLA"]
let scanner = newScanner(strategy, symbols)
```

### Manual Scanning

Provide data for each symbol manually:

```nim
import std/tables

# Load data for each symbol
var dataDict = initTable[string, seq[OHLCV]]()
dataDict["AAPL"] = readCSV("data/AAPL.csv")
dataDict["MSFT"] = readCSV("data/MSFT.csv")
dataDict["GOOG"] = readCSV("data/GOOG.csv")

# Scan with the data
let results = scanner.scan(dataDict, initialCash = 100000.0, commission = 0.001)
```

### CSV Directory Scanning

Automatically load CSV files from a directory:

```nim
# Expects files: AAPL.csv, MSFT.csv, GOOG.csv, etc.
let results = scanner.scanFromCSV(
  "data/",
  initialCash = 100000.0,
  commission = 0.001
)
```

The scanner looks for files named `{symbol}.csv` in the directory.

## Ranking Results

After scanning, rank results by various metrics:

### Rank by Total Return

Find symbols with highest returns:

```nim
let ranked = scanner.rankBy(results, RankBy.TotalReturn)

for i in 0..<min(5, ranked.len):
  let result = ranked[i]
  echo result.symbol, ": ", result.report.totalReturn, "% return"
```

### Rank by Sharpe Ratio

Find best risk-adjusted returns:

```nim
let ranked = scanner.rankBy(results, RankBy.SharpeRatio)

echo "Top 3 by Sharpe Ratio:"
for i in 0..2:
  if i < ranked.len:
    let result = ranked[i]
    echo result.symbol, ": Sharpe = ", result.report.sharpeRatio
```

### Available Ranking Metrics

```nim
# All ranking options
RankBy.TotalReturn        # Highest total return
RankBy.AnnualizedReturn   # Highest annualized return
RankBy.SharpeRatio        # Best risk-adjusted returns
RankBy.WinRate            # Highest win rate
RankBy.ProfitFactor       # Best profit factor
RankBy.MaxDrawdown        # Smallest drawdown (ascending)
RankBy.TotalTrades        # Most trading activity
```

**Note:** MaxDrawdown ranks ascending (smaller drawdown is better), all others rank descending (higher is better).

## Filtering Results

Filter results to find quality opportunities:

### Filter by Minimum Return

Only show symbols that meet return thresholds:

```nim
let filtered = scanner.filter(results, minReturn = 10.0)

echo "Symbols with >10% return: ", filtered.len
```

### Filter by Multiple Criteria

Combine filters for strict requirements:

```nim
let filtered = scanner.filter(
  results,
  minReturn = 8.0,      # At least 8% return
  minSharpe = 1.0,      # Sharpe ratio above 1.0
  minWinRate = 50.0,    # Win rate above 50%
  minTrades = 10,       # At least 10 trades
  maxDrawdown = -20.0   # Max drawdown less than -20%
)

echo "Symbols meeting all criteria: ", filtered.len
```

**Filter parameters:**
- `minReturn`: Minimum total return percentage
- `minSharpe`: Minimum Sharpe ratio
- `minWinRate`: Minimum win rate percentage
- `minTrades`: Minimum number of trades
- `maxDrawdown`: Maximum drawdown (as negative percentage)

All criteria must be met (AND logic).

### Getting Top N Results

Get the best N symbols after ranking:

```nim
# Get top 5 by Sharpe ratio
let top5 = scanner.topN(results, n = 5, rankBy = RankBy.SharpeRatio)

for result in top5:
  echo result.symbol, ": Sharpe = ", result.report.sharpeRatio
```

## Viewing Scan Results

### Summary Table

Display a formatted comparison table:

```nim
let results = scanner.scanFromCSV("data/")
echo scanner.summary(results)
```

Output example:
```
=== Scanner Results ===
Strategy: RSI Strategy
Symbols scanned: 10
Date range: 2023-01-01 to 2023-12-31

Symbol  Return%  Sharpe  MaxDD%   Trades  WinRate%  ProfitFactor
------  -------  ------  ------   ------  --------  ------------
AAPL     12.5    1.23   -8.2%      24      58.3       1.45
MSFT     15.2    1.45   -6.5%      28      64.3       1.67
GOOG      8.7    0.89  -11.3%      20      55.0       1.32
AMZN      6.2    0.72  -15.4%      22      50.0       1.18
TSLA     -2.1    0.15  -22.1%      31      41.9       0.89
```

### Accessing Individual Results

Process each result programmatically:

```nim
for result in results:
  echo "Symbol: ", result.symbol
  echo "Return: ", result.report.totalReturn, "%"
  echo "Sharpe: ", result.report.sharpeRatio
  echo "---"
  
  # Access full report
  if result.report.totalReturn > 10.0:
    echo result.report.summary()
```

Each `ScanResult` contains:
- `symbol`: The symbol tested
- `report`: Full BacktestReport with all metrics
- `data`: Historical data used

## Interpreting Scan Results

### Look for Consistency

Good strategies show consistent performance across symbols:

```nim
# Calculate statistics across symbols
var returns: seq[float64] = @[]
for result in results:
  returns.add(result.report.totalReturn)

let avgReturn = returns.sum() / returns.len.float64
let stdDev = calculateStdDev(returns)

echo "Average return: ", avgReturn, "%"
echo "Std deviation: ", stdDev, "%"
```

**Green flags:**
- Most symbols are profitable
- Returns are relatively consistent (low std dev)
- Sharpe ratios are positive across symbols
- Similar number of trades per symbol

**Red flags:**
- Only one or two symbols are profitable
- Huge variance in returns
- Some symbols have excessive trades, others have very few
- Strategy works on tech stocks but fails on everything else

### Consider Market Conditions

All symbols tested should cover similar time periods:

```nim
for result in results:
  echo result.symbol, ": ",
       result.data.len, " bars from ",
       fromUnix(result.data[0].timestamp), " to ",
       fromUnix(result.data[^1].timestamp)
```

If time periods vary significantly, results aren't comparable.

### Statistical Significance

More trades provide more reliable statistics:

```nim
for result in results:
  if result.report.totalTrades < 30:
    echo result.symbol, ": Only ", result.report.totalTrades,
         " trades (insufficient sample)"
```

With fewer than 20-30 trades, results may be due to luck rather than strategy effectiveness.

## Example: Complete Scan Workflow

Here's a complete example of scanning and analyzing results:

```nim
import tzutrader

# Create strategy
let strategy = newRSIStrategy(period = 14, oversold = 30, overbought = 70)

# Create scanner with symbols
let symbols = @["AAPL", "MSFT", "GOOG", "AMZN", "TSLA", 
                "NVDA", "META", "NFLX", "AMD", "INTC"]
let scanner = newScanner(strategy, symbols)

# Run scan
echo "Scanning ", symbols.len, " symbols..."
let results = scanner.scanFromCSV("data/", initialCash = 100000.0, commission = 0.001)

# Show summary
echo "\n", scanner.summary(results)

# Filter for quality results
let filtered = scanner.filter(
  results,
  minReturn = 5.0,
  minSharpe = 0.8,
  minWinRate = 50.0,
  minTrades = 15
)

echo "\nSymbols meeting quality criteria: ", filtered.len

# Rank by Sharpe ratio
let ranked = scanner.rankBy(filtered, RankBy.SharpeRatio)

# Show top 3
echo "\nTop 3 by risk-adjusted returns:"
for i in 0..<min(3, ranked.len):
  let result = ranked[i]
  echo (i + 1), ". ", result.symbol
  echo "   Return: ", result.report.totalReturn, "%"
  echo "   Sharpe: ", result.report.sharpeRatio
  echo "   Max DD: ", result.report.maxDrawdown, "%"
  echo "   Trades: ", result.report.totalTrades
  echo "   Win Rate: ", result.report.winRate, "%"
```

## Comparing Different Strategies

You can scan the same symbols with different strategies:

```nim
# Test RSI strategy
let rsiStrategy = newRSIStrategy(period = 14, oversold = 30, overbought = 70)
let rsiScanner = newScanner(rsiStrategy, symbols)
let rsiResults = rsiScanner.scanFromCSV("data/")

# Test MACD strategy
let macdStrategy = newMACDStrategy()
let macdScanner = newScanner(macdStrategy, symbols)
let macdResults = macdScanner.scanFromCSV("data/")

# Compare average returns
let rsiAvg = rsiResults.mapIt(it.report.totalReturn).sum() / rsiResults.len.float64
let macdAvg = macdResults.mapIt(it.report.totalReturn).sum() / macdResults.len.float64

echo "RSI average return: ", rsiAvg, "%"
echo "MACD average return: ", macdAvg, "%"
```

This helps identify which strategy approach works better for your symbol universe.

## Using the CLI for Scanning

The CLI tool provides scanning without writing code:

```bash
# Scan multiple symbols
./tzutrader_cli scan data/ AAPL,MSFT,GOOG,AMZN,TSLA \
  --strategy=rsi \
  --initial-cash=100000 \
  --commission=0.001

# Rank by Sharpe ratio
./tzutrader_cli scan data/ AAPL,MSFT,GOOG,AMZN,TSLA \
  --strategy=macd \
  --rank-by=sharpe

# Filter results
./tzutrader_cli scan data/ AAPL,MSFT,GOOG,AMZN,TSLA \
  --strategy=rsi \
  --min-return=5.0 \
  --min-sharpe=0.8 \
  --min-trades=15

# Get top N
./tzutrader_cli scan data/ AAPL,MSFT,GOOG,AMZN,TSLA \
  --strategy=rsi \
  --rank-by=sharpe \
  --top=5

# Export results
./tzutrader_cli scan data/ AAPL,MSFT,GOOG,AMZN,TSLA \
  --strategy=rsi \
  --export=scan_results.csv
```

See Chapter 8 (Advanced Workflows) for more CLI usage patterns.

## Export Scan Results

Export results for further analysis:

```nim
import tzutrader/exports

# Export to JSON
exportJson(results, "scan_results.json")

# Export to CSV
exportCsv(results, "scan_results.csv")
```

The CSV includes columns for symbol, return, Sharpe ratio, max drawdown, trades, win rate, and profit factor.

## Avoiding Common Mistakes

### Mistake 1: Cherry-Picking

Don't choose only the best-performing symbols for deployment. Those may have been lucky. Instead:
- Look at average performance across all symbols
- Consider what percentage of symbols are profitable
- Use out-of-sample testing on the top performers

### Mistake 2: Ignoring Sectors

If all tested symbols are from one sector (e.g., tech), the strategy may only work in that sector:

```nim
# Better: diverse sectors
let symbols = @[
  "AAPL",  # Tech
  "JPM",   # Finance
  "XOM",   # Energy
  "JNJ",   # Healthcare
  "WMT"    # Retail
]
```

### Mistake 3: Different Time Periods

Ensure all symbols cover the same date range. Comparing 2023 performance to 2020 performance isn't meaningful due to different market conditions.

### Mistake 4: Too Few Symbols

Testing 2-3 symbols doesn't provide enough evidence. Aim for at least 10-20 symbols across different sectors.

## Next Steps

The next chapter covers advanced workflows including parameter optimization, walk-forward testing, and batch processing with the CLI tool.

## Key Takeaways

- Test strategies across multiple symbols to identify robust approaches
- Use the Scanner module to automate multi-symbol backtesting
- Rank results by return, Sharpe ratio, or other metrics
- Filter results to find quality opportunities meeting multiple criteria
- Look for consistency across symbols, not just a few winners
- Ensure adequate sample size (30+ trades) for statistical significance
- Test diverse sectors, not just one industry
- Use the CLI tool for quick scanning without writing code
- Export results for analysis in spreadsheets or other tools
- Avoid cherry-picking winners - focus on average performance
