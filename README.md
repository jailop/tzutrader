# TzuTrader

A high-performance trading library in Nim for **backtesting strategies** and **building live trading bots**. It is a re-write of the Python's [pybottrader](https://github.com/datainquiry/pybottrader) library.

**TzuTrader enables you to:**
- 📊 Backtest algorithmic trading strategies on historical data
- 🤖 Build and deploy live trading bots with the same codebase
- 📈 Analyze performance with comprehensive metrics
- 🔄 Seamlessly transition from backtesting to live trading

## Features

### Core Architecture
- **Streaming-Only Design**: Process data one point at a time with O(1) memory usage
- **Backtest & Live Ready**: Same codebase for backtesting and live trading - test your strategy, then deploy it
- **Real-Time Performance**: Constant memory usage and minimal latency suitable for production bots
- **Type-Safe**: Leverages Nim's strong type system for compile-time safety
- **Zero Dependencies**: Pure Nim implementation (except optional Yahoo Finance data fetching)

### Technical Indicators (26 Total)
- **8 Moving Averages**: SMA, EMA, WMA, TRIMA, DEMA, TEMA, KAMA
- **6 Momentum Oscillators**: RSI, ROC, Stochastic, StochRSI, CMO, MOM
- **5 Trend Indicators**: MACD, ADX, PPO, AROON, Parabolic SAR
- **5 Volatility Measures**: ATR, Bollinger Bands, StdDev, True Range, NATR
- **3 Volume Indicators**: OBV, MFI, Accumulation/Distribution

All indicators use circular buffers for constant memory usage and support historical access.

### Strategy Development
- **16 Pre-Built Strategies**: Comprehensive collection covering all major trading approaches
  - **Mean Reversion** (6): RSI, Bollinger Bands, Stochastic, MFI, CCI, Filtered Mean Reversion
  - **Trend Following** (7): MA Crossover, MACD, KAMA, Aroon, Parabolic SAR, Triple MA, ADX Trend
  - **Volatility** (1): Keltner Channel (breakout/reversion modes)
  - **Hybrid/Combination** (2): Volume Breakout, Dual Momentum
- **Custom Strategy Framework**: Simple API for building your own strategies
- **Multi-Indicator Strategies**: Combine indicators for more sophisticated approaches
- **Position Sizing**: Volatility-adjusted and risk-based position sizing support

### Backtesting & Live Trading
- **Unified API**: Same strategy code works for both backtesting and live trading
- **Comprehensive Performance Metrics**: Returns, Sharpe ratio, max drawdown, win rate, profit factor
- **Transaction Costs**: Configurable commission and slippage modeling for realistic backtests
- **Portfolio Management**: Multi-asset support with position tracking
- **Multi-Symbol Scanning**: Test strategies across multiple assets simultaneously
- **Live Bot Framework**: Deploy strategies as always-on trading bots with minimal modifications

### Data Handling
- **Historical Data**: Load OHLCV data from CSV files for backtesting
- **Live Data Integration**: Works with any data source (broker APIs, websockets, market feeds)
- **Yahoo Finance Integration**: Fetch historical data directly from Yahoo Finance (via yfnim)
- **Flexible Data Structures**: Standard OHLCV bars with timestamps and volume
- **Data Export**: Export backtest results to CSV and JSON for analysis

### Performance
- **Fast Compilation**: Nim compiles to native machine code
- **Low Memory Footprint**: Streaming architecture with fixed-size buffers
- **No GC Pressure**: Minimal allocations during indicator updates
- **Optimized for Speed**: Can be compiled with `-d:release` for production use

### Developer Experience
- **CLI Tool**: Command-line interface for quick backtesting and scanning
- **Comprehensive Documentation**: User guide, reference guide, and API docs
- **16 Working Examples**: From basic indicators to advanced multi-factor strategies
- **Comprehensive Test Suite**: All indicators and strategies thoroughly tested

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

### Building a Live Trading Bot

The same strategy used for backtesting can power a live trading bot:

```nim
import tzutrader

# Create your strategy (same as backtesting)
let strategy = newRSIStrategy(period = 14, oversold = 30, overbought = 70)

# Live trading loop
while true:
  # Fetch latest market data (from broker API, websocket, etc.)
  let currentBar = getCurrentMarketData("AAPL")
  
  # Generate trading signal
  let signal = strategy.onBar(currentBar)
  
  # Execute trades based on signal
  case signal.position
  of Buy:
    if not hasPosition:
      placeOrder("AAPL", OrderType.Market, shares = 100)
      echo "BUY executed at ", signal.price
  of Sell:
    if hasPosition:
      placeOrder("AAPL", OrderType.Market, shares = -100)
      echo "SELL executed at ", signal.price
  of Stay:
    discard
  
  # Wait for next bar (e.g., 1 minute, 5 minutes, etc.)
  sleep(60_000)  # 1 minute
```

**Key Advantages for Live Trading:**
- **O(1) Memory**: Streaming architecture uses constant memory, runs indefinitely
- **Low Latency**: Minimal allocations mean fast signal generation
- **Stateful Indicators**: Maintain state across updates without data arrays
- **Same Code**: Test thoroughly with backtesting, deploy with confidence

## Core Capabilities

### Technical Indicators

TzuTrader uses a **streaming-only architecture** - indicators are updated one data point at a time:

```nim
import tzutrader

# Create indicator instances (streaming, O(1) memory)
var sma = newMA(period = 20)           # Simple Moving Average
var ema = newEMA(period = 20)          # Exponential Moving Average
var wma = newWMA(period = 20)          # Weighted Moving Average
var kama = newKAMA(period = 10)        # Kaufman Adaptive MA
var dema = newDEMA(period = 20)        # Double Exponential MA
var tema = newTEMA(period = 20)        # Triple Exponential MA

# Momentum & Oscillators
var rsi = newRSI(period = 14)          # Relative Strength Index
var stoch = newSTOCH(period = 14)      # Stochastic Oscillator
var stochRsi = newSTOCHRSI(rsiPeriod = 14, period = 14)  # Stochastic RSI
var cmo = newCMO(period = 14)          # Chande Momentum Oscillator
var mom = newMOM(period = 10)          # Momentum (absolute change)
var roc = newROC(period = 10)          # Rate of Change (percentage)

# Trend Indicators
var macd = newMACD(fast = 12, slow = 26, signal = 9)  # MACD
var ppo = newPPO(fast = 12, slow = 26, signal = 9)    # Percentage Price Oscillator
var adx = newADX(period = 14)          # ADX System
var aroon = newAROON(period = 25)      # AROON Oscillator

# Volatility
var bb = newBollingerBands(period = 20, stdDev = 2.0)  # Bollinger Bands
var atr = newATR(period = 14)          # Average True Range
var natr = newNATR(period = 14)        # Normalized ATR
var tr = newTRANGE()                   # True Range

# Volume
var obv = newOBV()                     # On-Balance Volume
var mfi = newMFI(period = 14)          # Money Flow Index
var ad = newAD()                       # Accumulation/Distribution

# Update indicators as new data arrives (streaming)
for bar in dataStream:
  let smaVal = sma.update(bar.close)
  let rsiVal = rsi.update(bar.open, bar.close)
  let stochVal = stoch.update(bar.high, bar.low, bar.close)
  let macdVal = macd.update(bar.close)
  let atrVal = atr.update(bar.high, bar.low, bar.close)
  
  # Returns NaN until enough data collected
  if not smaVal.isNaN:
    echo "SMA: ", smaVal
```

**25 Indicators Available:**
- **Moving Averages (8):** SMA, EMA, WMA, TRIMA, DEMA, TEMA, KAMA
- **Momentum (6):** RSI, ROC, Stochastic, StochRSI, CMO, MOM
- **Trend (4):** MACD, ADX (+DI/-DI), PPO, AROON
- **Volatility (5):** ATR, Bollinger Bands, StdDev, True Range, NATR
- **Volume (3):** OBV, MFI, Accumulation/Distribution

### Advanced Strategy Examples

TzuTrader's comprehensive indicator library enables sophisticated multi-factor strategies:

```nim
# Example 1: Trend Strength Filter with Adaptive Entry
# Uses KAMA for trend, StochRSI for timing, ADX for strength
type TrendStrengthStrategy = ref object of Strategy
  kama: KAMA
  stochRsi: STOCHRSI
  adx: ADX
  inPosition: bool

proc newTrendStrengthStrategy*(): TrendStrengthStrategy =
  result = TrendStrengthStrategy(
    kama: newKAMA(period = 10),
    stochRsi: newSTOCHRSI(rsiPeriod = 14, period = 14),
    adx: newADX(period = 14),
    inPosition: false
  )

method onBar*(self: TrendStrengthStrategy, bar: OHLCV): Signal =
  let kamaVal = self.kama.update(bar.close)
  let stochRsiVal = self.stochRsi.update(bar.open, bar.close)
  let adxVal = self.adx.update(bar.high, bar.low, bar.close)
  
  # Only trade in strong trends (ADX > 25) with good timing
  if not self.inPosition and adxVal.adx > 25.0:
    if bar.close > kamaVal and stochRsiVal.k < 20.0:  # Oversold in uptrend
      self.inPosition = true
      return Signal(position: Buy, price: bar.close, timestamp: bar.timestamp)
  
  elif self.inPosition:
    if stochRsiVal.k > 80.0 or bar.close < kamaVal:  # Exit on overbought or trend break
      self.inPosition = false
      return Signal(position: Sell, price: bar.close, timestamp: bar.timestamp)
  
  return Signal(position: Stay)

# Example 2: Multi-Asset Momentum Rotation
# Uses PPO for normalized comparison, AROON for trend confirmation
type MomentumRotationStrategy = ref object of Strategy
  ppoIndicators: Table[string, PPO]
  aroonIndicators: Table[string, AROON]
  symbols: seq[string]
  currentHolding: string

proc selectStrongest(self: MomentumRotationStrategy): string =
  var maxPPO = -Inf
  var strongest = ""
  
  for symbol in self.symbols:
    let ppoVal = self.ppoIndicators[symbol][0]
    let aroonVal = self.aroonIndicators[symbol][0]
    
    # Only consider assets in confirmed uptrends
    if aroonVal.up > 70.0 and ppoVal.ppo > maxPPO:
      maxPPO = ppoVal.ppo
      strongest = symbol
  
  return strongest

# Example 3: Volatility-Adjusted Position Sizing
# Uses NATR for normalized volatility measurement
type VolatilityAdjustedStrategy = ref object of Strategy
  rsi: RSI
  natr: NATR
  basePosition: float64

proc calculatePositionSize*(self: VolatilityAdjustedStrategy, price: float64): float64 =
  let natrVal = self.natr[0]  # Normalized ATR as percentage
  
  # Lower position size in high volatility, higher in low volatility
  # Target 2% account risk per trade
  if natrVal > 0:
    let riskMultiplier = 2.0 / natrVal  # Inverse relationship
    return self.basePosition * riskMultiplier
  
  return self.basePosition

# Example 4: Momentum Divergence Detection
# Uses MOM for divergence, CMO for confirmation
type DivergenceStrategy = ref object of Strategy
  mom: MOM
  cmo: CMO
  prices: seq[float64]
  momValues: seq[float64]

method onBar*(self: DivergenceStrategy, bar: OHLCV): Signal =
  let momVal = self.mom.update(bar.close)
  let cmoVal = self.cmo.update(bar.close)
  
  self.prices.add(bar.close)
  self.momValues.add(momVal)
  
  if self.prices.len >= 20:
    # Detect bearish divergence: price making higher highs, momentum making lower highs
    let recentPriceHigh = max(self.prices[^10..^1])
    let previousPriceHigh = max(self.prices[^20..^11])
    let recentMomHigh = max(self.momValues[^10..^1])
    let previousMomHigh = max(self.momValues[^20..^11])
    
    if recentPriceHigh > previousPriceHigh and recentMomHigh < previousMomHigh:
      # Bearish divergence confirmed by CMO below zero
      if cmoVal < 0:
        return Signal(position: Sell, price: bar.close, timestamp: bar.timestamp)
  
  return Signal(position: Stay)
```

See `examples/` directory for complete working implementations of these advanced strategies.

### Pre-Built Strategies

TzuTrader includes 16 professional-grade strategies covering all major trading approaches:

**Mean Reversion Strategies:**
```nim
# RSI Strategy - Classic overbought/oversold
let rsi = newRSIStrategy(period = 14, oversold = 30, overbought = 70)

# Bollinger Bands - Volatility mean reversion
let bb = newBollingerStrategy(period = 20, stdDev = 2.0)

# Stochastic - %K/%D crossovers in extreme zones
let stoch = newStochasticStrategy(kPeriod = 14, dPeriod = 3, oversold = 20, overbought = 80)

# Money Flow Index - Volume-weighted momentum
let mfi = newMFIStrategy(period = 14, oversold = 20, overbought = 80)

# Commodity Channel Index - Mean reversion with volatility
let cci = newCCIStrategy(period = 20)

# Filtered Mean Reversion - RSI with trend filter
let filtered = newFilteredMeanReversionStrategy(rsiPeriod = 14, trendPeriod = 200)
```

**Trend Following Strategies:**
```nim
# Moving Average Crossover - Classic golden/death cross
let crossover = newCrossoverStrategy(fastPeriod = 50, slowPeriod = 200)

# MACD Strategy - Momentum shifts
let macdStrat = newMACDStrategy(fast = 12, slow = 26, signal = 9)

# KAMA - Adaptive moving average
let kama = newKAMAStrategy(period = 10, fastPeriod = 2, slowPeriod = 30)

# Aroon - Trend strength and direction
let aroon = newAroonStrategy(period = 25, upThreshold = 70, downThreshold = 30)

# Parabolic SAR - Dynamic trailing stops
let psar = newParabolicSARStrategy(acceleration = 0.02, maximum = 0.20)

# Triple MA - Three moving average confirmation
let tripleMa = newTripleMAStrategy(fastPeriod = 20, mediumPeriod = 50, slowPeriod = 200)

# ADX Trend - Strength-filtered trend following
let adxTrend = newADXTrendStrategy(period = 14, adxThreshold = 25.0)
```

**Volatility Strategies:**
```nim
# Keltner Channel - Breakout or reversion (dual mode)
let keltnerBreakout = newKeltnerChannelStrategy(emaPeriod = 20, atrPeriod = 10, multiplier = 2.0, mode = Breakout)
let keltnerReversion = newKeltnerChannelStrategy(emaPeriod = 20, atrPeriod = 10, multiplier = 2.0, mode = Reversion)
```

**Hybrid/Combination Strategies:**
```nim
# Volume Breakout - Price breakout with volume confirmation
let volBreakout = newVolumeBreakoutStrategy(period = 20, volumeMultiplier = 1.5)

# Dual Momentum - ROC momentum with trend confirmation
let dualMom = newDualMomentumStrategy(rocPeriod = 12, smaPeriod = 50)
```

### Custom Strategies

```nim
import tzutrader

type
  MyStrategy = ref object of Strategy
    ma: MA
    period: int

proc newMyStrategy*(period: int = 20): MyStrategy =
  result = MyStrategy(
    ma: newMA(period),
    period: period
  )

method onBar*(self: MyStrategy, bar: OHLCV): Signal =
  # Your strategy logic here
  let maVal = self.ma.update(bar.close)
  
  # Wait for indicator warmup
  if maVal.isNaN:
    return Signal(position: Stay)
  
  if bar.close > maVal * 1.02:
    return Signal(position: Buy, price: bar.close, timestamp: bar.timestamp)
  elif bar.close < maVal * 0.98:
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
- Calculating technical indicators (all 25 indicators)
- Using pre-built strategies
- Creating custom strategies with advanced indicators
- **Advanced strategies:** Trend strength filters, momentum rotation, volatility-adjusted sizing, divergence detection
- Running backtests with different configurations
- Multi-symbol scanning
- Exporting results

Run examples:
```bash
nimble examples          # Compile all examples
./examples/backtest_example
./examples/rsi_strategy_example
./examples/scanner_example
./examples/advanced_strategies_example  # Advanced multi-indicator strategies
```

## Use Cases

### 1. Strategy Backtesting
Test your trading ideas on historical data before risking real capital:
- Load years of historical price data
- Simulate realistic trading with commissions and slippage
- Analyze comprehensive performance metrics
- Optimize strategy parameters

### 2. Live Trading Bots
Deploy automated trading bots that run 24/7:
- Same strategy code as backtesting (no rewrite needed)
- Streaming architecture minimizes memory and latency
- Connect to any broker API or market data feed
- Monitor and log trades in real-time

### 3. Research & Analysis
Explore trading ideas and market behavior:
- 25 technical indicators at your disposal
- Multi-asset scanning and comparison
- Statistical analysis of strategy performance
- Export results for further analysis

### 4. Education & Learning
Learn algorithmic trading with working examples:
- 13 complete example programs
- From basic indicators to advanced strategies
- Understand indicator calculations with documented formulas
- Build your own strategies step-by-step

## Why TzuTrader?

**For Backtesting:**
- ✅ Comprehensive indicator library (25 indicators)
- ✅ Realistic transaction cost modeling
- ✅ Detailed performance analytics
- ✅ Fast execution for large datasets

**For Live Trading:**
- ✅ O(1) memory usage - runs indefinitely
- ✅ Low latency indicator updates
- ✅ Proven in backtesting before going live
- ✅ Native compiled code for performance

**For Development:**
- ✅ Type-safe Nim language prevents bugs
- ✅ Same codebase for backtest and live
- ✅ Extensive documentation and examples
- ✅ Comprehensive test suite

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
