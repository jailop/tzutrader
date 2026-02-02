import std/[tables, strutils, math]
import ../core

type
  IndicatorSnapshot* = Table[string, float64]
    ## Snapshot of all indicator values at a given bar

  IndicatorCache* = ref object
    ## Cache for indicator values across multiple bars
    current*: IndicatorSnapshot
    history*: seq[IndicatorSnapshot] # Historical snapshots
    maxHistory*: int                 # Maximum history to keep

proc newIndicatorCache*(maxHistory: int = 100): IndicatorCache =
  ## Create a new indicator cache with specified history depth
  result = IndicatorCache(
    current: initTable[string, float64](),
    history: @[],
    maxHistory: maxHistory
  )

proc update*(cache: IndicatorCache, snapshot: IndicatorSnapshot) =
  ## Update cache with new snapshot, rotating history
  cache.history.add(cache.current)
  cache.current = snapshot

  # Trim history if exceeds max
  if cache.history.len > cache.maxHistory:
    cache.history.delete(0)

proc getValue*(cache: IndicatorCache, key: string, lookback: int = 0): float64 =
  ## Get indicator value with optional lookback
  ## lookback = 0: current value
  ## lookback = 1: previous bar value
  ## lookback = 2: two bars ago, etc.
  if lookback == 0:
    return cache.current.getOrDefault(key, NaN)
  elif lookback <= cache.history.len:
    let idx = cache.history.len - lookback
    return cache.history[idx].getOrDefault(key, NaN)
  else:
    return NaN # Not enough history

proc setValue*(cache: IndicatorCache, key: string, value: float64) =
  ## Set a value in the current snapshot
  cache.current[key] = value

proc createSnapshot*(bar: OHLCV, indicators: Table[string,
    float64]): IndicatorSnapshot =
  ## Create a snapshot from bar data and indicator values
  result = initTable[string, float64]()

  # Add pseudo-indicators for bar data
  result["price"] = bar.close
  result["close"] = bar.close
  result["open"] = bar.open
  result["high"] = bar.high
  result["low"] = bar.low
  result["volume"] = bar.volume

  # Add all indicator values
  for key, value in indicators:
    result[key] = value

proc parseHistoricalReference*(refStr: string): tuple[name: string,
    lookback: int] =
  ## Parse a reference that may include historical lookback
  ## Examples:
  ##   "rsi_14" -> ("rsi_14", 0)
  ##   "rsi_14[1]" -> ("rsi_14", 1)
  ##   "price[2]" -> ("price", 2)

  # Check for bracket notation
  if '[' in refStr and refStr.endsWith(']'):
    let parts = refStr.split('[')
    if parts.len == 2:
      let name = parts[0]
      let lookbackStr = parts[1][0 .. ^2] # Remove closing bracket
      try:
        let lookback = parseInt(lookbackStr)
        return (name, lookback)
      except ValueError:
        discard

  # No historical reference
  return (refStr, 0)

proc isNaNOrMissing*(value: float64): bool {.inline.} =
  ## Check if a value is NaN or indicates missing data
  result = value.isNaN or value == Inf or value == -Inf
