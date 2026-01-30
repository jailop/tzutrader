# TzuTrader

A high-performance trading bot library in Nim for backtesting algorithmic trading strategies. It is a re-write of the Python's [pybottrader](https://github.com/datainquiry/pybottrader) library.


## Quick Start

### Installation

```bash
git clone https://codeberg.org/jailop/tzutrader.git
cd tzutrader
nimble install -y
```

**Requirements:** Nim 2.0.0 or later

### Your First Backtest

```nim
import tzutrader

# Load historical data
let data = readCSV("data/AAPL.csv")

# Create RSI strategy
let strategy = newRSIStrategy(period = 14, oversold = 30, overbought = 70)

# Run backtest
let report = quickBacktest(
  symbol = "AAPL",
  strategy = strategy,
  data = data,
  initialCash = 100000.0,
  commission = 0.001
)

# View results
echo report.summary()
```

**Output:**
```
Backtest Report: AAPL
=====================================
Total Return:     23.45%
Annualized:       21.32%
Sharpe Ratio:     1.87
Max Drawdown:     -8.23%
Win Rate:         58.33%
Profit Factor:    2.26
Total Trades:     24
```

## Core Capabilities

### Technical Indicators

```nim
import tzutrader

let prices = @[100.0, 102.0, 104.0, 103.0, 105.0, 107.0, 110.0]

let sma5 = sma(prices, 5)              # Simple Moving Average
let ema10 = ema(prices, 10)            # Exponential Moving Average
let rsi14 = rsi(prices, 14)            # Relative Strength Index
let macdData = macd(prices)            # MACD with signal line
let bb = bollingerBands(prices, 20)    # Bollinger Bands
let atr14 = atr(ohlcvData, 14)         # Average True Range
```

**Available Indicators:** SMA, EMA, WMA, RSI, MACD, Bollinger Bands, ATR, ROC, OBV, Stochastic

### Pre-Built Strategies

```nim
# RSI Strategy - Mean reversion
let rsi = newRSIStrategy(period = 14, oversold = 30, overbought = 70)

# Moving Average Crossover - Trend following
let crossover = newCrossoverStrategy(fastPeriod = 10, slowPeriod = 20)

# MACD Strategy - Momentum
let macdStrat = newMACDStrategy(fast = 12, slow = 26, signal = 9)

# Bollinger Bands - Volatility breakout
let bb = newBollingerStrategy(period = 20, stdDev = 2.0)
```

### Custom Strategies

```nim
import tzutrader

type
  MyStrategy = ref object of Strategy
    period: int

proc newMyStrategy*(period: int = 20): MyStrategy =
  result = MyStrategy(period: period)

method onBar*(self: MyStrategy, bar: OHLCV): Signal =
  # Your strategy logic here
  self.addBar(bar)
  
  if self.bars.len < self.period:
    return Signal(position: Stay)
  
  let ma = sma(self.closePrices(), self.period)[^1]
  
  if bar.close > ma * 1.02:
    return Signal(position: Buy, price: bar.close, timestamp: bar.timestamp)
  elif bar.close < ma * 0.98:
    return Signal(position: Sell, price: bar.close, timestamp: bar.timestamp)
  else:
    return Signal(position: Stay)
```

### Multi-Symbol Scanning

```nim
import tzutrader

let scanner = newScanner("data/")
scanner.addStrategy(newRSIStrategy())

for symbol in ["AAPL", "MSFT", "GOOGL", "AMZN", "TSLA"]:
  scanner.addSymbol(symbol)

let results = scanner.run(initialCash = 100000.0, commission = 0.001)

# Export results
exportCsv(results, "scan_results.csv")

# Print top performers
for result in scanner.topN(results, 3):
  echo result.symbol, ": ", result.report.totalReturn, "%"
```

### CLI Tool

```bash
# Build CLI
nimble cli

# Backtest a single symbol
./tzutrader_cli backtest data/AAPL.csv --strategy=rsi --cash=50000

# Scan multiple symbols
./tzutrader_cli scan data/ AAPL,MSFT,GOOGL --strategy=macd --rank-by=sharpe

# Export results
./tzutrader_cli backtest data/AAPL.csv --strategy=rsi --export=results.json
```

## Documentation

TzuTrader provides comprehensive documentation at three levels:

- **[User Guide](docs/user_guide/)** - Learn concepts and understand how to use TzuTrader
- **[Reference Guide](docs/reference_guide/)** - Complete technical specifications with examples
- **[API Documentation](docs/api/)** - Exhaustive function reference (generate with `nimble docs`)

**Quick Links:**
- [Getting Started](docs/user_guide/01_getting_started.md)
- [Working with Data](docs/user_guide/02_data.md)
- [Building Strategies](docs/user_guide/04_strategies.md)
- [Running Backtests](docs/user_guide/06_backtesting.md)
- [Best Practices](docs/user_guide/09_best_practices.md)

## Performance Metrics

Backtest reports include comprehensive performance analytics:

- **Returns:** Total, annualized, and average per trade
- **Risk-Adjusted:** Sharpe ratio, Sortino ratio, max drawdown
- **Trade Statistics:** Win rate, profit factor, average win/loss
- **Portfolio:** Equity curve, transaction history, commission costs

## Testing

```bash
nimble test
```

## Examples

The `examples/` directory contains working programs demonstrating:

- Loading and processing CSV data
- Calculating technical indicators
- Using pre-built strategies
- Creating custom strategies
- Running backtests with different configurations
- Multi-symbol scanning
- Exporting results

Run examples:
```bash
nimble examples          # Compile all examples
./examples/backtest_example
./examples/rsi_strategy_example
./examples/scanner_example
```
