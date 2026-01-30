## KAMA (Kaufman Adaptive Moving Average) Strategy for tzutrader
##
## Adaptive trend-following strategy that adjusts to market volatility.
##
## **Strategy Type**: Adaptive Trend Following
##
## **Best Market Conditions**: All market conditions (adapts automatically)
##
## **Trading Logic**:
## - Buy when price crosses above KAMA
## - Sell when price crosses below KAMA
## - KAMA automatically adjusts smoothing based on market efficiency
## - In trending markets: KAMA becomes more responsive (like fast EMA)
## - In choppy markets: KAMA becomes smoother (like slow SMA)
##
## **Typical Parameters**:
## - period: 10 (efficiency ratio lookback)
## - fastPeriod: 2 (fast smoothing constant for trends)
## - slowPeriod: 30 (slow smoothing constant for chop)
##
## **Risk Profile**: Moderate to conservative, adapts to conditions
##
## **Complementary Strategies**: Works well standalone or with volume confirmation
##
## **Known Limitations**:
## - Still lags at major trend reversals (adaptive but not predictive)
## - May switch too quickly in transitional periods
## - Optimal parameters vary by asset and timeframe
## - Consider longer period (20-30) for smoother operation

import std/strformat
import ../core
import ../indicators
import base

export base.Strategy

type
  KAMAStrategy* = ref object of Strategy
    ## KAMA (Kaufman Adaptive Moving Average) strategy
    ## Adaptive trend following based on market efficiency
    period*: int
    fastPeriod*: int
    slowPeriod*: int
    kamaIndicator*: KAMA
    lastPriceAbove*: bool
    initialized*: bool

proc newKAMAStrategy*(period: int = 10, fastPeriod: int = 2, slowPeriod: int = 30,
                      symbol: string = ""): KAMAStrategy =
  ## Create a new KAMA strategy
  ## 
  ## Args:
  ##   period: Efficiency ratio period (default 10)
  ##   fastPeriod: Fast smoothing period for trending markets (default 2)
  ##   slowPeriod: Slow smoothing period for choppy markets (default 30)
  ##   symbol: Symbol to trade (optional)
  ## 
  ## Returns:
  ##   New KAMA strategy instance
  result = KAMAStrategy(
    name: "KAMA Strategy",
    symbol: symbol,
    period: period,
    fastPeriod: fastPeriod,
    slowPeriod: slowPeriod,
    kamaIndicator: newKAMA(period, fastPeriod, slowPeriod),
    lastPriceAbove: false,
    initialized: false
  )

method analyze*(s: KAMAStrategy, data: seq[OHLCV]): seq[Signal] =
  ## **DEPRECATED**: Use onBar() for streaming mode instead.
  raise newException(StrategyError, "KAMA analyze() batch mode deprecated. Use onBar() streaming mode.")

method onBar*(s: KAMAStrategy, bar: OHLCV): Signal =
  ## Process single bar using streaming KAMA
  let kamaVal = s.kamaIndicator.update(bar.close)
  
  var position = Position.Stay
  var reason = ""
  
  if not kamaVal.isNaN:
    let currentPriceAbove = bar.close > kamaVal
    
    # Only generate signals after initialization
    if s.initialized:
      # Buy signal: price crosses above KAMA
      if not s.lastPriceAbove and currentPriceAbove:
        position = Position.Buy
        reason = &"Price crosses above KAMA: ${bar.close:.2f} > ${kamaVal:.2f}"
      
      # Sell signal: price crosses below KAMA
      elif s.lastPriceAbove and not currentPriceAbove:
        position = Position.Sell
        reason = &"Price crosses below KAMA: ${bar.close:.2f} < ${kamaVal:.2f}"
      
      else:
        # No crossover
        position = Position.Stay
        if currentPriceAbove:
          reason = &"Price above KAMA: ${bar.close:.2f} > ${kamaVal:.2f}"
        else:
          reason = &"Price below KAMA: ${bar.close:.2f} < ${kamaVal:.2f}"
    else:
      # First valid KAMA value - initialize state
      s.initialized = true
      position = Position.Stay
      if currentPriceAbove:
        reason = &"KAMA initialized, price above: ${bar.close:.2f} > ${kamaVal:.2f}"
      else:
        reason = &"KAMA initialized, price below: ${bar.close:.2f} < ${kamaVal:.2f}"
    
    s.lastPriceAbove = currentPriceAbove
  else:
    reason = "Insufficient data for KAMA"
  
  result = Signal(
    position: position,
    symbol: s.symbol,
    timestamp: bar.timestamp,
    price: bar.close,
    reason: reason
  )

method reset*(s: KAMAStrategy) =
  ## Reset KAMA strategy state
  s.kamaIndicator = newKAMA(s.period, s.fastPeriod, s.slowPeriod)
  s.lastPriceAbove = false
  s.initialized = false
