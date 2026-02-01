# Reference Guide: Exports

## Overview

After running backtests or multi-symbol scans, you typically need to save results for analysis, reporting, or integration with other tools. TzuTrader's export module provides functions to write backtest reports, scan results, and trade logs to JSON or CSV formats.

Exporting serves several purposes:

- Record keeping: Archive backtest results for future comparison
- Analysis: Import data into spreadsheets, databases, or statistical software
- Reporting: Share results with colleagues or document trading research
- Monitoring: Track strategy performance over time as market conditions change

The export module handles formatting details so you can focus on analyzing results rather than writing serialization code.

Module: `tzutrader/exports.nim`

## JSON Export

JSON format preserves the complete structure of reports and results with human-readable formatting. It's well-suited for programmatic processing, web applications, and when you need to maintain all data relationships.

### BacktestReport to JSON

```nim
proc exportJson*(report: BacktestReport, filename: string)
```

Parameters:

| Parameter | Type | Description |
|-----------|------|-------------|
| `report` | BacktestReport | Report to export |
| `filename` | string | Output file path |

Example:

```nim
import tzutrader

let data = readCSV("data/AAPL.csv")
let strategy = newRSIStrategy()
let report = quickBacktest("AAPL", strategy, data)

exportJson(report, "results/aapl_backtest.json")
```

JSON Structure:

```json
{
  "symbol": "AAPL",
  "start_time": 1546300800,
  "end_time": 1577836800,
  "initial_cash": 100000.0,
  "final_value": 123450.67,
  "total_return": 23.45,
  "annualized_return": 21.32,
  "sharpe_ratio": 1.87,
  "max_drawdown": -8.23,
  "max_drawdown_duration": 3456000,
  "win_rate": 58.33,
  "total_trades": 24,
  "winning_trades": 14,
  "losing_trades": 10,
  "avg_win": 2.34,
  "avg_loss": -1.45,
  "profit_factor": 2.26,
  "best_trade": 8.92,
  "worst_trade": -4.21,
  "avg_trade_return": 0.98,
  "total_commission": 240.00
}
```

Field Details:

All fields correspond directly to the `BacktestReport` structure documented in the [Backtesting Engine reference](06_backtesting.md#field-reference). Timestamps are Unix seconds, monetary values are in the base currency (typically USD), and percentages are expressed as whole numbers (23.45 = 23.45%).

### ScanResults to JSON

```nim
proc exportJson*(results: seq[ScanResult], filename: string)
```

Parameters:

| Parameter | Type | Description |
|-----------|------|-------------|
| `results` | seq[ScanResult] | Scan results to export |
| `filename` | string | Output file path |

Example:

```nim
import tzutrader

let scanner = newScanner("data/")
let strategy = newRSIStrategy()
scanner.addStrategy(strategy)
scanner.addSymbol("AAPL")
scanner.addSymbol("MSFT")
scanner.addSymbol("GOOGL")

let results = scanner.run()
exportJson(results, "results/scan_results.json")
```

JSON Structure:

```json
[
  {
    "symbol": "AAPL",
    "report": {
      "symbol": "AAPL",
      "start_time": 1546300800,
      "end_time": 1577836800,
      "initial_cash": 100000.0,
      "final_value": 123450.67,
      "total_return": 23.45,
      "annualized_return": 21.32,
      "sharpe_ratio": 1.87,
      "max_drawdown": -8.23,
      "max_drawdown_duration": 3456000,
      "win_rate": 58.33,
      "total_trades": 24,
      "winning_trades": 14,
      "losing_trades": 10,
      "avg_win": 2.34,
      "avg_loss": -1.45,
      "profit_factor": 2.26,
      "best_trade": 8.92,
      "worst_trade": -4.21,
      "avg_trade_return": 0.98,
      "total_commission": 240.00
    },
    "signals_count": 48
  },
  {
    "symbol": "MSFT",
    "report": { ... },
    "signals_count": 52
  }
]
```

The export includes the full `BacktestReport` for each symbol plus the number of signals generated during the scan period. The `signals_count` field shows how actively the strategy traded each symbol.

### Trade Log to JSON

```nim
proc exportTradeLog*(logs: seq[TradeLog], filename: string)
```

Parameters:

| Parameter | Type | Description |
|-----------|------|-------------|
| `logs` | seq[TradeLog] | Trade logs to export |
| `filename` | string | Output file path |

Example:

```nim
import tzutrader

let data = readCSV("data/AAPL.csv")
let strategy = newRSIStrategy()
let backtester = newBacktester(strategy, verbose = true)
let report = backtester.run(data, "AAPL")

# Access trade logs from backtester
let logs = backtester.portfolio.tradeLogs
exportTradeLog(logs, "results/aapl_trades.json")
```

JSON Structure:

```json
[
  {
    "timestamp": 1546560000,
    "symbol": "AAPL",
    "action": "Buy",
    "quantity": 100,
    "price": 157.92,
    "cash": 84208.00,
    "equity": 100000.00
  },
  {
    "timestamp": 1548115200,
    "symbol": "AAPL",
    "action": "Sell",
    "quantity": 100,
    "price": 165.25,
    "cash": 100741.00,
    "equity": 100741.00
  }
]
```

Trade logs provide a chronological record of every executed order with portfolio state before and after each trade. This granular data helps debug strategy behavior and analyze individual trade sequences.

## CSV Export

CSV format provides maximum compatibility with spreadsheets, databases, and statistical software. It's ideal for comparative analysis across multiple backtests or when you need simple tabular data.

CSV exports flatten the data structure—each backtest becomes one row with all metrics as columns.

### BacktestReport to CSV

```nim
proc exportCsv*(report: BacktestReport, filename: string)
```

Parameters:

| Parameter | Type | Description |
|-----------|------|-------------|
| `report` | BacktestReport | Report to export |
| `filename` | string | Output file path |

Example:

```nim
import tzutrader

let report = quickBacktestCSV("AAPL", strategy, "data/AAPL.csv")
exportCsv(report, "results/aapl_backtest.csv")
```

CSV Structure:

```csv
symbol,start_time,end_time,initial_cash,final_value,total_return,annualized_return,sharpe_ratio,max_drawdown,max_drawdown_duration,win_rate,total_trades,winning_trades,losing_trades,avg_win,avg_loss,profit_factor,best_trade,worst_trade,avg_trade_return,total_commission
AAPL,1546300800,1577836800,100000.0,123450.67,23.45,21.32,1.87,-8.23,3456000,58.33,24,14,10,2.34,-1.45,2.26,8.92,-4.21,0.98,240.0
```

The file includes a header row with column names followed by one data row per report.

### ScanResults to CSV

```nim
proc exportCsv*(results: seq[ScanResult], filename: string)
```

Parameters:

| Parameter | Type | Description |
|-----------|------|-------------|
| `results` | seq[ScanResult] | Scan results to export |
| `filename` | string | Output file path |

Example:

```nim
import tzutrader

let scanner = newScanner("data/")
let strategy = newRSIStrategy()
scanner.addStrategy(strategy)

# Add multiple symbols
for symbol in ["AAPL", "MSFT", "GOOGL", "AMZN", "TSLA"]:
  scanner.addSymbol(symbol)

let results = scanner.run()
exportCsv(results, "results/scan_comparison.csv")
```

CSV Structure:

```csv
symbol,start_time,end_time,initial_cash,final_value,total_return,annualized_return,sharpe_ratio,max_drawdown,max_drawdown_duration,win_rate,total_trades,winning_trades,losing_trades,avg_win,avg_loss,profit_factor,best_trade,worst_trade,avg_trade_return,total_commission
AAPL,1546300800,1577836800,100000.0,123450.67,23.45,21.32,1.87,-8.23,3456000,58.33,24,14,10,2.34,-1.45,2.26,8.92,-4.21,0.98,240.0
MSFT,1546300800,1577836800,100000.0,118920.34,18.92,17.45,1.62,-10.12,4320000,55.00,20,11,9,2.89,-2.01,1.98,7.45,-5.32,0.95,200.0
GOOGL,1546300800,1577836800,100000.0,132156.89,32.16,29.34,2.14,-6.78,2592000,62.50,16,10,6,3.21,-1.89,2.87,9.87,-3.45,2.01,160.0
```

Each symbol's backtest becomes one row, making it easy to sort by metrics like total return or Sharpe ratio in a spreadsheet. This format excels for comparing strategy performance across many symbols.

### Trade Log to CSV

```nim
proc exportTradeLogCsv*(logs: seq[TradeLog], filename: string)
```

Parameters:

| Parameter | Type | Description |
|-----------|------|-------------|
| `logs` | seq[TradeLog] | Trade logs to export |
| `filename` | string | Output file path |

Example:

```nim
import tzutrader

let backtester = newBacktester(strategy, verbose = true)
let report = backtester.run(data, "AAPL")
let logs = backtester.portfolio.tradeLogs

exportTradeLogCsv(logs, "results/aapl_trades.csv")
```

CSV Structure:

```csv
timestamp,symbol,action,quantity,price,cash,equity
1546560000,AAPL,Buy,100,157.92,84208.0,100000.0
1548115200,AAPL,Sell,100,165.25,100741.0,100741.0
1550966400,AAPL,Buy,100,174.18,84156.82,100741.0
```

This format imports cleanly into spreadsheet software for calculating per-trade returns, analyzing holding periods, or creating trade visualizations.

## Format Selection Guidelines

Choose export formats based on your workflow and analysis needs:

### Use JSON When:

- Programmatic processing: You'll parse results with scripts or applications
- Web applications: Serving backtest data through APIs
- Complex structures: Maintaining relationships between nested data
- Future flexibility: You might need additional fields later
- Single reports: Exporting one backtest for detailed review

JSON preserves all data relationships and extends easily when you add new metrics to your backtesting system.

### Use CSV When:

- Spreadsheet analysis: Opening files in Excel, Google Sheets, or LibreOffice
- Database import: Loading data into SQL or NoSQL databases
- Statistical software: Analyzing results in R, Python pandas, or Julia
- Comparative analysis: Reviewing many backtests side-by-side
- Simple reporting: Sharing results with non-technical stakeholders

CSV's tabular format makes it immediately accessible in the widest range of analysis tools.

### Practical Workflow

A typical research workflow might use both formats:

```nim
import tzutrader, std/os

# Run parameter sweep
var results: seq[ScanResult] = @[]

for period in [10, 14, 20, 28]:
  for oversold in [25.0, 30.0, 35.0]:
    for overbought in [65.0, 70.0, 75.0]:
      let strategy = newRSIStrategy(period, oversold, overbought)
      
      let scanner = newScanner("data/")
      scanner.addStrategy(strategy)
      for symbol in ["AAPL", "MSFT", "GOOGL"]:
        scanner.addSymbol(symbol)
      
      results.add(scanner.run())

# Export to CSV for quick spreadsheet review
exportCsv(results, "parameter_sweep.csv")

# Export to JSON for detailed programmatic analysis
exportJson(results, "parameter_sweep.json")
```

This approach lets you quickly identify promising parameters in a spreadsheet, then dive into detailed analysis with custom scripts.

## Helper Functions

The export module also provides lower-level conversion functions for custom workflows:

### JSON Conversion

```nim
proc toJson*(report: BacktestReport): JsonNode
proc toJson*(scanResult: ScanResult): JsonNode
proc toJson*(results: seq[ScanResult]): JsonNode
proc toJson*(log: TradeLog): JsonNode
```

These functions convert objects to JSON nodes without writing to disk, useful for:

- Building custom export formats
- Embedding reports in larger JSON structures
- Sending results over network APIs
- Creating in-memory data pipelines

Example:

```nim
import tzutrader, std/json

let report = quickBacktest("AAPL", strategy, data)
let jsonNode = report.toJson()

# Add custom metadata
jsonNode["strategy_name"] = %"RSI_14_30_70"
jsonNode["test_date"] = %getCurrentDate()
jsonNode["notes"] = %"Testing with 0.1% commission"

writeFile("custom_report.json", jsonNode.pretty())
```

### CSV Conversion

```nim
proc toCsvHeader*(): string
proc toCsvRow*(report: BacktestReport): string
```

These functions generate CSV header and data rows without writing to disk, useful for:

- Appending results to existing CSV files
- Streaming results to databases
- Building custom CSV formats with additional columns

Example:

```nim
import tzutrader

var csvContent = toCsvHeader() & "\n"

for symbol in symbols:
  let report = quickBacktestCSV(symbol, strategy, &"data/{symbol}.csv")
  csvContent &= report.toCsvRow() & "\n"

writeFile("all_symbols.csv", csvContent)
```

## File Organization

Organize exported files to support reproducible research:

```
results/
├── 2024-01-15_rsi_scan/
│   ├── reports.json          # All scan results
│   ├── reports.csv           # Comparative view
│   ├── AAPL_trades.json      # Per-symbol trade logs
│   ├── MSFT_trades.json
│   └── README.txt            # Parameters and notes
├── 2024-01-22_macd_scan/
│   └── ...
└── parameter_sweeps/
    ├── rsi_period_sweep.csv
    └── rsi_threshold_sweep.csv
```

Include metadata files documenting:

- Strategy parameters used
- Data sources and date ranges
- Commission assumptions
- Initial capital amounts
- Any data preprocessing steps

This organization makes it easy to return to past research and understand what you tested.

## Performance Considerations

File sizes:

- JSON files are 2-3x larger than CSV for the same data due to formatting and field names
- Trade logs with hundreds of trades create substantial files (10,000 trades ≈ 1-2 MB JSON)
- Use compression (gzip) for archiving large result sets

Write performance:

Both JSON and CSV exports are I/O-bound. For extremely large scan results (thousands of symbols), consider:

- Writing results in batches rather than all at once
- Using streaming CSV appends instead of building full content in memory
- Storing results in a database rather than flat files

For typical scans of 10-100 symbols, export performance is negligible compared to backtest execution time.

## See Also

- [Backtesting Engine](06_backtesting.md) - BacktestReport structure and fields
- [Multi-Symbol Scanning](07_scanning.md) - ScanResult structure and Scanner usage
- [Portfolio Management](05_portfolio.md) - TradeLog structure and portfolio state
- [CLI Tool](09_cli.md) - Command-line export options

The export module provides the final step in the backtesting workflow—preserving your results for analysis, comparison, and decision-making about which strategies merit further research or live trading consideration.
