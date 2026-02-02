import std/strformat
import ../core
import ../indicators
import base

export base.Strategy

type
  CCIStrategy* = ref object of Strategy
    ## Commodity Channel Index strategy
    ## Mean reversion based on CCI crossovers
    period*: int
    oversoldLevel*: float64
    overboughtLevel*: float64
    cciIndicator*: CCI
    lastAboveOverbought*: bool
    lastBelowOversold*: bool

proc newCCIStrategy*(period: int = 20, oversoldLevel: float64 = -100.0,
                     overboughtLevel: float64 = 100.0,
                         symbol: string = ""): CCIStrategy =
  ## Create a new CCI strategy
  ##
  ## Args:
  ##   period: CCI period (default 20)
  ##   oversoldLevel: Oversold threshold for buy signals (default -100)
  ##   overboughtLevel: Overbought threshold for sell signals (default +100)
  ##   symbol: Symbol to trade (optional)
  ##
  ## Returns:
  ##   New CCI strategy instance
  result = CCIStrategy(
    name: "Commodity Channel Index Strategy",
    symbol: symbol,
    period: period,
    oversoldLevel: oversoldLevel,
    overboughtLevel: overboughtLevel,
    cciIndicator: newCCI(period),
    lastAboveOverbought: false,
    lastBelowOversold: false
  )

method analyze*(s: CCIStrategy, data: seq[OHLCV]): seq[Signal] =
  ## **DEPRECATED**: Use onBar() for streaming mode instead.
  raise newException(StrategyError, "CCI analyze() batch mode deprecated. Use onBar() streaming mode.")

method onBar*(s: CCIStrategy, bar: OHLCV): Signal =
  ## Process single bar using streaming CCI
  let cciVal = s.cciIndicator.update(bar.high, bar.low, bar.close)

  var position = Position.Stay
  var reason = ""

  if not cciVal.isNaN:
    let currentAboveOverbought = cciVal > s.overboughtLevel
    let currentBelowOversold = cciVal < s.oversoldLevel

    # Buy signal: CCI crosses above oversold level from below
    if s.lastBelowOversold and not currentBelowOversold and cciVal < 0:
      position = Position.Buy
      reason = &"CCI oversold reversal: {cciVal:.2f} crosses above {s.oversoldLevel:.2f}"

    # Sell signal: CCI crosses below overbought level from above
    elif s.lastAboveOverbought and not currentAboveOverbought and cciVal > 0:
      position = Position.Sell
      reason = &"CCI overbought reversal: {cciVal:.2f} crosses below {s.overboughtLevel:.2f}"

    else:
      # No signal
      position = Position.Stay
      if currentBelowOversold:
        reason = &"CCI oversold: {cciVal:.2f} < {s.oversoldLevel:.2f}"
      elif currentAboveOverbought:
        reason = &"CCI overbought: {cciVal:.2f} > {s.overboughtLevel:.2f}"
      else:
        reason = &"CCI neutral: {cciVal:.2f}"

    # Update state
    s.lastAboveOverbought = currentAboveOverbought
    s.lastBelowOversold = currentBelowOversold
  else:
    reason = "Insufficient data for CCI"

  result = Signal(
    position: position,
    symbol: s.symbol,
    timestamp: bar.timestamp,
    price: bar.close,
    reason: reason
  )

method reset*(s: CCIStrategy) =
  ## Reset CCI strategy state
  s.cciIndicator = newCCI(s.period)
  s.lastAboveOverbought = false
  s.lastBelowOversold = false
