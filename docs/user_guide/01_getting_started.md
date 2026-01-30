# Getting Started with TzuTrader

## What is Algorithmic Trading?

Algorithmic trading uses computer programs to execute trades based on predefined rules. Instead of manually watching charts and clicking buy or sell buttons, an algorithmic trader writes code that makes trading decisions automatically.

This approach has several advantages: it removes emotional decision-making, executes trades faster than humans can, and can monitor multiple markets simultaneously. However, it also requires careful testing to ensure the trading logic performs as expected.

## What is TzuTrader?

TzuTrader is a trading bot library for Nim that provides tools for building and testing algorithmic trading strategies. The library includes:

- **Technical indicators** for analyzing price data (RSI, MACD, moving averages, etc.)
- **Strategy templates** for common trading approaches
- **Portfolio management** for tracking positions and capital
- **Backtesting engine** for testing strategies against historical data
- **Performance analytics** for evaluating strategy results

TzuTrader is designed for retail traders who have programming experience and want to build systematic trading approaches. The library focuses on simplicity and clarity rather than attempting to cover every possible trading scenario.

## Backtesting vs Live Trading

Before deploying a trading bot with real money, traders test their strategies against historical data. This process, called backtesting, simulates how the strategy would have performed in the past.

While past performance does not guarantee future results, backtesting helps traders:
- Understand a strategy's behavior and risk profile
- Identify potential issues before risking real capital
- Compare different approaches objectively
- Build confidence in their trading logic

TzuTrader currently focuses on the backtesting phase. The library provides the building blocks for creating trading bots, testing them thoroughly, and understanding their performance characteristics.

## Installation

### Prerequisites

You need Nim version 2.0.0 or later installed on your system. If you don't have Nim yet, download it from [nim-lang.org](https://nim-lang.org).

### Install TzuTrader

Clone the repository and install dependencies:

```bash
git clone https://codeberg.org/jailop/tzutrader.git
cd tzutrader
nimble install -y
```

### Verify Installation

Run the test suite to ensure everything is working:

```bash
nimble test
```

You should see output indicating that tests are passing. The library includes over 200 tests covering all major functionality.

## Your First Backtest

Let's backtest a simple RSI (Relative Strength Index) strategy. RSI is a momentum indicator that measures whether a security is overbought or oversold. The strategy buys when RSI indicates oversold conditions and sells when overbought.

This example assumes you have historical price data in CSV format.

### Step 1: Prepare Your Data

Create a CSV file with OHLCV (Open, High, Low, Close, Volume) data. The format should be:

```csv
timestamp,open,high,low,close,volume
1609459200,100.0,105.0,95.0,102.0,1000000.0
1609545600,102.0,107.0,100.0,106.0,1200000.0
```

Timestamps are Unix timestamps (seconds since January 1, 1970). You can obtain historical data from various sources including Yahoo Finance, or use TzuTrader's mock data generation for testing.

For this example, let's generate mock data:

```nim
import tzutrader

# Generate 365 days of mock data
let startTime = fromUnix(1609459200)  # Jan 1, 2021
let endTime = startTime + initDuration(days = 365)
let data = generateMockOHLCV(
  "AAPL",
  startTime.toUnix(),
  endTime.toUnix(),
  Int1d,
  startPrice = 100.0,
  volatility = 0.02
)

# Save to CSV
writeCSV(data, "test_data.csv")
```

### Step 2: Create and Run a Backtest

Create a file called `first_backtest.nim`:

```nim
import tzutrader

# Read historical data from CSV
let data = readCSV("test_data.csv")

# Create an RSI strategy
# - Buy when RSI < 30 (oversold)
# - Sell when RSI > 70 (overbought)
let strategy = newRSIStrategy(
  period = 14,
  oversold = 30.0,
  overbought = 70.0,
  symbol = "AAPL"
)

# Run the backtest
let report = quickBacktestCSV(
  "test_data.csv",
  strategy,
  initialCash = 100000.0,
  commission = 0.001  # 0.1% commission
)

# Display results
echo "\n=== Backtest Results ==="
echo report.summary()
```

### Step 3: Compile and Run

```bash
nim c -r first_backtest.nim
```

You should see output similar to:

```
=== Backtest Results ===
Symbol: AAPL
Period: 2021-01-01 to 2021-12-31
Initial Capital: $100,000.00
Final Value: $108,245.50
Total Return: 8.25%
Annualized Return: 8.25%
Sharpe Ratio: 0.87
Maximum Drawdown: -12.34%
Total Trades: 24
Win Rate: 58.33%
Profit Factor: 1.45
```

## Understanding the Results

The backtest report provides several metrics to evaluate strategy performance:

### Return Metrics

- **Total Return**: The percentage gain or loss from start to finish. In this example, 8.25% means the initial $100,000 grew to $108,245.50.

- **Annualized Return**: The average yearly return if the strategy were run for multiple years. This helps compare strategies tested over different time periods.

### Risk Metrics

- **Sharpe Ratio**: A measure of risk-adjusted returns. Higher is better. Values above 1.0 are generally considered good, above 2.0 are very good, and above 3.0 are exceptional. This example's 0.87 is modest.

- **Maximum Drawdown**: The largest peak-to-valley decline during the test period. In this case, -12.34% means at one point the portfolio lost 12.34% of its value from a previous high. This measures the worst-case scenario an investor would have experienced.

### Trading Activity

- **Total Trades**: The number of buy or sell transactions executed. More trades mean more commission costs and potentially more market impact.

- **Win Rate**: The percentage of profitable trades. This example's 58.33% means 14 out of 24 trades were winners. A high win rate doesn't guarantee profitability if losing trades are much larger than winning trades.

- **Profit Factor**: The ratio of gross profits to gross losses. Values above 1.0 indicate profitability. This example's 1.45 means for every dollar lost, the strategy made $1.45 in winning trades.

## Next Steps

Now that you've run your first backtest, you can:

1. **Learn about data management** - Understand how to work with different data sources and formats (see Chapter 2: Working with Market Data)

2. **Explore indicators** - Understand what technical indicators measure and when to use them (see Chapter 3: Understanding Technical Indicators)

3. **Try different strategies** - TzuTrader includes RSI, moving average crossover, MACD, and Bollinger Bands strategies (see Chapter 4: Building Trading Strategies)

4. **Understand portfolio management** - Learn about position sizing, commissions, and performance tracking (see Chapter 5: Managing Your Portfolio)

5. **Interpret backtest results** - Learn what makes a good backtest and common pitfalls to avoid (see Chapter 6: Running Backtests)

Remember that backtesting has limitations. It assumes you can execute trades at historical prices, doesn't account for slippage or market impact, and cannot predict future market conditions. A strategy that performed well in the past may not perform well in the future. Backtesting is a tool for understanding strategy behavior, not a guarantee of future profits.

TzuTrader provides the foundation for building trading bots through proper testing and analysis. Once you've thoroughly tested a strategy through backtesting, you would need additional infrastructure for live trading (market data feeds, order execution systems, risk controls, etc.).

## Using the CLI Tool

TzuTrader includes a command-line tool for quick backtests without writing code:

```bash
# Build the CLI tool
nimble cli

# Run a backtest
./tzutrader_cli backtest data/AAPL.csv --strategy=rsi --initial-cash=100000

# Scan multiple symbols
./tzutrader_cli scan data/ AAPL,MSFT,GOOG --strategy=macd --rank-by=sharpe

# Export results
./tzutrader_cli backtest data/AAPL.csv --strategy=rsi --export=results.json
```

The CLI tool is covered in detail in the Reference Guide Chapter 9: CLI Reference.

## Getting Help

- **API Documentation**: Auto-generated documentation for all functions and types
- **Reference Guide**: Comprehensive reference for all features and parameters
- **User Guide**: Conceptual guides for understanding and using TzuTrader

If you encounter issues:

1. Check that your data file format matches the expected CSV structure
2. Verify your Nim version is 2.0.0 or later
3. Run the test suite to ensure the library is working correctly
4. Review the examples in the `examples/` directory

## What's Next?

The next chapter covers working with market data, including where to get historical data, understanding the CSV format, and handling common data issues.
