## Keltner Channel Strategy for tzutrader
##
## Volatility-based breakout or mean reversion strategy using Keltner Channels.
##
## **Strategy Type**: Volatility Breakout / Mean Reversion (configurable)
##
## **Best Market Conditions**: 
## - Breakout mode: Trending markets with volatility expansion
## - Reversion mode: Ranging markets with clear boundaries
##
## **Trading Logic**:
## - **Breakout Mode** (default):
##   - Buy when price breaks above upper band
##   - Sell when price breaks below lower band
## - **Reversion Mode**:
##   - Buy when price touches/crosses below lower band (oversold)
##   - Sell when price touches/crosses above upper band (overbought)
##
## **Channel Calculation**:
## - Middle line: EMA (typically 20-period)
## - Upper band: Middle + (multiplier × ATR)
## - Lower band: Middle - (multiplier × ATR)
##
## **Typical Parameters**:
## - emaPeriod: 20 (middle line)
## - atrPeriod: 10 (volatility measurement)
## - multiplier: 2.0 (band width)
## - mode: "breakout" or "reversion"
##
## **Risk Profile**: Moderate to High
##
## **Complementary Strategies**: Works well with volume confirmation or trend filters
##
## **Known Limitations**:
## - Breakout mode: False breakouts in ranging markets
## - Reversion mode: Can be caught in strong trends
## - Requires appropriate mode selection for market conditions

import std/strformat
import ../core
import ../indicators
import base

export base.Strategy

type
  KeltnerMode* = enum
    ## Keltner Channel trading mode
    Breakout    ## Trade breakouts above/below bands
    Reversion   ## Trade mean reversion at bands

type
  KeltnerChannelStrategy* = ref object of Strategy
    ## Keltner Channel strategy
    ## Trades volatility expansion (breakout) or contraction (reversion)
    emaPeriod*: int
    atrPeriod*: int
    multiplier*: float64
    mode*: KeltnerMode
    emaIndicator*: EMA
    atrIndicator*: ATR
    lastAboveUpper*: bool
    lastBelowLower*: bool
    initialized*: bool

proc newKeltnerChannelStrategy*(emaPeriod: int = 20, atrPeriod: int = 10,
                                 multiplier: float64 = 2.0, mode: KeltnerMode = Breakout,
                                 symbol: string = ""): KeltnerChannelStrategy =
  ## Create a new Keltner Channel strategy
  ## 
  ## Args:
  ##   emaPeriod: Period for middle EMA line (default 20)
  ##   atrPeriod: Period for ATR calculation (default 10)
  ##   multiplier: ATR multiplier for band width (default 2.0)
  ##   mode: Trading mode - Breakout or Reversion (default Breakout)
  ##   symbol: Symbol to trade (optional)
  ## 
  ## Returns:
  ##   New KeltnerChannelStrategy instance
  result = KeltnerChannelStrategy(
    emaPeriod: emaPeriod,
    atrPeriod: atrPeriod,
    multiplier: multiplier,
    mode: mode,
    emaIndicator: newEMA(emaPeriod, memSize = 1),
    atrIndicator: newATR(atrPeriod, memSize = 1),
    lastAboveUpper: false,
    lastBelowLower: false,
    initialized: false
  )
  result.symbol = symbol

proc onData*(s: KeltnerChannelStrategy, bar: OHLCV): Signal =
  ## Process single bar using streaming Keltner Channels
  let emaValue = s.emaIndicator.update(bar.close)
  let atrValue = s.atrIndicator.update(bar.low, bar.high, bar.close)
  
  # Need both EMA and ATR to be valid
  if emaValue.isNaN or atrValue.isNaN:
    return newSignal(Position.Stay, s.symbol, bar.close, "Insufficient data")
  
  # Calculate Keltner Channel bands
  let middle = emaValue
  let upper = middle + (s.multiplier * atrValue)
  let lower = middle - (s.multiplier * atrValue)
  
  # Check position relative to bands
  let aboveUpper = bar.close > upper
  let belowLower = bar.close < lower
  
  var position = Position.Stay
  var reason = ""
  
  if not s.initialized:
    # Initialize state
    s.lastAboveUpper = aboveUpper
    s.lastBelowLower = belowLower
    s.initialized = true
    reason = "Initialization"
  else:
    # Generate signals based on mode
    if s.mode == Breakout:
      # Breakout mode: Trade breakouts through bands
      if aboveUpper and not s.lastAboveUpper:
        position = Position.Buy
        reason = &"Breakout above upper Keltner band (Price: {bar.close:.2f}, Upper: {upper:.2f})"
      elif belowLower and not s.lastBelowLower:
        position = Position.Sell
        reason = &"Breakdown below lower Keltner band (Price: {bar.close:.2f}, Lower: {lower:.2f})"
      else:
        reason = &"Within bands (Price: {bar.close:.2f}, Range: {lower:.2f}-{upper:.2f})"
    else:
      # Reversion mode: Trade mean reversion at bands
      if belowLower and not s.lastBelowLower:
        position = Position.Buy
        reason = &"Mean reversion buy at lower band (Price: {bar.close:.2f}, Lower: {lower:.2f})"
      elif aboveUpper and not s.lastAboveUpper:
        position = Position.Sell
        reason = &"Mean reversion sell at upper band (Price: {bar.close:.2f}, Upper: {upper:.2f})"
      else:
        reason = &"Within bands (Price: {bar.close:.2f}, Range: {lower:.2f}-{upper:.2f})"
  
  # Update state
  s.lastAboveUpper = aboveUpper
  s.lastBelowLower = belowLower
  
  result = newSignal(position, s.symbol, bar.close, reason)

proc reset*(s: KeltnerChannelStrategy) =
  ## Reset strategy state
  s.emaIndicator = newEMA(s.emaPeriod, memSize = 1)
  s.atrIndicator = newATR(s.atrPeriod, memSize = 1)
  s.lastAboveUpper = false
  s.lastBelowLower = false
  s.initialized = false

proc name*(s: KeltnerChannelStrategy): string =
  ## Return strategy name
  let modeStr = if s.mode == Breakout: "Breakout" else: "Reversion"
  result = &"Keltner Channel Strategy ({modeStr})"
