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
export base.PositionSizingType # Export position sizing types
export base.name
export base.analyze
export base.onBar
export base.reset
export base.getPositionSizing # Export position sizing method
export base.setRiskManagement # Export risk management configuration
export base.getIndicatorValue # Export indicator value accessor

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
export keltner.KeltnerChannelStrategy, keltner.newKeltnerChannelStrategy,
    keltner.KeltnerMode

# Phase 3 combination/hybrid strategies
export triple_ma.TripleMAStrategy, triple_ma.newTripleMAStrategy
export adx_trend.ADXTrendStrategy, adx_trend.newADXTrendStrategy
export volume_breakout.VolumeBreakoutStrategy,
    volume_breakout.newVolumeBreakoutStrategy
export dual_momentum.DualMomentumStrategy, dual_momentum.newDualMomentumStrategy
export filtered_mean_reversion.FilteredMeanReversionStrategy,
    filtered_mean_reversion.newFilteredMeanReversionStrategy
