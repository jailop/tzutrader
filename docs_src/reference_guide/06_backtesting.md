# Reference Guide: Backtesting Engine

## Overview

Backtesting simulates how a trading strategy would have performed on historical data. TzuTrader's backtesting engine integrates strategies with portfolio management, executes signals, tracks performance, and generates comprehensive reports.

The backtesting system handles the mechanics of trade execution, position sizing, commission calculation, and performance measurement so you can focus on strategy logic.

**Module:** `tzutrader/trader.nim`

## Understanding Backtesting

A backtest processes historical data bar by bar, asking the strategy for a trading signal at each step. When the strategy issues a buy or sell signal, the backtester executes it through the portfolio, which manages cash, positions, and accounting.

**Key concepts:**

- **Bar-by-bar execution:** The engine processes data sequentially, mimicking real-time trading
- **No lookahead:** Strategies see only past data at each bar, preventing unrealistic future knowledge
- **Position sizing:** The backtester calculates how many shares to buy based on available cash
- **Automatic closing:** Final positions are closed at the last bar's price for complete accounting

The backtesting engine doesn't make trading decisions—it provides the infrastructure for testing strategies you define.

## Backtester Type

### Constructor

```nim
proc newBacktester*(strategy: Strategy, initialCash: float64 = 100000.0,
                   commission: float64 = 0.0, verbose: bool = false): Backtester
```

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `strategy` | Strategy | — | Trading strategy to test |
| `initialCash` | float64 | 100000.0 | Starting capital ($) |
| `commission` | float64 | 0.0 | Commission rate (0.001 = 0.1%) |
| `verbose` | bool | false | Enable detailed logging |

**Returns:** Configured Backtester instance

**Example:**

```nim
import tzutrader

let strategy = newRSIStrategy(period = 14, oversold = 30.0, overbought = 70.0)
let backtester = newBacktester(
  strategy = strategy,
  initialCash = 50000.0,
  commission = 0.001,  # 0.1% per trade
  verbose = true
)
```

### Running a Backtest

```nim
proc run*(bt: Backtester, data: seq[OHLCV], symbol: string = ""): BacktestReport
```

**Parameters:**

- `data`: Historical OHLCV bars (must be in chronological order)
- `symbol`: Symbol identifier for reporting (optional)

**Returns:** Complete `BacktestReport` with all performance metrics

**Process:**

1. Resets strategy and portfolio state
2. Iterates through each historical bar
3. Requests signal from strategy
4. Updates portfolio with current prices
5. Records equity curve point
6. Executes signal if not `Stay`
7. Closes final positions at last bar
8. Calculates comprehensive performance metrics

**Example:**

```nim
import tzutrader

let data = readCSV("data/AAPL.csv")
let strategy = newRSIStrategy()
let backtester = newBacktester(strategy, initialCash = 100000.0)

let report = backtester.run(data, "AAPL")
echo report
```

## Convenience Functions

For quick backtests without creating a Backtester object explicitly:

### quickBacktest

```nim
proc quickBacktest*(symbol: string, strategy: Strategy, data: seq[OHLCV],
                   initialCash: float64 = 100000.0, 
                   commission: float64 = 0.0,
                   verbose: bool = false): BacktestReport
```

**Example:**

```nim
let report = quickBacktest("AAPL", strategy, data, initialCash = 50000.0)
```

### quickBacktestCSV

```nim
proc quickBacktestCSV*(symbol: string, strategy: Strategy, csvPath: string,
                       initialCash: float64 = 100000.0,
                       commission: float64 = 0.0,
                       verbose: bool = false): BacktestReport
```

**Example:**

```nim
let report = quickBacktestCSV("AAPL", strategy, "data/AAPL.csv")
```

This function loads CSV data and runs the backtest in one call—convenient for quick tests.

## BacktestReport Type

The `BacktestReport` contains complete backtest results organized into several categories.

### Structure

```nim
type
  BacktestReport* = object
    symbol*: string
    startTime*: int64
    endTime*: int64
    initialCash*: float64
    finalValue*: float64
    totalReturn*: float64
    annualizedReturn*: float64
    sharpeRatio*: float64
    maxDrawdown*: float64
    maxDrawdownDuration*: int64
    winRate*: float64
    totalTrades*: int
    winningTrades*: int
    losingTrades*: int
    avgWin*: float64
    avgLoss*: float64
    profitFactor*: float64
    bestTrade*: float64
    worstTrade*: float64
    avgTradeReturn*: float64
    totalCommission*: float64
```

### Field Reference

#### Basic Information

| Field | Type | Description |
|-------|------|-------------|
| `symbol` | string | Symbol tested |
| `startTime` | int64 | First bar timestamp (Unix) |
| `endTime` | int64 | Last bar timestamp (Unix) |
| `initialCash` | float64 | Starting capital |
| `finalValue` | float64 | Final portfolio equity |

#### Return Metrics

| Field | Type | Formula | Description |
|-------|------|---------|-------------|
| `totalReturn` | float64 | $$\frac{\text{final} - \text{initial}}{\text{initial}} \times 100$$ | Total percentage gain/loss |
| `annualizedReturn` | float64 | $$\left(\frac{\text{final}}{\text{initial}}\right)^{\frac{1}{years}} - 1 \times 100$$ | Return scaled to annual rate |

**Annualized Return:**

The annualized return normalizes returns to a yearly basis, making it easier to compare strategies tested over different time periods. A 50% return over 6 months annualizes to roughly 104%, while the same return over 2 years annualizes to about 22%.

#### Risk-Adjusted Metrics

| Field | Type | Description |
|-------|------|-------------|
| `sharpeRatio` | float64 | Risk-adjusted return measure |

**Sharpe Ratio Formula:**

$$\text{Sharpe} = \frac{\bar{r} - r_f}{\sigma_r} \times \sqrt{252}$$

where:
- $\bar{r}$ is the average return per period
- $r_f$ is the risk-free rate per period
- $\sigma_r$ is the standard deviation of returns
- $\sqrt{252}$ annualizes the ratio (assuming 252 trading days)

**Interpretation:**

- **> 1.0:** Generally acceptable performance
- **> 2.0:** Good risk-adjusted performance
- **> 3.0:** Excellent (rare for retail strategies)
- **< 0:** Strategy lost money or had very high volatility

Higher Sharpe ratios indicate better risk-adjusted returns. However, the Sharpe ratio assumes normally distributed returns, which financial data often violates.

#### Drawdown Metrics

| Field | Type | Description |
|-------|------|-------------|
| `maxDrawdown` | float64 | Largest peak-to-trough decline (%) |
| `maxDrawdownDuration` | int64 | Longest drawdown period (seconds) |

**Maximum Drawdown Formula:**

$$\text{Max Drawdown} = \max_{t} \left( \frac{\text{Peak}_t - \text{Equity}_t}{\text{Peak}_t} \times 100 \right)$$

where $\text{Peak}_t$ is the highest equity value observed up to time $t$.

**Understanding Drawdown:**

Drawdown measures how much the equity curve declined from its peak before recovering. A -15% max drawdown means at some point, the portfolio lost 15% from its highest value.

Drawdown duration indicates how long it took to recover. Long drawdown periods test trader discipline—can you stick with a strategy during a 6-month losing period?

#### Trade Statistics

| Field | Type | Description |
|-------|------|-------------|
| `totalTrades` | int | Number of completed round-trip trades |
| `winningTrades` | int | Number of profitable trades |
| `losingTrades` | int | Number of unprofitable trades |
| `winRate` | float64 | Percentage of winning trades |

**Win Rate Formula:**

$$\text{Win Rate} = \frac{\text{Winning Trades}}{\text{Total Trades}} \times 100$$

**Important Note:** Win rate alone doesn't determine profitability. A strategy with 40% win rate can be highly profitable if winners are much larger than losers.

#### Profit Metrics

| Field | Type | Description |
|-------|------|-------------|
| `avgWin` | float64 | Average profit per winning trade ($) |
| `avgLoss` | float64 | Average loss per losing trade ($) |
| `profitFactor` | float64 | Ratio of gross profit to gross loss |
| `bestTrade` | float64 | Largest winning trade ($) |
| `worstTrade` | float64 | Largest losing trade ($) |
| `avgTradeReturn` | float64 | Average P&L across all trades ($) |

**Profit Factor Formula:**

$$\text{Profit Factor} = \frac{\sum \text{Winning Trades}}{\left|\sum \text{Losing Trades}\right|}$$

**Interpretation:**

- **> 1.0:** Strategy is profitable overall
- **< 1.0:** Strategy loses money
- **≈ 2.0:** Good performance (winners are 2x losers)
- **> 3.0:** Excellent performance

Profit factor captures both win rate and average win/loss magnitude. A profit factor of 2.0 means you make $2 for every $1 you lose.

#### Cost Metrics

| Field | Type | Description |
|-------|------|-------------|
| `totalCommission` | float64 | Total commissions paid ($) |

High commission totals relative to profits indicate a strategy trades too frequently for its edge to overcome costs.

### Report Display

```nim
proc `$`*(report: BacktestReport): string
```

Formats the report as a readable multi-line summary with all metrics organized by category.

```nim
proc formatCompact*(report: BacktestReport): string
```

Returns a one-line summary suitable for comparing multiple backtests:

```
AAPL: Return=+15.30% Sharpe=1.45 Trades=42 WinRate=58.3% MaxDD=-12.50%
```

## TradeLog Type

The backtester maintains a log of all trades for detailed analysis.

```nim
type
  TradeLog* = object
    timestamp*: int64
    symbol*: string
    action*: Position
    quantity*: float64
    price*: float64
    cash*: float64
    equity*: float64
```

**Fields:**

- `timestamp`: When the trade occurred (Unix timestamp)
- `symbol`: Symbol traded
- `action`: Buy or Sell
- `quantity`: Shares traded
- `price`: Execution price
- `cash`: Cash balance after trade
- `equity`: Total portfolio equity after trade

**Accessing Trade Logs:**

```nim
let backtester = newBacktester(strategy)
let report = backtester.run(data, "AAPL")

for trade in backtester.tradeLogs:
  echo trade.timestamp.fromUnix.format("yyyy-MM-dd"), ": ",
       trade.action, " ", trade.quantity, " @ $", trade.price
```

## Equity Curve

The backtester records portfolio equity at every bar, creating an equity curve for visualization.

**Access:**

```nim
let backtester = newBacktester(strategy)
let report = backtester.run(data, "AAPL")

for (timestamp, equity) in backtester.equityCurve:
  echo timestamp.fromUnix.format("yyyy-MM-dd"), ": $", equity
```

**Usage:**

Export the equity curve to CSV for plotting in Excel, Python, or other visualization tools:

```nim
var csvFile = open("equity_curve.csv", fmWrite)
csvFile.writeLine("date,equity")
for (timestamp, equity) in backtester.equityCurve:
  csvFile.writeLine(timestamp.fromUnix.format("yyyy-MM-dd"), ",", equity)
csvFile.close()
```

## Position Sizing

The backtester uses a simple position sizing rule:

**Buy orders:** Use 95% of available cash to leave a buffer for commissions and prevent insufficient-fund rejections.

**Formula:**

$$\text{Quantity} = \left\lfloor \frac{\text{Cash} \times 0.95}{\text{Price}} \right\rfloor$$

The floor function ensures we buy whole shares (no fractional shares).

**Sell orders:** Close the entire position.

**Custom Position Sizing:**

For custom position sizing logic, implement it within your strategy's signal generation. Return `Stay` when you don't want to trade, even if your indicator suggests otherwise.

## Commission Modeling

Commissions reduce proceeds from sells and increase costs for buys.

**Buy Transaction Total Cost:**

$$\text{Total Cost} = (\text{Quantity} \times \text{Price}) + \text{Commission}$$

where:

$$\text{Commission} = (\text{Quantity} \times \text{Price}) \times \text{Rate}$$

**Sell Transaction Net Proceeds:**

$$\text{Net Proceeds} = (\text{Quantity} \times \text{Price}) - \text{Commission}$$

**Impact on Performance:**

Even small commission rates significantly affect high-frequency strategies. A strategy that trades weekly with 0.1% commissions pays roughly 10% annually in transaction costs (50 round trips × 0.2%).

## Verbose Mode

Setting `verbose = true` prints detailed execution information:

```
============================================================
Starting Backtest: AAPL
Period: 2020-01-01 to 2021-12-31
Bars: 504
Initial Cash: $100000.00
============================================================

[BUY] 2020-03-15 - AAPL: 650 @ $153.18
[SELL] 2020-05-22 - AAPL: 650 @ $167.45
[BUY] 2020-06-10 - AAPL: 700 @ $142.50
...

============================================================
Backtest Complete!
============================================================
[Full report display]
```

Use verbose mode when:
- Debugging unexpected strategy behavior
- Understanding why a backtest underperformed expectations
- Learning how the strategy makes decisions
- Verifying signal logic works correctly

## Common Backtest Patterns

### Basic Backtest

```nim
import tzutrader

let data = readCSV("data/AAPL.csv")
let strategy = newRSIStrategy()
let report = quickBacktest("AAPL", strategy, data)

echo "Total Return: ", report.totalReturn, "%"
echo "Sharpe Ratio: ", report.sharpeRatio
```

### Parameter Comparison

```nim
import tzutrader

let data = readCSV("data/AAPL.csv")

for period in [10, 14, 20]:
  let strategy = newRSIStrategy(period = period)
  let report = quickBacktest("AAPL", strategy, data)
  echo "RSI(", period, "): ", report.formatCompact()
```

### Commission Sensitivity Analysis

```nim
import tzutrader

let data = readCSV("data/AAPL.csv")
let strategy = newMACDStrategy()

for commRate in [0.0, 0.0005, 0.001, 0.002]:
  let report = quickBacktest("AAPL", strategy, data, commission = commRate)
  echo "Commission ", commRate * 100, "%: Return=", report.totalReturn, "%"
```

### Multiple Symbols

```nim
import tzutrader, std/tables

let strategy = newCrossoverStrategy()
var results = initTable[string, BacktestReport]()

for symbol in ["AAPL", "MSFT", "GOOG"]:
  let data = readCSV("data/" & symbol & ".csv")
  results[symbol] = quickBacktest(symbol, strategy, data)

# Find best performer
var bestSymbol = ""
var bestReturn = -Inf
for symbol, report in results:
  if report.totalReturn > bestReturn:
    bestReturn = report.totalReturn
    bestSymbol = symbol

echo "Best: ", bestSymbol, " with ", bestReturn, "% return"
```

## Limitations and Considerations

### Market Impact

The backtester assumes trades execute at the signal price without slippage or market impact. Real trading involves:

- **Slippage:** Execution price differs from signal price
- **Market impact:** Large orders move prices against you
- **Liquidity:** Not all prices are available in sufficient size

For liquid stocks with small position sizes, these effects are minimal. For large positions or illiquid stocks, they matter significantly.

### Survivorship Bias

If your dataset includes only stocks that survived to present day, results are overly optimistic. Bankrupted companies don't appear in most historical datasets, yet a real strategy would have held some losers to zero.

### Overfitting

Backtests measure how a strategy performed on specific historical data. Optimizing parameters to maximize backtest results often creates strategies that fail in live trading because they're tuned to past noise rather than genuine patterns.

See [User Guide: Best Practices](../user_guide/10_best_practices.md) for mitigating these issues.

### Signal Timing

Strategies generate signals based on the current bar's data. In live trading, you might not know the bar's close price until the period ends, introducing timing challenges the backtest doesn't model.

## Performance Considerations

**Backtesting speed:** Typical backtests run in milliseconds to seconds depending on:
- Data size (number of bars)
- Strategy complexity (indicator calculations)
- Number of trades executed

**Memory usage:** Moderate. The backtester stores:
- Equity curve (one point per bar)
- Trade logs (one entry per trade)
- Portfolio state

For very large datasets (millions of bars), consider streaming data rather than loading everything into memory.

## See Also

- [Portfolio Reference](05_portfolio.md) - Portfolio management and metrics
- [Strategy Reference](04_strategies.md) - Strategy implementation
- [Scanner Reference](07_scanning.md) - Multi-symbol backtesting
- [User Guide: Backtesting](../user_guide/06_backtesting.md) - Conceptual introduction
- [User Guide: Best Practices](../user_guide/10_best_practices.md) - Avoiding common mistakes
