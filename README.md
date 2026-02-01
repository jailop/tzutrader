# TzuTrader

A high-performance Nim library for **backtesting trading strategies** and **building live trading bots**. Rewrite of Python's [pybottrader](https://github.com/datainquiry/pybottrader).

[Documentation](https://jailop.codeberg.page/tzutrader/docs/)

**Key Features:**

- Backtest strategies on historical data
- Implement strategies using Nim or using a declarative format in yaml
  files.
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
# Quick backtest with Yahoo Finance data
tzu --run-strat=rsi --symbol=AAPL --start=2023-01-01

# Using short options (-r for run-strat, -s for symbol, -e for endDate)
tzu -r rsi -s AAPL --start=2023-01-01 -e 2023-12-31

# With custom strategy parameters
tzu --run-strat=macd -s AAPL --start=2023-01-01 --fast=10 --slow=20 --signal=5

# Using CSV file (no --start required)
tzu --run-strat=bollinger --csvFile=data/AAPL.csv

# Multiple custom parameters
tzu -r rsi -s MSFT --start=2024-01-01 -p 10 -o 25 --overbought=75

# Available strategies
tzu --help
```

**Common Options:**
- `-r`, `--run-strat=STRATEGY` - Strategy to backtest (required)
- `-s`, `--symbol=SYMBOL` - Symbol for Yahoo Finance data
- `--start=YYYY-MM-DD` - Start date (required for Yahoo Finance)
- `-e`, `--endDate=YYYY-MM-DD` - End date (optional, defaults to today)
- `-c`, `--csvFile=FILE` - Use CSV file instead of Yahoo Finance
- `-p`, `--period=N` - Period for indicators (default varies by strategy)
- `-i`, `--initialCash=N` - Starting capital (default: 100000.0)
- `--commission=N` - Commission rate (default: 0.0)

**Note:** `--start` has no short option to avoid conflicts. Use the full `--start=` form.

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

## ⚠️ Disclaimer

**This software is provided for educational and research purposes
only.**

- **No Financial Advice**: TzuTrader does not provide financial,
  investment, trading, or any other type of professional advice. Any
  strategies, indicators, or results shown are for informational
  purposes only.
- **No Liability**: The authors and contributors are not responsible for
  any financial losses, damages, or other consequences resulting from
  the use of this library.
- **Trading Risks**: Trading financial instruments involves substantial
  risk of loss. Past performance does not guarantee future results.
- **Use at Your Own Risk**: Users are solely responsible for their
  trading decisions and should consult with qualified financial
  professionals before making any investment decisions.

By using TzuTrader, you acknowledge that you understand these risks and
accept full responsibility for your actions.


