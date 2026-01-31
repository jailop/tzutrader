# TzuTrader

A high-performance Nim library for **backtesting trading strategies** and **building live trading bots**. Rewrite of Python's [pybottrader](https://github.com/datainquiry/pybottrader).

**Key Features:**
- 📊 Backtest strategies on historical data
- 🤖 Deploy live trading bots with the same code
- 📈 26 technical indicators with O(1) memory
- 🔄 16 pre-built strategies (mean reversion, trend following, hybrid)
- ⚡ Fast, type-safe, streaming architecture

## Quick Start

### Installation

```bash
git clone https://codeberg.org/jailop/tzutrader.git
cd tzutrader
nimble install -y
```

**Requirements:** Nim 2.0.0+

### CLI Tool (Optional)

```bash
nimble cli   # Creates ./tzu binary

# Quick backtest
./tzu rsi -s AAPL --start=2023-01-01

# Get help
./tzu --help
./tzu rsi --help
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

## Core Features

### Streaming Architecture
- **O(1) Memory**: Constant memory usage, runs indefinitely
- **Live Trading Ready**: Same code for backtesting and production
- **Low Latency**: Minimal allocations, native machine code
- **Type-Safe**: Compile-time safety with Nim's type system

### Technical Indicators (26)
- **Moving Averages (8):** SMA, EMA, WMA, TRIMA, DEMA, TEMA, KAMA
- **Momentum (6):** RSI, ROC, Stochastic, StochRSI, CMO, MOM
- **Trend (5):** MACD, ADX, PPO, AROON, Parabolic SAR
- **Volatility (5):** ATR, Bollinger Bands, StdDev, TRANGE, NATR
- **Volume (3):** OBV, MFI, Accumulation/Distribution

All indicators use circular buffers and support historical value access.

### Pre-Built Strategies (16)

**Mean Reversion:** RSI, Bollinger Bands, Stochastic, MFI, CCI, Filtered Mean Reversion

**Trend Following:** MA Crossover, MACD, KAMA, Aroon, Parabolic SAR, Triple MA, ADX

**Volatility:** Keltner Channel (breakout/reversion modes)

**Hybrid:** Volume Breakout, Dual Momentum

```nim
# Example: RSI Strategy
let rsi = newRSIStrategy(period = 14, oversold = 30, overbought = 70)

# Example: MACD Strategy
let macd = newMACDStrategy(fast = 12, slow = 26, signal = 9)

# Example: Bollinger Bands
let bb = newBollingerStrategy(period = 20, stdDev = 2.0)
```

## CLI Usage

```bash
# Build CLI
nimble cli

# Simple Yahoo Finance backtest (default)
./tzu rsi -s AAPL --start=2023-01-01
./tzu macd -s BTC-USD --start=2024-01-01

# Custom parameters
./tzu rsi -s TSLA --start=2023-01-01 --period=10 --oversold=25

# Portfolio configuration
./tzu rsi -s AAPL --start=2023-01-01 \
  --initialCash=50000 \
  --commission=0.001 \
  --minCommission=1.0

# CSV file
./tzu rsi --csvFile=data/AAPL.csv

# Coinbase crypto
export COINBASE_API_KEY="your_key"
export COINBASE_SECRET_KEY="your_secret"
./tzu psar --coinbase=ETH-USD --start=2024-01-01

# All 16 strategies available
./tzu --help
```

## Custom Strategy Example

```nim
import tzutrader

type
  MyStrategy = ref object of Strategy
    ma: MA
    rsi: RSI

proc newMyStrategy*(maPeriod: int = 20, rsiPeriod: int = 14): MyStrategy =
  result = MyStrategy(
    ma: newMA(maPeriod),
    rsi: newRSI(rsiPeriod)
  )

method onBar*(self: MyStrategy, bar: OHLCV): Signal =
  let maVal = self.ma.update(bar.close)
  let rsiVal = self.rsi.update(bar.open, bar.close)
  
  if maVal.isNaN or rsiVal.isNaN:
    return Signal(position: Stay)
  
  # Buy when price above MA and RSI oversold
  if bar.close > maVal and rsiVal < 30.0:
    return Signal(position: Buy, price: bar.close, timestamp: bar.timestamp)
  
  # Sell when RSI overbought
  elif rsiVal > 70.0:
    return Signal(position: Sell, price: bar.close, timestamp: bar.timestamp)
  
  return Signal(position: Stay)
```

## Live Trading Bot Example

```nim
import tzutrader

let strategy = newRSIStrategy(period = 14, oversold = 30, overbought = 70)

# Live trading loop
while true:
  let currentBar = getCurrentMarketData("AAPL")  # From your broker API
  let signal = strategy.onBar(currentBar)
  
  case signal.position
  of Buy:
    if not hasPosition:
      placeOrder("AAPL", OrderType.Market, shares = 100)
  of Sell:
    if hasPosition:
      placeOrder("AAPL", OrderType.Market, shares = -100)
  of Stay:
    discard
  
  sleep(60_000)  # Wait for next bar
```

**Advantages:**
- Same strategy code for backtesting and live trading
- O(1) memory - runs indefinitely without memory growth
- Low latency signal generation
- Test thoroughly before deploying

## Multi-Symbol Scanning

```nim
import tzutrader

let scanner = newScanner("data/")
scanner.addStrategy(newRSIStrategy())

for symbol in ["AAPL", "MSFT", "GOOGL", "AMZN", "TSLA"]:
  scanner.addSymbol(symbol)

let results = scanner.run(initialCash = 100000.0, commission = 0.001)

# Export and analyze
exportCsv(results, "scan_results.csv")
for result in scanner.topN(results, 3):
  echo result.symbol, ": ", result.report.totalReturn, "%"
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

## Performance Metrics

All backtests include comprehensive analytics:
- **Returns:** Total, annualized, per-trade
- **Risk:** Sharpe ratio, max drawdown, drawdown duration
- **Trade Stats:** Win rate, profit factor, avg win/loss
- **Portfolio:** Equity curve, transaction history, commission costs

## Testing

```bash
nimble test    # Run full test suite (93 tests)
```

## Examples

```bash
nimble examples   # Compile all examples
./examples/backtest_example
./examples/rsi_strategy_example
./examples/advanced_strategies_example
```

The `examples/` directory demonstrates:
- All 26 indicators
- All 16 pre-built strategies
- Custom strategy development
- Multi-symbol scanning
- CSV data handling
- Live bot patterns

## Why TzuTrader?

**For Backtesting:**
- ✅ 26 technical indicators, 16 strategies
- ✅ Realistic transaction costs (commission, slippage)
- ✅ Comprehensive performance metrics
- ✅ Fast execution on large datasets

**For Live Trading:**
- ✅ O(1) memory - runs indefinitely
- ✅ Low latency updates
- ✅ Test in backtest, deploy with confidence
- ✅ Native compiled code

**For Development:**
- ✅ Type-safe Nim prevents runtime errors
- ✅ Same codebase for backtest and live
- ✅ Extensive documentation and examples
- ✅ Comprehensive test suite

## Limitations

TzuTrader focuses on OHLCV-based technical analysis. Not currently supported:
- Order book / Level 2 data
- News sentiment or alternative data
- Tick-level execution modeling

This focused scope enables the streaming architecture with constant memory usage, suitable for most retail trading strategies.

## About the Name

TzuTrader is named after Sun Tzu (孫子), author of *The Art of War*. Key principles that apply to algorithmic trading:

- **"Know the enemy and know yourself"** - Understand markets and your strategy through rigorous backtesting
- **"The general who wins makes many calculations before battle"** - Systematic validation before deployment
- **"To secure ourselves against defeat lies in our own hands"** - Risk management and position sizing protect capital

The name reflects disciplined strategy development through systematic testing rather than speculation.

## License

MIT

## Links

- **Repository:** https://codeberg.org/jailop/tzutrader
- **Documentation:** [docs/](docs/)
- **Issues:** https://codeberg.org/jailop/tzutrader/issues
