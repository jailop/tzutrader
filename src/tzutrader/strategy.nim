## Strategy module for tzutrader
##
## This module provides a framework for creating and using trading strategies.
## It includes a base Strategy class and several pre-built strategies.
##
## Features:
## - Base Strategy class with common interface
## - Pre-built strategies (RSI, MA Crossover, MACD, Bollinger Bands)
## - Easy custom strategy creation
## - Batch and streaming modes
## - Signal generation for Buy/Sell/Stay decisions

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
    name*: string
    symbol*: string
    history*: seq[OHLCV]  ## For strategies that need bar history

# Base methods that all strategies must implement

method name*(s: Strategy): string {.base.} =
  ## Get strategy name
  s.name

method analyze*(s: Strategy, data: seq[OHLCV]): seq[Signal] {.base.} =
  ## Analyze historical data and generate signals for each bar (batch mode)
  ## 
  ## Args:
  ##   data: Historical OHLCV data
  ## 
  ## Returns:
  ##   Sequence of signals, one for each bar
  raise newException(StrategyError, "analyze() not implemented for " & s.name)

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
  ## Analyze data using RSI, generating a signal for each bar
  let prices = data.mapIt(it.close)
  let rsiValues = rsi(prices, s.period)
  
  result = @[]
  for i, bar in data:
    let rsiVal = rsiValues[i]
    var position = Position.Stay
    var reason = ""
    
    if not rsiVal.isNaN:
      if rsiVal < s.oversold:
        position = Position.Buy
        reason = &"RSI oversold: {rsiVal:.2f} < {s.oversold:.2f}"
      elif rsiVal > s.overbought:
        position = Position.Sell
        reason = &"RSI overbought: {rsiVal:.2f} > {s.overbought:.2f}"
      else:
        position = Position.Stay
        reason = &"RSI neutral: {rsiVal:.2f}"
    else:
      reason = "Insufficient data for RSI"
    
    result.add(Signal(
      position: position,
      symbol: s.symbol,
      timestamp: bar.timestamp,
      price: bar.close,
      reason: reason
    ))

method onBar*(s: RSIStrategy, bar: OHLCV): Signal =
  ## Process single bar using streaming RSI
  s.history.add(bar)
  let rsiVal = s.rsiIndicator.update(bar.close)
  
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
  s.history = @[]

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
  ## Analyze data using MA crossover, generating a signal for each bar
  let prices = data.mapIt(it.close)
  let fastMA = sma(prices, s.fastPeriod)
  let slowMA = sma(prices, s.slowPeriod)
  
  result = @[]
  for i, bar in data:
    let currentFast = fastMA[i]
    let currentSlow = slowMA[i]
    
    var position = Position.Stay
    var reason = ""
    
    if not currentFast.isNaN and not currentSlow.isNaN and i > 0:
      let prevFast = fastMA[i-1]
      let prevSlow = slowMA[i-1]
      
      # Golden cross: fast crosses above slow
      if not prevFast.isNaN and not prevSlow.isNaN:
        if prevFast <= prevSlow and currentFast > currentSlow:
          position = Position.Buy
          reason = &"Golden cross: Fast MA ({currentFast:.2f}) > Slow MA ({currentSlow:.2f})"
        # Death cross: fast crosses below slow
        elif prevFast >= prevSlow and currentFast < currentSlow:
          position = Position.Sell
          reason = &"Death cross: Fast MA ({currentFast:.2f}) < Slow MA ({currentSlow:.2f})"
        else:
          position = Position.Stay
          reason = &"No crossover: Fast={currentFast:.2f}, Slow={currentSlow:.2f}"
      else:
        reason = "Insufficient data for crossover detection"
    else:
      reason = "Insufficient data for moving averages"
    
    result.add(Signal(
      position: position,
      symbol: s.symbol,
      timestamp: bar.timestamp,
      price: bar.close,
      reason: reason
    ))

method onBar*(s: CrossoverStrategy, bar: OHLCV): Signal =
  ## Process single bar using streaming MAs
  s.history.add(bar)
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
  s.history = @[]

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
  ## Analyze data using MACD, generating a signal for each bar
  let prices = data.mapIt(it.close)
  let macdData = macd(prices, s.fastPeriod, s.slowPeriod, s.signalPeriod)
  
  result = @[]
  for i, bar in data:
    let currentMACD = macdData.macd[i]
    let currentSignal = macdData.signal[i]
    let currentHist = macdData.histogram[i]
    
    var position = Position.Stay
    var reason = ""
    
    if not currentMACD.isNaN and not currentSignal.isNaN and i > 0:
      let prevMACD = macdData.macd[i-1]
      let prevSignal = macdData.signal[i-1]
      
      if not prevMACD.isNaN and not prevSignal.isNaN:
        # Bullish crossover: MACD crosses above signal
        if prevMACD <= prevSignal and currentMACD > currentSignal:
          position = Position.Buy
          reason = &"MACD bullish crossover: MACD ({currentMACD:.3f}) > Signal ({currentSignal:.3f})"
        # Bearish crossover: MACD crosses below signal
        elif prevMACD >= prevSignal and currentMACD < currentSignal:
          position = Position.Sell
          reason = &"MACD bearish crossover: MACD ({currentMACD:.3f}) < Signal ({currentSignal:.3f})"
        else:
          position = Position.Stay
          reason = &"No MACD crossover: Histogram={currentHist:.3f}"
      else:
        reason = "Insufficient data for MACD crossover"
    else:
      reason = "Insufficient data for MACD"
    
    result.add(Signal(
      position: position,
      symbol: s.symbol,
      timestamp: bar.timestamp,
      price: bar.close,
      reason: reason
    ))

method onBar*(s: MACDStrategy, bar: OHLCV): Signal =
  ## Process single bar using streaming MACD
  s.history.add(bar)
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
      reason = &"No MACD crossover: Histogram={macdResult.histogram:.3f}"
    
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
  s.history = @[]

# ============================================================================
# Bollinger Bands Strategy
# ============================================================================

type
  BollingerStrategy* = ref object of Strategy
    ## Bollinger Bands mean reversion strategy
    ## Buy when price touches lower band, sell when price touches upper band
    period*: int
    stdDev*: float64
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
    lastPosition: Position.Stay
  )

method analyze*(s: BollingerStrategy, data: seq[OHLCV]): seq[Signal] =
  ## Analyze data using Bollinger Bands, generating a signal for each bar
  let prices = data.mapIt(it.close)
  let bb = bollinger(prices, s.period, s.stdDev)
  
  result = @[]
  for i, bar in data:
    let currentPrice = bar.close
    let currentUpper = bb.upper[i]
    let currentMiddle = bb.middle[i]
    let currentLower = bb.lower[i]
    
    var position = Position.Stay
    var reason = ""
    
    if not currentUpper.isNaN and not currentLower.isNaN:
      # Buy when price is at or below lower band (oversold)
      if currentPrice <= currentLower:
        position = Position.Buy
        reason = &"Price at lower band: ${currentPrice:.2f} <= ${currentLower:.2f}"
      # Sell when price is at or above upper band (overbought)
      elif currentPrice >= currentUpper:
        position = Position.Sell
        reason = &"Price at upper band: ${currentPrice:.2f} >= ${currentUpper:.2f}"
      # Exit when price returns to middle
      elif abs(currentPrice - currentMiddle) < (currentUpper - currentMiddle) * 0.3:
        position = Position.Stay
        reason = &"Price near middle band: ${currentPrice:.2f} ≈ ${currentMiddle:.2f}"
      else:
        position = Position.Stay
        reason = &"Price within bands: ${currentLower:.2f} < ${currentPrice:.2f} < ${currentUpper:.2f}"
    else:
      reason = "Insufficient data for Bollinger Bands"
    
    result.add(Signal(
      position: position,
      symbol: s.symbol,
      timestamp: bar.timestamp,
      price: bar.close,
      reason: reason
    ))

method onBar*(s: BollingerStrategy, bar: OHLCV): Signal =
  ## Bollinger Bands strategy doesn't have a good streaming implementation
  ## because it needs full history for standard deviation calculation.
  ## We'll just delegate to analyze with a single bar.
  result = Signal(
    position: Position.Stay,
    symbol: s.symbol,
    timestamp: bar.timestamp,
    price: bar.close,
    reason: "Bollinger Bands requires batch mode (use analyze())"
  )

method reset*(s: BollingerStrategy) =
  ## Reset Bollinger strategy state
  s.lastPosition = Position.Stay
  s.history = @[]
