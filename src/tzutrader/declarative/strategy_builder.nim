## Strategy Builder with Indicator Factory
##
## This module builds executable strategies from StrategyYAML definitions.
## It creates indicator instances, evaluates conditions, and generates signals.
##
## Phase 1: Semi-automated approach - manual indicator mapping
## Phase 2: Full introspection using macros (future enhancement)

import std/[tables, strformat, strutils, options]
import ../strategy
import ../strategies/base  # Import for PositionSizingType
import ../indicators
import ../core
import ./schema

export PositionSizingType  # Export position sizing types

type
  IndicatorKind* = enum
    ## Supported indicator types
    ikMA, ikEMA, ikRSI, ikMACD, ikBollinger, ikSTOCH, ikCCI, ikMFI,
    ikADX, ikATR, ikOBV, ikAROON, ikPSAR,
    # Category 1: Advanced Moving Averages
    ikTRIMA, ikDEMA, ikTEMA, ikKAMA,
    # Category 2: Statistical Indicators
    ikMV, ikSTDEV, ikTRANGE,
    # Category 3: Volatility Indicators
    ikNATR,
    # Category 4: Volume Indicators
    ikAD,
    # Category 5: Momentum Indicators
    ikMOM, ikCMO,
    # Category 6: Advanced Oscillators
    ikSTOCHRSI, ikPPO
  
  IndicatorInstance* = ref object
    ## Runtime indicator instance with type-erased interface
    case kind*: IndicatorKind
    of ikMA:
      ma*: MA
    of ikEMA:
      ema*: EMA
    of ikRSI:
      rsi*: RSI
    of ikMACD:
      macd*: MACD
    of ikBollinger:
      bb*: BollingerBands
    of ikSTOCH:
      stoch*: STOCH
    of ikCCI:
      cci*: CCI
    of ikMFI:
      mfi*: MFI
    of ikADX:
      adx*: ADX
    of ikATR:
      atr*: ATR
    of ikOBV:
      obv*: OBV
    of ikAROON:
      aroon*: AROON
    of ikPSAR:
      psar*: PSAR
    # Category 1: Advanced Moving Averages
    of ikTRIMA:
      trima*: TRIMA
    of ikDEMA:
      dema*: DEMA
    of ikTEMA:
      tema*: TEMA
    of ikKAMA:
      kama*: KAMA
    # Category 2: Statistical Indicators
    of ikMV:
      mv*: MV
    of ikSTDEV:
      stdev*: STDEV
    of ikTRANGE:
      trange*: TRANGE
    # Category 3: Volatility Indicators
    of ikNATR:
      natr*: NATR
    # Category 4: Volume Indicators
    of ikAD:
      ad*: AD
    # Category 5: Momentum Indicators
    of ikMOM:
      mom*: MOM
    of ikCMO:
      cmo*: CMO
    # Category 6: Advanced Oscillators
    of ikSTOCHRSI:
      stochrsi*: STOCHRSI
    of ikPPO:
      ppo*: PPO
  
  DeclarativeStrategy* = ref object of Strategy
    ## A strategy built from YAML definition
    strategyDef*: StrategyYAML
    indicators*: Table[string, IndicatorInstance]
    indicatorSources*: Table[string, string]  # Maps indicator ID to source field
    indicatorOutputs*: Table[string, string]  # Maps indicator ID to output field
    lastSignal*: Position
    previousValues*: Table[string, float64]  # For crosses_above/below detection
  
  BuildError* = object of CatchableError
    ## Error during strategy building

# ============================================================================
# Indicator Factory
# ============================================================================

proc getIntParam(params: Table[string, ParamValue], key: string, default: int): int =
  ## Get integer parameter with default
  if params.hasKey(key):
    let p = params[key]
    if p.kind == pkInt:
      return p.intVal
    elif p.kind == pkFloat:
      return p.floatVal.int
  return default

proc getFloatParam(params: Table[string, ParamValue], key: string, default: float): float =
  ## Get float parameter with default
  if params.hasKey(key):
    let p = params[key]
    if p.kind == pkFloat:
      return p.floatVal
    elif p.kind == pkInt:
      return p.intVal.float
  return default

proc createIndicator*(indicatorDef: IndicatorYAML): IndicatorInstance =
  ## Create an indicator instance from YAML definition
  ## This is the semi-automated factory approach for Phase 1
  let indType = indicatorDef.indicatorType.toLowerAscii()
  
  case indType
  of "ma", "sma":
    let period = getIntParam(indicatorDef.params, "period", 20)
    result = IndicatorInstance(kind: ikMA, ma: newMA(period))
  
  of "ema":
    let period = getIntParam(indicatorDef.params, "period", 20)
    let alpha = getFloatParam(indicatorDef.params, "alpha", 2.0)
    result = IndicatorInstance(kind: ikEMA, ema: newEMA(period, alpha))
  
  of "rsi":
    let period = getIntParam(indicatorDef.params, "period", 14)
    result = IndicatorInstance(kind: ikRSI, rsi: newRSI(period))
  
  of "macd":
    let fast = getIntParam(indicatorDef.params, "fast", 12)
    let slow = getIntParam(indicatorDef.params, "slow", 26)
    let signal = getIntParam(indicatorDef.params, "signal", 9)
    result = IndicatorInstance(kind: ikMACD, macd: newMACD(fast, slow, signal))
  
  of "bollinger", "bb":
    let period = getIntParam(indicatorDef.params, "period", 20)
    let numStdDev = getFloatParam(indicatorDef.params, "numStdDev", 2.0)
    result = IndicatorInstance(kind: ikBollinger, bb: newBollingerBands(period, numStdDev))
  
  of "stoch", "stochastic":
    let kPeriod = getIntParam(indicatorDef.params, "kPeriod", 14)
    let dPeriod = getIntParam(indicatorDef.params, "dPeriod", 3)
    result = IndicatorInstance(kind: ikSTOCH, stoch: newSTOCH(kPeriod, dPeriod))
  
  of "cci":
    let period = getIntParam(indicatorDef.params, "period", 20)
    result = IndicatorInstance(kind: ikCCI, cci: newCCI(period))
  
  of "mfi":
    let period = getIntParam(indicatorDef.params, "period", 14)
    result = IndicatorInstance(kind: ikMFI, mfi: newMFI(period))
  
  of "adx":
    let period = getIntParam(indicatorDef.params, "period", 14)
    result = IndicatorInstance(kind: ikADX, adx: newADX(period))
  
  of "atr":
    let period = getIntParam(indicatorDef.params, "period", 14)
    result = IndicatorInstance(kind: ikATR, atr: newATR(period))
  
  of "obv":
    result = IndicatorInstance(kind: ikOBV, obv: newOBV())
  
  of "aroon":
    let period = getIntParam(indicatorDef.params, "period", 25)
    result = IndicatorInstance(kind: ikAROON, aroon: newAROON(period))
  
  of "psar", "parabolic_sar":
    let acceleration = getFloatParam(indicatorDef.params, "acceleration", 0.02)
    let maximum = getFloatParam(indicatorDef.params, "maximum", 0.20)
    result = IndicatorInstance(kind: ikPSAR, psar: newPSAR(acceleration, maximum))
  
  # Category 1: Advanced Moving Averages
  
  of "trima", "triangular_ma":
    let period = getIntParam(indicatorDef.params, "period", 20)
    result = IndicatorInstance(kind: ikTRIMA, trima: newTRIMA(period))
  
  of "dema", "double_ema":
    let period = getIntParam(indicatorDef.params, "period", 20)
    result = IndicatorInstance(kind: ikDEMA, dema: newDEMA(period))
  
  of "tema", "triple_ema":
    let period = getIntParam(indicatorDef.params, "period", 20)
    result = IndicatorInstance(kind: ikTEMA, tema: newTEMA(period))
  
  of "kama", "kaufman":
    let period = getIntParam(indicatorDef.params, "period", 10)
    let fastPeriod = getIntParam(indicatorDef.params, "fastPeriod", 2)
    let slowPeriod = getIntParam(indicatorDef.params, "slowPeriod", 30)
    result = IndicatorInstance(kind: ikKAMA, kama: newKAMA(period, fastPeriod, slowPeriod))
  
  # Category 2: Statistical Indicators
  
  of "mv", "variance":
    let period = getIntParam(indicatorDef.params, "period", 20)
    result = IndicatorInstance(kind: ikMV, mv: newMV(period))
  
  of "stdev", "stddev", "standard_deviation":
    let period = getIntParam(indicatorDef.params, "period", 20)
    result = IndicatorInstance(kind: ikSTDEV, stdev: newSTDEV(period))
  
  of "trange", "true_range":
    result = IndicatorInstance(kind: ikTRANGE, trange: newTRANGE())
  
  # Category 3: Volatility Indicators
  
  of "natr", "normalized_atr":
    let period = getIntParam(indicatorDef.params, "period", 14)
    result = IndicatorInstance(kind: ikNATR, natr: newNATR(period))
  
  # Category 4: Volume Indicators
  
  of "ad", "accumulation_distribution":
    result = IndicatorInstance(kind: ikAD, ad: newAD())
  
  # Category 5: Momentum Indicators
  
  of "mom", "momentum":
    let period = getIntParam(indicatorDef.params, "period", 10)
    result = IndicatorInstance(kind: ikMOM, mom: newMOM(period))
  
  of "cmo", "chande":
    let period = getIntParam(indicatorDef.params, "period", 14)
    result = IndicatorInstance(kind: ikCMO, cmo: newCMO(period))
  
  # Category 6: Advanced Oscillators
  
  of "stochrsi", "stochastic_rsi":
    let rsiPeriod = getIntParam(indicatorDef.params, "rsiPeriod", 14)
    let period = getIntParam(indicatorDef.params, "period", 14)
    let kPeriod = getIntParam(indicatorDef.params, "kPeriod", 3)
    let dPeriod = getIntParam(indicatorDef.params, "dPeriod", 3)
    result = IndicatorInstance(kind: ikSTOCHRSI, stochrsi: newSTOCHRSI(rsiPeriod, period, kPeriod, dPeriod))
  
  of "ppo", "percentage_price_oscillator":
    let fastPeriod = getIntParam(indicatorDef.params, "fastPeriod", 12)
    let slowPeriod = getIntParam(indicatorDef.params, "slowPeriod", 26)
    let signalPeriod = getIntParam(indicatorDef.params, "signalPeriod", 9)
    result = IndicatorInstance(kind: ikPPO, ppo: newPPO(fastPeriod, slowPeriod, signalPeriod))
  
  else:
    raise newException(BuildError, "Unknown indicator type: " & indicatorDef.indicatorType)

# ============================================================================
# Indicator Value Extraction
# ============================================================================

proc getValue*(ind: IndicatorInstance, subfield: string = ""): float64 =
  ## Get current value from indicator
  ## Subfield allows accessing sub-values like "signal" for MACD
  case ind.kind
  of ikMA:
    result = ind.ma[0]
  of ikEMA:
    result = ind.ema[0]
  of ikRSI:
    result = ind.rsi[0]
  of ikMACD:
    if subfield == "signal":
      result = ind.macd[0].signal
    elif subfield == "histogram" or subfield == "hist":
      result = ind.macd[0].hist
    else:
      result = ind.macd[0].macd  # MACD line
  of ikBollinger:
    if subfield == "upper":
      result = ind.bb[0].upper
    elif subfield == "lower":
      result = ind.bb[0].lower
    else:
      result = ind.bb[0].middle  # Middle band (SMA)
  of ikSTOCH:
    if subfield == "d":
      result = ind.stoch[0].d
    else:
      result = ind.stoch[0].k
  of ikCCI:
    result = ind.cci[0]
  of ikMFI:
    result = ind.mfi[0]
  of ikADX:
    if subfield == "di_plus" or subfield == "plus":
      result = ind.adx[0].plusDI
    elif subfield == "di_minus" or subfield == "minus":
      result = ind.adx[0].minusDI
    else:
      result = ind.adx[0].adx  # ADX value
  of ikATR:
    result = ind.atr[0]
  of ikOBV:
    result = ind.obv[0]
  of ikAROON:
    if subfield == "down":
      result = ind.aroon[0].down
    elif subfield == "oscillator":
      result = ind.aroon[0].oscillator
    else:
      result = ind.aroon[0].up
  of ikPSAR:
    result = ind.psar[0].sar
  # Category 1: Advanced Moving Averages
  of ikTRIMA:
    result = ind.trima[0]
  of ikDEMA:
    result = ind.dema[0]
  of ikTEMA:
    result = ind.tema[0]
  of ikKAMA:
    result = ind.kama[0]
  # Category 2: Statistical Indicators
  of ikMV:
    result = ind.mv[0]
  of ikSTDEV:
    result = ind.stdev[0]
  of ikTRANGE:
    result = ind.trange[0]
  # Category 3: Volatility Indicators
  of ikNATR:
    result = ind.natr[0]
  # Category 4: Volume Indicators
  of ikAD:
    result = ind.ad[0]
  # Category 5: Momentum Indicators
  of ikMOM:
    result = ind.mom[0]
  of ikCMO:
    result = ind.cmo[0]
  # Category 6: Advanced Oscillators
  of ikSTOCHRSI:
    if subfield == "d":
      result = ind.stochrsi[0].d
    else:
      result = ind.stochrsi[0].k
  of ikPPO:
    if subfield == "signal":
      result = ind.ppo[0].signal
    elif subfield == "histogram" or subfield == "hist":
      result = ind.ppo[0].histogram
    else:
      result = ind.ppo[0].ppo

proc updateIndicator*(ind: IndicatorInstance, bar: OHLCV, source: string = "close") =
  ## Update indicator with new bar
  ## source specifies which field to use: open, high, low, close, volume
  ## Note: Returns nothing, use getValue() to get current value
  
  # Get the source value
  let sourceValue = case source
    of "open": bar.open
    of "high": bar.high
    of "low": bar.low
    of "close": bar.close
    of "volume": bar.volume
    else: bar.close
  
  case ind.kind
  # Single-value indicators that can use any source
  of ikMA:
    discard ind.ma.update(sourceValue)
  of ikEMA:
    discard ind.ema.update(sourceValue)
  of ikTRIMA:
    discard ind.trima.update(sourceValue)
  of ikDEMA:
    discard ind.dema.update(sourceValue)
  of ikTEMA:
    discard ind.tema.update(sourceValue)
  of ikKAMA:
    discard ind.kama.update(sourceValue)
  of ikMV:
    discard ind.mv.update(sourceValue)
  of ikSTDEV:
    discard ind.stdev.update(sourceValue)
  of ikMOM:
    discard ind.mom.update(sourceValue)
  of ikCMO:
    discard ind.cmo.update(sourceValue)
  of ikMACD:
    discard ind.macd.update(sourceValue)
  of ikBollinger:
    discard ind.bb.update(sourceValue)
  of ikPPO:
    discard ind.ppo.update(sourceValue)
  
  # Multi-value indicators that require specific OHLC fields
  of ikRSI:
    discard ind.rsi.update(bar.open, bar.close)
  of ikSTOCH:
    discard ind.stoch.update(bar.high, bar.low, bar.close)
  of ikCCI:
    discard ind.cci.update(bar.high, bar.low, bar.close)
  of ikMFI:
    discard ind.mfi.update(bar.high, bar.low, bar.close, bar.volume)
  of ikADX:
    discard ind.adx.update(bar.high, bar.low, bar.close)
  of ikATR:
    discard ind.atr.update(bar.high, bar.low, bar.close)
  of ikOBV:
    discard ind.obv.update(bar.close, bar.volume)
  of ikAROON:
    discard ind.aroon.update(bar.high, bar.low)
  of ikPSAR:
    discard ind.psar.update(bar.high, bar.low, bar.close)
  of ikTRANGE:
    discard ind.trange.update(bar.high, bar.low, bar.close)
  of ikNATR:
    discard ind.natr.update(bar.high, bar.low, bar.close)
  of ikAD:
    discard ind.ad.update(bar.high, bar.low, bar.close, bar.volume)
  of ikSTOCHRSI:
    discard ind.stochrsi.update(bar.open, bar.close)

# ============================================================================
# Condition Evaluation
# ============================================================================

proc parseReference*(s: DeclarativeStrategy, refStr: string, bar: OHLCV): float64 =
  ## Parse a reference and return its value
  ## References can be:
  ## - Indicator IDs: "rsi_14"
  ## - Indicator subfields: "macd_12_26_9.signal"
  ## - Special keywords: "price", "volume", etc.
  ## - Literal numbers: "30", "70"
  
  # Try literal number first
  try:
    return parseFloat(refStr)
  except ValueError:
    discard
  
  # Check for special keywords
  case refStr.toLowerAscii()
  of "price", "close":
    return bar.close
  of "open":
    return bar.open
  of "high":
    return bar.high
  of "low":
    return bar.low
  of "volume":
    return bar.volume
  else:
    discard
  
  # Check for indicator with subfield
  let parts = refStr.split('.')
  if parts.len == 2:
    # Has subfield like "macd.signal"
    if s.indicators.hasKey(parts[0]):
      return s.indicators[parts[0]].getValue(parts[1])
    else:
      raise newException(BuildError, "Unknown indicator: " & parts[0])
  elif parts.len == 1:
    # Simple indicator reference - check for configured output
    if s.indicators.hasKey(refStr):
      # Use configured output if available, otherwise use default (empty string)
      let output = s.indicatorOutputs.getOrDefault(refStr, "")
      return s.indicators[refStr].getValue(output)
    else:
      raise newException(BuildError, "Unknown reference: " & refStr)
  else:
    raise newException(BuildError, "Invalid reference format: " & refStr)

proc evaluateCondition*(s: DeclarativeStrategy, condition: ConditionYAML, bar: OHLCV): bool =
  ## Evaluate a condition (recursive for AND/OR)
  ## Returns true if condition is met
  case condition.kind
  of ckSimple:
    let leftVal = s.parseReference(condition.left, bar)
    let rightVal = s.parseReference(condition.right, bar)
    
    # Handle NaN values (insufficient data)
    if leftVal.isNaN or rightVal.isNaN:
      return false
    
    case condition.operator
    of opLessThan:
      return leftVal < rightVal
    of opGreaterThan:
      return leftVal > rightVal
    of opLessEqual:
      return leftVal <= rightVal
    of opGreaterEqual:
      return leftVal >= rightVal
    of opEqual:
      return abs(leftVal - rightVal) < 1e-9  # Float equality with tolerance
    of opNotEqual:
      return abs(leftVal - rightVal) >= 1e-9
    of opCrossesAbove:
      # Current: left > right, Previous: left <= right
      let key = condition.left & "_vs_" & condition.right
      let prevLeft = s.previousValues.getOrDefault(key & "_left", NaN)
      let prevRight = s.previousValues.getOrDefault(key & "_right", NaN)
      
      # Store current values for next comparison
      s.previousValues[key & "_left"] = leftVal
      s.previousValues[key & "_right"] = rightVal
      
      if prevLeft.isNaN or prevRight.isNaN:
        return false  # Need at least 2 bars for crossover
      
      return (leftVal > rightVal) and (prevLeft <= prevRight)
    
    of opCrossesBelow:
      # Current: left < right, Previous: left >= right
      let key = condition.left & "_vs_" & condition.right
      let prevLeft = s.previousValues.getOrDefault(key & "_left", NaN)
      let prevRight = s.previousValues.getOrDefault(key & "_right", NaN)
      
      # Store current values for next comparison
      s.previousValues[key & "_left"] = leftVal
      s.previousValues[key & "_right"] = rightVal
      
      if prevLeft.isNaN or prevRight.isNaN:
        return false
      
      return (leftVal < rightVal) and (prevLeft >= prevRight)
  
  of ckAnd:
    # All conditions must be true (short-circuit evaluation)
    for child in condition.andConditions:
      if not s.evaluateCondition(child, bar):
        return false
    return true
  
  of ckOr:
    # At least one condition must be true (short-circuit evaluation)
    for child in condition.orConditions:
      if s.evaluateCondition(child, bar):
        return true
    return false
  
  of ckNot:
    raise newException(BuildError, "NOT conditions not supported in Phase 1")

# ============================================================================
# Strategy Builder
# ============================================================================

proc buildStrategy*(strategyDef: StrategyYAML): DeclarativeStrategy =
  ## Build an executable strategy from YAML definition
  ## Creates indicator instances and prepares for execution
  
  result = DeclarativeStrategy(
    name: strategyDef.metadata.name,
    symbol: "",  # Will be set when running
    strategyDef: strategyDef,
    indicators: initTable[string, IndicatorInstance](),
    indicatorSources: initTable[string, string](),
    indicatorOutputs: initTable[string, string](),
    lastSignal: Position.Stay,
    previousValues: initTable[string, float64]()
  )
  
  # Create all indicator instances and store source/output configurations
  for indicatorDef in strategyDef.indicators:
    result.indicators[indicatorDef.id] = createIndicator(indicatorDef)
    
    # Store source configuration (default to "close")
    if indicatorDef.source.isSome():
      result.indicatorSources[indicatorDef.id] = indicatorDef.source.get()
    else:
      result.indicatorSources[indicatorDef.id] = "close"
    
    # Store output configuration if specified
    if indicatorDef.output.isSome():
      result.indicatorOutputs[indicatorDef.id] = indicatorDef.output.get()

# ============================================================================
# Strategy Execution
# ============================================================================

method onBar*(s: DeclarativeStrategy, bar: OHLCV): Signal =
  ## Process a single bar and generate signal
  ## Updates all indicators and evaluates entry/exit rules
  
  # Update all indicators with the new bar, using their configured source
  for id, indicator in s.indicators:
    let source = s.indicatorSources.getOrDefault(id, "close")
    updateIndicator(indicator, bar, source)
  
  var position = Position.Stay
  var reason = ""
  
  # Evaluate entry rule
  if s.evaluateCondition(s.strategyDef.entryRule.conditions, bar):
    if s.lastSignal != Position.Buy:
      position = Position.Buy
      reason = "Entry conditions met"
      s.lastSignal = Position.Buy
  
  # Evaluate exit rule
  if s.evaluateCondition(s.strategyDef.exitRule.conditions, bar):
    if s.lastSignal != Position.Sell:
      position = Position.Sell
      reason = "Exit conditions met"
      s.lastSignal = Position.Sell
  
  # If no signal, keep current state
  if position == Position.Stay:
    reason = "Conditions not met"
  
  result = Signal(
    position: position,
    symbol: s.symbol,
    timestamp: bar.timestamp,
    price: bar.close,
    reason: reason
  )

method reset*(s: DeclarativeStrategy) =
  ## Reset strategy state
  s.lastSignal = Position.Stay
  s.previousValues.clear()
  
method getPositionSizing*(s: DeclarativeStrategy): tuple[sizingType: PositionSizingType, value: float] =
  ## Return position sizing configuration from YAML definition
  case s.strategyDef.positionSizing.kind
  of psFixed:
    result = (pstFixed, s.strategyDef.positionSizing.fixedSize)
  of psPercent:
    result = (pstPercent, s.strategyDef.positionSizing.percentCapital)
  of psDynamic:
    # Phase 3 - not yet implemented
    raise newException(BuildError, "Dynamic position sizing not yet implemented")

  # Recreate all indicators
  for indicatorDef in s.strategyDef.indicators:
    s.indicators[indicatorDef.id] = createIndicator(indicatorDef)
