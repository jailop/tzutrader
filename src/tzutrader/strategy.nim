## Strategy module for tzutrader
##
## This module provides a framework for creating and using trading strategies.
## It includes a base Strategy class and several pre-built strategies.
##
## Usage:
##
## ```nim
## import tzutrader/strategy
## 
## # Create a strategy
## var rsiStrat = newRSIStrategy(period = 14, oversold = 30, overbought = 70)
## 
## # Process bars
## for bar in data:
##   let signal = rsiStrat.onBar(bar)
##   if signal.position == Position.Buy:
##     echo "Buy signal: ", signal.reason
## ```

import strategies/[adx_trend, aroon, base, bollinger, cci, crossover,
    dual_momentum, filtered_mean_reversion, kama, keltner, macd, mfi,
    parabolic_sar, rsi, stochastic, triple_ma, volume_breakout]

export adx_trend, aroon, base, bollinger, cci, crossover, dual_momentum,
    filtered_mean_reversion, kama, keltner, macd, mfi, parabolic_sar, rsi,
    stochastic, triple_ma, volume_breakout
