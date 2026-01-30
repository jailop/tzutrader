# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.6.0] - 2026-01-30

### Added - Phase 6: Trading Engine & Backtesting ✓

#### Trader Module (`src/tzutrader/trader.nim`)
- **Core Types**
  - `BacktestReport` - Comprehensive performance report with 20+ metrics
    - Symbol, start/end time, initial/final values
    - Total and annualized returns
    - Sharpe ratio, max drawdown, drawdown duration
    - Win rate, profit factor, trade statistics
    - Best/worst trades, average returns
    - Total commission tracking
  - `TradeLog` - Individual trade event logging
    - Timestamp, symbol, action, quantity, price
    - Cash and equity snapshots
  - `Backtester` - Main backtesting engine
    - Strategy integration
    - Portfolio management
    - Trade execution and logging
    - Equity curve tracking

- **Backtesting Operations**
  - `newBacktester()` - Create backtester with strategy
  - `run()` - Execute backtest on historical data
  - `executeSignal()` - Convert strategy signals to portfolio orders
  - Automatic position sizing (95% of available cash)
  - Final position auto-close at end of backtest

- **Convenience API**
  - `quickBacktest()` - Simple backtest function
  - `quickBacktestCSV()` - Backtest directly from CSV file
  - Single-function backtesting for rapid testing

- **Performance Analytics**
  - Annualized return calculation with compound growth
  - Sharpe ratio from transaction-based returns
  - Max drawdown tracked through equity curve
  - Win rate and profit factor calculations
  - Best/worst trade tracking
  - Average win/loss statistics

- **Report Formatting**
  - Detailed multi-line report with `$` operator
  - Compact one-line summary with `formatCompact()`
  - Human-readable performance metrics

#### Tests (`tests/test_trader.nim`)
- 30 comprehensive unit tests covering:
  - Backtester construction (3 tests)
  - Backtest execution (5 tests)
  - Signal execution (2 tests)
  - Commission handling (1 test)
  - Report generation (4 tests)
  - Convenience API (2 tests)
  - Performance metrics (4 tests)
  - Trade logging (2 tests)
  - Strategy integration with RSI, Crossover, MACD, Bollinger (4 tests)
  - Edge cases (2 tests)

#### Examples
- `examples/backtest_example.nim` - Comprehensive backtesting demonstration
  - Quick backtest with RSI strategy
  - Full backtest with MA crossover
  - Multi-strategy comparison (6 strategies)
  - CSV-based backtesting
  - Performance metrics analysis
  - Trade log examination
  - Strategy comparison tables

#### Documentation
- Trader module fully documented
- Backtesting workflow explained
- Performance metrics definitions
- Report format documentation

### Changed
- Updated main module to export trader module
- Version bumped to 0.6.0
- Test suite now includes trader tests (180 total tests)
- Nimble file updated with trader tasks and examples
- README updated with backtesting examples

### Features
- **Signal Execution Logic**
  - Buy signals: Calculate quantity from available cash
  - Sell signals: Close entire position
  - Stay signals: No action
  - All trades logged with full context

- **Position Sizing**
  - Uses 95% of available cash per trade (5% buffer)
  - Floor quantity to avoid fractional shares
  - Automatic quantity calculation

- **Performance Metrics**
  - 20+ comprehensive metrics in BacktestReport
  - Equity curve for drawdown analysis
  - Transaction-based return calculations
  - Risk-adjusted performance measures

### Integration
- Works seamlessly with Phase 4 strategies
- Uses Phase 5 portfolio for trade execution
- Integrates with Phase 2 CSV data
- Generates comprehensive performance reports

## [0.5.0] - 2026-01-30

### Added - Phase 5: Portfolio Management ✓

#### Portfolio Module (`src/tzutrader/portfolio.nim`)
- **Core Types**
  - `PositionSide` enum - Long, Short, Flat position types
  - `PositionInfo` - Position tracking with P&L calculation
    - Symbol, side, quantity, entry price/time
    - Current price and unrealized P&L
    - Realized P&L from partial closes
  - `Portfolio` - Main portfolio management class
    - Cash and position tracking
    - Commission support (rate + minimum)
    - Transaction history
    - Total realized P&L tracking
  - `PerformanceMetrics` - Comprehensive performance analytics
    - Total and annualized returns
    - Sharpe ratio, max drawdown
    - Win rate, profit factor
    - Trade statistics (wins, losses, averages)

- **Portfolio Operations**
  - `newPortfolio()` - Create portfolio with initial cash
  - `buy()` - Execute buy orders with commission
  - `sell()` - Execute sell orders (full or partial)
  - `closePosition()` - Close entire position
  - `hasPosition()` - Check for open positions
  - `getPosition()` - Query position details
  - `updatePrices()` - Update all positions with market prices

- **Valuation & Analytics**
  - `equity()` - Total portfolio value (cash + positions)
  - `marketValue()` - Total market value of positions
  - `unrealizedPnL()` - Unrealized profit/loss
  - `realizedPnL()` - Realized profit/loss
  - `totalPnL()` - Combined P&L
  - `calculatePerformance()` - Full performance metrics
  - Commission calculation with min/max support

- **Position Management**
  - Average entry price calculation for multiple buys
  - Automatic P&L tracking (realized + unrealized)
  - Position lifecycle management (open/partial/close)
  - Market value and P&L updates

#### Tests (`tests/test_portfolio.nim`)
- 39 comprehensive unit tests covering:
  - Portfolio construction (3 tests)
  - Position management (10 tests)
  - Commission calculations (4 tests)
  - Valuation and P&L (6 tests)
  - Transaction history (3 tests)
  - Performance metrics (5 tests)
  - Position updates (2 tests)
  - Edge cases (4 tests)
  - String representations (3 tests)

#### Examples
- `examples/portfolio_example.nim` - Comprehensive portfolio demonstration
  - Basic operations (create, buy, sell)
  - Price updates and P&L tracking
  - Position closing
  - Transaction history
  - Performance metrics
  - Commission handling
  - Simulated trading strategy

#### Documentation
- Portfolio module fully documented
- Performance metrics explained
- Commission structure documented

### Changed
- Updated main module to export portfolio
- Version bumped to 0.5.0
- Test suite now includes portfolio tests (151 total tests)
- Nimble file updated with portfolio tasks

### Fixed
- Realized P&L now correctly tracked when positions fully close
- Portfolio total realized P&L properly accumulated

## [0.4.0] - 2026-01-30

### Added - Phase 4: Strategy Framework ✓

#### Strategy Module (`src/tzutrader/strategy.nim`)
- **Base Strategy Class**
  - `Strategy` base type with virtual methods
  - `analyze()` - Batch mode processing for historical data
  - `onBar()` - Streaming mode for real-time processing
  - `reset()` - Clear internal state for reuse
  - Protected `history` field for bar storage

- **Pre-built Strategies**
  - `RSIStrategy` - Relative Strength Index strategy
    - Buy when RSI < oversold threshold
    - Sell when RSI > overbought threshold
    - Configurable period, oversold, overbought parameters
    - `newRSIStrategy()` constructor
  - `CrossoverStrategy` - Moving Average Crossover
    - Buy on golden cross (fast MA crosses above slow MA)
    - Sell on death cross (fast MA crosses below slow MA)
    - Configurable fast and slow periods
    - `newCrossoverStrategy()` constructor
  - `MACDStrategy` - MACD Line Crossover
    - Buy when MACD line crosses above signal line
    - Sell when MACD line crosses below signal line
    - Configurable fast, slow, signal periods
    - `newMACDStrategy()` constructor
  - `BollingerStrategy` - Bollinger Bands Mean Reversion
    - Buy when price touches lower band
    - Sell when price touches upper band
    - Configurable period and standard deviation
    - `newBollingerStrategy()` constructor

#### Features
- **Dual API**: All strategies support both batch and streaming modes
- **Consistent Interface**: All strategies inherit from base `Strategy` class
- **Signal Generation**: Returns `Signal` objects with position, timestamp, and price
- **Stateful Processing**: Maintains internal state for streaming mode
- **Reset Capability**: All strategies can be reset for reuse
- **Type Safety**: Compile-time polymorphism via method dispatch

#### Testing
- Comprehensive test suite (27 tests, all passing)
- Tests for all 4 strategies in batch and streaming modes
- Signal generation validation
- Reset functionality tests
- Batch vs streaming consistency tests
- Multi-strategy comparison tests
- Real CSV data integration tests
- `tests/test_strategy.nim` with full coverage

#### Examples
- `examples/strategy_example.nim` - Complete demonstration
- Batch mode analysis on historical data
- Streaming mode for real-time simulation
- Multi-strategy comparison
- Multi-symbol analysis
- Parameter tuning examples
- CSV data integration

#### Documentation
- Full API documentation in module comments
- Usage examples for each strategy
- Strategy design patterns
- Batch vs streaming mode guidelines

### Design Decisions
- Base class with virtual methods for extensibility
- Dual API (batch + streaming) for flexibility
- Strategies maintain minimal state (just history)
- Signal objects for clean separation of concerns
- Reset method for strategy reuse across datasets
- Consistent constructor naming (`new*Strategy`)

### Integration
- Works seamlessly with Phase 3 indicators
- Uses Phase 2 CSV data streaming
- Generates Phase 1 Signal objects
- Ready for Phase 5 portfolio integration

## [0.3.0] - 2026-01-30

### Added - Phase 3: Technical Indicators ✓

#### Indicators Module (`src/tzutrader/indicators.nim`)
- **Pure Nim implementations** of all indicators (no C++ dependencies)
- **Dual API**: Batch mode and streaming mode for all indicators
- **Base Types**
  - `IndicatorBase` - Base type for streaming indicators
  - Helper functions for NaN handling and rolling windows
- **Moving Averages**
  - `sma()` / `newSMA()` - Simple Moving Average
  - `ema()` / `newEMA()` - Exponential Moving Average
  - `wma()` - Weighted Moving Average (batch only)
- **Momentum Indicators**
  - `rsi()` / `newRSI()` - Relative Strength Index
  - `roc()` - Rate of Change
- **Trend Indicators**
  - `macd()` / `newMACD()` - Moving Average Convergence Divergence
  - Returns tuple: (macd, signal, histogram)
- **Volatility Indicators**
  - `atr()` / `newATR()` - Average True Range
  - `bollinger()` - Bollinger Bands (returns upper, middle, lower)
  - `stddev()` - Standard Deviation
- **Volume Indicators**
  - `obv()` / `newOBV()` - On-Balance Volume
- **Utilities**
  - `roi()` - Return on Investment calculator

#### Features
- Memory-efficient rolling windows using `Deque`
- Proper NaN handling for insufficient data periods
- Consistent API across all indicators
- Both batch processing and real-time streaming support
- Optimized for performance (pure Nim, no Python overhead)

#### Testing
- Comprehensive unit test suite (32 tests, all passing)
- Tests for all indicators in both batch and streaming modes
- Edge case testing (empty data, flat prices, insufficient periods)
- Integration tests for multi-indicator workflows
- `tests/test_indicators.nim` with full coverage

#### Examples
- `examples/indicators_example.nim` - Complete demonstration
- Batch mode calculations on historical data
- Streaming mode for real-time updates
- Multi-indicator analysis
- Trading signal detection examples
- ROI calculation examples

#### Documentation
- Full API documentation in module comments
- Usage examples for each indicator
- Performance characteristics documented
- Streaming vs batch mode guidelines

### Design Decisions
- Pure Nim implementation eliminates C++ build complexity
- Dual API (batch + streaming) serves both historical and real-time needs
- NaN for insufficient data periods (industry standard)
- Deque-based rolling windows for memory efficiency
- Consistent naming: lowercase for batch, `new*` prefix for streaming constructors

### Performance
- Significantly faster than Python implementations
- Zero-copy operations where possible
- Efficient memory usage with rolling windows
- Optimized for both small and large datasets

## [0.2.0] - 2026-01-30

### Added - Phase 2: Data Management ✓

#### Data Module (`src/tzutrader/data.nim`)
- `Interval` enum for time intervals (1m, 5m, 15m, 30m, 1h, 1d, 1wk, 1mo)
- `DataStream` type for managing symbol data streams
- `Quote` type for real-time market quotes
- Yahoo Finance integration via yfnim (conditional compilation)
- Caching mechanism for historical data
  - `addToCache()`, `getCached()`, `clearCache()`
  - `isCached()` for cache validation
- Mock data generation for testing
  - `generateMockOHLCV()` - Generate realistic OHLCV bars
  - `generateMockQuote()` - Generate mock quotes
- Data fetching API
  - `fetch()` - Get historical data with caching
  - `latest()` - Get most recent bar
  - `getQuote()` - Get current quote
- Batch operations
  - `fetchMultiple()` - Fetch multiple symbols at once
  - `getQuotes()` - Get quotes for multiple symbols
- Iterator interface for streaming data
- Interval utilities
  - `toSeconds()` - Convert interval to seconds
  - `maxHistory()` - Get maximum history duration

#### Testing
- Complete unit test suite for data module (29 tests, all passing)
- Tests for intervals, caching, mock data, fetching, iterators
- String representation tests
- `tests/test_data.nim` with comprehensive coverage

#### Dependencies
- Added yfnim dependency for Yahoo Finance data
- Conditional compilation support (`when defined(useYfnim)`)
- Falls back to mock data when yfnim not available

### Design Decisions
- Mock data generator allows testing without network calls
- Caching reduces API calls and improves performance
- Conditional compilation for yfnim allows gradual integration
- All time intervals match Yahoo Finance API
- Batch operations for efficient multi-symbol fetching

## [0.1.0] - 2026-01-30

### Added - Phase 1: Core Foundation

#### Core Module (`src/tzutrader/core.nim`)
- `Position` enum (Stay, Buy, Sell)
- `OHLCV` data structure for market data
- `Signal` type for trading signals
- `StrategyConfig` for strategy parameters
- `Transaction` type for trade records
- Error types: `TzuTraderError`, `DataError`, `StrategyError`, `PortfolioError`
- Helper functions: `newSignal`, `newStrategyConfig`, `newTransaction`
- OHLCV validation and utility functions:
  - `isValid()` - Validate OHLCV data
  - `typicalPrice()` - Calculate typical price
  - `trueRange()` - Calculate true range for ATR
  - `change()` - Price change
  - `changePercent()` - Percentage change
- String representations for all types
- JSON serialization/deserialization for all types

#### Testing
- Complete unit test suite for core types (22 tests, all passing)
- Tests for validation, calculations, and serialization
- `tests/test_core.nim` with comprehensive coverage

#### Project Structure
- Nimble package configuration (`tzutrader.nimble`)
- Main module file (`src/tzutrader.nim`)
- Directory structure for tests, examples, docs, benchmarks
- README with project overview and quick start
- Getting Started documentation
- MIT License

#### Build System
- Nimble tasks for testing, documentation, and benchmarks
- Clean compilation without warnings
- Support for Nim >= 2.0.0

### Design Decisions
- Pure Nim implementation (no C++ dependencies)
- Flat module architecture for ease of use
- Unix timestamps (int64) for all time representations
- Float64 for all price/quantity data
- Comprehensive error types for better error handling

### Performance
- All core operations are zero-copy where possible
- Efficient string formatting
- Minimal allocations in hot paths

## Future Releases

### [0.7.0] - Phase 7: Utilities & Tools (Optional)
- Multi-symbol scanners
- Advanced reporting (JSON/CSV export)
- CLI tool
- Live trading mode

### [1.0.0] - Production Release
- Complete feature set
- Stable API
- Performance optimizations
- Comprehensive documentation

[Unreleased]: https://github.com/yourusername/tzutrader/compare/v0.6.0...HEAD
[0.6.0]: https://github.com/yourusername/tzutrader/releases/tag/v0.6.0
[0.5.0]: https://github.com/yourusername/tzutrader/releases/tag/v0.5.0
[0.4.0]: https://github.com/yourusername/tzutrader/releases/tag/v0.4.0
[0.3.0]: https://github.com/yourusername/tzutrader/releases/tag/v0.3.0
[0.2.0]: https://github.com/yourusername/tzutrader/releases/tag/v0.2.0
[0.1.0]: https://github.com/yourusername/tzutrader/releases/tag/v0.1.0
