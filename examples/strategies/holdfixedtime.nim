## Hold Fixed Time Strategy
## 
## This is a time based strategy. Shares are bought when there a strong
## reversion in prices. Those shares are hold for fixed period of time
## to be sell without considering the exit price.

import std/[times, strformat, strutils, tables, sequtils]
import tzutrader/[core, indicators, strategy, trader, data]
import circularqueue

type
  DiffDownStrat* = ref object of Strategy
    threshold*: float
    holdingPeriod*: int
    openSMA: SMA
    closeSMA: SMA
    entryTime: CircularQueue[int]
    hasEntered: bool

proc newDiffDownStrat*(symbol: string, smaPeriod: int, holdingPeriod: int,
    threshold: float): DiffDownStrat =
  result = DiffDownStrat(
    name: "DiffDownStrat",
    symbol: symbol,
    holdingPeriod: holdingPeriod,
    threshold: threshold,
    openSMA: newSMA(smaPeriod),
    closeSMA: newSMA(smaPeriod),
    entryTime: newCircularQueue[int](32),
    hasEntered: false
  )

method reset*(s: DiffDownStrat) =
  ## Reset strategy state
  s.hasEntered = false
  s.openSMA = newSMA(s.openSMA.period)
  s.closeSMA = newSMA(s.closeSMA.period)
  s.entryTime = newCircularQueue[int](32)

method onBar*(s: DiffDownStrat, bar: OHLCV): Signal =
  ## Process bar and generate trading signals
  # Update SMAs with close price
  discard s.openSMA.update(bar.close)
  discard s.closeSMA.update(bar.close)
  
  # Calculate difference
  let diff = s.closeSMA[0] - s.openSMA[0]
  
  # Initialize signal
  var signal = Signal(
    position: Position.Stay,
    symbol: s.symbol,
    timestamp: bar.timestamp,
    price: bar.close,
    reason: ""
  )
  
  # Skip if indicators not ready
  if diff.isNaN:
    return signal
  
  # Entry logic: diff < threshold and not already entered
  if not s.hasEntered and diff < s.threshold:
    signal.position = Position.Buy
    signal.price = bar.close
    signal.reason = &"Diff={diff:.4f} < threshold={s.threshold:.4f}"
    s.entryTime.enqueue(bar.timestamp)
    s.hasEntered = true
  
  # Early exit: diff >= threshold
  elif s.hasEntered and diff >= s.threshold:
    s.hasEntered = false
    signal.reason = &"Diff={diff:.4f} >= threshold={s.threshold:.4f} (early exit)"
  
  # Time-based exit: holding period elapsed
  if not s.entryTime.isEmpty and bar.timestamp - s.entryTime.peek >= s.holdingPeriod:
    signal.position = Position.Sell
    signal.price = bar.close
    signal.reason = &"Holding period elapsed ({s.holdingPeriod}s)"
    discard s.entryTime.dequeue()
  
  return signal
