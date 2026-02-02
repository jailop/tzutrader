import std/strformat
import ../core
import ../indicators
import base

export base.Strategy

type
  AroonStrategy* = ref object of Strategy
    ## Aroon indicator strategy
    ## Identifies trend strength and direction
    period*: int
    upThreshold*: float64
    downThreshold*: float64
    aroonIndicator*: AROON
    lastPosition*: Position

proc newAroonStrategy*(period: int = 25, upThreshold: float64 = 70.0,
                       downThreshold: float64 = 30.0,
                           symbol: string = ""): AroonStrategy =
  ## Create a new Aroon strategy
  ##
  ## Args:
  ##   period: Aroon lookback period (default 25)
  ##   upThreshold: Threshold for strong trend (default 70)
  ##   downThreshold: Threshold for weak counter-trend (default 30)
  ##   symbol: Symbol to trade (optional)
  ##
  ## Returns:
  ##   New Aroon strategy instance
  result = AroonStrategy(
    name: "Aroon Strategy",
    symbol: symbol,
    period: period,
    upThreshold: upThreshold,
    downThreshold: downThreshold,
    aroonIndicator: newAROON(period),
    lastPosition: Position.Stay
  )

method analyze*(s: AroonStrategy, data: seq[OHLCV]): seq[Signal] =
  ## **DEPRECATED**: Use onBar() for streaming mode instead.
  raise newException(StrategyError, "Aroon analyze() batch mode deprecated. Use onBar() streaming mode.")

method onBar*(s: AroonStrategy, bar: OHLCV): Signal =
  ## Process single bar using streaming Aroon indicator
  let aroonResult = s.aroonIndicator.update(bar.high, bar.low)

  var position = Position.Stay
  var reason = ""

  if not aroonResult.up.isNaN and not aroonResult.down.isNaN:
    # Strong uptrend: Aroon Up high, Aroon Down low
    if aroonResult.up > s.upThreshold and aroonResult.down < s.downThreshold:
      if s.lastPosition != Position.Buy:
        position = Position.Buy
        reason = &"Strong uptrend: Aroon Up({aroonResult.up:.2f}) > {s.upThreshold:.0f}, Down({aroonResult.down:.2f}) < {s.downThreshold:.0f}"
        s.lastPosition = Position.Buy
      else:
        position = Position.Stay
        reason = &"Uptrend continues: Up={aroonResult.up:.2f}, Down={aroonResult.down:.2f}"

    # Strong downtrend: Aroon Down high, Aroon Up low
    elif aroonResult.down > s.upThreshold and aroonResult.up < s.downThreshold:
      if s.lastPosition != Position.Sell:
        position = Position.Sell
        reason = &"Strong downtrend: Aroon Down({aroonResult.down:.2f}) > {s.upThreshold:.0f}, Up({aroonResult.up:.2f}) < {s.downThreshold:.0f}"
        s.lastPosition = Position.Sell
      else:
        position = Position.Stay
        reason = &"Downtrend continues: Up={aroonResult.up:.2f}, Down={aroonResult.down:.2f}"

    # No clear trend
    else:
      position = Position.Stay
      if aroonResult.up > aroonResult.down:
        reason = &"Weak uptrend or consolidation: Up={aroonResult.up:.2f}, Down={aroonResult.down:.2f}"
      else:
        reason = &"Weak downtrend or consolidation: Up={aroonResult.up:.2f}, Down={aroonResult.down:.2f}"
      # Don't reset lastPosition in consolidation
  else:
    reason = "Insufficient data for Aroon"

  result = Signal(
    position: position,
    symbol: s.symbol,
    timestamp: bar.timestamp,
    price: bar.close,
    reason: reason
  )

method reset*(s: AroonStrategy) =
  ## Reset Aroon strategy state
  s.aroonIndicator = newAROON(s.period)
  s.lastPosition = Position.Stay
