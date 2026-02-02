import std/strformat
import ../core
import ../indicators
import base

export base.Strategy

type
  StochasticStrategy* = ref object of Strategy
    ## Stochastic Oscillator strategy
    ## Trades %K/%D crossovers in overbought/oversold zones
    kPeriod*: int
    dPeriod*: int
    oversold*: float64
    overbought*: float64
    stochIndicator*: STOCH
    lastKAboveD*: bool
    lastInOversold*: bool
    lastInOverbought*: bool

proc newStochasticStrategy*(kPeriod: int = 14, dPeriod: int = 3,
                            oversold: float64 = 20.0,
                                overbought: float64 = 80.0,
                            symbol: string = ""): StochasticStrategy =
  ## Create a new Stochastic Oscillator strategy
  ##
  ## Args:
  ##   kPeriod: Period for %K calculation (default 14)
  ##   dPeriod: Period for %D smoothing (default 3)
  ##   oversold: Oversold threshold for buy signals (default 20)
  ##   overbought: Overbought threshold for sell signals (default 80)
  ##   symbol: Symbol to trade (optional)
  ##
  ## Returns:
  ##   New Stochastic strategy instance
  result = StochasticStrategy(
    name: "Stochastic Oscillator Strategy",
    symbol: symbol,
    kPeriod: kPeriod,
    dPeriod: dPeriod,
    oversold: oversold,
    overbought: overbought,
    stochIndicator: newSTOCH(kPeriod, dPeriod),
    lastKAboveD: false,
    lastInOversold: false,
    lastInOverbought: false
  )

method analyze*(s: StochasticStrategy, data: seq[OHLCV]): seq[Signal] =
  ## **DEPRECATED**: Use onBar() for streaming mode instead.
  raise newException(StrategyError, "Stochastic analyze() batch mode deprecated. Use onBar() streaming mode.")

method onBar*(s: StochasticStrategy, bar: OHLCV): Signal =
  ## Process single bar using streaming Stochastic Oscillator
  let stochResult = s.stochIndicator.update(bar.high, bar.low, bar.close)

  var position = Position.Stay
  var reason = ""

  if not stochResult.k.isNaN and not stochResult.d.isNaN:
    let currentKAboveD = stochResult.k > stochResult.d
    let inOversold = stochResult.k < s.oversold
    let inOverbought = stochResult.k > s.overbought

    # Buy signal: %K crosses above %D while in or just leaving oversold zone
    if not s.lastKAboveD and currentKAboveD and (inOversold or
        s.lastInOversold):
      position = Position.Buy
      reason = &"Stochastic bullish crossover in oversold: %K({stochResult.k:.2f}) > %D({stochResult.d:.2f})"

    # Sell signal: %K crosses below %D while in or just leaving overbought zone
    elif s.lastKAboveD and not currentKAboveD and (inOverbought or
        s.lastInOverbought):
      position = Position.Sell
      reason = &"Stochastic bearish crossover in overbought: %K({stochResult.k:.2f}) < %D({stochResult.d:.2f})"

    else:
      # No signal
      position = Position.Stay
      if inOversold:
        reason = &"Stochastic oversold: %K={stochResult.k:.2f}, %D={stochResult.d:.2f}"
      elif inOverbought:
        reason = &"Stochastic overbought: %K={stochResult.k:.2f}, %D={stochResult.d:.2f}"
      else:
        reason = &"Stochastic neutral: %K={stochResult.k:.2f}, %D={stochResult.d:.2f}"

    # Update state
    s.lastKAboveD = currentKAboveD
    s.lastInOversold = inOversold
    s.lastInOverbought = inOverbought
  else:
    reason = "Insufficient data for Stochastic Oscillator"

  result = Signal(
    position: position,
    symbol: s.symbol,
    timestamp: bar.timestamp,
    price: bar.close,
    reason: reason
  )

method reset*(s: StochasticStrategy) =
  ## Reset Stochastic strategy state
  s.stochIndicator = newSTOCH(s.kPeriod, s.dPeriod)
  s.lastKAboveD = false
  s.lastInOversold = false
  s.lastInOverbought = false
