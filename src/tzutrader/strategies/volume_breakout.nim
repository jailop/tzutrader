## Volume Breakout Strategy for tzutrader
##
## Price breakout strategy with volume confirmation to reduce false signals.
##
## **Strategy Type**: Breakout + Volume Confirmation
##
## **Best Market Conditions**: Markets transitioning from consolidation to trend
##
## **Trading Logic**:
## - Track price range (high/low) over N periods
## - Buy when: price breaks above range high AND volume > avgVolume × multiplier
## - Sell when: price breaks below range low AND volume > avgVolume × multiplier
## - Volume confirmation filters out weak/false breakouts
##
## **Typical Parameters**:
## - period: 20 (lookback for price range and volume average)
## - volumeMultiplier: 1.5 (volume must be 1.5x average)
##
## **Risk Profile**: Moderate to High, catches strong moves
##
## **Complementary Strategies**: Works well with trend filters
##
## **Known Limitations**:
## - Misses low-volume breakouts that can still be valid
## - Can generate false signals in highly volatile markets
## - Requires consistent volume data
## - Late entry after breakout already occurred

import std/strformat
import ../core
import ../indicators
import base

export base.Strategy

type
  VolumeBreakoutStrategy* = ref object of Strategy
    ## Volume Breakout strategy
    ## Trades breakouts confirmed by volume spikes
    period*: int
    volumeMultiplier*: float64
    volumeMA*: MA
    priceHighs*: seq[float64]
    priceLows*: seq[float64]
    pos*: int
    length*: int
    lastBreakoutDirection*: Position
    initialized*: bool

proc newVolumeBreakoutStrategy*(period: int = 20, volumeMultiplier: float64 = 1.5,
                                 symbol: string = ""): VolumeBreakoutStrategy =
  ## Create a new Volume Breakout strategy
  ## 
  ## Args:
  ##   period: Lookback period for range and volume average (default 20)
  ##   volumeMultiplier: Volume must exceed average by this factor (default 1.5)
  ##   symbol: Symbol to trade (optional)
  ## 
  ## Returns:
  ##   New VolumeBreakoutStrategy instance
  result = VolumeBreakoutStrategy(
    period: period,
    volumeMultiplier: volumeMultiplier,
    volumeMA: newMA(period, memSize = 1),
    priceHighs: newSeq[float64](period),
    priceLows: newSeq[float64](period),
    pos: 0,
    length: 0,
    lastBreakoutDirection: Position.Stay,
    initialized: false
  )
  result.symbol = symbol

proc onData*(s: VolumeBreakoutStrategy, bar: OHLCV): Signal =
  ## Process single bar using streaming volume breakout logic
  
  # Update volume MA
  let avgVolume = s.volumeMA.update(bar.volume)
  
  # Build up price history
  if s.length < s.period:
    s.priceHighs[s.pos] = bar.high
    s.priceLows[s.pos] = bar.low
    s.pos = (s.pos + 1) mod s.period
    s.length += 1
    return newSignal(Position.Stay, s.symbol, bar.close, "Building price history")
  
  # Calculate range high and low from previous periods (excluding current bar)
  var rangeHigh = s.priceHighs[0]
  var rangeLow = s.priceLows[0]
  
  for i in 1..<s.period:
    if s.priceHighs[i] > rangeHigh:
      rangeHigh = s.priceHighs[i]
    if s.priceLows[i] < rangeLow:
      rangeLow = s.priceLows[i]
  
  # Check if volume is sufficient
  let volumeConfirmed = if avgVolume.isNaN: false else: bar.volume > (avgVolume * s.volumeMultiplier)
  
  var position = Position.Stay
  var reason = ""
  
  # Check for breakouts
  if bar.high > rangeHigh and volumeConfirmed:
    # Upward breakout with volume confirmation
    position = Position.Buy
    reason = &"Upward breakout with volume (High: {bar.high:.2f} > Range: {rangeHigh:.2f}, Vol: {bar.volume:.0f} > {avgVolume * s.volumeMultiplier:.0f})"
    s.lastBreakoutDirection = Position.Buy
  elif bar.low < rangeLow and volumeConfirmed:
    # Downward breakout with volume confirmation
    position = Position.Sell
    reason = &"Downward breakout with volume (Low: {bar.low:.2f} < Range: {rangeLow:.2f}, Vol: {bar.volume:.0f} > {avgVolume * s.volumeMultiplier:.0f})"
    s.lastBreakoutDirection = Position.Sell
  elif bar.high > rangeHigh or bar.low < rangeLow:
    # Breakout without volume confirmation
    reason = &"Breakout without volume confirmation (Vol: {bar.volume:.0f} < {avgVolume * s.volumeMultiplier:.0f})"
  else:
    # Within range
    reason = &"Within range (Price: {bar.close:.2f}, Range: {rangeLow:.2f}-{rangeHigh:.2f})"
  
  # Update price history
  s.priceHighs[s.pos] = bar.high
  s.priceLows[s.pos] = bar.low
  s.pos = (s.pos + 1) mod s.period
  
  s.initialized = true
  
  result = newSignal(position, s.symbol, bar.close, reason)

proc reset*(s: VolumeBreakoutStrategy) =
  ## Reset strategy state
  s.volumeMA = newMA(s.period, memSize = 1)
  s.priceHighs = newSeq[float64](s.period)
  s.priceLows = newSeq[float64](s.period)
  s.pos = 0
  s.length = 0
  s.lastBreakoutDirection = Position.Stay
  s.initialized = false

proc name*(s: VolumeBreakoutStrategy): string =
  ## Return strategy name
  result = &"Volume Breakout Strategy (period: {s.period}, volMult: {s.volumeMultiplier:.1f}x)"
