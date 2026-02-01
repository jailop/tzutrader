## Triple Moving Average Strategy for tzutrader
##
## Trend following strategy using three moving averages for strong confirmation.
##
## **Strategy Type**: Trend Following
##
## **Best Market Conditions**: Strong trending markets (up or down)
##
## **Trading Logic**:
## - Buy when: fast MA > medium MA > slow MA (all aligned upward)
## - Sell when: fast MA < medium MA < slow MA (all aligned downward)
## - Provides stronger confirmation than dual crossover
## - Reduces false signals in choppy markets
##
## **Typical Parameters**:
## - fastPeriod: 20 (short-term trend)
## - mediumPeriod: 50 (intermediate trend)
## - slowPeriod: 200 (long-term trend)
##
## **Risk Profile**: Conservative, fewer but higher quality signals
##
## **Complementary Strategies**: Works well with volume confirmation
##
## **Known Limitations**:
## - Slower to react than single or dual MA strategies
## - May miss quick reversals
## - Requires strong trends for good performance
## - Late entry points (waits for full alignment)

import std/strformat
import ../core
import ../indicators
import base

export base.Strategy

type
  TripleMAStrategy* = ref object of Strategy
    ## Triple Moving Average strategy
    ## Uses three MAs for trend confirmation
    fastPeriod*: int
    mediumPeriod*: int
    slowPeriod*: int
    fastMA*: MA
    mediumMA*: MA
    slowMA*: MA
    lastAlignment*: Position
    initialized*: bool

proc newTripleMAStrategy*(fastPeriod: int = 20, mediumPeriod: int = 50,
                          slowPeriod: int = 200, symbol: string = ""): TripleMAStrategy =
  ## Create a new Triple Moving Average strategy
  ## 
  ## Args:
  ##   fastPeriod: Period for fast MA (default 20)
  ##   mediumPeriod: Period for medium MA (default 50)
  ##   slowPeriod: Period for slow MA (default 200)
  ##   symbol: Symbol to trade (optional)
  ## 
  ## Returns:
  ##   New TripleMAStrategy instance
  if fastPeriod >= mediumPeriod or mediumPeriod >= slowPeriod:
    raise newException(ValueError, "MA periods must be: fast < medium < slow")
  
  result = TripleMAStrategy(
    fastPeriod: fastPeriod,
    mediumPeriod: mediumPeriod,
    slowPeriod: slowPeriod,
    fastMA: newMA(fastPeriod, memSize = 1),
    mediumMA: newMA(mediumPeriod, memSize = 1),
    slowMA: newMA(slowPeriod, memSize = 1),
    lastAlignment: Position.Stay,
    initialized: false
  )
  result.symbol = symbol

proc onData*(s: TripleMAStrategy, bar: OHLCV): Signal =
  ## Process single bar using streaming Triple MA
  let fastValue = s.fastMA.update(bar.close)
  let mediumValue = s.mediumMA.update(bar.close)
  let slowValue = s.slowMA.update(bar.close)
  
  # Need all three MAs to be valid
  if fastValue.isNaN or mediumValue.isNaN or slowValue.isNaN:
    return newSignal(Position.Stay, s.symbol, bar.close, "Insufficient data")
  
  var position = Position.Stay
  var reason = ""
  var currentAlignment = Position.Stay
  
  # Check alignment
  if fastValue > mediumValue and mediumValue > slowValue:
    # Bullish alignment
    currentAlignment = Position.Buy
    if not s.initialized or s.lastAlignment != Position.Buy:
      position = Position.Buy
      reason = &"Triple MA bullish alignment (Fast: {fastValue:.2f} > Med: {mediumValue:.2f} > Slow: {slowValue:.2f})"
    else:
      reason = &"Maintaining bullish alignment"
  elif fastValue < mediumValue and mediumValue < slowValue:
    # Bearish alignment
    currentAlignment = Position.Sell
    if not s.initialized or s.lastAlignment != Position.Sell:
      position = Position.Sell
      reason = &"Triple MA bearish alignment (Fast: {fastValue:.2f} < Med: {mediumValue:.2f} < Slow: {slowValue:.2f})"
    else:
      reason = &"Maintaining bearish alignment"
  else:
    # No clear alignment
    currentAlignment = Position.Stay
    reason = &"MAs not aligned (Fast: {fastValue:.2f}, Med: {mediumValue:.2f}, Slow: {slowValue:.2f})"
  
  # Update state
  s.lastAlignment = currentAlignment
  s.initialized = true
  
  result = newSignal(position, s.symbol, bar.close, reason)

proc reset*(s: TripleMAStrategy) =
  ## Reset strategy state
  s.fastMA = newMA(s.fastPeriod, memSize = 1)
  s.mediumMA = newMA(s.mediumPeriod, memSize = 1)
  s.slowMA = newMA(s.slowPeriod, memSize = 1)
  s.lastAlignment = Position.Stay
  s.initialized = false

proc name*(s: TripleMAStrategy): string =
  ## Return strategy name
  result = &"Triple MA Strategy ({s.fastPeriod}/{s.mediumPeriod}/{s.slowPeriod})"
