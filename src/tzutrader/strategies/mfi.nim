## Money Flow Index (MFI) Strategy for tzutrader
##
## Volume-weighted momentum strategy based on Money Flow Index.
##
## **Strategy Type**: Momentum / Volume-Weighted
##
## **Best Market Conditions**: Markets where volume provides meaningful signals
##
## **Trading Logic**:
## - Buy when MFI crosses above oversold threshold (default 20)
## - Sell when MFI crosses below overbought threshold (default 80)
## - MFI combines price and volume, providing better confirmation than RSI alone
##
## **Typical Parameters**:
## - period: 14 (standard MFI period)
## - oversold: 20.0 (buy threshold)
## - overbought: 80.0 (sell threshold)
##
## **Risk Profile**: Moderate, volume confirmation reduces false signals
##
## **Complementary Strategies**: Works well with price pattern recognition
##
## **Known Limitations**:
## - Requires reliable volume data
## - Can stay overbought/oversold for extended periods in trends
## - Less effective in low-volume or manipulated markets
## - Consider divergence analysis for stronger signals (not yet implemented)

import std/strformat
import ../core
import ../indicators
import base

export base.Strategy

type
  MFIStrategy* = ref object of Strategy
    ## Money Flow Index strategy
    ## Volume-weighted momentum indicator for overbought/oversold conditions
    period*: int
    oversold*: float64
    overbought*: float64
    mfiIndicator*: MFI
    lastSignal*: Position

proc newMFIStrategy*(period: int = 14, oversold: float64 = 20.0,
                     overbought: float64 = 80.0, symbol: string = ""): MFIStrategy =
  ## Create a new Money Flow Index strategy
  ## 
  ## Args:
  ##   period: MFI period (default 14)
  ##   oversold: Oversold threshold for buy signals (default 20)
  ##   overbought: Overbought threshold for sell signals (default 80)
  ##   symbol: Symbol to trade (optional)
  ## 
  ## Returns:
  ##   New MFI strategy instance
  result = MFIStrategy(
    name: "Money Flow Index Strategy",
    symbol: symbol,
    period: period,
    oversold: oversold,
    overbought: overbought,
    mfiIndicator: newMFI(period),
    lastSignal: Position.Stay
  )

proc analyze*(s: MFIStrategy, data: seq[OHLCV]): seq[Signal] =
  ## **DEPRECATED**: Use onBar() for streaming mode instead.
  raise newException(StrategyError, "MFI analyze() batch mode deprecated. Use onBar() streaming mode.")

proc onData*(s: MFIStrategy, bar: OHLCV): Signal =
  ## Process single bar using streaming MFI
  let mfiVal = s.mfiIndicator.update(bar.high, bar.low, bar.close, bar.volume)
  
  var position = Position.Stay
  var reason = ""
  
  if not mfiVal.isNaN:
    # Buy when MFI is oversold (and we haven't already signaled buy)
    if mfiVal < s.oversold and s.lastSignal != Position.Buy:
      position = Position.Buy
      reason = &"MFI oversold: {mfiVal:.2f} < {s.oversold:.2f}"
      s.lastSignal = Position.Buy
    
    # Sell when MFI is overbought (and we haven't already signaled sell)
    elif mfiVal > s.overbought and s.lastSignal != Position.Sell:
      position = Position.Sell
      reason = &"MFI overbought: {mfiVal:.2f} > {s.overbought:.2f}"
      s.lastSignal = Position.Sell
    
    else:
      # No signal
      position = Position.Stay
      if mfiVal < s.oversold:
        reason = &"MFI oversold (already signaled): {mfiVal:.2f}"
      elif mfiVal > s.overbought:
        reason = &"MFI overbought (already signaled): {mfiVal:.2f}"
      else:
        reason = &"MFI neutral: {mfiVal:.2f}"
  else:
    reason = "Insufficient data for MFI"
  
  result = Signal(
    position: position,
    symbol: s.symbol,
    timestamp: bar.timestamp,
    price: bar.close,
    reason: reason
  )

proc reset*(s: MFIStrategy) =
  ## Reset MFI strategy state
  s.mfiIndicator = newMFI(s.period)
  s.lastSignal = Position.Stay
