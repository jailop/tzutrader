## Concept-based RSI Strategy Implementation
##
## This is a parallel implementation of the RSI strategy using the StrategyLike
## concept instead of inheritance. It demonstrates how concepts provide better
## compile-time dispatch than traditional inheritance.
##
## **Key Difference from strategies/rsi.nim:**
## - Uses value type (object) instead of ref object
## - No inheritance from Strategy
## - Implements the StrategyLike concept interface with generic onData[T]
## - Generic dispatch is resolved at compile-time
## - Supports extending to other data types (Quote, Tick, etc.) without changes

import std/strformat
import ../core
import ../indicators
import core


type
  RSIStrat* = object
    ## Concept-based RSI strategy (value type, not reference)
    ##
    ## This is not a Strategy subclass. Instead, it implements the StrategyLike
    ## concept, which provides compile-time type checking without inheritance.
    name*: string
    symbol*: string
    period*: int
    oversold*: float64
    overbought*: float64
    rsiIndicator*: RSI
    lastSignal*: Position

proc newRSIStrat*(
  period: int = 14,
  oversold: float64 = 30.0,
  overbought: float64 = 70.0,
  symbol: string = ""
): RSIStrat =
  ## Create a new concept-based RSI strategy
  ##
  ## Args:
  ##   period: RSI period (default 14)
  ##   oversold: Oversold threshold for buy signals (default 30)
  ##   overbought: Overbought threshold for sell signals (default 70)
  ##   symbol: Symbol to trade (optional)
  ##
  ## Returns:
  ##   New RSI strategy instance (value type)
  
  RSIStrat(
    name: "RSI Strategy",
    symbol: symbol,
    period: period,
    oversold: oversold,
    overbought: overbought,
    rsiIndicator: newRSI(period),
    lastSignal: Position.Stay
  )

proc onData*[T](s: var RSIStrat, data: T): Signal =
  ## Generic onData method that handles different data types
  ##
  ## This implements the StrategyLike concept interface.
  ## Currently supports OHLCV bars. Can be extended for Quote, Tick, etc.
  ##
  ## Args:
  ##   data: Data of any supported type (OHLCV, Quote, etc.)
  ##
  ## Returns:
  ##   Signal with trading recommendation
  
  when T is OHLCV:
    # Process OHLCV bar
    let rsiVal = s.rsiIndicator.update(data.open, data.close)
    
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
      timestamp: data.timestamp,
      price: data.close,
      reason: reason
    )
  else:
    {.error: "RSIStrat does not support " & $T}

proc reset*(s: var RSIStrat) =
  ## Reset RSI strategy state
  ##
  ## This implements the StrategyLike concept interface.
  
  s.rsiIndicator = newRSI(s.period)
  s.lastSignal = Position.Stay

proc getPositionSizing*(s: RSIStrat): tuple[sizingType: PositionSizingType, value: float] =
  ## Get position sizing preference for this strategy
  ##
  ## This implements the StrategyLike concept interface.
  ##
  ## Returns:
  ##   Tuple of (sizing type, value) - uses default 95% of cash
  
  (pstDefault, 0.0)
