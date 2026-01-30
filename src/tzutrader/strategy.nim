## Strategy module for tzutrader
##
## This module provides a framework for creating and using trading strategies.
## It includes a base Strategy class and several pre-built strategies.
##
## Features:
## - Base Strategy class with common interface
## - Pre-built strategies (RSI, MA Crossover, MACD, Bollinger Bands, and more)
## - Easy custom strategy creation
## - Streaming-only architecture (processes one bar at a time)
## - Signal generation for Buy/Sell/Stay decisions
## - Minimal state maintenance (no historical data accumulation)
##
## Available Strategies:
## 
## **Mean Reversion Strategies:**
## - RSIStrategy: RSI-based overbought/oversold signals
## - BollingerStrategy: Bollinger Bands mean reversion
## - StochasticStrategy: Stochastic Oscillator crossovers
## - MFIStrategy: Volume-weighted momentum (Money Flow Index)
## - CCIStrategy: Commodity Channel Index reversals
##
## **Trend Following Strategies:**
## - CrossoverStrategy: Moving average crossovers (Golden/Death cross)
## - MACDStrategy: MACD line and signal line crossovers
## - KAMAStrategy: Adaptive moving average (adjusts to volatility)
## - AroonStrategy: Trend strength and direction identification
## - ParabolicSARStrategy: Dynamic trailing stops with SAR
## - TripleMAStrategy: Three moving average trend confirmation
## - ADXTrendStrategy: ADX-filtered trend following
##
## **Volatility Strategies:**
## - KeltnerChannelStrategy: Volatility breakout or mean reversion
##
## **Hybrid/Combination Strategies:**
## - VolumeBreakoutStrategy: Price breakout with volume confirmation
## - DualMomentumStrategy: ROC momentum with trend confirmation
## - FilteredMeanReversionStrategy: RSI mean reversion with trend filter
##
## Usage:
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

import std/[strformat, sequtils, times]
import core
import indicators

# Import all strategy modules
import strategies/base
import strategies/rsi
import strategies/crossover
import strategies/macd
import strategies/bollinger
import strategies/stochastic
import strategies/mfi
import strategies/cci
import strategies/aroon
import strategies/kama
import strategies/parabolic_sar
import strategies/keltner
import strategies/triple_ma
import strategies/adx_trend
import strategies/volume_breakout
import strategies/dual_momentum
import strategies/filtered_mean_reversion

# Export base strategy type and interface
export base.Strategy
export base.name
export base.analyze
export base.onBar
export base.reset

# Export all strategy types and constructors
# Classic strategies
export rsi.RSIStrategy, rsi.newRSIStrategy
export crossover.CrossoverStrategy, crossover.newCrossoverStrategy
export macd.MACDStrategy, macd.newMACDStrategy
export bollinger.BollingerStrategy, bollinger.newBollingerStrategy

# Phase 1 new strategies
export stochastic.StochasticStrategy, stochastic.newStochasticStrategy
export mfi.MFIStrategy, mfi.newMFIStrategy
export cci.CCIStrategy, cci.newCCIStrategy
export aroon.AroonStrategy, aroon.newAroonStrategy
export kama.KAMAStrategy, kama.newKAMAStrategy

# Phase 2 new strategies
export parabolic_sar.ParabolicSARStrategy, parabolic_sar.newParabolicSARStrategy
export keltner.KeltnerChannelStrategy, keltner.newKeltnerChannelStrategy, keltner.KeltnerMode

# Phase 3 combination/hybrid strategies
export triple_ma.TripleMAStrategy, triple_ma.newTripleMAStrategy
export adx_trend.ADXTrendStrategy, adx_trend.newADXTrendStrategy
export volume_breakout.VolumeBreakoutStrategy, volume_breakout.newVolumeBreakoutStrategy
export dual_momentum.DualMomentumStrategy, dual_momentum.newDualMomentumStrategy
export filtered_mean_reversion.FilteredMeanReversionStrategy, filtered_mean_reversion.newFilteredMeanReversionStrategy
