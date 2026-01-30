# TzuTrader Documentation

TzuTrader is a trading bot library for Nim that provides tools for building and testing algorithmic trading strategies.

## Documentation Structure

TzuTrader provides three types of documentation, each serving a different purpose:

### 1. User Guide (Start Here!)

The **User Guide** helps you understand concepts and use the library effectively. Written for retail traders with programming experience, it emphasizes understanding over exhaustive coverage.

**Chapters:**
1. [Getting Started](user_guide/01_getting_started.md) - Install TzuTrader and run your first backtest
2. [Working with Market Data](user_guide/02_data.md) - Understanding OHLCV data and CSV format
3. [Understanding Technical Indicators](user_guide/03_indicators.md) - What indicators measure and when to use them
4. [Building Trading Strategies](user_guide/04_strategies.md) - Using pre-built strategies and creating custom ones
5. [Managing Your Portfolio](user_guide/05_portfolio.md) - Capital allocation, position sizing, and performance tracking
6. [Running Backtests](user_guide/06_backtesting.md) - Testing strategies and interpreting results
7. [Comparing Strategies](user_guide/07_scanning.md) - Scanning multiple symbols and ranking results
8. [Advanced Workflows](user_guide/08_workflows.md) - Parameter optimization and batch processing
9. [Best Practices](user_guide/09_best_practices.md) - Testing methodology and risk management

### 2. Reference Guide

The **Reference Guide** provides complete specifications for all features, functions, and parameters. Use this when you need detailed technical information.

**Chapters:**
1. [Core Concepts](reference_guide/01_core.md) - OHLCV, signals, positions, and transactions
2. [Data Management](reference_guide/02_data.md) - CSV I/O, data streaming, and validation
3. [Technical Indicators](reference_guide/03_indicators.md) - Complete indicator reference with parameters
4. [Trading Strategies](reference_guide/04_strategies.md) - Strategy API and pre-built strategy specifications
5. [Portfolio Management](reference_guide/05_portfolio.md) - Portfolio API and performance metrics
6. [Backtesting Engine](reference_guide/06_backtesting.md) - Backtest configuration and report fields
7. [Multi-Symbol Scanning](reference_guide/07_scanning.md) - Scanner API, ranking, and filtering
8. [Export Capabilities](reference_guide/08_exports.md) - JSON and CSV export formats
9. [CLI Tool](reference_guide/09_cli.md) - Command-line interface complete reference

### 3. API Documentation

The **API Documentation** is auto-generated from source code comments. It provides detailed information about every function, type, and module.

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

- **How do I...?** → Check the User Guide
- **What parameters does X take?** → Check the Reference Guide
- **What functions are available?** → Check the API Documentation

### Common Tasks

- [Load historical data from CSV](user_guide/02_data.md#loading-data-from-csv)
- [Generate test data](user_guide/02_data.md#generating-test-data)
- [Calculate technical indicators](user_guide/03_indicators.md)
- [Create a custom strategy](user_guide/04_strategies.md)
- [Run a backtest](user_guide/06_backtesting.md#setting-up-a-backtest)
- [Compare strategies across symbols](user_guide/07_scanning.md)
- [Export results to JSON/CSV](reference_guide/08_exports.md)
- [Use the CLI tool](reference_guide/09_cli.md)

## Library Overview

### Core Modules

- **core** - Fundamental types (OHLCV, Signal, Transaction)
- **data** - Historical data loading and streaming
- **indicators** - Technical indicators (RSI, MACD, moving averages, etc.)
- **strategy** - Strategy framework and pre-built strategies
- **portfolio** - Portfolio management and performance tracking
- **trader** - Backtesting engine
- **scanner** - Multi-symbol scanning and ranking
- **exports** - JSON and CSV export functionality

### Available Strategies

- **RSI Strategy** - Buys when oversold, sells when overbought
- **Moving Average Crossover** - Golden cross and death cross signals
- **MACD Strategy** - MACD line crossover signals
- **Bollinger Bands Strategy** - Mean reversion at bands

### Performance Metrics

TzuTrader calculates comprehensive performance metrics:

- Total and annualized returns
- Sharpe ratio (risk-adjusted returns)
- Maximum drawdown
- Win rate and profit factor
- Average win/loss amounts
- Number of trades
- Equity curve tracking

## Installation

```bash
git clone https://codeberg.org/jailop/tzutrader.git
cd tzutrader
nimble install -y
```

**Requirements:** Nim 2.0.0 or later

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

## CLI Tool

TzuTrader includes a command-line tool for backtesting without writing code:

```bash
# Build the CLI
nimble cli

# Run a backtest
./tzutrader_cli backtest data/AAPL.csv --strategy=rsi

# Scan multiple symbols
./tzutrader_cli scan data/ AAPL,MSFT,GOOG --strategy=macd --rank-by=sharpe

# Export results
./tzutrader_cli backtest data/AAPL.csv --strategy=rsi --export=results.json
```

See the [CLI Reference](reference_guide/09_cli.md) for complete documentation.

## Getting Help

### Documentation Issues

If you find errors or unclear explanations in the documentation:

1. Check if there's an updated version
2. Review the examples directory for working code
3. Consult the API documentation for technical details

### Code Issues

If you encounter bugs or unexpected behavior:

1. Verify your data format matches the CSV requirements
2. Check that Nim version is 2.0.0 or later
3. Run `nimble test` to ensure the library is working correctly
4. Review the relevant User Guide chapter

## Contributing

Contributions are welcome. When contributing documentation:

- Follow the professional, modest tone of existing docs
- Avoid buzzwords and superlatives
- Provide working code examples
- Explain the "why" not just the "how"
- Target retail traders with coding abilities

## Project Status

**Current Version:** 0.7.0

TzuTrader is in active development. All core features are complete and tested. The library currently focuses on backtesting; live trading infrastructure is not included.

## License

MIT License - see LICENSE file for details

## Acknowledgments

Inspired by [pybottrader](https://github.com/datainquiry/pybottrader) from the DataInquiry team.

## Limitations

TzuTrader is designed specifically for price-based technical analysis using OHLCV (Open, High, Low, Close, Volume) data. All indicators and strategies in the library operate on this standardized market data format.

**Current scope:**
- Technical indicators calculate from OHLCV bars
- Pre-built strategies generate signals from price and volume patterns
- Backtesting simulates trading based on historical OHLCV data

**Not currently supported:**
- Order book data and market microstructure analysis
- Level 2 data or bid-ask spreads
- Alternative data sources (news sentiment, social media, economic indicators)
- Cross-asset correlation strategies requiring synchronized multi-market data
- Tick-level or sub-bar execution modeling

This focused scope allows TzuTrader to maintain its streaming architecture with constant memory usage. For most retail traders working with daily, hourly, or minute bars, OHLCV data provides sufficient information for technical analysis strategies. The library can be extended with custom indicators and strategies that work within this data framework.

## About the Name

TzuTrader takes its name from Sun Tzu (孫子), the ancient Chinese military strategist and author of *The Art of War*. Written around the 5th century BC, this treatise on military strategy has found application far beyond warfare, particularly in business and trading.

Several principles from *The Art of War* apply directly to algorithmic trading:

**"Know the enemy and know yourself; in a hundred battles you will never be in peril."** This translates to understanding both market conditions and your strategy's behavior through rigorous backtesting before risking capital.

**"The general who wins the battle makes many calculations in his temple before the battle is fought."** Systematic backtesting and strategy validation embody this preparation, allowing traders to test ideas thoroughly before deployment.

**"In war, numbers alone confer no advantage."** Similarly in trading, simply having more indicators or complex strategies does not guarantee success. What matters is disciplined execution of well-tested approaches.

**"To secure ourselves against defeat lies in our own hands."** Risk management and position sizing—core features of TzuTrader—are tools traders control directly, protecting capital regardless of market outcomes.

The name reflects the library's emphasis on preparation through backtesting, disciplined strategy development, and systematic decision-making based on tested rules rather than emotion or speculation.

## Next Steps

Ready to start? Head to the [Getting Started Guide](user_guide/01_getting_started.md) and run your first backtest in under 15 minutes.
