# Getting Started with TzuTrader

## Introduction

TzuTrader is a simplified trading bot library written in Nim. It provides a clean, flat architecture that makes algorithmic trading accessible while maintaining high performance through Nim's compiled nature.

## Installation

### From Source

```bash
git clone <repository-url>
cd tzutrader
nimble install
```

### Requirements

- Nim >= 2.0.0
- yfnim (for Yahoo Finance data)

## Your First Strategy

Let's create a simple RSI-based trading strategy:

```nim
import tzutrader

# 1. Create a strategy configuration
let strategy = newRSIStrategy(
  period = 14,
  oversold = 30.0,
  overbought = 70.0
)

# 2. Set up a portfolio with initial capital
let portfolio = newPortfolio(initialCash = 10000.0)

# 3. Create a trader
let trader = newTrader(strategy, portfolio)

# 4. Add symbols to trade
trader.addSymbol("AAPL")

# 5. Run backtest
let report = trader.backtest(
  startTime = parseTime("2023-01-01"),
  endTime = parseTime("2024-01-01")
)

# 6. View results
echo "Total Return: ", report.totalReturn, "%"
echo "Win Rate: ", report.winRate, "%"
echo "Total Trades: ", report.totalTrades
```

## Core Concepts

### Positions

TzuTrader uses three position types:
- `Stay`: Hold current position
- `Buy`: Enter or increase long position
- `Sell`: Exit or decrease position

### OHLCV Data

Market data is represented as OHLCV (Open-High-Low-Close-Volume) bars:

```nim
let bar = OHLCV(
  timestamp: getTime().toUnix(),
  open: 100.0,
  high: 105.0,
  low: 99.0,
  close: 103.0,
  volume: 1000000.0
)
```

### Signals

Strategies generate signals that indicate trading actions:

```nim
let signal = newSignal(
  position = Buy,
  symbol = "AAPL",
  price = 150.0,
  reason = "RSI oversold at 25"
)
```

## Next Steps

- Learn about [built-in strategies](strategies.md)
- Explore [technical indicators](indicators.md)
- Create [custom strategies](custom-strategies.md)
- Understand [backtesting](backtesting.md)

## Project Status

TzuTrader is in active development with all core features complete and tested:

Completed:
- ✓ Core types and data structures
- ✓ Testing framework
- ✓ JSON serialization
- ✓ Data module with Yahoo Finance integration
- ✓ Historical data fetching and CSV support
- ✓ 25 technical indicators
- ✓ Pre-built and custom strategies
- ✓ Portfolio management
- ✓ Backtesting engine
- ✓ Multi-symbol scanning
- ✓ Export capabilities (CSV/JSON)
- ✓ CLI tool
- ✓ Comprehensive documentation
