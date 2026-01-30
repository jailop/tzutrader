# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Phase 2 - Data Management (In Progress)
- Yahoo Finance integration via yfnim
- Data streaming and caching
- Historical and real-time quote data

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
