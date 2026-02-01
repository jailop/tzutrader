## Bollinger Bands Strategy for tzutrader
##
## Mean reversion strategy based on Bollinger Bands volatility indicator.
##
## **Strategy Type**: Mean Reversion / Volatility
##
## **Best Market Conditions**: Ranging markets with normal volatility
##
## **Trading Logic**:
## - Buy when price touches or breaks below lower band (oversold)
## - Sell when price touches or breaks above upper band (overbought)
## - Exit signals when price returns near middle band
##
## **Typical Parameters**:
## - period: 20 (standard BB period)
## - stdDev: 2.0 (number of standard deviations)
## - Alternative: 2.5 or 3.0 for wider bands
##
## **Risk Profile**: Moderate, assumes mean reversion behavior
##
## **Complementary Strategies**: Works well with volume or RSI confirmation
##
## **Known Limitations**:
## - Poor performance in strong trending markets
## - Band touches can persist in trends ("walking the bands")
## - Consider adding trend filter for better results

import std/[strformat, math]
import ../core
import ../indicators
import base

export base.Strategy

type
  BollingerStrategy* = ref object of Strategy
    ## Bollinger Bands mean reversion strategy
    ## Buy when price touches lower band, sell when price touches upper band
    period*: int
    stdDev*: float64
    bbIndicator*: BollingerBands
    lastPosition*: Position

proc newBollingerStrategy*(period: int = 20, stdDev: float64 = 2.0,
                           symbol: string = ""): BollingerStrategy =
  ## Create a new Bollinger Bands strategy
  ## 
  ## Args:
  ##   period: BB period (default 20)
  ##   stdDev: Number of standard deviations (default 2.0)
  ##   symbol: Symbol to trade (optional)
  ## 
  ## Returns:
  ##   New Bollinger Bands strategy instance
  result = BollingerStrategy(
    name: "Bollinger Bands Strategy",
    symbol: symbol,
    period: period,
    stdDev: stdDev,
    bbIndicator: newBollingerBands(period, stdDev),
    lastPosition: Position.Stay
  )

proc analyze*(s: BollingerStrategy, data: seq[OHLCV]): seq[Signal] =
  ## **DEPRECATED**: Use onBar() for streaming mode instead.
  raise newException(StrategyError, "Bollinger analyze() batch mode deprecated. Use onBar() streaming mode.")

proc onData*(s: BollingerStrategy, bar: OHLCV): Signal =
  ## Process single bar using streaming Bollinger Bands
  let bb = s.bbIndicator.update(bar.close)
  
  var position = Position.Stay
  var reason = ""
  
  if not bb.upper.isNaN and not bb.lower.isNaN:
    let currentPrice = bar.close
    
    # Buy when price is at or below lower band (oversold)
    if currentPrice <= bb.lower:
      position = Position.Buy
      reason = &"Price at lower band: ${currentPrice:.2f} <= ${bb.lower:.2f}"
    # Sell when price is at or above upper band (overbought)
    elif currentPrice >= bb.upper:
      position = Position.Sell
      reason = &"Price at upper band: ${currentPrice:.2f} >= ${bb.upper:.2f}"
    # Exit when price returns to middle
    elif abs(currentPrice - bb.middle) < (bb.upper - bb.middle) * 0.3:
      position = Position.Stay
      reason = &"Price near middle band: ${currentPrice:.2f} ≈ ${bb.middle:.2f}"
    else:
      position = Position.Stay
      reason = &"Price within bands: ${bb.lower:.2f} < ${currentPrice:.2f} < ${bb.upper:.2f}"
  else:
    reason = "Insufficient data for Bollinger Bands"
  
  result = Signal(
    position: position,
    symbol: s.symbol,
    timestamp: bar.timestamp,
    price: bar.close,
    reason: reason
  )

proc reset*(s: BollingerStrategy) =
  ## Reset Bollinger strategy state
  s.bbIndicator = newBollingerBands(s.period, s.stdDev)
  s.lastPosition = Position.Stay
