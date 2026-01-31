## Base strategy types and interface for tzutrader strategies
##
## This module defines the base Strategy class that all strategies inherit from.

import ../core

export core

type
  PositionSizingType* = enum
    ## How the strategy calculates position sizes
    pstDefault,   ## Use backtester default (95% of cash)
    pstFixed,     ## Fixed number of shares
    pstPercent    ## Percentage of portfolio equity
  
  Strategy* = ref object of RootObj
    ## Base strategy class
    ## All strategies should inherit from this
    ## Strategies are streaming-only and maintain minimal state
    name*: string
    symbol*: string

# Base methods that all strategies must implement

method name*(s: Strategy): string {.base.} =
  ## Get strategy name
  s.name

method analyze*(s: Strategy, data: seq[OHLCV]): seq[Signal] {.base.} =
  ## Analyze historical data and generate signals for each bar (batch mode)
  ## 
  ## **DEPRECATED**: Batch mode is deprecated. Use streaming onBar() instead.
  ## 
  ## This method processes all historical data at once. For real-time trading
  ## or more memory-efficient processing, use the onBar() method with streaming data.
  ## 
  ## Args:
  ##   data: Historical OHLCV data
  ## 
  ## Returns:
  ##   Sequence of signals, one for each bar
  raise newException(StrategyError, "analyze() batch mode is deprecated. Use onBar() for streaming mode.")

method onBar*(s: Strategy, bar: OHLCV): Signal {.base.} =
  ## Process a single bar and generate signal (streaming mode)
  ## 
  ## Args:
  ##   bar: Single OHLCV bar
  ## 
  ## Returns:
  ##   Signal with position recommendation
  raise newException(StrategyError, "onBar() not implemented for " & s.name)

method reset*(s: Strategy) {.base.} =
  ## Reset strategy state (for streaming mode)
  discard

method getPositionSizing*(s: Strategy): tuple[sizingType: PositionSizingType, value: float] {.base.} =
  ## Get position sizing preference for this strategy
  ## 
  ## Returns:
  ##   Tuple of (sizing type, value):
  ##   - (pstDefault, 0.0): Use backtester default (95% of cash)
  ##   - (pstFixed, N): Use fixed N shares
  ##   - (pstPercent, P): Use P percent of portfolio equity
  ## 
  ## Default implementation returns pstDefault
  result = (pstDefault, 0.0)
