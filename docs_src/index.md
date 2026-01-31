# TzuTrader Documentation

TzuTrader is a trading bot library for Nim that provides tools for
building and testing algorithmic trading strategies.


**This software is not stable yet. Don't use in production. The API is
still evolving**

## Documentation Structure

TzuTrader provides three types of documentation, each serving a
different purpose:

### 1. User Guide (Start Here!)

The **User Guide** helps you understand concepts and use the library
effectively. Written for retail traders with programming experience, it
emphasizes understanding over exhaustive coverage.

**Chapters:**

1. [Getting Started](user_guide/01_getting_started.md) - Install
   TzuTrader and run your first backtest
2. [Working with Market Data](user_guide/02_data.md) - Understanding
   OHLCV data and CSV format
3. [Understanding Technical Indicators](user_guide/03_indicators.md) -
   What indicators measure and when to use them
4. [Building Trading Strategies](user_guide/04_strategies.md) - Using
   pre-built strategies and creating custom ones
5. [Managing Your Portfolio](user_guide/05_portfolio.md) - Capital
   allocation, position sizing, and performance tracking
6. [Running Backtests](user_guide/06_backtesting.md) - Testing
   strategies and interpreting results
7. [Comparing Strategies](user_guide/07_scanning.md) - Scanning multiple
   symbols and ranking results
8. [Advanced Workflows](user_guide/08_workflows.md) - Parameter
   optimization and batch processing
9. [Best Practices](user_guide/09_best_practices.md) - Testing
   methodology and risk management

### 2. Reference Guide

The **Reference Guide** provides complete specifications for all
features, functions, and parameters. Use this when you need detailed
technical information.

**Chapters:**

1. [Core Concepts](reference_guide/01_core.md) - OHLCV, signals,
   positions, and transactions
2. [Data Management](reference_guide/02_data.md) - CSV I/O, data
   streaming, and validation
3. [Technical Indicators](reference_guide/03_indicators.md) - Complete
   indicator reference with parameters
4. [Trading Strategies](reference_guide/04_strategies.md) - Strategy API
   and pre-built strategy specifications
5. [Portfolio Management](reference_guide/05_portfolio.md) - Portfolio
   API and performance metrics
6. [Backtesting Engine](reference_guide/06_backtesting.md) - Backtest
   configuration and report fields
7. [Multi-Symbol Scanning](reference_guide/07_scanning.md) - Scanner
   API, ranking, and filtering
8. [Export Capabilities](reference_guide/08_exports.md) - JSON and CSV
   export formats
9. [CLI Tool](reference_guide/09_cli.md) - Command-line interface
   complete reference

### 3. API Documentation

The **API Documentation** is auto-generated from source code comments.
It provides detailed information about every function, type, and module.

**Browse:** [API Documentation](api/index.html)

**Generate locally:** `nimble docs`

**Modules:**

- [tzutrader](api/tzutrader.html) - Main module (all exports)
- [core](api/core.html) - Core types and data structures
- [data](api/data.html) - Data loading and management
- [indicators](api/indicators.html) - Technical indicators
- [strategy](api/strategy.html) - Strategy framework
- [portfolio](api/portfolio.html) - Portfolio management
- [trader](api/trader.html) - Backtesting engine
- [scanner](api/scanner.html) - Multi-symbol scanning
- [exports](api/exports.html) - Export functionality

## Quick Links

### New to TzuTrader?

1. Read [Getting Started](user_guide/01_getting_started.md)
2. Follow the [first backtest example](user_guide/01_getting_started.md#your-first-backtest)
3. Explore the examples in the repository

### Looking for Specific Information?

- How do I...? → Check the User Guide
- What parameters does X take? → Check the Reference Guide
- What functions are available? → Check the API Documentation

### Common Tasks

- [Load historical data from CSV](user_guide/02_data.md#loading-data-from-csv)
- [Generate test data](user_guide/02_data.md#generating-test-data)
- [Calculate technical indicators](user_guide/03_indicators.md)
- [Create a custom strategy](user_guide/04_strategies.md)
- [Run a backtest](user_guide/06_backtesting.md#setting-up-a-backtest)
- [Compare strategies across symbols](user_guide/07_scanning.md)
- [Export results to JSON/CSV](reference_guide/08_exports.md)
- [Use the CLI tool](reference_guide/09_cli.md)

## Installation

```bash
git clone https://codeberg.org/jailop/tzutrader.git
cd tzutrader
nimble install -y
```

Requirements: Nim 2.0.0 or later

## Quick Example

```nim
import tzutrader

# Load data
let data = readCSV("data/AAPL.csv")

# Create strategy
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

## Limitations

At this moment, TzuTrader only supports price-based technical analysis
using OHLCV (Open, High, Low, Close, Volume) data. All indicators and
strategies in the library operate on this standardized market data
format.

## About the Name

TzuTrader takes its name from Sun Tzu, the ancient Chinese
military strategist and author of *The Art of War*. Written around the
5th century BC, this treatise on military strategy has found application
far beyond warfare, particularly in business.

## ⚠️ Disclaimer

This software is provided for educational and research purposes only.

- No Financial Advice: TzuTrader does not provide financial, investment,
  trading, or any other type of professional advice. Any strategies,
  indicators, or results shown are for informational purposes only.
- No Liability: The authors and contributors are not responsible for any
  financial losses, damages, or other consequences resulting from the
  use of this library.
- Trading Risks: Trading financial instruments involves substantial risk
  of loss. Past performance does not guarantee future results.
  Backtested results do not represent actual trading and may not reflect
  the impact of material market factors such as liquidity, slippage, and
  transaction costs.
- Use at Your Own Risk: Users are solely responsible for their trading
  decisions and should consult with qualified financial professionals
  before making any investment decisions.

By using TzuTrader, you acknowledge that you understand these risks and
accept full responsibility for your actions.

## Next Steps

Ready to start? Head to the [Getting Started
Guide](user_guide/01_getting_started.md) and run your first backtest in
under 15 minutes.
