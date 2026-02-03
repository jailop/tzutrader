## Concept-based MACD Strategy Implementation
##
## Parallel implementation using StrategyLike concept.

import std/strformat
import ../core
import ../indicators
import core


type
  MACDStrat* = object
    ## Concept-based MACD strategy
    name*: string
    symbol*: string
    fastPeriod*: int
    slowPeriod*: int
    signalPeriod*: int
    macdIndicator*: MACD
    lastSignal*: Position

proc newMACDStrat*(
  fastPeriod: int = 12,
  slowPeriod: int = 26,
  signalPeriod: int = 9,
  symbol: string = ""
): MACDStrat =
  ## Create a new concept-based MACD strategy
  ##
  ## Args:
  ##   fastPeriod: Fast EMA period (default 12)
  ##   slowPeriod: Slow EMA period (default 26)
  ##   signalPeriod: Signal line period (default 9)
  ##   symbol: Symbol to trade (optional)
  ##
  ## Returns:
  ##   New MACD strategy instance
  
  MACDStrat(
    name: "MACD Strategy",
    symbol: symbol,
    fastPeriod: fastPeriod,
    slowPeriod: slowPeriod,
    signalPeriod: signalPeriod,
    macdIndicator: newMACD(fastPeriod, slowPeriod, signalPeriod),
    lastSignal: Position.Stay
  )

proc onData*[T](s: var MACDStrat, data: T): Signal =
  ## Generic onData method that handles different data types
  ##
  ## Currently supports OHLCV bars. Can be extended for other data types.
  
  when T is OHLCV:
    let macdVal = s.macdIndicator.update(data.close)
    
    var position = Position.Stay
    var reason = ""
    
    if not macdVal.macdLine.isNaN and not macdVal.signalLine.isNaN:
      let histogram = macdVal.macdLine - macdVal.signalLine
      
      # Buy when MACD crosses above signal line
      if histogram > 0 and s.lastSignal != Position.Buy:
        position = Position.Buy
        reason = &"MACD above signal: {macdVal.macdLine:.4f} > {macdVal.signalLine:.4f}"
        s.lastSignal = Position.Buy
      # Sell when MACD crosses below signal line
      elif histogram < 0 and s.lastSignal != Position.Sell:
        position = Position.Sell
        reason = &"MACD below signal: {macdVal.macdLine:.4f} < {macdVal.signalLine:.4f}"
        s.lastSignal = Position.Sell
      else:
        position = Position.Stay
        reason = &"MACD histogram: {histogram:.4f}"
    else:
      reason = "Insufficient data for MACD"
    
    result = Signal(
      position: position,
      symbol: s.symbol,
      timestamp: data.timestamp,
      price: data.close,
      reason: reason
    )
  else:
    {.error: "MACDStrat does not support " & $T}

proc reset*(s: var MACDStrat) =
  ## Reset MACD strategy state
  
  s.macdIndicator = newMACD(s.fastPeriod, s.slowPeriod, s.signalPeriod)
  s.lastSignal = Position.Stay

proc getPositionSizing*(s: MACDStrat): tuple[sizingType: PositionSizingType, value: float] =
  ## Get position sizing preference for this strategy
  
  (pstDefault, 0.0)
