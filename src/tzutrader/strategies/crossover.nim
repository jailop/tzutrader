import std/strformat
import ../core
import ../indicators
import base

export base.Strategy

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
