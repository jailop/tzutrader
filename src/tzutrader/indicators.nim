import std/[math, deques]
import core

type
  Indicator*[T] = ref object of RootObj
    ## Base type for all indicators with circular buffer
    memData: seq[T]
    memPos: int
    memSize: int

proc newIndicator*[T](memSize: int = 1): Indicator[T] =
  ## Create base indicator with circular buffer
  result = Indicator[T](
    memData: newSeq[T](memSize),
    memPos: 0,
    memSize: memSize
  )

proc push*[T](ind: Indicator[T], value: T) =
  ## Push new value into circular buffer
  ind.memPos = (ind.memPos + 1) mod ind.memSize
  ind.memData[ind.memPos] = value

proc `[]`*[T](ind: Indicator[T], key: int): T =
  ## Get value at index: 0 = current, -1 = previous, etc.
  if key > 0 or -key >= ind.memSize:
    raise newException(IndexDefect, "Invalid index")
  let realPos = (ind.memPos + ind.memSize + key) mod ind.memSize
  result = ind.memData[realPos]

proc get*[T](ind: Indicator[T], key: int = 0): T =
  ## Get value at index (wrapper around [])
  result = ind[key]

# Helper functions

proc isNaN*(x: float64): bool {.inline.} =
  ## Check if value is NaN
  result = x.classify == fcNaN

# Simple Moving Average (SMA / MA)

type
  MA* = ref object of Indicator[float64]
    ## Simple Moving Average
    period: int
    prevs: seq[float64]
    length: int
    pos: int
    accum: float64

proc newMA*(period: int, memSize: int = 1): MA =
  ## Create new Moving Average indicator
  ##
  ## Args:
  ##   period: Number of periods for average
  ##   memSize: Size of circular buffer for storing computed values (default 1)
  result = MA(
    memData: newSeq[float64](memSize),
    memPos: 0,
    memSize: memSize,
    period: period,
    prevs: newSeq[float64](period),
    length: 0,
    pos: 0,
    accum: 0.0
  )

proc update*(ma: MA, value: float64): float64 =
  ## Update MA with new value
  ##
  ## Returns current MA value (NaN if insufficient data)
  if ma.length < ma.period:
    ma.length += 1
  else:
    ma.accum -= ma.prevs[ma.pos]

  ma.prevs[ma.pos] = value
  ma.accum += value
  ma.pos = (ma.pos + 1) mod ma.period

  if ma.length < ma.period:
    ma.push(NaN)
  else:
    ma.push(ma.accum / ma.period.float64)

  result = ma[0]

# Exponential Moving Average (EMA)

type
  EMA* = ref object of Indicator[float64]
    ## Exponential Moving Average
    period: int
    alpha: float64
    smoothFactor: float64
    length: int
    prev: float64

proc newEMA*(period: int, alpha: float64 = 2.0, memSize: int = 1): EMA =
  ## Create new Exponential Moving Average indicator
  ##
  ## Args:
  ##   period: Number of periods
  ##   alpha: Smoothing factor coefficient (default 2.0)
  ##   memSize: Size of circular buffer (default 1)
  result = EMA(
    memData: newSeq[float64](memSize),
    memPos: 0,
    memSize: memSize,
    period: period,
    alpha: alpha,
    smoothFactor: alpha / (1.0 + period.float64),
    length: 0,
    prev: 0.0
  )

proc update*(ema: EMA, value: float64): float64 =
  ## Update EMA with new value
  ##
  ## Returns current EMA value (NaN if insufficient data)
  ema.length += 1

  if ema.length < ema.period:
    ema.prev += value
  elif ema.length == ema.period:
    ema.prev += value
    ema.prev /= ema.period.float64
  else:
    ema.prev = (value * ema.smoothFactor) + ema.prev * (1.0 - ema.smoothFactor)

  if ema.length < ema.period:
    ema.push(NaN)
  else:
    ema.push(ema.prev)

  result = ema[0]

# Moving Variance (MV)

type
  MV* = ref object of Indicator[float64]
    ## Moving Variance
    ma: MA
    prevs: seq[float64]
    period: int
    length: int
    pos: int

proc newMV*(period: int, memSize: int = 1): MV =
  ## Create new Moving Variance indicator
  result = MV(
    memData: newSeq[float64](memSize),
    memPos: 0,
    memSize: memSize,
    ma: newMA(period),
    prevs: newSeq[float64](period),
    period: period,
    length: 0,
    pos: 0
  )

proc update*(mv: MV, value: float64): float64 =
  ## Update MV with new value
  if mv.length < mv.period:
    mv.length += 1

  mv.prevs[mv.pos] = value
  mv.pos = (mv.pos + 1) mod mv.period
  discard mv.ma.update(value)

  if mv.length < mv.period:
    mv.push(NaN)
  else:
    var accum = 0.0
    for i in 0..<mv.prevs.len:
      let diff = mv.prevs[i] - mv.ma[0]
      accum += diff * diff
    mv.push(accum / mv.period.float64)

  result = mv[0]

# Standard Deviation (STDEV)

type
  STDEV* = ref object of Indicator[float64]
    ## Standard Deviation
    mv: MV

proc newSTDEV*(period: int, memSize: int = 1): STDEV =
  ## Create new Standard Deviation indicator
  result = STDEV(
    memData: newSeq[float64](memSize),
    memPos: 0,
    memSize: memSize,
    mv: newMV(period)
  )

proc update*(stdev: STDEV, value: float64): float64 =
  ## Update STDEV with new value
  let variance = stdev.mv.update(value)
  if variance.isNaN:
    stdev.push(NaN)
  else:
    stdev.push(sqrt(variance))
  result = stdev[0]

# Triangular Moving Average (TRIMA)

type
  TRIMA* = ref object of Indicator[float64]
    ## Triangular Moving Average (double-smoothed MA)
    ##
    ## TRIMA is calculated by taking a Simple Moving Average of a Simple Moving Average.
    ## This double smoothing produces a smoother line with less lag than SMA, but more
    ## lag than EMA. The result is a triangular weighting where the central values have
    ## more influence than the edges.
    ##
    ## Formula: TRIMA = SMA(SMA(price, n), n)
    ##
    ## Interpretation:
    ## - Smoother than SMA, reduces noise
    ## - Good for identifying underlying trend
    ## - Less responsive to price changes (more lag)
    ## - Useful for filtering out market noise in trending markets
    firstMA: MA
    secondMA: MA
    period: int

proc newTRIMA*(period: int, memSize: int = 1): TRIMA =
  ## Create new Triangular Moving Average indicator
  ##
  ## Args:
  ##   period: Number of periods for both moving averages
  ##   memSize: Size of circular buffer for storing computed values (default 1)
  ##
  ## Example:
  ##   var trima = newTRIMA(10)
  ##   let value = trima.update(price)
  result = TRIMA(
    memData: newSeq[float64](memSize),
    memPos: 0,
    memSize: memSize,
    period: period,
    firstMA: newMA(period),
    secondMA: newMA(period)
  )
  # Initialize buffer with NaN
  for i in 0..<memSize:
    result.memData[i] = NaN

proc update*(trima: TRIMA, value: float64): float64 =
  ## Update TRIMA with new value
  ##
  ## Returns current TRIMA value (NaN if insufficient data)
  let firstMAValue = trima.firstMA.update(value)

  if firstMAValue.isNaN:
    trima.push(NaN)
  else:
    let trimaValue = trima.secondMA.update(firstMAValue)
    trima.push(trimaValue)

  result = trima[0]

# Double Exponential Moving Average (DEMA)

type
  DEMA* = ref object of Indicator[float64]
    ## Double Exponential Moving Average
    ##
    ## DEMA is designed to reduce the lag of traditional EMAs by using a combination
    ## of a single EMA and a double EMA. It's more responsive to price changes than
    ## both SMA and EMA.
    ##
    ## Formula: DEMA = 2 * EMA(price) - EMA(EMA(price))
    ##
    ## Interpretation:
    ## - Less lag than EMA
    ## - More responsive to recent price changes
    ## - Better for catching trend changes earlier
    ## - Can be more sensitive to noise
    firstEMA: EMA
    secondEMA: EMA
    period: int

proc newDEMA*(period: int, memSize: int = 1): DEMA =
  ## Create new Double Exponential Moving Average indicator
  ##
  ## Args:
  ##   period: Number of periods for the EMA calculations
  ##   memSize: Size of circular buffer for storing computed values (default 1)
  ##
  ## Example:
  ##   var dema = newDEMA(10)
  ##   let value = dema.update(price)
  result = DEMA(
    memData: newSeq[float64](memSize),
    memPos: 0,
    memSize: memSize,
    period: period,
    firstEMA: newEMA(period),
    secondEMA: newEMA(period)
  )
  # Initialize buffer with NaN
  for i in 0..<memSize:
    result.memData[i] = NaN

proc update*(dema: DEMA, value: float64): float64 =
  ## Update DEMA with new value
  ##
  ## Returns current DEMA value (NaN if insufficient data)
  let ema1 = dema.firstEMA.update(value)

  if ema1.isNaN:
    dema.push(NaN)
  else:
    let ema2 = dema.secondEMA.update(ema1)
    if ema2.isNaN:
      dema.push(NaN)
    else:
      # DEMA = 2 * EMA - EMA(EMA)
      let demaValue = 2.0 * ema1 - ema2
      dema.push(demaValue)

  result = dema[0]

# Triple Exponential Moving Average (TEMA)

type
  TEMA* = ref object of Indicator[float64]
    ## Triple Exponential Moving Average
    ##
    ## TEMA takes the DEMA concept further by using three EMAs to achieve even less lag.
    ## It's highly responsive to price changes with minimal lag.
    ##
    ## Formula: TEMA = 3 * EMA - 3 * EMA(EMA) + EMA(EMA(EMA))
    ##
    ## Interpretation:
    ## - Minimal lag among moving averages
    ## - Very responsive to price changes
    ## - Excellent for short-term trend identification
    ## - Can be whipsawed in choppy markets
    firstEMA: EMA
    secondEMA: EMA
    thirdEMA: EMA
    period: int

proc newTEMA*(period: int, memSize: int = 1): TEMA =
  ## Create new Triple Exponential Moving Average indicator
  ##
  ## Args:
  ##   period: Number of periods for the EMA calculations
  ##   memSize: Size of circular buffer for storing computed values (default 1)
  ##
  ## Example:
  ##   var tema = newTEMA(10)
  ##   let value = tema.update(price)
  result = TEMA(
    memData: newSeq[float64](memSize),
    memPos: 0,
    memSize: memSize,
    period: period,
    firstEMA: newEMA(period),
    secondEMA: newEMA(period),
    thirdEMA: newEMA(period)
  )
  # Initialize buffer with NaN
  for i in 0..<memSize:
    result.memData[i] = NaN

proc update*(tema: TEMA, value: float64): float64 =
  ## Update TEMA with new value
  ##
  ## Returns current TEMA value (NaN if insufficient data)
  let ema1 = tema.firstEMA.update(value)

  if ema1.isNaN:
    tema.push(NaN)
  else:
    let ema2 = tema.secondEMA.update(ema1)
    if ema2.isNaN:
      tema.push(NaN)
    else:
      let ema3 = tema.thirdEMA.update(ema2)
      if ema3.isNaN:
        tema.push(NaN)
      else:
        # TEMA = 3 * EMA - 3 * EMA(EMA) + EMA(EMA(EMA))
        let temaValue = 3.0 * ema1 - 3.0 * ema2 + ema3
        tema.push(temaValue)

  result = tema[0]

# Kaufman Adaptive Moving Average (KAMA)

type
  KAMA* = ref object of Indicator[float64]
    ## Kaufman Adaptive Moving Average
    ##
    ## KAMA is an adaptive moving average that adjusts its smoothing constant based on
    ## market volatility. In trending markets, it becomes more responsive (like EMA).
    ## In choppy markets, it becomes smoother (like SMA). This adaptability makes it
    ## excellent for filtering out noise while being responsive to genuine trends.
    ##
    ## The calculation uses an Efficiency Ratio (ER) to measure market direction:
    ## - ER = (absolute price change) / (sum of absolute bar-to-bar changes)
    ## - ER near 1.0 = strong trend (more responsive)
    ## - ER near 0.0 = choppy/sideways (more smoothing)
    ##
    ## Formula:
    ##   ER = abs(price - price[period]) / sum(abs(price[i] - price[i-1]))
    ##   SC = (ER * (fastSC - slowSC) + slowSC)^2
    ##   KAMA = KAMA[prev] + SC * (price - KAMA[prev])
    ##
    ## Interpretation:
    ## - Adapts to market conditions automatically
    ## - Reduces whipsaws in sideways markets
    ## - Responsive in trending markets
    ## - Smoothing constant adjusts between fast (2) and slow (30) EMAs
    period: int
    fastPeriod: int
    slowPeriod: int
    fastSC: float64 # Fast smoothing constant
    slowSC: float64 # Slow smoothing constant
    prices: seq[float64] # Price window for ER calculation
    pos: int
    length: int
    prevKAMA: float64
    initialized: bool

proc newKAMA*(period: int = 10, fastPeriod: int = 2, slowPeriod: int = 30,
              memSize: int = 1): KAMA =
  ## Create new Kaufman Adaptive Moving Average indicator
  ##
  ## Args:
  ##   period: Period for Efficiency Ratio calculation (default 10)
  ##   fastPeriod: Fast EMA period for trending markets (default 2)
  ##   slowPeriod: Slow EMA period for choppy markets (default 30)
  ##   memSize: Size of circular buffer for storing computed values (default 1)
  ##
  ## Example:
  ##   var kama = newKAMA(10)  # Use defaults
  ##   let value = kama.update(price)
  result = KAMA(
    memData: newSeq[float64](memSize),
    memPos: 0,
    memSize: memSize,
    period: period,
    fastPeriod: fastPeriod,
    slowPeriod: slowPeriod,
    fastSC: 2.0 / (fastPeriod.float64 + 1.0),
    slowSC: 2.0 / (slowPeriod.float64 + 1.0),
    prices: newSeq[float64](period + 1),
    pos: 0,
    length: 0,
    prevKAMA: NaN,
    initialized: false
  )
  # Initialize buffer with NaN
  for i in 0..<memSize:
    result.memData[i] = NaN

proc update*(kama: KAMA, value: float64): float64 =
  ## Update KAMA with new value
  ##
  ## Returns current KAMA value (NaN if insufficient data)

  # Store price in circular buffer
  kama.prices[kama.pos] = value
  kama.pos = (kama.pos + 1) mod (kama.period + 1)

  if kama.length < kama.period + 1:
    kama.length += 1

  # Need period + 1 values to calculate
  if kama.length < kama.period + 1:
    kama.push(NaN)
    return NaN

  # Initialize KAMA with first price if needed
  if not kama.initialized:
    kama.prevKAMA = kama.prices[(kama.pos + kama.period) mod (kama.period + 1)]
    kama.initialized = true

  # Calculate Efficiency Ratio (ER)
  # ER = abs(change) / sum(volatility)
  let oldestIdx = kama.pos # Points to oldest value after increment
  let newestIdx = (kama.pos + kama.period) mod (kama.period + 1)

  let change = abs(kama.prices[newestIdx] - kama.prices[oldestIdx])

  var volatility = 0.0
  for i in 0..<kama.period:
    let idx1 = (oldestIdx + i) mod (kama.period + 1)
    let idx2 = (oldestIdx + i + 1) mod (kama.period + 1)
    volatility += abs(kama.prices[idx2] - kama.prices[idx1])

  # Efficiency Ratio
  var er = 0.0
  if volatility > 0.0:
    er = change / volatility

  # Smoothing Constant (SC)
  # SC = [ER * (fastSC - slowSC) + slowSC]^2
  let sc = er * (kama.fastSC - kama.slowSC) + kama.slowSC
  let sc2 = sc * sc

  # KAMA calculation
  # KAMA = KAMA[prev] + SC * (price - KAMA[prev])
  let kamaValue = kama.prevKAMA + sc2 * (value - kama.prevKAMA)
  kama.prevKAMA = kamaValue
  kama.push(kamaValue)

  result = kama[0]

# Return on Investment (ROI)

proc calculateROI*(initialValue, finalValue: float64): float64 =
  ## Calculate ROI between two values
  if initialValue == 0 or initialValue.isNaN:
    return NaN
  result = finalValue / initialValue - 1.0

type
  ROI* = ref object of Indicator[float64]
    ## Return on Investment
    prev: float64

proc newROI*(memSize: int = 1): ROI =
  ## Create new ROI indicator
  result = ROI(
    memData: newSeq[float64](memSize),
    memPos: 0,
    memSize: memSize,
    prev: NaN
  )

proc update*(roi: ROI, value: float64): float64 =
  ## Update ROI with new value
  let curr = calculateROI(roi.prev, value)
  roi.push(curr)
  roi.prev = value
  result = roi[0]

# Relative Strength Index (RSI)

type
  RSI* = ref object of Indicator[float64]
    ## Relative Strength Index
    gains: MA
    losses: MA

proc newRSI*(period: int = 14, memSize: int = 1): RSI =
  ## Create new RSI indicator
  result = RSI(
    memData: newSeq[float64](memSize),
    memPos: 0,
    memSize: memSize,
    gains: newMA(period),
    losses: newMA(period)
  )

proc update*(rsi: RSI, openPrice, closePrice: float64): float64 =
  ## Update RSI with open and close prices
  let diff = closePrice - openPrice
  discard rsi.gains.update(if diff >= 0.0: diff else: 0.0)
  discard rsi.losses.update(if diff < 0.0: -diff else: 0.0)

  if rsi.losses[0].isNaN:
    rsi.push(NaN)
  else:
    let rsiValue = 100.0 - 100.0 / (1.0 + rsi.gains[0] / rsi.losses[0])
    rsi.push(rsiValue)

  result = rsi[0]

# Rate of Change (ROC)

type
  ROC* = ref object of Indicator[float64]
    ## Rate of Change
    period: int
    prevs: seq[float64]
    length: int
    pos: int

proc newROC*(period: int = 12, memSize: int = 1): ROC =
  ## Create new Rate of Change indicator
  result = ROC(
    memData: newSeq[float64](memSize),
    memPos: 0,
    memSize: memSize,
    period: period,
    prevs: newSeq[float64](period),
    length: 0,
    pos: 0
  )

proc update*(roc: ROC, value: float64): float64 =
  ## Update ROC with new value
  if roc.length < roc.period:
    roc.length += 1
    roc.prevs[roc.pos] = value
    roc.pos = (roc.pos + 1) mod roc.period
    roc.push(NaN)
  else:
    let oldValue = roc.prevs[roc.pos]
    roc.prevs[roc.pos] = value
    roc.pos = (roc.pos + 1) mod roc.period

    if oldValue == 0.0:
      roc.push(NaN)
    else:
      roc.push(((value - oldValue) / oldValue) * 100.0)

  result = roc[0]

# MACD Result Type

type
  MACDResult* = object
    ## MACD calculation result
    macd*: float64
    signal*: float64
    hist*: float64

# MACD

type
  MACD* = ref object of Indicator[MACDResult]
    ## Moving Average Convergence Divergence
    shortEma: EMA
    longEma: EMA
    diffEma: EMA
    start: int
    counter: int

proc newMACD*(shortPeriod: int = 12, longPeriod: int = 26,
              diffPeriod: int = 9, memSize: int = 1): MACD =
  ## Create new MACD indicator
  var memData = newSeq[MACDResult](memSize)
  # Initialize with NaN values
  for i in 0..<memSize:
    memData[i] = MACDResult(macd: NaN, signal: NaN, hist: NaN)

  result = MACD(
    memData: memData,
    memPos: 0,
    memSize: memSize,
    shortEma: newEMA(shortPeriod),
    longEma: newEMA(longPeriod),
    diffEma: newEMA(diffPeriod),
    start: max(longPeriod, shortPeriod),
    counter: 0
  )

proc update*(macd: MACD, value: float64): MACDResult =
  ## Update MACD with new value
  macd.counter += 1
  discard macd.shortEma.update(value)
  discard macd.longEma.update(value)

  var macdResult: MACDResult
  if macd.counter >= macd.start:
    let diff = macd.shortEma[0] - macd.longEma[0]
    discard macd.diffEma.update(diff)
    macdResult = MACDResult(
      macd: diff,
      signal: macd.diffEma[0],
      hist: diff - macd.diffEma[0]
    )
  else:
    macdResult = MACDResult(macd: NaN, signal: NaN, hist: NaN)

  macd.push(macdResult)
  result = macd[0]

# Average True Range (ATR)

type
  ATR* = ref object of Indicator[float64]
    ## Average True Range
    prevs: MA

proc newATR*(period: int = 14, memSize: int = 1): ATR =
  ## Create new ATR indicator
  result = ATR(
    memData: newSeq[float64](memSize),
    memPos: 0,
    memSize: memSize,
    prevs: newMA(period)
  )

proc update*(atr: ATR, lowPrice, highPrice, closePrice: float64): float64 =
  ## Update ATR with low, high, and close prices
  let tr = max(max(highPrice - lowPrice, highPrice - closePrice),
               lowPrice - closePrice)
  discard atr.prevs.update(tr)
  atr.push(atr.prevs[0])
  result = atr[0]

# Bollinger Bands

type
  BollingerResult* = object
    ## Bollinger Bands result
    upper*: float64
    middle*: float64
    lower*: float64

type
  BollingerBands* = ref object of Indicator[BollingerResult]
    ## Bollinger Bands
    ma: MA
    stdev: STDEV
    numStdDev: float64

proc newBollingerBands*(period: int = 20, numStdDev: float64 = 2.0,
                        memSize: int = 1): BollingerBands =
  ## Create new Bollinger Bands indicator
  var memData = newSeq[BollingerResult](memSize)
  # Initialize with NaN values
  for i in 0..<memSize:
    memData[i] = BollingerResult(upper: NaN, middle: NaN, lower: NaN)

  result = BollingerBands(
    memData: memData,
    memPos: 0,
    memSize: memSize,
    ma: newMA(period),
    stdev: newSTDEV(period),
    numStdDev: numStdDev
  )

proc update*(bb: BollingerBands, value: float64): BollingerResult =
  ## Update Bollinger Bands with new value
  discard bb.ma.update(value)
  discard bb.stdev.update(value)

  var bbResult: BollingerResult
  if bb.ma[0].isNaN or bb.stdev[0].isNaN:
    bbResult = BollingerResult(upper: NaN, middle: NaN, lower: NaN)
  else:
    let middle = bb.ma[0]
    let offset = bb.stdev[0] * bb.numStdDev
    bbResult = BollingerResult(
      upper: middle + offset,
      middle: middle,
      lower: middle - offset
    )

  bb.push(bbResult)
  result = bb[0]

# On-Balance Volume (OBV)

type
  OBV* = ref object of Indicator[float64]
    ## On-Balance Volume
    prevClose: float64
    obvValue: float64
    initialized: bool

proc newOBV*(memSize: int = 1): OBV =
  ## Create new OBV indicator
  result = OBV(
    memData: newSeq[float64](memSize),
    memPos: 0,
    memSize: memSize,
    prevClose: NaN,
    obvValue: 0.0,
    initialized: false
  )

proc update*(obv: OBV, closePrice, volume: float64): float64 =
  ## Update OBV with close price and volume
  if not obv.initialized:
    obv.obvValue = volume
    obv.prevClose = closePrice
    obv.initialized = true
  else:
    if closePrice > obv.prevClose:
      obv.obvValue += volume
    elif closePrice < obv.prevClose:
      obv.obvValue -= volume
    obv.prevClose = closePrice

  obv.push(obv.obvValue)
  result = obv[0]

# Stochastic Oscillator (STOCH)

type
  StochResult* = object
    ## Stochastic Oscillator result
    k*: float64 ## %K line (fast)
    d*: float64 ## %D line (slow, SMA of %K)

type
  STOCH* = ref object of Indicator[StochResult]
    ## Stochastic Oscillator
    ##
    ## Measures momentum by comparing closing price to the price range over a period.
    ## %K shows where the close is relative to the high-low range.
    ## %D is a moving average of %K, providing a smoother signal line.
    ##
    ## Interpretation:
    ## - Values above 80 indicate overbought conditions
    ## - Values below 20 indicate oversold conditions
    ## - %K crossing above %D is a bullish signal
    ## - %K crossing below %D is a bearish signal
    kPeriod: int
    dPeriod: int
    highWindow: seq[float64]
    lowWindow: seq[float64]
    closeWindow: seq[float64]
    length: int
    pos: int
    kMA: MA # Moving average for %D line

proc newSTOCH*(kPeriod: int = 14, dPeriod: int = 3, memSize: int = 1): STOCH =
  ## Create new Stochastic Oscillator indicator
  ##
  ## Args:
  ##   kPeriod: Number of periods for %K calculation (default 14)
  ##   dPeriod: Number of periods for %D smoothing (default 3)
  ##   memSize: Size of circular buffer for storing computed values (default 1)
  ##
  ## Example:
  ## .. code-block:: nim
  ##    var stoch = newSTOCH(kPeriod = 14, dPeriod = 3, memSize = 10)
  ##    for bar in data:
  ##      let result = stoch.update(bar.high, bar.low, bar.close)
  ##      if not result.k.isNaN:
  ##        echo "Stochastic %K: ", result.k, " %D: ", result.d
  var memData = newSeq[StochResult](memSize)
  # Initialize with NaN values
  for i in 0..<memSize:
    memData[i] = StochResult(k: NaN, d: NaN)

  result = STOCH(
    memData: memData,
    memPos: 0,
    memSize: memSize,
    kPeriod: kPeriod,
    dPeriod: dPeriod,
    highWindow: newSeq[float64](kPeriod),
    lowWindow: newSeq[float64](kPeriod),
    closeWindow: newSeq[float64](kPeriod),
    length: 0,
    pos: 0,
    kMA: newMA(dPeriod)
  )

proc update*(stoch: STOCH, high, low, close: float64): StochResult =
  ## Update Stochastic Oscillator with new bar
  ##
  ## Args:
  ##   high: High price of the bar
  ##   low: Low price of the bar
  ##   close: Close price of the bar
  ##
  ## Returns:
  ##   StochResult with %K and %D values (NaN if insufficient data)
  if stoch.length < stoch.kPeriod:
    stoch.length += 1

  # Update rolling windows
  stoch.highWindow[stoch.pos] = high
  stoch.lowWindow[stoch.pos] = low
  stoch.closeWindow[stoch.pos] = close
  stoch.pos = (stoch.pos + 1) mod stoch.kPeriod

  var stochResult: StochResult
  if stoch.length < stoch.kPeriod:
    # Not enough data yet
    stochResult = StochResult(k: NaN, d: NaN)
  else:
    # Find highest high and lowest low in the window
    var highestHigh = stoch.highWindow[0]
    var lowestLow = stoch.lowWindow[0]
    for i in 1..<stoch.kPeriod:
      if stoch.highWindow[i] > highestHigh:
        highestHigh = stoch.highWindow[i]
      if stoch.lowWindow[i] < lowestLow:
        lowestLow = stoch.lowWindow[i]

    # Calculate %K
    let range = highestHigh - lowestLow
    var k: float64
    if range == 0.0:
      k = 50.0 # Neutral value when no range
    else:
      k = 100.0 * (close - lowestLow) / range

    # Calculate %D (moving average of %K)
    let d = stoch.kMA.update(k)

    stochResult = StochResult(k: k, d: d)

  stoch.push(stochResult)
  result = stoch[0]

# Commodity Channel Index (CCI)

type
  CCI* = ref object of Indicator[float64]
    ## Commodity Channel Index
    ##
    ## Measures the deviation of the typical price from its average.
    ## Useful for identifying cyclical trends and overbought/oversold conditions.
    ##
    ## Formula: CCI = (Typical Price - MA(Typical Price)) / (0.015 * Mean Deviation)
    ## Where Typical Price = (High + Low + Close) / 3
    ##
    ## Interpretation:
    ## - Values above +100 indicate overbought conditions
    ## - Values below -100 indicate oversold conditions
    ## - Can range beyond +/-100 (unbounded)
    period: int
    tpWindow: seq[float64] # Typical price window
    length: int
    pos: int
    tpMA: MA # MA for typical price

proc newCCI*(period: int = 20, memSize: int = 1): CCI =
  ## Create new Commodity Channel Index indicator
  ##
  ## Args:
  ##   period: Number of periods for calculation (default 20)
  ##   memSize: Size of circular buffer (default 1)
  ##
  ## Example:
  ## .. code-block:: nim
  ##    var cci = newCCI(period = 20)
  ##    for bar in data:
  ##      let value = cci.update(bar.high, bar.low, bar.close)
  ##      if not value.isNaN:
  ##        if value > 100: echo "Overbought"
  ##        elif value < -100: echo "Oversold"
  result = CCI(
    memData: newSeq[float64](memSize),
    memPos: 0,
    memSize: memSize,
    period: period,
    tpWindow: newSeq[float64](period),
    length: 0,
    pos: 0,
    tpMA: newMA(period)
  )

proc update*(cci: CCI, high, low, close: float64): float64 =
  ## Update CCI with new bar
  ##
  ## Args:
  ##   high: High price of the bar
  ##   low: Low price of the bar
  ##   close: Close price of the bar
  ##
  ## Returns:
  ##   CCI value (NaN if insufficient data)
  # Calculate typical price
  let typicalPrice = (high + low + close) / 3.0

  if cci.length < cci.period:
    cci.length += 1

  # Update typical price window
  cci.tpWindow[cci.pos] = typicalPrice
  cci.pos = (cci.pos + 1) mod cci.period

  # Update MA of typical price
  let tpAvg = cci.tpMA.update(typicalPrice)

  if tpAvg.isNaN:
    cci.push(NaN)
  else:
    # Calculate mean deviation
    var sumDeviation = 0.0
    for i in 0..<cci.period:
      sumDeviation += abs(cci.tpWindow[i] - tpAvg)
    let meanDeviation = sumDeviation / cci.period.float64

    # Calculate CCI
    var cciValue: float64
    if meanDeviation == 0.0:
      cciValue = 0.0
    else:
      cciValue = (typicalPrice - tpAvg) / (0.015 * meanDeviation)

    cci.push(cciValue)

  result = cci[0]

# Money Flow Index (MFI)

type
  MFI* = ref object of Indicator[float64]
    ## Money Flow Index
    ##
    ## Volume-weighted RSI that measures buying and selling pressure.
    ## Combines price and volume to identify overbought/oversold conditions.
    ##
    ## Formula: MFI = 100 - 100 / (1 + Money Flow Ratio)
    ## Where Money Flow Ratio = Positive Money Flow / Negative Money Flow
    ## Money Flow = Typical Price * Volume
    ##
    ## Interpretation:
    ## - Values above 80 indicate overbought conditions
    ## - Values below 20 indicate oversold conditions
    ## - Divergences with price can signal reversals
    period: int
    prevTypicalPrice: float64
    posFlowWindow: seq[float64]
    negFlowWindow: seq[float64]
    length: int
    pos: int

proc newMFI*(period: int = 14, memSize: int = 1): MFI =
  ## Create new Money Flow Index indicator
  ##
  ## Args:
  ##   period: Number of periods for calculation (default 14)
  ##   memSize: Size of circular buffer (default 1)
  ##
  ## Example:
  ## .. code-block:: nim
  ##    var mfi = newMFI(period = 14)
  ##    for bar in data:
  ##      let value = mfi.update(bar.high, bar.low, bar.close, bar.volume)
  ##      if not value.isNaN:
  ##        if value > 80: echo "Overbought"
  ##        elif value < 20: echo "Oversold"
  result = MFI(
    memData: newSeq[float64](memSize),
    memPos: 0,
    memSize: memSize,
    period: period,
    prevTypicalPrice: NaN,
    posFlowWindow: newSeq[float64](period),
    negFlowWindow: newSeq[float64](period),
    length: 0,
    pos: 0
  )

proc update*(mfi: MFI, high, low, close, volume: float64): float64 =
  ## Update MFI with new bar
  ##
  ## Args:
  ##   high: High price of the bar
  ##   low: Low price of the bar
  ##   close: Close price of the bar
  ##   volume: Volume of the bar
  ##
  ## Returns:
  ##   MFI value (NaN if insufficient data)
  # Calculate typical price
  let typicalPrice = (high + low + close) / 3.0
  let moneyFlow = typicalPrice * volume

  # Determine if positive or negative flow
  var posFlow = 0.0
  var negFlow = 0.0

  if not mfi.prevTypicalPrice.isNaN:
    if typicalPrice > mfi.prevTypicalPrice:
      posFlow = moneyFlow
    elif typicalPrice < mfi.prevTypicalPrice:
      negFlow = moneyFlow
    # If equal, both remain 0

  if mfi.length < mfi.period:
    mfi.length += 1

  # Update flow windows
  mfi.posFlowWindow[mfi.pos] = posFlow
  mfi.negFlowWindow[mfi.pos] = negFlow
  mfi.pos = (mfi.pos + 1) mod mfi.period
  mfi.prevTypicalPrice = typicalPrice

  if mfi.length < mfi.period:
    mfi.push(NaN)
  else:
    # Calculate sums
    var sumPosFlow = 0.0
    var sumNegFlow = 0.0
    for i in 0..<mfi.period:
      sumPosFlow += mfi.posFlowWindow[i]
      sumNegFlow += mfi.negFlowWindow[i]

    # Calculate MFI
    var mfiValue: float64
    if sumNegFlow == 0.0:
      if sumPosFlow == 0.0:
        mfiValue = 50.0 # Neutral when no flow
      else:
        mfiValue = 100.0 # All positive flow
    else:
      let moneyFlowRatio = sumPosFlow / sumNegFlow
      mfiValue = 100.0 - 100.0 / (1.0 + moneyFlowRatio)

    mfi.push(mfiValue)

  result = mfi[0]

# Average Directional Movement Index (ADX)

type
  ADXResult* = object
    ## ADX calculation result
    adx*: float64     ## ADX value (trend strength)
    plusDI*: float64  ## +DI (positive directional indicator)
    minusDI*: float64 ## -DI (negative directional indicator)

type
  ADX* = ref object of Indicator[ADXResult]
    ## Average Directional Movement Index
    ##
    ## Measures the strength of a trend (not direction).
    ## Includes +DI and -DI which show trend direction.
    ##
    ## Interpretation:
    ## - ADX < 20: Weak or no trend
    ## - ADX 20-40: Moderate trend
    ## - ADX > 40: Strong trend
    ## - +DI > -DI: Uptrend
    ## - -DI > +DI: Downtrend
    ##
    ## Wilder's smoothing formula used for TR, +DM, -DM, and ADX
    period: int
    prevHigh: float64
    prevLow: float64
    prevClose: float64
    # Smoothed values (Wilder's smoothing)
    smoothedTR: float64
    smoothedPlusDM: float64
    smoothedMinusDM: float64
    smoothedDX: float64
    length: int
    initialized: bool

proc newADX*(period: int = 14, memSize: int = 1): ADX =
  ## Create new ADX indicator
  ##
  ## Args:
  ##   period: Number of periods for calculation (default 14)
  ##   memSize: Size of circular buffer (default 1)
  ##
  ## Example:
  ## .. code-block:: nim
  ##    var adx = newADX(period = 14)
  ##    for bar in data:
  ##      let result = adx.update(bar.high, bar.low, bar.close)
  ##      if not result.adx.isNaN:
  ##        echo "ADX: ", result.adx, " +DI: ", result.plusDI, " -DI: ", result.minusDI
  var memData = newSeq[ADXResult](memSize)
  # Initialize with NaN values
  for i in 0..<memSize:
    memData[i] = ADXResult(adx: NaN, plusDI: NaN, minusDI: NaN)

  result = ADX(
    memData: memData,
    memPos: 0,
    memSize: memSize,
    period: period,
    prevHigh: NaN,
    prevLow: NaN,
    prevClose: NaN,
    smoothedTR: 0.0,
    smoothedPlusDM: 0.0,
    smoothedMinusDM: 0.0,
    smoothedDX: 0.0,
    length: 0,
    initialized: false
  )

proc update*(adx: ADX, high, low, close: float64): ADXResult =
  ## Update ADX with new bar
  ##
  ## Args:
  ##   high: High price of the bar
  ##   low: Low price of the bar
  ##   close: Close price of the bar
  ##
  ## Returns:
  ##   ADXResult with ADX, +DI, and -DI values (NaN if insufficient data)
  var adxResult: ADXResult

  if adx.prevHigh.isNaN:
    # First bar - just store values
    adx.prevHigh = high
    adx.prevLow = low
    adx.prevClose = close
    adxResult = ADXResult(adx: NaN, plusDI: NaN, minusDI: NaN)
  else:
    # Calculate True Range
    let tr1 = high - low
    let tr2 = abs(high - adx.prevClose)
    let tr3 = abs(low - adx.prevClose)
    let tr = max(max(tr1, tr2), tr3)

    # Calculate Directional Movement
    let upMove = high - adx.prevHigh
    let downMove = adx.prevLow - low

    var plusDM = 0.0
    var minusDM = 0.0

    if upMove > downMove and upMove > 0:
      plusDM = upMove
    if downMove > upMove and downMove > 0:
      minusDM = downMove

    # Wilder's smoothing
    adx.length += 1

    if adx.length <= adx.period:
      # Initial accumulation phase
      adx.smoothedTR += tr
      adx.smoothedPlusDM += plusDM
      adx.smoothedMinusDM += minusDM

      if adx.length == adx.period:
        # First smoothed values (simple average)
        adx.smoothedTR = adx.smoothedTR / adx.period.float64
        adx.smoothedPlusDM = adx.smoothedPlusDM / adx.period.float64
        adx.smoothedMinusDM = adx.smoothedMinusDM / adx.period.float64
        adx.initialized = true

      adxResult = ADXResult(adx: NaN, plusDI: NaN, minusDI: NaN)
    else:
      # Wilder's smoothing: smoothed = (prev * (n-1) + current) / n
      adx.smoothedTR = (adx.smoothedTR * (adx.period - 1).float64 + tr) /
          adx.period.float64
      adx.smoothedPlusDM = (adx.smoothedPlusDM * (adx.period - 1).float64 +
          plusDM) / adx.period.float64
      adx.smoothedMinusDM = (adx.smoothedMinusDM * (adx.period - 1).float64 +
          minusDM) / adx.period.float64

      # Calculate +DI and -DI
      var plusDI = 0.0
      var minusDI = 0.0

      if adx.smoothedTR > 0:
        plusDI = 100.0 * adx.smoothedPlusDM / adx.smoothedTR
        minusDI = 100.0 * adx.smoothedMinusDM / adx.smoothedTR

      # Calculate DX (Directional Index)
      var dx = 0.0
      let diSum = plusDI + minusDI
      if diSum > 0:
        dx = 100.0 * abs(plusDI - minusDI) / diSum

      # Smooth DX to get ADX (Wilder's smoothing again)
      if adx.length == adx.period + 1:
        # First ADX is just DX
        adx.smoothedDX = dx
      else:
        adx.smoothedDX = (adx.smoothedDX * (adx.period - 1).float64 + dx) /
            adx.period.float64

      adxResult = ADXResult(adx: adx.smoothedDX, plusDI: plusDI,
          minusDI: minusDI)

    # Update previous values
    adx.prevHigh = high
    adx.prevLow = low
    adx.prevClose = close

  adx.push(adxResult)
  result = adx[0]

# True Range (TRANGE)

proc calculateTrueRange*(high, low, prevClose: float64): float64 =
  ## Calculate True Range for a single bar
  ##
  ## True Range is the greatest of:
  ## - Current High - Current Low
  ## - abs(Current High - Previous Close)
  ## - abs(Current Low - Previous Close)
  ##
  ## Returns the true range value
  if prevClose.isNaN:
    # First bar - just use high-low
    return high - low

  let hl = high - low
  let hpc = abs(high - prevClose)
  let lpc = abs(low - prevClose)

  result = max(hl, max(hpc, lpc))

type
  TRANGE* = ref object of Indicator[float64]
    ## True Range
    ##
    ## Measures market volatility by calculating the greatest of:
    ## - Current high minus current low
    ## - Absolute value of current high minus previous close
    ## - Absolute value of current low minus previous close
    ##
    ## True Range accounts for gaps and limit moves, providing a more
    ## complete picture of volatility than simple high-low range.
    ##
    ## Interpretation:
    ## - Higher values = higher volatility
    ## - Lower values = lower volatility
    ## - Useful for position sizing and stop-loss placement
    ## - Foundation for ATR calculation
    prevClose: float64

proc newTRANGE*(memSize: int = 1): TRANGE =
  ## Create new True Range indicator
  ##
  ## Args:
  ##   memSize: Size of circular buffer for storing computed values (default 1)
  ##
  ## Example:
  ##   var tr = newTRANGE()
  ##   let trValue = tr.update(high, low, close)
  result = TRANGE(
    memData: newSeq[float64](memSize),
    memPos: 0,
    memSize: memSize,
    prevClose: NaN
  )
  # Initialize buffer with NaN
  for i in 0..<memSize:
    result.memData[i] = NaN

proc update*(tr: TRANGE, high, low, close: float64): float64 =
  ## Update True Range with new bar
  ##
  ## Returns current True Range value
  let trValue = calculateTrueRange(high, low, tr.prevClose)
  tr.prevClose = close
  tr.push(trValue)
  result = tr[0]

# Normalized Average True Range (NATR)

type
  NATR* = ref object of Indicator[float64]
    ## Normalized Average True Range
    ##
    ## NATR is ATR expressed as a percentage of the closing price.
    ## This normalization allows for comparison of volatility across
    ## different price levels and different instruments.
    ##
    ## Formula: NATR = (ATR / Close) * 100
    ##
    ## Interpretation:
    ## - Expressed as percentage of price
    ## - Allows comparison across different price ranges
    ## - 2-3% is typical for stocks
    ## - Higher % = more volatile relative to price
    ## - Lower % = less volatile relative to price
    atr: ATR
    period: int

proc newNATR*(period: int = 14, memSize: int = 1): NATR =
  ## Create new Normalized Average True Range indicator
  ##
  ## Args:
  ##   period: Number of periods for ATR calculation (default 14)
  ##   memSize: Size of circular buffer for storing computed values (default 1)
  ##
  ## Example:
  ##   var natr = newNATR(14)
  ##   let natrValue = natr.update(high, low, close)
  result = NATR(
    memData: newSeq[float64](memSize),
    memPos: 0,
    memSize: memSize,
    atr: newATR(period),
    period: period
  )
  # Initialize buffer with NaN
  for i in 0..<memSize:
    result.memData[i] = NaN

proc update*(natr: NATR, high, low, close: float64): float64 =
  ## Update NATR with new bar
  ##
  ## Returns current NATR value (NaN if insufficient data or close is zero)
  let atrValue = natr.atr.update(high, low, close)

  if atrValue.isNaN or close == 0.0:
    natr.push(NaN)
  else:
    let natrValue = (atrValue / close) * 100.0
    natr.push(natrValue)

  result = natr[0]

# Accumulation/Distribution (AD)

type
  AD* = ref object of Indicator[float64]
    ## Accumulation/Distribution Line
    ##
    ## A/D is a cumulative indicator that uses volume flow to assess
    ## whether a stock is being accumulated (bought) or distributed (sold).
    ## It relates the closing price to the high-low range and multiplies
    ## by volume.
    ##
    ## Formula:
    ##   Money Flow Multiplier = ((Close - Low) - (High - Close)) / (High - Low)
    ##   Money Flow Volume = Money Flow Multiplier * Volume
    ##   A/D = Previous A/D + Money Flow Volume
    ##
    ## Interpretation:
    ## - Rising A/D line = accumulation (buying pressure)
    ## - Falling A/D line = distribution (selling pressure)
    ## - Divergence from price can signal reversals
    ## - Compare trend of A/D with price trend
    adValue: float64
    initialized: bool

proc newAD*(memSize: int = 1): AD =
  ## Create new Accumulation/Distribution indicator
  ##
  ## Args:
  ##   memSize: Size of circular buffer for storing computed values (default 1)
  ##
  ## Example:
  ##   var ad = newAD()
  ##   let adValue = ad.update(high, low, close, volume)
  result = AD(
    memData: newSeq[float64](memSize),
    memPos: 0,
    memSize: memSize,
    adValue: 0.0,
    initialized: false
  )
  # Initialize buffer with NaN (until first value)
  for i in 0..<memSize:
    result.memData[i] = NaN

proc update*(ad: AD, high, low, close, volume: float64): float64 =
  ## Update A/D with new bar
  ##
  ## Returns current A/D value

  # Calculate Money Flow Multiplier
  let range = high - low
  var mfm = 0.0

  if range > 0.0:
    mfm = ((close - low) - (high - close)) / range
  # If range is 0, mfm stays 0

  # Calculate Money Flow Volume
  let mfv = mfm * volume

  # Update cumulative A/D
  if not ad.initialized:
    ad.adValue = mfv
    ad.initialized = true
  else:
    ad.adValue += mfv

  ad.push(ad.adValue)
  result = ad[0]

# Aroon Indicator (AROON)

type
  AroonResult* = object
    ## Aroon calculation result
    up*: float64         ## Aroon Up (0-100)
    down*: float64       ## Aroon Down (0-100)
    oscillator*: float64 ## Aroon Oscillator (Up - Down, range -100 to +100)

type
  AROON* = ref object of Indicator[AroonResult]
    ## Aroon Indicator
    ##
    ## Aroon identifies when trends are likely to change by measuring
    ## the time since the highest high and lowest low over a period.
    ##
    ## Formulas:
    ##   Aroon Up = ((period - periods since period high) / period) * 100
    ##   Aroon Down = ((period - periods since period low) / period) * 100
    ##   Aroon Oscillator = Aroon Up - Aroon Down
    ##
    ## Interpretation:
    ## - Aroon Up > 70 and Aroon Down < 30: Strong uptrend
    ## - Aroon Down > 70 and Aroon Up < 30: Strong downtrend
    ## - Both near 50: Consolidation
    ## - Aroon Oscillator > 0: Bullish
    ## - Aroon Oscillator < 0: Bearish
    ## - Crossovers signal trend changes
    period: int
    highs: seq[float64]
    lows: seq[float64]
    pos: int
    length: int

proc newAROON*(period: int = 25, memSize: int = 1): AROON =
  ## Create new Aroon indicator
  ##
  ## Args:
  ##   period: Number of periods to look back (default 25)
  ##   memSize: Size of circular buffer for storing computed values (default 1)
  ##
  ## Example:
  ##   var aroon = newAROON(25)
  ##   let aroonResult = aroon.update(high, low)
  result = AROON(
    memData: newSeq[AroonResult](memSize),
    memPos: 0,
    memSize: memSize,
    period: period,
    highs: newSeq[float64](period),
    lows: newSeq[float64](period),
    pos: 0,
    length: 0
  )
  # Initialize buffer with NaN
  for i in 0..<memSize:
    result.memData[i] = AroonResult(up: NaN, down: NaN, oscillator: NaN)

proc update*(aroon: AROON, high, low: float64): AroonResult =
  ## Update Aroon with new bar
  ##
  ## Returns current Aroon result (NaN if insufficient data)

  # Store values in circular buffer
  aroon.highs[aroon.pos] = high
  aroon.lows[aroon.pos] = low
  aroon.pos = (aroon.pos + 1) mod aroon.period

  if aroon.length < aroon.period:
    aroon.length += 1

  if aroon.length < aroon.period:
    aroon.push(AroonResult(up: NaN, down: NaN, oscillator: NaN))
    return aroon[0]

  # Find periods since highest high and lowest low
  # Iterate from most recent (periodsAgo=0) to oldest (periodsAgo=period-1)
  var highestHigh = -Inf
  var lowestLow = Inf
  var periodsSinceHigh = aroon.period - 1 # Start with oldest
  var periodsSinceLow = aroon.period - 1

  for periodsAgo in 0..<aroon.period:
    # Calculate actual index in circular buffer
    # Most recent value is at (pos - 1), going backwards in time
    let idx = (aroon.pos - 1 - periodsAgo + aroon.period) mod aroon.period

    if aroon.highs[idx] >= highestHigh:
      highestHigh = aroon.highs[idx]
      periodsSinceHigh = periodsAgo

    if aroon.lows[idx] <= lowestLow:
      lowestLow = aroon.lows[idx]
      periodsSinceLow = periodsAgo

  # Calculate Aroon Up and Aroon Down
  let aroonUp = ((aroon.period.float64 - periodsSinceHigh.float64) /
      aroon.period.float64) * 100.0
  let aroonDown = ((aroon.period.float64 - periodsSinceLow.float64) /
      aroon.period.float64) * 100.0
  let aroonOsc = aroonUp - aroonDown

  let aroonResult = AroonResult(
    up: aroonUp,
    down: aroonDown,
    oscillator: aroonOsc
  )

  aroon.push(aroonResult)
  result = aroon[0]

# Stochastic RSI (STOCHRSI)

type
  STOCHRSI* = ref object of Indicator[StochResult]
    ## Stochastic RSI - Applies Stochastic oscillator to RSI values
    ## More sensitive than standard RSI, useful for overbought/oversold in trends
    rsi: RSI
    period: int
    kPeriod: int
    dPeriod: int
    rsiValues: seq[float64] # Circular buffer for RSI values
    pos: int
    length: int
    kMA: MA # Moving average for %K smoothing
    dMA: MA # Moving average for %D

proc newSTOCHRSI*(rsiPeriod: int = 14, period: int = 14, kPeriod: int = 3,
    dPeriod: int = 3, memSize: int = 1): STOCHRSI =
  ## Create new Stochastic RSI indicator
  ##
  ## Args:
  ##   rsiPeriod: Period for RSI calculation (default 14)
  ##   period: Lookback period for Stochastic calculation (default 14)
  ##   kPeriod: Smoothing period for %K (default 3)
  ##   dPeriod: Smoothing period for %D (default 3)
  ##   memSize: Size of circular buffer (default 1)
  result = STOCHRSI(
    memData: newSeq[StochResult](memSize),
    memPos: 0,
    memSize: memSize,
    rsi: newRSI(rsiPeriod),
    period: period,
    kPeriod: kPeriod,
    dPeriod: dPeriod,
    rsiValues: newSeq[float64](period),
    pos: 0,
    length: 0,
    kMA: newMA(kPeriod),
    dMA: newMA(dPeriod)
  )

proc update*(stochRsi: STOCHRSI, openPrice, closePrice: float64): StochResult =
  ## Update Stochastic RSI with price data
  ##
  ## Returns StochResult with %K and %D values (NaN if insufficient data)

  # First, calculate RSI
  let rsiValue = stochRsi.rsi.update(openPrice, closePrice)

  # Store RSI value in circular buffer
  stochRsi.rsiValues[stochRsi.pos] = rsiValue
  stochRsi.pos = (stochRsi.pos + 1) mod stochRsi.period
  if stochRsi.length < stochRsi.period:
    stochRsi.length += 1

  # Need full period of RSI values to calculate Stochastic
  if stochRsi.length < stochRsi.period or classify(rsiValue) == fcNan:
    stochRsi.push(StochResult(k: NaN, d: NaN))
    return stochRsi[0]

  # Find highest and lowest RSI over the period
  var highestRSI = -Inf
  var lowestRSI = Inf

  for i in 0..<stochRsi.period:
    let rsi = stochRsi.rsiValues[i]
    if classify(rsi) != fcNan:
      if rsi > highestRSI:
        highestRSI = rsi
      if rsi < lowestRSI:
        lowestRSI = rsi

  # Calculate raw Stochastic value
  var rawK: float64
  if highestRSI == lowestRSI:
    rawK = 50.0 # Neutral when no range
  else:
    rawK = ((rsiValue - lowestRSI) / (highestRSI - lowestRSI)) * 100.0

  # Smooth with moving averages
  let smoothedK = stochRsi.kMA.update(rawK)
  let smoothedD = stochRsi.dMA.update(smoothedK)

  let stochResult = StochResult(
    k: smoothedK,
    d: smoothedD
  )

  stochRsi.push(stochResult)
  result = stochRsi[0]

# Percentage Price Oscillator (PPO)

type
  PPOResult* = object
    ## Result from PPO indicator
    ppo*: float64       # Main PPO line (fast EMA - slow EMA) / slow EMA * 100
    signal*: float64    # Signal line (EMA of PPO)
    histogram*: float64 # Histogram (PPO - Signal)

  PPO* = ref object of Indicator[PPOResult]
    ## Percentage Price Oscillator - MACD expressed as percentage
    ## Better for cross-asset comparison than absolute MACD
    fastPeriod: int
    slowPeriod: int
    signalPeriod: int
    fastEMA: EMA
    slowEMA: EMA
    signalEMA: EMA
    length: int

proc newPPO*(fastPeriod: int = 12, slowPeriod: int = 26, signalPeriod: int = 9,
    memSize: int = 1): PPO =
  ## Create new Percentage Price Oscillator
  ##
  ## Args:
  ##   fastPeriod: Fast EMA period (default 12)
  ##   slowPeriod: Slow EMA period (default 26)
  ##   signalPeriod: Signal line EMA period (default 9)
  ##   memSize: Size of circular buffer (default 1)
  result = PPO(
    memData: newSeq[PPOResult](memSize),
    memPos: 0,
    memSize: memSize,
    fastPeriod: fastPeriod,
    slowPeriod: slowPeriod,
    signalPeriod: signalPeriod,
    fastEMA: newEMA(fastPeriod),
    slowEMA: newEMA(slowPeriod),
    signalEMA: newEMA(signalPeriod),
    length: 0
  )

proc update*(ppo: PPO, value: float64): PPOResult =
  ## Update PPO with new price value
  ##
  ## Returns PPOResult with ppo, signal, and histogram (NaN if insufficient data)
  ppo.length += 1

  let fastValue = ppo.fastEMA.update(value)
  let slowValue = ppo.slowEMA.update(value)

  # Need both EMAs ready before calculating PPO
  if ppo.length < ppo.slowPeriod or classify(slowValue) == fcNan or slowValue == 0.0:
    ppo.push(PPOResult(ppo: NaN, signal: NaN, histogram: NaN))
    return ppo[0]

  # Calculate PPO as percentage
  let ppoValue = ((fastValue - slowValue) / slowValue) * 100.0

  # Calculate signal line
  let signalValue = ppo.signalEMA.update(ppoValue)

  # Calculate histogram
  var histValue: float64
  if classify(signalValue) == fcNan:
    histValue = NaN
  else:
    histValue = ppoValue - signalValue

  let ppoResult = PPOResult(
    ppo: ppoValue,
    signal: signalValue,
    histogram: histValue
  )

  ppo.push(ppoResult)
  result = ppo[0]

# Chande Momentum Oscillator (CMO)

type
  CMO* = ref object of Indicator[float64]
    ## Chande Momentum Oscillator - Alternative to RSI
    ## Uses sum of gains/losses instead of average
    ## Range: -100 to +100 (vs RSI 0 to 100)
    period: int
    gains: seq[float64] # Circular buffer for gains
    losses: seq[float64] # Circular buffer for losses
    pos: int
    length: int
    prevClose: float64

proc newCMO*(period: int = 14, memSize: int = 1): CMO =
  ## Create new Chande Momentum Oscillator
  ##
  ## Args:
  ##   period: Lookback period (default 14)
  ##   memSize: Size of circular buffer (default 1)
  result = CMO(
    memData: newSeq[float64](memSize),
    memPos: 0,
    memSize: memSize,
    period: period,
    gains: newSeq[float64](period),
    losses: newSeq[float64](period),
    pos: 0,
    length: 0,
    prevClose: NaN
  )

proc update*(cmo: CMO, close: float64): float64 =
  ## Update CMO with new close price
  ##
  ## Returns CMO value in range -100 to +100 (NaN if insufficient data)

  # Calculate price change
  var gain = 0.0
  var loss = 0.0

  if classify(cmo.prevClose) != fcNan:
    let change = close - cmo.prevClose
    if change > 0:
      gain = change
    elif change < 0:
      loss = -change

  cmo.prevClose = close

  # Store in circular buffers
  cmo.gains[cmo.pos] = gain
  cmo.losses[cmo.pos] = loss
  cmo.pos = (cmo.pos + 1) mod cmo.period
  if cmo.length < cmo.period:
    cmo.length += 1

  # Need full period to calculate CMO
  if cmo.length < cmo.period:
    cmo.push(NaN)
    return cmo[0]

  # Sum all gains and losses
  var sumGains = 0.0
  var sumLosses = 0.0
  for i in 0..<cmo.period:
    sumGains += cmo.gains[i]
    sumLosses += cmo.losses[i]

  # Calculate CMO
  let totalMovement = sumGains + sumLosses
  var cmoValue: float64
  if totalMovement == 0.0:
    cmoValue = 0.0 # No movement = neutral
  else:
    cmoValue = ((sumGains - sumLosses) / totalMovement) * 100.0

  cmo.push(cmoValue)
  result = cmo[0]

# Momentum (MOM)

type
  MOM* = ref object of Indicator[float64]
    ## Simple Momentum - Current price minus price N periods ago
    ## Foundation for many other indicators
    ## Positive = upward momentum, Negative = downward momentum
    period: int
    prices: seq[float64] # Circular buffer for historical prices
    pos: int
    length: int

proc newMOM*(period: int = 10, memSize: int = 1): MOM =
  ## Create new Momentum indicator
  ##
  ## Args:
  ##   period: Lookback period (default 10)
  ##   memSize: Size of circular buffer (default 1)
  result = MOM(
    memData: newSeq[float64](memSize),
    memPos: 0,
    memSize: memSize,
    period: period,
    prices: newSeq[float64](period),
    pos: 0,
    length: 0
  )

proc update*(mom: MOM, price: float64): float64 =
  ## Update Momentum with new price
  ##
  ## Returns momentum value (current - price N periods ago)
  ## Returns NaN if insufficient data

  if mom.length < mom.period:
    # Still collecting initial data
    mom.prices[mom.pos] = price
    mom.pos = (mom.pos + 1) mod mom.period
    mom.length += 1
    mom.push(NaN)
  else:
    # Have enough data - calculate momentum
    # Read old price BEFORE overwriting it
    let oldPrice = mom.prices[mom.pos]
    let momentum = price - oldPrice

    # Now store new price and advance
    mom.prices[mom.pos] = price
    mom.pos = (mom.pos + 1) mod mom.period

    mom.push(momentum)

  result = mom[0]

type
  PSARResult* = object
    ## Parabolic SAR result
    sar*: float64    ## SAR value (stop and reverse level)
    isUptrend*: bool ## True if in uptrend, False if in downtrend
    af*: float64     ## Current acceleration factor

type
  PSAR* = ref object of Indicator[PSARResult]
    ## Parabolic SAR (Stop and Reverse)
    ##
    ## Provides dynamic trailing stop levels that follow price trends.
    ## SAR dots appear below price during uptrends and above during downtrends.
    ##
    ## Interpretation:
    ## - When price crosses above SAR: Buy signal (trend reversal to uptrend)
    ## - When price crosses below SAR: Sell signal (trend reversal to downtrend)
    ## - Distance between price and SAR indicates trend strength
    ## - SAR accelerates toward price as trend continues
    acceleration: float64 ## Acceleration factor step (default 0.02)
    maximum: float64 ## Maximum acceleration factor (default 0.20)
    sar: float64 ## Current SAR value
    extreme: float64 ## Extreme point in current trend
    af: float64 ## Current acceleration factor
    isUptrend: bool ## Current trend direction
    initialized: bool ## Whether indicator has been initialized
    initHigh: float64 ## Initial high for first 2 bars
    initLow: float64 ## Initial low for first 2 bars
    barCount: int ## Number of bars processed

proc newPSAR*(acceleration: float64 = 0.02, maximum: float64 = 0.20,
    memSize: int = 1): PSAR =
  ## Create new Parabolic SAR indicator
  ##
  ## Args:
  ##   acceleration: Acceleration factor step (default 0.02)
  ##   maximum: Maximum acceleration factor (default 0.20)
  ##   memSize: Size of circular buffer for storing computed values (default 1)
  ##
  ## Example:
  ## .. code-block:: nim
  ##    var psar = newPSAR(acceleration = 0.02, maximum = 0.20, memSize = 10)
  ##    for bar in data:
  ##      let result = psar.update(bar.high, bar.low, bar.close)
  ##      if result.isUptrend:
  ##        echo "SAR (uptrend): ", result.sar
  ##      else:
  ##        echo "SAR (downtrend): ", result.sar
  var memData = newSeq[PSARResult](memSize)
  # Initialize with NaN values
  for i in 0..<memSize:
    memData[i] = PSARResult(sar: NaN, isUptrend: true, af: acceleration)

  result = PSAR(
    memData: memData,
    memPos: 0,
    memSize: memSize,
    acceleration: acceleration,
    maximum: maximum,
    sar: NaN,
    extreme: NaN,
    af: acceleration,
    isUptrend: true,
    initialized: false,
    initHigh: -Inf,
    initLow: Inf,
    barCount: 0
  )

proc update*(psar: PSAR, high, low, close: float64): PSARResult =
  ## Update Parabolic SAR with new bar
  ##
  ## Args:
  ##   high: High price of the bar
  ##   low: Low price of the bar
  ##   close: Close price of the bar
  ##
  ## Returns:
  ##   PSARResult with SAR value, trend direction, and acceleration factor
  psar.barCount += 1

  # Need at least 2 bars to initialize
  if psar.barCount == 1:
    psar.initHigh = high
    psar.initLow = low
    let psarResult = PSARResult(sar: NaN, isUptrend: true,
        af: psar.acceleration)
    psar.push(psarResult)
    return psarResult

  if not psar.initialized:
    # Initialize on second bar
    # Assume uptrend if close > open, otherwise downtrend
    # Use first two bars to determine initial trend
    if close > psar.initLow:
      # Start in uptrend
      psar.isUptrend = true
      psar.sar = psar.initLow # SAR starts at the low
      psar.extreme = max(psar.initHigh, high) # EP is the highest high
    else:
      # Start in downtrend
      psar.isUptrend = false
      psar.sar = psar.initHigh # SAR starts at the high
      psar.extreme = min(psar.initLow, low) # EP is the lowest low

    psar.af = psar.acceleration
    psar.initialized = true

    let psarResult = PSARResult(sar: psar.sar, isUptrend: psar.isUptrend, af: psar.af)
    psar.push(psarResult)
    return psarResult

  # Calculate new SAR value
  let prevSAR = psar.sar
  let prevExtreme = psar.extreme
  let prevAF = psar.af
  let wasUptrend = psar.isUptrend

  # Update SAR using formula: SAR = prior SAR + prior AF * (prior EP - prior SAR)
  psar.sar = prevSAR + prevAF * (prevExtreme - prevSAR)

  # Check for trend reversal
  var reversal = false

  if wasUptrend:
    # In uptrend: SAR should be below price
    # Reversal if SAR crosses above the low
    if psar.sar > low:
      reversal = true
      psar.isUptrend = false
      psar.sar = prevExtreme # SAR becomes the extreme point of previous trend
      psar.extreme = low # New extreme is current low
      psar.af = psar.acceleration # Reset AF
    else:
      # Continue uptrend
      # Ensure SAR doesn't exceed the low of previous 2 bars
      # (This prevents SAR from being too close to price)
      if psar.sar > low:
        psar.sar = low

      # Update extreme point if new high
      if high > psar.extreme:
        psar.extreme = high
        # Increase acceleration factor
        psar.af = min(psar.af + psar.acceleration, psar.maximum)
  else:
    # In downtrend: SAR should be above price
    # Reversal if SAR crosses below the high
    if psar.sar < high:
      reversal = true
      psar.isUptrend = true
      psar.sar = prevExtreme # SAR becomes the extreme point of previous trend
      psar.extreme = high # New extreme is current high
      psar.af = psar.acceleration # Reset AF
    else:
      # Continue downtrend
      # Ensure SAR doesn't go below the high of previous 2 bars
      if psar.sar < high:
        psar.sar = high

      # Update extreme point if new low
      if low < psar.extreme:
        psar.extreme = low
        # Increase acceleration factor
        psar.af = min(psar.af + psar.acceleration, psar.maximum)

  let psarResult = PSARResult(sar: psar.sar, isUptrend: psar.isUptrend, af: psar.af)
  psar.push(psarResult)
  result = psarResult

# SMA is an alias for MA
type SMA* = MA

proc newSMA*(period: int, memSize: int = 1): SMA =
  ## Create Simple Moving Average (alias for MA)
  result = newMA(period, memSize)
