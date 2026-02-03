## Concept-based Bollinger Bands Strategy Implementation
##
## Parallel implementation using StrategyLike concept.
## See rsi_strat.nim for explanation of the concept-based approach.

import std/[strformat, math]
import ../core
import ../indicators
import core


type
  BollingerStrat* = object
    ## Concept-based Bollinger Bands strategy
    name*: string
    symbol*: string
    period*: int
    stdDev*: float64
    bbIndicator*: BollingerBands
    lastPosition*: Position

proc newBollingerStrat*(
  period: int = 20,
  stdDev: float64 = 2.0,
  symbol: string = ""
): BollingerStrat =
  ## Create a new concept-based Bollinger Bands strategy
  ##
  ## Args:
  ##   period: BB period (default 20)
  ##   stdDev: Number of standard deviations (default 2.0)
  ##   symbol: Symbol to trade (optional)
  ##
  ## Returns:
  ##   New Bollinger Bands strategy instance
  
  BollingerStrat(
    name: "Bollinger Bands Strategy",
    symbol: symbol,
    period: period,
    stdDev: stdDev,
    bbIndicator: newBollingerBands(period, stdDev),
    lastPosition: Position.Stay
  )

proc onData*[T](s: var BollingerStrat, data: T): Signal =
  ## Generic onData method that handles different data types
  ##
  ## Currently supports OHLCV bars. Can be extended for other data types.
  
  when T is OHLCV:
    let bb = s.bbIndicator.update(data.close)
    
    var position = Position.Stay
    var reason = ""
    
    if not bb.upper.isNaN and not bb.lower.isNaN:
      let currentPrice = data.close
      
      # Buy when price is at or below lower band (oversold)
      if currentPrice <= bb.lower and s.lastPosition != Position.Buy:
        position = Position.Buy
        reason = &"Price at lower band: {currentPrice:.2f} <= {bb.lower:.2f}"
        s.lastPosition = Position.Buy
      # Sell when price is at or above upper band (overbought)
      elif currentPrice >= bb.upper and s.lastPosition != Position.Sell:
        position = Position.Sell
        reason = &"Price at upper band: {currentPrice:.2f} >= {bb.upper:.2f}"
        s.lastPosition = Position.Sell
      else:
        position = Position.Stay
        reason = &"Price between bands: {bb.lower:.2f} < {currentPrice:.2f} < {bb.upper:.2f}"
    else:
      reason = "Insufficient data for Bollinger Bands"
    
    result = Signal(
      position: position,
      symbol: s.symbol,
      timestamp: data.timestamp,
      price: data.close,
      reason: reason
    )
  else:
    {.error: "BollingerStrat does not support " & $T}

proc reset*(s: var BollingerStrat) =
  ## Reset Bollinger Bands strategy state
  
  s.bbIndicator = newBollingerBands(s.period, s.stdDev)
  s.lastPosition = Position.Stay

proc getPositionSizing*(s: BollingerStrat): tuple[sizingType: PositionSizingType, value: float] =
  ## Get position sizing preference for this strategy
  
  (pstDefault, 0.0)
