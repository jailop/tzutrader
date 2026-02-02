import std/strformat
import ../core
import ../indicators
import base

export base.Strategy

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
                     overbought: float64 = 70.0,
                         symbol: string = ""): RSIStrategy =
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
