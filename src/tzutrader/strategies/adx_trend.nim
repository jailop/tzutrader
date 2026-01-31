## ADX Trend Strength Strategy for tzutrader
##
## Trend following strategy with ADX filter for trend strength confirmation.
##
## **Strategy Type**: Trend Following + Strength Filter
##
## **Best Market Conditions**: Strongly trending markets with clear direction
##
## **Trading Logic**:
## - Only trade when ADX > threshold (indicates strong trend)
## - Use +DI/-DI crossovers for direction
## - Buy: +DI crosses above -DI when ADX > threshold
## - Sell: -DI crosses above +DI when ADX > threshold
## - Filters out weak/choppy markets where trends are unclear
##
## **Typical Parameters**:
## - period: 14 (ADX calculation period)
## - adxThreshold: 25.0 (minimum ADX for trading)
##
## **Risk Profile**: Moderate, focuses on strong trends only
##
## **Complementary Strategies**: Works well with momentum indicators
##
## **Known Limitations**:
## - Misses opportunities in weak but profitable trends
## - ADX is a lagging indicator
## - May stay out of market for extended periods
## - Requires sufficient volatility

import std/strformat
import ../core
import ../indicators
import base

export base.Strategy

type
  ADXTrendStrategy* = ref object of Strategy
    ## ADX Trend Strength strategy
    ## Uses ADX to filter trades, +DI/-DI for direction
    period*: int
    adxThreshold*: float64
    adxIndicator*: ADX
    lastPlusDIAbove*: bool
    initialized*: bool

proc newADXTrendStrategy*(period: int = 14, adxThreshold: float64 = 25.0,
                          symbol: string = ""): ADXTrendStrategy =
  ## Create a new ADX Trend Strength strategy
  ## 
  ## Args:
  ##   period: Period for ADX calculation (default 14)
  ##   adxThreshold: Minimum ADX value to take trades (default 25.0)
  ##   symbol: Symbol to trade (optional)
  ## 
  ## Returns:
  ##   New ADXTrendStrategy instance
  result = ADXTrendStrategy(
    period: period,
    adxThreshold: adxThreshold,
    adxIndicator: newADX(period, memSize = 1),
    lastPlusDIAbove: false,
    initialized: false
  )
  result.symbol = symbol

proc on*(s: ADXTrendStrategy, bar: OHLCV): Signal =
  ## Process single bar using streaming ADX
  let adxResult = s.adxIndicator.update(bar.low, bar.high, bar.close)
  
  # Need valid ADX values
  if adxResult.adx.isNaN or adxResult.plusDI.isNaN or adxResult.minusDI.isNaN:
    return newSignal(Position.Stay, s.symbol, bar.close, "Insufficient data")
  
  var position = Position.Stay
  var reason = ""
  
  # Check if trend is strong enough
  if adxResult.adx < s.adxThreshold:
    reason = &"ADX too low for trading (ADX: {adxResult.adx:.2f} < {s.adxThreshold:.2f})"
    s.initialized = true
    s.lastPlusDIAbove = adxResult.plusDI > adxResult.minusDI
    return newSignal(Position.Stay, s.symbol, bar.close, reason)
  
  # Check for DI crossovers
  let plusDIAbove = adxResult.plusDI > adxResult.minusDI
  
  if not s.initialized:
    # Initialize state
    s.lastPlusDIAbove = plusDIAbove
    s.initialized = true
    reason = &"Initialization (ADX: {adxResult.adx:.2f}, +DI: {adxResult.plusDI:.2f}, -DI: {adxResult.minusDI:.2f})"
  else:
    # Check for crossovers
    if plusDIAbove and not s.lastPlusDIAbove:
      # +DI crossed above -DI
      position = Position.Buy
      reason = &"+DI crossed above -DI with strong trend (ADX: {adxResult.adx:.2f}, +DI: {adxResult.plusDI:.2f}, -DI: {adxResult.minusDI:.2f})"
    elif not plusDIAbove and s.lastPlusDIAbove:
      # -DI crossed above +DI
      position = Position.Sell
      reason = &"-DI crossed above +DI with strong trend (ADX: {adxResult.adx:.2f}, +DI: {adxResult.plusDI:.2f}, -DI: {adxResult.minusDI:.2f})"
    else:
      # No crossover
      let direction = if plusDIAbove: "bullish" else: "bearish"
      reason = &"Strong {direction} trend continues (ADX: {adxResult.adx:.2f}, +DI: {adxResult.plusDI:.2f}, -DI: {adxResult.minusDI:.2f})"
  
  # Update state
  s.lastPlusDIAbove = plusDIAbove
  
  result = newSignal(position, s.symbol, bar.close, reason)

proc reset*(s: ADXTrendStrategy) =
  ## Reset strategy state
  s.adxIndicator = newADX(s.period, memSize = 1)
  s.lastPlusDIAbove = false
  s.initialized = false

proc name*(s: ADXTrendStrategy): string =
  ## Return strategy name
  result = &"ADX Trend Strategy (threshold: {s.adxThreshold:.0f})"
