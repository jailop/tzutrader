## Mean Reversion with Trend Filter Strategy for tzutrader
##
## Hybrid strategy combining RSI mean reversion with EMA trend filter.
##
## **Strategy Type**: Mean Reversion + Trend Filter (Hybrid)
##
## **Best Market Conditions**: Trending markets with pullbacks
##
## **Trading Logic**:
## - Only take mean reversion trades in direction of long-term trend
## - Long-term trend: Price vs EMA (typically 200-period)
## - Buy: RSI oversold (<30) AND price > EMA (uptrend)
## - Sell: RSI overbought (>70) OR price < EMA (trend break)
## - Filters out counter-trend mean reversion trades
##
## **Typical Parameters**:
## - rsiPeriod: 14 (RSI calculation)
## - trendPeriod: 200 (long-term trend EMA)
## - oversold: 30.0 (RSI buy threshold)
## - overbought: 70.0 (RSI sell threshold)
##
## **Risk Profile**: Conservative, only trades with-trend pullbacks
##
## **Complementary Strategies**: Works well with volume confirmation
##
## **Known Limitations**:
## - Requires established trend (no signals in trendless markets)
## - May miss opportunities in strong counter-trend moves
## - Long-term EMA is slow to adapt
## - Fewer trading opportunities than pure mean reversion

import std/strformat
import ../core
import ../indicators
import base

export base.Strategy

type
  FilteredMeanReversionStrategy* = ref object of Strategy
    ## Mean Reversion with Trend Filter strategy
    ## Uses RSI for mean reversion but only in direction of trend
    rsiPeriod*: int
    trendPeriod*: int
    oversold*: float64
    overbought*: float64
    rsiIndicator*: RSI
    trendEMA*: EMA
    lastInUptrend*: bool
    lastRsiOversold*: bool
    lastRsiOverbought*: bool
    initialized*: bool

proc newFilteredMeanReversionStrategy*(rsiPeriod: int = 14, trendPeriod: int = 200,
                                        oversold: float64 = 30.0, overbought: float64 = 70.0,
                                        symbol: string = ""): FilteredMeanReversionStrategy =
  ## Create a new Filtered Mean Reversion strategy
  ## 
  ## Args:
  ##   rsiPeriod: Period for RSI calculation (default 14)
  ##   trendPeriod: Period for trend EMA (default 200)
  ##   oversold: RSI oversold threshold for buy signals (default 30.0)
  ##   overbought: RSI overbought threshold for sell signals (default 70.0)
  ##   symbol: Symbol to trade (optional)
  ## 
  ## Returns:
  ##   New FilteredMeanReversionStrategy instance
  result = FilteredMeanReversionStrategy(
    rsiPeriod: rsiPeriod,
    trendPeriod: trendPeriod,
    oversold: oversold,
    overbought: overbought,
    rsiIndicator: newRSI(rsiPeriod, memSize = 1),
    trendEMA: newEMA(trendPeriod, memSize = 1),
    lastInUptrend: false,
    lastRsiOversold: false,
    lastRsiOverbought: false,
    initialized: false
  )
  result.symbol = symbol

method onBar*(s: FilteredMeanReversionStrategy, bar: OHLCV): Signal =
  ## Process single bar using streaming filtered mean reversion logic
  let rsiValue = s.rsiIndicator.update(bar.open, bar.close)
  let emaValue = s.trendEMA.update(bar.close)
  
  # Need both RSI and EMA to be valid
  if rsiValue.isNaN or emaValue.isNaN:
    return newSignal(Position.Stay, s.symbol, bar.close, "Insufficient data")
  
  # Check current conditions
  let inUptrend = bar.close > emaValue
  let rsiOversold = rsiValue < s.oversold
  let rsiOverbought = rsiValue > s.overbought
  
  var position = Position.Stay
  var reason = ""
  
  if not s.initialized:
    # Initialize state
    s.lastInUptrend = inUptrend
    s.lastRsiOversold = rsiOversold
    s.lastRsiOverbought = rsiOverbought
    s.initialized = true
    let trendStatus = if inUptrend: "uptrend" else: "downtrend"
    reason = &"Initialization ({trendStatus}, RSI: {rsiValue:.2f})"
  else:
    # Check for signal conditions
    
    # Buy: RSI becomes oversold while in uptrend (with-trend pullback)
    if rsiOversold and not s.lastRsiOversold and inUptrend:
      position = Position.Buy
      reason = &"RSI oversold in uptrend - pullback buy opportunity (RSI: {rsiValue:.2f} < {s.oversold:.0f}, Price: {bar.close:.2f} > EMA: {emaValue:.2f})"
    
    # Sell conditions:
    # 1. RSI becomes overbought (take profit on mean reversion)
    # 2. Price breaks below EMA (trend broken)
    elif (rsiOverbought and not s.lastRsiOverbought) or (not inUptrend and s.lastInUptrend):
      position = Position.Sell
      if rsiOverbought and not s.lastRsiOverbought:
        reason = &"RSI overbought - mean reversion complete (RSI: {rsiValue:.2f} > {s.overbought:.0f})"
      else:
        reason = &"Price broke below trend EMA (Price: {bar.close:.2f} < EMA: {emaValue:.2f})"
    else:
      # No signal
      let trendStatus = if inUptrend: "uptrend" else: "downtrend"
      if rsiOversold and not inUptrend:
        reason = &"RSI oversold but in downtrend - no trade (RSI: {rsiValue:.2f}, {trendStatus})"
      else:
        reason = &"No signal ({trendStatus}, RSI: {rsiValue:.2f})"
    
    # Update state
    s.lastInUptrend = inUptrend
    s.lastRsiOversold = rsiOversold
    s.lastRsiOverbought = rsiOverbought
  
  result = newSignal(position, s.symbol, bar.close, reason)

method reset*(s: FilteredMeanReversionStrategy) =
  ## Reset strategy state
  s.rsiIndicator = newRSI(s.rsiPeriod, memSize = 1)
  s.trendEMA = newEMA(s.trendPeriod, memSize = 1)
  s.lastInUptrend = false
  s.lastRsiOversold = false
  s.lastRsiOverbought = false
  s.initialized = false

method name*(s: FilteredMeanReversionStrategy): string =
  ## Return strategy name
  result = &"Filtered Mean Reversion Strategy (RSI: {s.rsiPeriod}, EMA: {s.trendPeriod})"
