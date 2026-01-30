## Strategy module for tzutrader
##
## This module provides a framework for creating and using trading strategies.
## It includes a base Strategy class and several pre-built strategies.
##
## Features:
## - Base Strategy class with common interface
## - Pre-built strategies (RSI, MA Crossover, MACD, Bollinger Bands)
## - Easy custom strategy creation
## - Streaming-only architecture (processes one bar at a time)
## - Signal generation for Buy/Sell/Stay decisions
## - Minimal state maintenance (no historical data accumulation)

import std/[strformat, sequtils, times]
import core
import indicators

# ============================================================================
# Base Strategy Types
# ============================================================================

type
  Strategy* = ref object of RootObj
    ## Base strategy class
    ## All strategies should inherit from this
    ## Strategies are streaming-only and maintain minimal state
    name*: string
    symbol*: string

# Base methods that all strategies must implement

method name*(s: Strategy): string {.base.} =
  ## Get strategy name
  s.name

method analyze*(s: Strategy, data: seq[OHLCV]): seq[Signal] {.base.} =
  ## Analyze historical data and generate signals for each bar (batch mode)
  ## 
  ## **DEPRECATED**: Batch mode is deprecated. Use streaming onBar() instead.
  ## 
  ## This method processes all historical data at once. For real-time trading
  ## or more memory-efficient processing, use the onBar() method with streaming data.
  ## 
  ## Args:
  ##   data: Historical OHLCV data
  ## 
  ## Returns:
  ##   Sequence of signals, one for each bar
  raise newException(StrategyError, "analyze() batch mode is deprecated. Use onBar() for streaming mode.")

method onBar*(s: Strategy, bar: OHLCV): Signal {.base.} =
  ## Process a single bar and generate signal (streaming mode)
  ## 
  ## Args:
  ##   bar: Single OHLCV bar
  ## 
  ## Returns:
  ##   Signal with position recommendation
  raise newException(StrategyError, "onBar() not implemented for " & s.name)

method reset*(s: Strategy) {.base.} =
  ## Reset strategy state (for streaming mode)
  discard

# ============================================================================
# RSI Strategy
# ============================================================================

type
  RSIStrategy* = ref object of Strategy
    ## RSI-based strategy
    ## Buys when RSI is oversold, sells when overbought
    period*: int
    oversold*: float64
    overbought*: float64
    rsiIndicator*: RSI
    lastSignal*: Position

proc newRSIStrategy*(period: int = 14, oversold: float64 = 30.0, 
                     overbought: float64 = 70.0, symbol: string = ""): RSIStrategy =
  ## Create a new RSI strategy
  ## 
  ## Args:
  ##   period: RSI period (default 14)
  ##   oversold: Oversold threshold for buy signals (default 30)
  ##   overbought: Overbought threshold for sell signals (default 70)
  ##   symbol: Symbol to trade (optional)
  ## 
  ## Returns:
  ##   New RSI strategy instance
  result = RSIStrategy(
    name: "RSI Strategy",
    symbol: symbol,
    period: period,
    oversold: oversold,
    overbought: overbought,
    rsiIndicator: newRSI(period),
    lastSignal: Position.Stay
  )

method analyze*(s: RSIStrategy, data: seq[OHLCV]): seq[Signal] =
  ## **DEPRECATED**: Use onBar() for streaming mode instead.
  ## 
  ## Batch analyze() requires batch indicator functions which have been removed
  ## in favor of streaming-only design. Use the onBar() method instead:
  ##
  ## .. code-block:: nim
  ##    var strategy = newRSIStrategy()
  ##    for bar in data:
  ##      let signal = strategy.onBar(bar)
  ##      # Process signal...
  raise newException(StrategyError, "RSI analyze() batch mode deprecated. Use onBar() streaming mode.")

method onBar*(s: RSIStrategy, bar: OHLCV): Signal =
  ## Process single bar using streaming RSI
  # RSI needs open and close prices
  let rsiVal = s.rsiIndicator.update(bar.open, bar.close)
  
  var position = Position.Stay
  var reason = ""
  
  if not rsiVal.isNaN:
    if rsiVal < s.oversold and s.lastSignal != Position.Buy:
      position = Position.Buy
      reason = &"RSI oversold: {rsiVal:.2f} < {s.oversold:.2f}"
      s.lastSignal = Position.Buy
    elif rsiVal > s.overbought and s.lastSignal != Position.Sell:
      position = Position.Sell
      reason = &"RSI overbought: {rsiVal:.2f} > {s.overbought:.2f}"
      s.lastSignal = Position.Sell
    else:
      position = Position.Stay
      reason = &"RSI neutral: {rsiVal:.2f}"
  else:
    reason = "Insufficient data for RSI"
  
  result = Signal(
    position: position,
    symbol: s.symbol,
    timestamp: bar.timestamp,
    price: bar.close,
    reason: reason
  )

method reset*(s: RSIStrategy) =
  ## Reset RSI strategy state
  s.rsiIndicator = newRSI(s.period)
  s.lastSignal = Position.Stay

# ============================================================================
# Moving Average Crossover Strategy
# ============================================================================

type
  CrossoverStrategy* = ref object of Strategy
    ## Moving average crossover strategy
    ## Golden cross (fast > slow) = buy, Death cross (fast < slow) = sell
    fastPeriod*: int
    slowPeriod*: int
    fastMA*: SMA
    slowMA*: SMA
    lastFastAbove*: bool

proc newCrossoverStrategy*(fastPeriod: int = 50, slowPeriod: int = 200,
                           symbol: string = ""): CrossoverStrategy =
  ## Create a new MA crossover strategy
  ## 
  ## Args:
  ##   fastPeriod: Fast moving average period (default 50)
  ##   slowPeriod: Slow moving average period (default 200)
  ##   symbol: Symbol to trade (optional)
  ## 
  ## Returns:
  ##   New crossover strategy instance
  result = CrossoverStrategy(
    name: &"MA Crossover ({fastPeriod}/{slowPeriod})",
    symbol: symbol,
    fastPeriod: fastPeriod,
    slowPeriod: slowPeriod,
    fastMA: newSMA(fastPeriod),
    slowMA: newSMA(slowPeriod),
    lastFastAbove: false
  )

method analyze*(s: CrossoverStrategy, data: seq[OHLCV]): seq[Signal] =
  ## **DEPRECATED**: Use onBar() for streaming mode instead.
  raise newException(StrategyError, "Crossover analyze() batch mode deprecated. Use onBar() streaming mode.")

method onBar*(s: CrossoverStrategy, bar: OHLCV): Signal =
  ## Process single bar using streaming MAs
  let fastVal = s.fastMA.update(bar.close)
  let slowVal = s.slowMA.update(bar.close)
  
  var position = Position.Stay
  var reason = ""
  
  if not fastVal.isNaN and not slowVal.isNaN:
    let currentFastAbove = fastVal > slowVal
    
    # Detect crossover
    if not s.lastFastAbove and currentFastAbove:
      # Golden cross
      position = Position.Buy
      reason = &"Golden cross: Fast MA ({fastVal:.2f}) > Slow MA ({slowVal:.2f})"
    elif s.lastFastAbove and not currentFastAbove:
      # Death cross
      position = Position.Sell
      reason = &"Death cross: Fast MA ({fastVal:.2f}) < Slow MA ({slowVal:.2f})"
    else:
      position = Position.Stay
      reason = &"No crossover: Fast={fastVal:.2f}, Slow={slowVal:.2f}"
    
    s.lastFastAbove = currentFastAbove
  else:
    reason = "Insufficient data for moving averages"
  
  result = Signal(
    position: position,
    symbol: s.symbol,
    timestamp: bar.timestamp,
    price: bar.close,
    reason: reason
  )

method reset*(s: CrossoverStrategy) =
  ## Reset crossover strategy state
  s.fastMA = newSMA(s.fastPeriod)
  s.slowMA = newSMA(s.slowPeriod)
  s.lastFastAbove = false

# ============================================================================
# MACD Strategy
# ============================================================================

type
  MACDStrategy* = ref object of Strategy
    ## MACD-based strategy
    ## Bullish when MACD > signal, bearish when MACD < signal
    fastPeriod*: int
    slowPeriod*: int
    signalPeriod*: int
    macdIndicator*: MACD
    lastMACDAbove*: bool

proc newMACDStrategy*(fastPeriod: int = 12, slowPeriod: int = 26,
                      signalPeriod: int = 9, symbol: string = ""): MACDStrategy =
  ## Create a new MACD strategy
  ## 
  ## Args:
  ##   fastPeriod: Fast EMA period (default 12)
  ##   slowPeriod: Slow EMA period (default 26)
  ##   signalPeriod: Signal line EMA period (default 9)
  ##   symbol: Symbol to trade (optional)
  ## 
  ## Returns:
  ##   New MACD strategy instance
  result = MACDStrategy(
    name: "MACD Strategy",
    symbol: symbol,
    fastPeriod: fastPeriod,
    slowPeriod: slowPeriod,
    signalPeriod: signalPeriod,
    macdIndicator: newMACD(fastPeriod, slowPeriod, signalPeriod),
    lastMACDAbove: false
  )

method analyze*(s: MACDStrategy, data: seq[OHLCV]): seq[Signal] =
  ## **DEPRECATED**: Use onBar() for streaming mode instead.
  raise newException(StrategyError, "MACD analyze() batch mode deprecated. Use onBar() streaming mode.")

method onBar*(s: MACDStrategy, bar: OHLCV): Signal =
  ## Process single bar using streaming MACD
  let macdResult = s.macdIndicator.update(bar.close)
  
  var position = Position.Stay
  var reason = ""
  
  if not macdResult.macd.isNaN and not macdResult.signal.isNaN:
    let currentMACDAbove = macdResult.macd > macdResult.signal
    
    # Detect crossover
    if not s.lastMACDAbove and currentMACDAbove:
      # Bullish crossover
      position = Position.Buy
      reason = &"MACD bullish crossover: MACD ({macdResult.macd:.3f}) > Signal ({macdResult.signal:.3f})"
    elif s.lastMACDAbove and not currentMACDAbove:
      # Bearish crossover
      position = Position.Sell
      reason = &"MACD bearish crossover: MACD ({macdResult.macd:.3f}) < Signal ({macdResult.signal:.3f})"
    else:
      position = Position.Stay
      reason = &"No MACD crossover: Histogram={macdResult.hist:.3f}"
    
    s.lastMACDAbove = currentMACDAbove
  else:
    reason = "Insufficient data for MACD"
  
  result = Signal(
    position: position,
    symbol: s.symbol,
    timestamp: bar.timestamp,
    price: bar.close,
    reason: reason
  )

method reset*(s: MACDStrategy) =
  ## Reset MACD strategy state
  s.macdIndicator = newMACD(s.fastPeriod, s.slowPeriod, s.signalPeriod)
  s.lastMACDAbove = false

# ============================================================================
# Bollinger Bands Strategy
# ============================================================================

type
  BollingerStrategy* = ref object of Strategy
    ## Bollinger Bands mean reversion strategy
    ## Buy when price touches lower band, sell when price touches upper band
    period*: int
    stdDev*: float64
    bbIndicator*: BollingerBands
    lastPosition*: Position

proc newBollingerStrategy*(period: int = 20, stdDev: float64 = 2.0,
                           symbol: string = ""): BollingerStrategy =
  ## Create a new Bollinger Bands strategy
  ## 
  ## Args:
  ##   period: BB period (default 20)
  ##   stdDev: Number of standard deviations (default 2.0)
  ##   symbol: Symbol to trade (optional)
  ## 
  ## Returns:
  ##   New Bollinger Bands strategy instance
  result = BollingerStrategy(
    name: "Bollinger Bands Strategy",
    symbol: symbol,
    period: period,
    stdDev: stdDev,
    bbIndicator: newBollingerBands(period, stdDev),
    lastPosition: Position.Stay
  )

method analyze*(s: BollingerStrategy, data: seq[OHLCV]): seq[Signal] =
  ## **DEPRECATED**: Use onBar() for streaming mode instead.
  raise newException(StrategyError, "Bollinger analyze() batch mode deprecated. Use onBar() streaming mode.")

method onBar*(s: BollingerStrategy, bar: OHLCV): Signal =
  ## Process single bar using streaming Bollinger Bands
  let bb = s.bbIndicator.update(bar.close)
  
  var position = Position.Stay
  var reason = ""
  
  if not bb.upper.isNaN and not bb.lower.isNaN:
    let currentPrice = bar.close
    
    # Buy when price is at or below lower band (oversold)
    if currentPrice <= bb.lower:
      position = Position.Buy
      reason = &"Price at lower band: ${currentPrice:.2f} <= ${bb.lower:.2f}"
    # Sell when price is at or above upper band (overbought)
    elif currentPrice >= bb.upper:
      position = Position.Sell
      reason = &"Price at upper band: ${currentPrice:.2f} >= ${bb.upper:.2f}"
    # Exit when price returns to middle
    elif abs(currentPrice - bb.middle) < (bb.upper - bb.middle) * 0.3:
      position = Position.Stay
      reason = &"Price near middle band: ${currentPrice:.2f} ≈ ${bb.middle:.2f}"
    else:
      position = Position.Stay
      reason = &"Price within bands: ${bb.lower:.2f} < ${currentPrice:.2f} < ${bb.upper:.2f}"
  else:
    reason = "Insufficient data for Bollinger Bands"
  
  result = Signal(
    position: position,
    symbol: s.symbol,
    timestamp: bar.timestamp,
    price: bar.close,
    reason: reason
  )

method reset*(s: BollingerStrategy) =
  ## Reset Bollinger strategy state
  s.bbIndicator = newBollingerBands(s.period, s.stdDev)
  s.lastPosition = Position.Stay
