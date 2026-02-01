## Dual Momentum Strategy for tzutrader
##
## Combines absolute momentum (rate of change) with trend confirmation (SMA).
##
## **Strategy Type**: Momentum + Trend Confirmation
##
## **Best Market Conditions**: Trending markets with sustained momentum
##
## **Trading Logic**:
## - Absolute momentum: ROC measures price change over time
## - Trend confirmation: Price vs SMA shows trend direction
## - Buy when: ROC > 0 AND price > SMA (positive momentum in uptrend)
## - Sell when: ROC < 0 OR price < SMA (negative momentum or downtrend)
## - Requires both signals to align for entry
##
## **Typical Parameters**:
## - rocPeriod: 12 (momentum lookback)
## - smaPeriod: 50 (trend confirmation)
##
## **Risk Profile**: Moderate, combines momentum with trend
##
## **Complementary Strategies**: Works well with volume confirmation
##
## **Known Limitations**:
## - Requires both signals to align (fewer trades)
## - May miss early momentum before trend confirmation
## - Can whipsaw in choppy markets
## - Momentum can reverse quickly

import std/strformat
import ../core
import ../indicators
import base

export base.Strategy

type
  DualMomentumStrategy* = ref object of Strategy
    ## Dual Momentum strategy
    ## Combines ROC momentum with SMA trend confirmation
    rocPeriod*: int
    smaPeriod*: int
    rocIndicator*: ROC
    smaIndicator*: MA
    lastPositiveRoc*: bool
    lastAboveSma*: bool
    initialized*: bool

proc newDualMomentumStrategy*(rocPeriod: int = 12, smaPeriod: int = 50,
                               symbol: string = ""): DualMomentumStrategy =
  ## Create a new Dual Momentum strategy
  ## 
  ## Args:
  ##   rocPeriod: Period for ROC momentum calculation (default 12)
  ##   smaPeriod: Period for SMA trend confirmation (default 50)
  ##   symbol: Symbol to trade (optional)
  ## 
  ## Returns:
  ##   New DualMomentumStrategy instance
  result = DualMomentumStrategy(
    rocPeriod: rocPeriod,
    smaPeriod: smaPeriod,
    rocIndicator: newROC(rocPeriod, memSize = 1),
    smaIndicator: newMA(smaPeriod, memSize = 1),
    lastPositiveRoc: false,
    lastAboveSma: false,
    initialized: false
  )
  result.symbol = symbol

proc onData*(s: DualMomentumStrategy, bar: OHLCV): Signal =
  ## Process single bar using streaming dual momentum logic
  let rocValue = s.rocIndicator.update(bar.close)
  let smaValue = s.smaIndicator.update(bar.close)
  
  # Need both ROC and SMA to be valid
  if rocValue.isNaN or smaValue.isNaN:
    return newSignal(Position.Stay, s.symbol, bar.close, "Insufficient data")
  
  # Check current conditions
  let positiveRoc = rocValue > 0.0
  let aboveSma = bar.close > smaValue
  
  var position = Position.Stay
  var reason = ""
  
  if not s.initialized:
    # Initialize state
    s.lastPositiveRoc = positiveRoc
    s.lastAboveSma = aboveSma
    s.initialized = true
    reason = &"Initialization (ROC: {rocValue:.2f}%, Price: {bar.close:.2f}, SMA: {smaValue:.2f})"
  else:
    # Check for signal conditions
    let bullishNow = positiveRoc and aboveSma
    let bearishNow = not positiveRoc or not aboveSma
    let wasBullish = s.lastPositiveRoc and s.lastAboveSma
    
    if bullishNow and not wasBullish:
      # Both momentum and trend turned positive
      position = Position.Buy
      reason = &"Dual momentum bullish (ROC: {rocValue:.2f}% > 0, Price: {bar.close:.2f} > SMA: {smaValue:.2f})"
    elif bearishNow and wasBullish:
      # Either momentum or trend turned negative
      position = Position.Sell
      if not positiveRoc:
        reason = &"Negative momentum (ROC: {rocValue:.2f}% < 0)"
      else:
        reason = &"Price below trend (Price: {bar.close:.2f} < SMA: {smaValue:.2f})"
    else:
      # No state change
      if bullishNow:
        reason = &"Maintaining bullish momentum (ROC: {rocValue:.2f}%, Price: {bar.close:.2f} > SMA: {smaValue:.2f})"
      else:
        let rocStatus = if positiveRoc: "positive" else: "negative"
        let trendStatus = if aboveSma: "above" else: "below"
        reason = &"Momentum {rocStatus}, price {trendStatus} SMA (ROC: {rocValue:.2f}%, Price: {bar.close:.2f}, SMA: {smaValue:.2f})"
    
    # Update state
    s.lastPositiveRoc = positiveRoc
    s.lastAboveSma = aboveSma
  
  result = newSignal(position, s.symbol, bar.close, reason)

proc reset*(s: DualMomentumStrategy) =
  ## Reset strategy state
  s.rocIndicator = newROC(s.rocPeriod, memSize = 1)
  s.smaIndicator = newMA(s.smaPeriod, memSize = 1)
  s.lastPositiveRoc = false
  s.lastAboveSma = false
  s.initialized = false

proc name*(s: DualMomentumStrategy): string =
  ## Return strategy name
  result = &"Dual Momentum Strategy (ROC: {s.rocPeriod}, SMA: {s.smaPeriod})"
