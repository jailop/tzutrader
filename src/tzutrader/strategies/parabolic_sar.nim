## Parabolic SAR Strategy for tzutrader
##
## Trend following strategy with dynamic trailing stops using Parabolic SAR.
##
## **Strategy Type**: Trend Following / Trailing Stop
##
## **Best Market Conditions**: Trending markets (both up and down)
##
## **Trading Logic**:
## - Buy when price crosses above SAR (trend reversal to uptrend)
## - Sell when price crosses below SAR (trend reversal to downtrend)
## - SAR provides dynamic stop-loss levels that accelerate with trend
##
## **Typical Parameters**:
## - acceleration: 0.02 (acceleration factor increment)
## - maximum: 0.20 (maximum acceleration factor)
##
## **Risk Profile**: Moderate, good for trending markets
##
## **Complementary Strategies**: Works well with ADX for trend strength filtering
##
## **Known Limitations**:
## - Generates many whipsaw signals in ranging/choppy markets
## - Best used with trend filters or in strongly trending markets
## - Late entry signals (reversal-based, not breakout-based)

import std/strformat
import ../core
import ../indicators
import base

export base.Strategy

type
  ParabolicSARStrategy* = ref object of Strategy
    ## Parabolic SAR strategy
    ## Trades trend reversals based on SAR crossovers
    acceleration*: float64
    maximum*: float64
    psarIndicator*: PSAR
    lastTrendUp*: bool
    initialized*: bool

proc newParabolicSARStrategy*(acceleration: float64 = 0.02, maximum: float64 = 0.20,
                               symbol: string = ""): ParabolicSARStrategy =
  ## Create a new Parabolic SAR strategy
  ## 
  ## Args:
  ##   acceleration: Acceleration factor step (default 0.02)
  ##   maximum: Maximum acceleration factor (default 0.20)
  ##   symbol: Symbol to trade (optional)
  ## 
  ## Returns:
  ##   New ParabolicSARStrategy instance
  result = ParabolicSARStrategy(
    acceleration: acceleration,
    maximum: maximum,
    psarIndicator: newPSAR(acceleration, maximum, memSize = 2),
    lastTrendUp: false,
    initialized: false
  )
  result.symbol = symbol

method onBar*(s: ParabolicSARStrategy, bar: OHLCV): Signal =
  ## Process single bar using streaming Parabolic SAR
  let psarResult = s.psarIndicator.update(bar.high, bar.low, bar.close)
  
  # Need at least 2 bars to generate signals
  if psarResult.sar.isNaN:
    return newSignal(Position.Stay, s.symbol, bar.close, "Insufficient data")
  
  var position = Position.Stay
  var reason = ""
  
  if not s.initialized:
    # Initialize state on first valid reading
    s.lastTrendUp = psarResult.isUptrend
    s.initialized = true
    reason = "Initialization"
  else:
    # Check for trend reversal
    if psarResult.isUptrend and not s.lastTrendUp:
      # Trend changed from down to up
      position = Position.Buy
      reason = &"Parabolic SAR reversal to uptrend (SAR: {psarResult.sar:.2f}, Price: {bar.close:.2f})"
    elif not psarResult.isUptrend and s.lastTrendUp:
      # Trend changed from up to down
      position = Position.Sell
      reason = &"Parabolic SAR reversal to downtrend (SAR: {psarResult.sar:.2f}, Price: {bar.close:.2f})"
    else:
      # No reversal
      reason = if psarResult.isUptrend: "In uptrend" else: "In downtrend"
  
  # Update state
  s.lastTrendUp = psarResult.isUptrend
  
  result = newSignal(position, s.symbol, bar.close, reason)

method reset*(s: ParabolicSARStrategy) =
  ## Reset strategy state
  s.psarIndicator = newPSAR(s.acceleration, s.maximum, memSize = 2)
  s.lastTrendUp = false
  s.initialized = false

method name*(s: ParabolicSARStrategy): string =
  ## Return strategy name
  result = "Parabolic SAR Strategy"
