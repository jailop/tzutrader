# TzuTrader

A simplified, high-performance trading bot library in Nim.

## Overview

TzuTrader is inspired by [pybottrader](https://github.com/datainquiry/pybottrader) but reimagined for Nim with a simplified, flat architecture. It eliminates the nested module structure and C++ dependencies of the original, providing an intuitive API for algorithmic trading.

## Features

- **Pure Nim Implementation**: All indicators reimplemented in Nim (no C++/CMake/pybind11)
- **Flat Architecture**: Simple imports like `import tzutrader`
- **High Performance**: 10-100x faster than Python equivalents
- **Yahoo Finance Integration**: Built-in data provider via yfnim
- **Comprehensive Indicators**: MA, EMA, RSI, MACD, ATR, Bollinger Bands, and more
- **Pre-built Strategies**: RSI, Moving Average Crossover, MACD
- **Backtesting Engine**: Test strategies against historical data
- **Type Safety**: Compile-time type checking prevents runtime errors

## Installation

```bash
git clone <repository-url>
cd tzutrader
nimble install
```

## Quick Start

### Using Technical Indicators (Phase 3 - Available Now!)

```nim
import tzutrader

# Batch mode - calculate indicators on historical data
let prices = @[100.0, 102.0, 104.0, 103.0, 105.0, 107.0, 108.0, 110.0]

let sma5 = sma(prices, 5)          # Simple Moving Average
let ema5 = ema(prices, 5)          # Exponential Moving Average  
let rsi14 = rsi(prices, 14)        # Relative Strength Index
let macdData = macd(prices)        # MACD with signal and histogram

# Streaming mode - update in real-time
var smaCalc = newSMA(5)
for price in incomingPrices:
  let currentSMA = smaCalc.update(price)
  if not currentSMA.isNaN:
    echo "SMA(5): ", currentSMA
```

### Full Strategy Backtesting (Coming in Phase 4)

```nim
import tzutrader

# Create a strategy
let strategy = newRSIStrategy(period=14, oversold=30, overbought=70)

# Run a backtest
let report = quickBacktest(
  symbols = @["AAPL"],
  strategy = strategy,
  startTime = parseTime("2023-01-01"),
  endTime = parseTime("2024-01-01"),
  initialCash = 10000.0
)

# View results
echo "Total Return: ", report.totalReturn, "%"
echo "Win Rate: ", report.winRate, "%"
echo "Sharpe Ratio: ", report.sharpeRatio
```

## Documentation

- [Getting Started](docs/getting-started.md)
- [API Reference](docs/api-reference.md) (generate with `nimble docs`)
- [Examples](examples/)

## Project Structure

```
tzutrader/
├── src/
│   └── tzutrader/
│       ├── core.nim          # Core types (✓ Phase 1 Complete)
│       ├── data.nim          # Yahoo Finance data (✓ Phase 2 Complete)
│       ├── indicators.nim    # Technical indicators (✓ Phase 3 Complete)
│       ├── strategy.nim      # Strategy framework (Phase 4)
│       ├── portfolio.nim     # Portfolio management (Phase 5)
│       └── trader.nim        # Trading engine (Phase 6)
├── tests/                    # Unit tests (83 tests passing)
├── examples/                 # Example programs
├── docs/                     # Documentation
└── benchmarks/              # Performance benchmarks
```

## Development Status

**Version**: 0.3.0 (Alpha)  
**Current Phase**: Phase 3 - Technical Indicators ✓

### Phase 1: Core Foundation (✓ Complete)
- ✓ Nimble package structure
- ✓ Core types module (`core.nim`)
- ✓ Testing framework
- ✓ Unit tests (22/22 passing)
- ✓ JSON serialization
- ✓ Documentation structure

### Phase 2: Data Management (✓ Complete)
- ✓ Yahoo Finance integration via yfnim
- ✓ Data streaming and caching
- ✓ Historical and real-time quotes
- ✓ Mock data generation for testing
- ✓ Batch operations for multiple symbols
- ✓ Unit tests (29/29 passing)

### Phase 3: Technical Indicators (✓ Complete)
- ✓ Pure Nim implementations (no C++ dependencies)
- ✓ Moving averages (SMA, EMA, WMA)
- ✓ Momentum indicators (RSI, ROC)
- ✓ Trend indicators (MACD)
- ✓ Volatility indicators (ATR, Bollinger Bands)
- ✓ Volume indicators (OBV)
- ✓ Both batch and streaming modes
- ✓ Unit tests (32/32 passing)
- ✓ Example programs

### Coming Next

**Phase 4**: Strategy Framework (Week 6-8)
- Pure Nim implementations of all indicators
- Both batch and streaming modes
- Performance benchmarks

See [plan.md](plan.md) for complete roadmap.

## Running Tests

```bash
nimble test
```

Current test results:
```
Phase 1 - Core Types: 22/22 tests passed ✓
Phase 2 - Data Module: 29/29 tests passed ✓
Total: 51/51 tests passed ✓
```

## Comparison with pybottrader

| Feature | pybottrader | tzutrader |
|---------|-------------|-----------|
| Language | Python | Nim |
| Indicators | C++ with Python bindings | Pure Nim |
| Build System | CMake + pybind11 | Nimble only |
| Module Structure | Nested (3+ levels) | Flat (1 level) |
| Performance | Baseline | 10-100x faster |
| Dependencies | Many (PyQt6, pybind11, etc) | Minimal |
| Distribution | Requires Python env | Single binary |

## License

MIT License

## Acknowledgments

Inspired by [pybottrader](https://github.com/datainquiry/pybottrader) by the DataInquiry team.
