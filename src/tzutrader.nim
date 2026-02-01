## TzuTrader - A Simplified Trading Bot Library in Nim
##
## **DISCLAIMER**: This software is provided for educational and research purposes only.
## It does not constitute financial advice. Trading involves substantial risk of loss.
## Past performance does not guarantee future results. The authors and contributors are
## not responsible for any losses incurred from using this library. Users are solely
## responsible for their trading decisions and should consult with qualified financial
## professionals before making any investment decisions.
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

import tzutrader/core
import tzutrader/data
import tzutrader/indicators
import tzutrader/strategy
import tzutrader/strategy_builder
import tzutrader/portfolio
import tzutrader/trader
import tzutrader/scanner
import tzutrader/exports
import tzutrader/declarative
import tzutrader/screener/[screener, parser, reports, schema, alerts]

# Re-export core types for convenience
export core, data, indicators, strategy, strategy_builder, portfolio, trader, scanner, exports, declarative
export screener, parser, reports, schema, alerts
