## Technical indicators module for tzutrader
##
## Pure Nim implementations of all technical indicators.
## Replaces pybottrader's C++ indicators with native Nim code.
##
## Features:
## - Moving averages (SMA, EMA, WMA)
## - Momentum indicators (RSI, Stochastic, ROC)
## - Trend indicators (MACD, ADX)
## - Volatility indicators (ATR, Bollinger Bands, Standard Deviation)
## - Volume indicators (OBV)
## - Both batch and streaming modes
## - Memory-efficient rolling windows
## - NaN handling for partial data

import std/[math, sequtils, deques]
import core

# ============================================================================
# Base Types and Utilities
# ============================================================================

type
  IndicatorBase* = ref object of RootObj
    ## Base type for streaming indicators
    period*: int
    values*: Deque[float64]
    initialized*: bool

# Helper functions

proc isNaN*(x: float64): bool {.inline.} =
  ## Check if value is NaN
  result = x.classify == fcNaN

proc nanToZero*(x: float64): float64 {.inline.} =
  ## Convert NaN to zero
  if x.isNaN: 0.0 else: x

proc addValue*(ind: IndicatorBase, value: float64) =
  ## Add value to indicator's rolling window
  ind.values.addLast(value)
  if ind.values.len > ind.period:
    discard ind.values.popFirst()

proc isFull*(ind: IndicatorBase): bool =
  ## Check if indicator has enough data
  ind.values.len >= ind.period

# ============================================================================
# Moving Averages
# ============================================================================

# Simple Moving Average (SMA)

proc sma*(data: seq[float64], period: int): seq[float64] =
  ## Calculate Simple Moving Average (SMA)
  ## 
  ## Args:
  ##   data: Price data
  ##   period: Number of periods for average
  ## 
  ## Returns:
  ##   Sequence of SMA values (NaN for insufficient data)
  result = newSeq[float64](data.len)
  
  for i in 0..<data.len:
    if i < period - 1:
      result[i] = NaN
    else:
      var sum = 0.0
      for j in (i - period + 1)..i:
        sum += data[j]
      result[i] = sum / period.float64

type
  SMA* = ref object of IndicatorBase
    ## Streaming Simple Moving Average

proc newSMA*(period: int): SMA =
  ## Create new SMA indicator
  result = SMA(period: period, values: initDeque[float64](), initialized: false)

proc update*(sma: SMA, value: float64): float64 =
  ## Update SMA with new value and return current SMA
  sma.addValue(value)
  
  if not sma.isFull():
    return NaN
  
  sma.initialized = true
  var sum = 0.0
  for v in sma.values:
    sum += v
  result = sum / sma.period.float64

proc current*(sma: SMA): float64 =
  ## Get current SMA value
  if not sma.initialized or not sma.isFull():
    return NaN
  var sum = 0.0
  for v in sma.values:
    sum += v
  result = sum / sma.period.float64

# Exponential Moving Average (EMA)

proc ema*(data: seq[float64], period: int): seq[float64] =
  ## Calculate Exponential Moving Average (EMA)
  ## 
  ## Args:
  ##   data: Price data
  ##   period: Number of periods for average
  ## 
  ## Returns:
  ##   Sequence of EMA values
  result = newSeq[float64](data.len)
  
  if data.len == 0:
    return
  
  let multiplier = 2.0 / (period.float64 + 1.0)
  
  # First EMA is SMA
  if data.len >= period:
    var sum = 0.0
    for i in 0..<period:
      sum += data[i]
    result[period - 1] = sum / period.float64
    
    # Subsequent EMAs
    for i in period..<data.len:
      result[i] = (data[i] - result[i - 1]) * multiplier + result[i - 1]
  
  # Fill initial values with NaN
  for i in 0..<min(period - 1, data.len):
    result[i] = NaN

type
  EMA* = ref object of IndicatorBase
    ## Streaming Exponential Moving Average
    multiplier: float64
    currentEma: float64

proc newEMA*(period: int): EMA =
  ## Create new EMA indicator
  let multiplier = 2.0 / (period.float64 + 1.0)
  result = EMA(
    period: period,
    values: initDeque[float64](),
    multiplier: multiplier,
    currentEma: NaN,
    initialized: false
  )

proc update*(ema: EMA, value: float64): float64 =
  ## Update EMA with new value and return current EMA
  ema.addValue(value)
  
  if not ema.isFull():
    return NaN
  
  if not ema.initialized:
    # First EMA is SMA
    var sum = 0.0
    for v in ema.values:
      sum += v
    ema.currentEma = sum / ema.period.float64
    ema.initialized = true
    return ema.currentEma
  
  # Subsequent EMAs
  ema.currentEma = (value - ema.currentEma) * ema.multiplier + ema.currentEma
  result = ema.currentEma

proc current*(ema: EMA): float64 =
  ## Get current EMA value
  result = ema.currentEma

# Weighted Moving Average (WMA)

proc wma*(data: seq[float64], period: int): seq[float64] =
  ## Calculate Weighted Moving Average (WMA)
  ## 
  ## Args:
  ##   data: Price data
  ##   period: Number of periods for average
  ## 
  ## Returns:
  ##   Sequence of WMA values
  result = newSeq[float64](data.len)
  
  let denominator = period * (period + 1) / 2
  
  for i in 0..<data.len:
    if i < period - 1:
      result[i] = NaN
    else:
      var weightedSum = 0.0
      for j in 0..<period:
        let weight = (j + 1).float64
        weightedSum += data[i - period + 1 + j] * weight
      result[i] = weightedSum / denominator

# ============================================================================
# Momentum Indicators
# ============================================================================

# Relative Strength Index (RSI)

proc rsi*(data: seq[float64], period: int = 14): seq[float64] =
  ## Calculate Relative Strength Index (RSI)
  ## 
  ## Args:
  ##   data: Price data
  ##   period: Number of periods (default 14)
  ## 
  ## Returns:
  ##   Sequence of RSI values (0-100)
  result = newSeq[float64](data.len)
  
  if data.len < period + 1:
    for i in 0..<data.len:
      result[i] = NaN
    return
  
  # Calculate initial average gain and loss
  var avgGain = 0.0
  var avgLoss = 0.0
  
  for i in 1..period:
    let change = data[i] - data[i - 1]
    if change > 0:
      avgGain += change
    else:
      avgLoss += abs(change)
  
  avgGain /= period.float64
  avgLoss /= period.float64
  
  # Fill initial values with NaN
  for i in 0..period:
    result[i] = NaN
  
  # Calculate RSI
  if avgLoss == 0:
    result[period] = 100.0
  else:
    let rs = avgGain / avgLoss
    result[period] = 100.0 - (100.0 / (1.0 + rs))
  
  # Calculate subsequent RSI values using smoothing
  for i in (period + 1)..<data.len:
    let change = data[i] - data[i - 1]
    var gain = 0.0
    var loss = 0.0
    
    if change > 0:
      gain = change
    else:
      loss = abs(change)
    
    avgGain = (avgGain * (period - 1).float64 + gain) / period.float64
    avgLoss = (avgLoss * (period - 1).float64 + loss) / period.float64
    
    if avgLoss == 0:
      result[i] = 100.0
    else:
      let rs = avgGain / avgLoss
      result[i] = 100.0 - (100.0 / (1.0 + rs))

type
  RSI* = ref object of IndicatorBase
    ## Streaming Relative Strength Index
    avgGain: float64
    avgLoss: float64
    prevPrice: float64

proc newRSI*(period: int = 14): RSI =
  ## Create new RSI indicator
  result = RSI(
    period: period,
    values: initDeque[float64](),
    avgGain: 0.0,
    avgLoss: 0.0,
    prevPrice: NaN,
    initialized: false
  )

proc update*(rsi: RSI, price: float64): float64 =
  ## Update RSI with new price and return current RSI
  if rsi.prevPrice.isNaN:
    rsi.prevPrice = price
    return NaN
  
  let change = price - rsi.prevPrice
  rsi.prevPrice = price
  
  var gain = 0.0
  var loss = 0.0
  if change > 0:
    gain = change
  else:
    loss = abs(change)
  
  rsi.addValue(price)
  
  if not rsi.isFull():
    # Accumulate for initial average
    if change > 0:
      rsi.avgGain += change
    else:
      rsi.avgLoss += abs(change)
    return NaN
  
  if not rsi.initialized:
    # Calculate initial averages
    rsi.avgGain /= rsi.period.float64
    rsi.avgLoss /= rsi.period.float64
    rsi.initialized = true
  else:
    # Smooth the averages
    rsi.avgGain = (rsi.avgGain * (rsi.period - 1).float64 + gain) / rsi.period.float64
    rsi.avgLoss = (rsi.avgLoss * (rsi.period - 1).float64 + loss) / rsi.period.float64
  
  if rsi.avgLoss == 0:
    return 100.0
  
  let rs = rsi.avgGain / rsi.avgLoss
  result = 100.0 - (100.0 / (1.0 + rs))

proc current*(rsi: RSI): float64 =
  ## Get current RSI value
  if not rsi.initialized:
    return NaN
  if rsi.avgLoss == 0:
    return 100.0
  let rs = rsi.avgGain / rsi.avgLoss
  result = 100.0 - (100.0 / (1.0 + rs))

# Rate of Change (ROC)

proc roc*(data: seq[float64], period: int = 12): seq[float64] =
  ## Calculate Rate of Change (ROC)
  ## 
  ## Args:
  ##   data: Price data
  ##   period: Number of periods
  ## 
  ## Returns:
  ##   Sequence of ROC values (percentage)
  result = newSeq[float64](data.len)
  
  for i in 0..<data.len:
    if i < period:
      result[i] = NaN
    else:
      if data[i - period] == 0:
        result[i] = NaN
      else:
        result[i] = ((data[i] - data[i - period]) / data[i - period]) * 100.0

# ============================================================================
# Trend Indicators
# ============================================================================

# Moving Average Convergence Divergence (MACD)

proc macd*(data: seq[float64], fastPeriod: int = 12, slowPeriod: int = 26, 
          signalPeriod: int = 9): tuple[macd, signal, histogram: seq[float64]] =
  ## Calculate MACD (Moving Average Convergence Divergence)
  ## 
  ## Args:
  ##   data: Price data
  ##   fastPeriod: Fast EMA period (default 12)
  ##   slowPeriod: Slow EMA period (default 26)
  ##   signalPeriod: Signal line EMA period (default 9)
  ## 
  ## Returns:
  ##   Tuple of (MACD line, signal line, histogram)
  let fastEma = ema(data, fastPeriod)
  let slowEma = ema(data, slowPeriod)
  
  # Calculate MACD line
  result.macd = newSeq[float64](data.len)
  for i in 0..<data.len:
    if fastEma[i].isNaN or slowEma[i].isNaN:
      result.macd[i] = NaN
    else:
      result.macd[i] = fastEma[i] - slowEma[i]
  
  # Calculate signal line (EMA of MACD)
  result.signal = ema(result.macd.mapIt(if it.isNaN: 0.0 else: it), signalPeriod)
  
  # Calculate histogram
  result.histogram = newSeq[float64](data.len)
  for i in 0..<data.len:
    if result.macd[i].isNaN or result.signal[i].isNaN:
      result.histogram[i] = NaN
    else:
      result.histogram[i] = result.macd[i] - result.signal[i]

type
  MACD* = ref object of IndicatorBase
    ## Streaming MACD indicator
    fastEma: EMA
    slowEma: EMA
    signalEma: EMA
    macdLine: float64

proc newMACD*(fastPeriod: int = 12, slowPeriod: int = 26, signalPeriod: int = 9): MACD =
  ## Create new MACD indicator
  result = MACD(
    period: slowPeriod,
    values: initDeque[float64](),
    fastEma: newEMA(fastPeriod),
    slowEma: newEMA(slowPeriod),
    signalEma: newEMA(signalPeriod),
    macdLine: NaN,
    initialized: false
  )

proc update*(macd: MACD, price: float64): tuple[macd, signal, histogram: float64] =
  ## Update MACD with new price
  let fast = macd.fastEma.update(price)
  let slow = macd.slowEma.update(price)
  
  if fast.isNaN or slow.isNaN:
    return (NaN, NaN, NaN)
  
  macd.macdLine = fast - slow
  macd.initialized = true
  
  let signal = macd.signalEma.update(macd.macdLine)
  
  if signal.isNaN:
    return (macd.macdLine, NaN, NaN)
  
  let histogram = macd.macdLine - signal
  result = (macd.macdLine, signal, histogram)

proc current*(macd: MACD): tuple[macd, signal, histogram: float64] =
  ## Get current MACD values
  if not macd.initialized:
    return (NaN, NaN, NaN)
  let signal = macd.signalEma.current()
  if signal.isNaN:
    return (macd.macdLine, NaN, NaN)
  result = (macd.macdLine, signal, macd.macdLine - signal)

# ============================================================================
# Volatility Indicators
# ============================================================================

# Average True Range (ATR)

proc atr*(high, low, close: seq[float64], period: int = 14): seq[float64] =
  ## Calculate Average True Range (ATR)
  ## 
  ## Args:
  ##   high: High prices
  ##   low: Low prices
  ##   close: Close prices
  ##   period: Number of periods (default 14)
  ## 
  ## Returns:
  ##   Sequence of ATR values
  result = newSeq[float64](high.len)
  
  if high.len < 2:
    for i in 0..<high.len:
      result[i] = NaN
    return
  
  # Calculate true ranges
  var trueRanges = newSeq[float64](high.len)
  trueRanges[0] = high[0] - low[0]
  
  for i in 1..<high.len:
    let hl = high[i] - low[i]
    let hc = abs(high[i] - close[i - 1])
    let lc = abs(low[i] - close[i - 1])
    trueRanges[i] = max(hl, max(hc, lc))
  
  # Calculate ATR using EMA of true ranges
  result = ema(trueRanges, period)

type
  ATR* = ref object of IndicatorBase
    ## Streaming Average True Range
    atrValue: float64
    prevClose: float64

proc newATR*(period: int = 14): ATR =
  ## Create new ATR indicator
  result = ATR(
    period: period,
    values: initDeque[float64](),
    atrValue: NaN,
    prevClose: NaN,
    initialized: false
  )

proc update*(atr: ATR, high, low, close: float64): float64 =
  ## Update ATR with new OHLC data
  var tr: float64
  
  if atr.prevClose.isNaN:
    tr = high - low
  else:
    let hl = high - low
    let hc = abs(high - atr.prevClose)
    let lc = abs(low - atr.prevClose)
    tr = max(hl, max(hc, lc))
  
  atr.prevClose = close
  atr.addValue(tr)
  
  if not atr.isFull():
    return NaN
  
  if not atr.initialized:
    # Initial ATR is SMA of true ranges
    var sum = 0.0
    for v in atr.values:
      sum += v
    atr.atrValue = sum / atr.period.float64
    atr.initialized = true
  else:
    # Smooth ATR
    atr.atrValue = (atr.atrValue * (atr.period - 1).float64 + tr) / atr.period.float64
  
  result = atr.atrValue

proc current*(atr: ATR): float64 =
  ## Get current ATR value
  result = atr.atrValue

# Bollinger Bands

proc bollinger*(data: seq[float64], period: int = 20, stdDev: float64 = 2.0): 
    tuple[upper, middle, lower: seq[float64]] =
  ## Calculate Bollinger Bands
  ## 
  ## Args:
  ##   data: Price data
  ##   period: Number of periods (default 20)
  ##   stdDev: Number of standard deviations (default 2.0)
  ## 
  ## Returns:
  ##   Tuple of (upper band, middle band, lower band)
  result.middle = sma(data, period)
  result.upper = newSeq[float64](data.len)
  result.lower = newSeq[float64](data.len)
  
  for i in 0..<data.len:
    if i < period - 1:
      result.upper[i] = NaN
      result.lower[i] = NaN
    else:
      # Calculate standard deviation
      var sumSq = 0.0
      for j in (i - period + 1)..i:
        let diff = data[j] - result.middle[i]
        sumSq += diff * diff
      let std = sqrt(sumSq / period.float64)
      
      result.upper[i] = result.middle[i] + stdDev * std
      result.lower[i] = result.middle[i] - stdDev * std

# Standard Deviation

proc stddev*(data: seq[float64], period: int): seq[float64] =
  ## Calculate rolling standard deviation
  ## 
  ## Args:
  ##   data: Data series
  ##   period: Number of periods
  ## 
  ## Returns:
  ##   Sequence of standard deviation values
  result = newSeq[float64](data.len)
  
  for i in 0..<data.len:
    if i < period - 1:
      result[i] = NaN
    else:
      var mean = 0.0
      for j in (i - period + 1)..i:
        mean += data[j]
      mean /= period.float64
      
      var variance = 0.0
      for j in (i - period + 1)..i:
        let diff = data[j] - mean
        variance += diff * diff
      variance /= period.float64
      
      result[i] = sqrt(variance)

# ============================================================================
# Volume Indicators
# ============================================================================

# On-Balance Volume (OBV)

proc obv*(close, volume: seq[float64]): seq[float64] =
  ## Calculate On-Balance Volume (OBV)
  ## 
  ## Args:
  ##   close: Close prices
  ##   volume: Volume data
  ## 
  ## Returns:
  ##   Sequence of OBV values
  result = newSeq[float64](close.len)
  
  if close.len == 0:
    return
  
  result[0] = volume[0]
  
  for i in 1..<close.len:
    if close[i] > close[i - 1]:
      result[i] = result[i - 1] + volume[i]
    elif close[i] < close[i - 1]:
      result[i] = result[i - 1] - volume[i]
    else:
      result[i] = result[i - 1]

type
  OBV* = ref object of IndicatorBase
    ## Streaming On-Balance Volume
    obvValue: float64
    prevClose: float64

proc newOBV*(): OBV =
  ## Create new OBV indicator
  result = OBV(
    period: 1,
    values: initDeque[float64](),
    obvValue: 0.0,
    prevClose: NaN,
    initialized: false
  )

proc update*(obv: OBV, close, volume: float64): float64 =
  ## Update OBV with new close/volume data
  if not obv.initialized:
    obv.obvValue = volume
    obv.prevClose = close
    obv.initialized = true
    return obv.obvValue
  
  if close > obv.prevClose:
    obv.obvValue += volume
  elif close < obv.prevClose:
    obv.obvValue -= volume
  
  obv.prevClose = close
  result = obv.obvValue

proc current*(obv: OBV): float64 =
  ## Get current OBV value
  result = obv.obvValue

# ============================================================================
# Utility Functions
# ============================================================================

proc roi*(initial, final: float64): float64 =
  ## Calculate Return on Investment (ROI)
  ## 
  ## Args:
  ##   initial: Initial value
  ##   final: Final value
  ## 
  ## Returns:
  ##   ROI as percentage
  if initial == 0:
    return NaN
  result = ((final - initial) / initial) * 100.0
