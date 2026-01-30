# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Phase 4 - Strategy Framework (Next)
- Strategy base class and interface
- Pre-built strategies (RSI, Crossover, MACD, Bollinger)
- Strategy composition support

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

### [0.2.0] - Phase 2: Data Management
- Yahoo Finance data integration
- Data streaming and caching mechanisms
- Support for multiple timeframes

### [0.3.0] - Phase 3: Technical Indicators  
- Pure Nim implementations of 15+ indicators
- Moving averages (SMA, EMA, WMA)
- Momentum indicators (RSI, Stochastic, ROC)
- Trend indicators (MACD, ADX)
- Volatility indicators (ATR, Bollinger Bands)
- Volume indicators (OBV)

### [0.4.0] - Phase 4: Strategy Framework
- Strategy base class and interface
- Pre-built strategies (RSI, Crossover, MACD, Bollinger)
- Strategy composition support

### [0.5.0] - Phase 5: Portfolio Management
- Portfolio tracking and valuation
- Transaction management
- Performance metrics (returns, Sharpe ratio)
- Risk management features

### [0.6.0] - Phase 6: Trading Engine
- Backtesting engine
- Live trading support
- Signal execution
- Performance reporting

### [1.0.0] - Production Release
- Complete feature set
- Stable API
- Performance optimizations
- Comprehensive documentation
- CLI tools

[Unreleased]: https://github.com/yourusername/tzutrader/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/yourusername/tzutrader/releases/tag/v0.1.0
