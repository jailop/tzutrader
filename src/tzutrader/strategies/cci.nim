## Commodity Channel Index (CCI) Strategy for tzutrader
##
## Mean reversion strategy based on Commodity Channel Index.
##
## **Strategy Type**: Mean Reversion / Trend
##
## **Best Market Conditions**: Works in both trending and ranging markets
##
## **Trading Logic**:
## - Buy when CCI crosses above -100 from below (oversold reversal)
## - Sell when CCI crosses below +100 from above (overbought reversal)
## - CCI is unbounded, can signal extreme moves beyond ±100
##
## **Typical Parameters**:
## - period: 20 (standard CCI period)
## - oversoldLevel: -100 (buy threshold)
## - overboughtLevel: +100 (sell threshold)
## - Alternative thresholds: ±150 or ±200 for stronger signals
##
## **Risk Profile**: Moderate, suitable for cyclical price movements
##
## **Complementary Strategies**: Works well with trend confirmation
##
## **Known Limitations**:
## - Can produce many signals in choppy markets
## - Extreme readings (>±200) may indicate trend rather than reversal
## - Consider using ±100 for mean reversion, >±200 for trend following
## - No divergence detection currently implemented

import std/strformat
import ../core
import ../indicators
import base

export base.Strategy

type
  CCIStrategy* = ref object of Strategy
    ## Commodity Channel Index strategy
    ## Mean reversion based on CCI crossovers
    period*: int
    oversoldLevel*: float64
    overboughtLevel*: float64
    cciIndicator*: CCI
    lastAboveOverbought*: bool
    lastBelowOversold*: bool

proc newCCIStrategy*(period: int = 20, oversoldLevel: float64 = -100.0,
                     overboughtLevel: float64 = 100.0, symbol: string = ""): CCIStrategy =
  ## Create a new CCI strategy
  ## 
  ## Args:
  ##   period: CCI period (default 20)
  ##   oversoldLevel: Oversold threshold for buy signals (default -100)
  ##   overboughtLevel: Overbought threshold for sell signals (default +100)
  ##   symbol: Symbol to trade (optional)
  ## 
  ## Returns:
  ##   New CCI strategy instance
  result = CCIStrategy(
    name: "Commodity Channel Index Strategy",
    symbol: symbol,
    period: period,
    oversoldLevel: oversoldLevel,
    overboughtLevel: overboughtLevel,
    cciIndicator: newCCI(period),
    lastAboveOverbought: false,
    lastBelowOversold: false
  )

proc analyze*(s: CCIStrategy, data: seq[OHLCV]): seq[Signal] =
  ## **DEPRECATED**: Use onBar() for streaming mode instead.
  raise newException(StrategyError, "CCI analyze() batch mode deprecated. Use onBar() streaming mode.")

proc on*(s: CCIStrategy, bar: OHLCV): Signal =
  ## Process single bar using streaming CCI
  let cciVal = s.cciIndicator.update(bar.high, bar.low, bar.close)
  
  var position = Position.Stay
  var reason = ""
  
  if not cciVal.isNaN:
    let currentAboveOverbought = cciVal > s.overboughtLevel
    let currentBelowOversold = cciVal < s.oversoldLevel
    
    # Buy signal: CCI crosses above oversold level from below
    if s.lastBelowOversold and not currentBelowOversold and cciVal < 0:
      position = Position.Buy
      reason = &"CCI oversold reversal: {cciVal:.2f} crosses above {s.oversoldLevel:.2f}"
    
    # Sell signal: CCI crosses below overbought level from above
    elif s.lastAboveOverbought and not currentAboveOverbought and cciVal > 0:
      position = Position.Sell
      reason = &"CCI overbought reversal: {cciVal:.2f} crosses below {s.overboughtLevel:.2f}"
    
    else:
      # No signal
      position = Position.Stay
      if currentBelowOversold:
        reason = &"CCI oversold: {cciVal:.2f} < {s.oversoldLevel:.2f}"
      elif currentAboveOverbought:
        reason = &"CCI overbought: {cciVal:.2f} > {s.overboughtLevel:.2f}"
      else:
        reason = &"CCI neutral: {cciVal:.2f}"
    
    # Update state
    s.lastAboveOverbought = currentAboveOverbought
    s.lastBelowOversold = currentBelowOversold
  else:
    reason = "Insufficient data for CCI"
  
  result = Signal(
    position: position,
    symbol: s.symbol,
    timestamp: bar.timestamp,
    price: bar.close,
    reason: reason
  )

proc reset*(s: CCIStrategy) =
  ## Reset CCI strategy state
  s.cciIndicator = newCCI(s.period)
  s.lastAboveOverbought = false
  s.lastBelowOversold = false
