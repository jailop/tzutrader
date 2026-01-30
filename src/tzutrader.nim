## TzuTrader - A Simplified Trading Bot Library in Nim
##
## TzuTrader is a high-performance trading bot library designed with simplicity
## and ease of use in mind. It provides a flat architecture with minimal nesting,
## making it easy to get started with algorithmic trading.
##
## Features
## ========
##
## - **Pure Nim Implementation**: No C++ dependencies
## - **Flat Architecture**: Simple imports, intuitive API
## - **High Performance**: Compiled speed for real-time trading
## - **Yahoo Finance Integration**: Built-in data provider
## - **Backtesting**: Test strategies against historical data
## - **Technical Indicators**: Complete set reimplemented in pure Nim
## - **Pre-built Strategies**: RSI, Moving Average Crossover, MACD, and more
##
## Quick Start
## ===========
##
## .. code-block:: nim
##   import tzutrader
##   
##   # Create a strategy
##   let strategy = newRSIStrategy(period=14, oversold=30, overbought=70)
##   
##   # Run a backtest
##   let report = quickBacktest(
##     symbols = @["AAPL"],
##     strategy = strategy,
##     startTime = parseTime("2023-01-01"),
##     endTime = parseTime("2024-01-01"),
##     initialCash = 10000.0
##   )
##   
##   # View results
##   echo "Total Return: ", report.totalReturn, "%"
##
## Modules
## =======
##
## - `core <tzutrader/core.html>`_: Core types and data structures
## - `data <tzutrader/data.html>`_: Data streaming and Yahoo Finance integration
## - `indicators <tzutrader/indicators.html>`_: Technical indicators (pure Nim)
## - `strategy <tzutrader/strategy.html>`_: Strategy framework and pre-built strategies
## - `portfolio <tzutrader/portfolio.html>`_: Portfolio management
## - `trader <tzutrader/trader.html>`_: Trading engine and backtesting

import tzutrader/core
import tzutrader/data
import tzutrader/indicators
import tzutrader/strategy
import tzutrader/portfolio

# Re-export core types for convenience
export core, data, indicators, strategy, portfolio

# Version information
const
  TzuTraderVersion* = "0.5.0"
  TzuTraderAuthor* = "tzutrader contributors"
  TzuTraderLicense* = "MIT"
