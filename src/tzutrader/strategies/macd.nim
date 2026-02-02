import std/strformat
import ../core
import ../indicators
import base

export base.Strategy

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
                      signalPeriod: int = 9,
                          symbol: string = ""): MACDStrategy =
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
