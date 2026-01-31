# TzuTrader

A high-performance Nim library for **backtesting trading strategies** and **building live trading bots**. Rewrite of Python's [pybottrader](https://github.com/datainquiry/pybottrader).

[Documentation](https://jailop.codeberg.page/tzutrader/docs/)

**Key Features:**
- Backtest strategies on historical data
- Build live trading bots with the same code
- Technical indicators with O(1) memory
- Pre-built strategies (mean reversion, trend following, hybrid)
- Fast, type-safe, streaming architecture

## Quick Start

### Installation

```bash
git clone https://codeberg.org/jailop/tzutrader.git
cd tzutrader
nimble install -y   # Installs library + tzu CLI command
```

**Requirements:** Nim 2.0.0+

### CLI Tool

After installation, the `tzu` command is available globally:

```bash
# Quick backtest
tzu rsi -s AAPL --start=2023-01-01

# Get help
tzu --help
tzu rsi --help
```

**Development workflow:**
```bash
nimble build   # Build ./tzu in current directory
nimble install # Install library and CLI globally
```

### Library Example

```nim
import tzutrader

# Load data and create strategy
let data = readCSV("data/AAPL.csv")
let strategy = newRSIStrategy(period = 14, oversold = 30, overbought = 70)

# Run backtest
let report = quickBacktest(
  symbol = "AAPL",
  strategy = strategy,
  data = data,
  initialCash = 100000.0,
  commission = 0.001
)

echo report.summary()
```

**Output:**
```
Backtest Report: AAPL
Total Return:     23.45%
Sharpe Ratio:     1.87
Max Drawdown:     -8.23%
Win Rate:         58.33%
```

## Documentation

- **[User Guide](docs/user_guide/)** - Concepts and tutorials
- **[Reference Guide](docs/reference_guide/)** - Technical specifications
- **[API Documentation](docs/api/)** - Complete API reference (`nimble docs`)

**Quick Links:**

- [Getting Started](docs/user_guide/01_getting_started.md)
- [Technical Indicators](docs/reference_guide/03_indicators.md)
- [Strategy Development](docs/user_guide/04_strategies.md)
- [CLI Reference](docs/reference_guide/09_cli.md)


