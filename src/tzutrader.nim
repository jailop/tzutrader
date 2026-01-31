## TzuTrader - A Trading Bot Library in Nim

import tzutrader/core
import tzutrader/data
import tzutrader/datastreamers
import tzutrader/indicators
import tzutrader/strategy
import tzutrader/portfolio
import tzutrader/trader
import tzutrader/scanner
import tzutrader/exports
import tzutrader/declarative

# Re-export core types for convenience
export core, data, indicators, strategy, portfolio, trader, scanner, exports, declarative, datastreamers

# Version information
const
  TzuTraderVersion* = "0.1.0"
  TzuTraderAuthor* = "Jaime Lopez"
  TzuTraderLicense* = "MIT"
