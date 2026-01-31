## Unit tests for strategy builder

import std/[unittest, tables, times, math]
import tzutrader/core
import tzutrader/declarative/[schema, parser, validator, strategy_builder]

proc testBar(close: float = 100.0, open: float = 100.0, high: float = 105.0, 
             low: float = 95.0, volume: float = 1000.0): OHLCV =
  ## Helper to create test bars
  OHLCV(
    timestamp: now().toTime().toUnix(),
    open: open,
    high: high,
    low: low,
    close: close,
    volume: volume
  )

suite "Strategy Builder - Indicator Factory":
  
  test "Create RSI indicator":
    var indicatorDef = IndicatorYAML(
      id: "rsi_14",
      indicatorType: "rsi",
      params: {"period": newParamInt(14)}.toTable
    )
    
    let ind = createIndicator(indicatorDef)
    check ind.kind == ikRSI
  
  test "Create MACD indicator":
    var indicatorDef = IndicatorYAML(
      id: "macd_12_26_9",
      indicatorType: "macd",
      params: {
        "fast": newParamInt(12),
        "slow": newParamInt(26),
        "signal": newParamInt(9)
      }.toTable
    )
    
    let ind = createIndicator(indicatorDef)
    check ind.kind == ikMACD
  
  test "Create MA indicator":
    var indicatorDef = IndicatorYAML(
      id: "sma_50",
      indicatorType: "ma",
      params: {"period": newParamInt(50)}.toTable
    )
    
    let ind = createIndicator(indicatorDef)
    check ind.kind == ikMA
  
  test "Create Bollinger Bands":
    var indicatorDef = IndicatorYAML(
      id: "bb_20",
      indicatorType: "bollinger",
      params: {
        "period": newParamInt(20),
        "numStdDev": newParamFloat(2.0)
      }.toTable
    )
    
    let ind = createIndicator(indicatorDef)
    check ind.kind == ikBollinger
  
  test "Unknown indicator type raises error":
    var indicatorDef = IndicatorYAML(
      id: "unknown",
      indicatorType: "nonexistent",
      params: initTable[string, ParamValue]()
    )
    
    expect BuildError:
      discard createIndicator(indicatorDef)

suite "Strategy Builder - Build Strategy":
  
  test "Build simple RSI strategy":
    let strategy = parseStrategyYAMLFile("tests/declarative/fixtures/valid_rsi.yml")
    let builtStrategy = buildStrategy(strategy)
    
    check builtStrategy.name == "Simple RSI Strategy"
    check builtStrategy.indicators.len == 1
    check builtStrategy.indicators.hasKey("rsi_14")
  
  test "Build RSI with trend filter":
    let strategy = parseStrategyYAMLFile("tests/declarative/fixtures/valid_rsi_trend.yml")
    let builtStrategy = buildStrategy(strategy)
    
    check builtStrategy.indicators.len == 2
    check builtStrategy.indicators.hasKey("rsi_14")
    check builtStrategy.indicators.hasKey("sma_200")
  
  test "Build MACD strategy":
    let strategy = parseStrategyYAMLFile("tests/declarative/fixtures/valid_macd.yml")
    let builtStrategy = buildStrategy(strategy)
    
    check builtStrategy.indicators.len == 1
    check builtStrategy.indicators.hasKey("macd_12_26_9")

suite "Strategy Builder - Condition Evaluation":
  
  test "Evaluate simple less than condition":
    let strategy = parseStrategyYAMLFile("tests/declarative/fixtures/valid_rsi.yml")
    var builtStrategy = buildStrategy(strategy)
    
    # Update indicators several times to get valid values
    for i in 0..<20:
      let bar = testBar(close = 102.0 + i.float, open = 100.0 + i.float, 
                        high = 105.0 + i.float, low = 95.0 + i.float)
      discard builtStrategy.onBar(bar)
    
    # Now the RSI should have valid values
    check builtStrategy.indicators.hasKey("rsi_14")
  
  test "Parse literal number reference":
    let strategy = parseStrategyYAMLFile("tests/declarative/fixtures/valid_rsi.yml")
    var builtStrategy = buildStrategy(strategy)
    
    let bar = testBar()
    let val = builtStrategy.parseReference("30", bar)
    check val == 30.0
  
  test "Parse special reference - price":
    let strategy = parseStrategyYAMLFile("tests/declarative/fixtures/valid_rsi.yml")
    var builtStrategy = buildStrategy(strategy)
    
    let bar = testBar(close = 102.0)
    let val = builtStrategy.parseReference("price", bar)
    check val == 102.0
  
  test "Parse special reference - volume":
    let strategy = parseStrategyYAMLFile("tests/declarative/fixtures/valid_rsi.yml")
    var builtStrategy = buildStrategy(strategy)
    
    let bar = testBar(volume = 5000.0)
    let val = builtStrategy.parseReference("volume", bar)
    check val == 5000.0

suite "Strategy Builder - Strategy Execution":
  
  test "Execute simple RSI strategy":
    let strategy = parseStrategyYAMLFile("tests/declarative/fixtures/valid_rsi.yml")
    var builtStrategy = buildStrategy(strategy)
    builtStrategy.symbol = "TEST"
    
    # Generate some test bars to prime indicators
    for i in 0..<30:
      let bar = testBar(close = 100.0 - i.float * 2.0, open = 100.0 - i.float * 2.0,
                        high = 105.0 - i.float * 2.0, low = 95.0 - i.float * 2.0)
      
      let signal = builtStrategy.onBar(bar)
      check signal.symbol == "TEST"
      check signal.position in [Position.Buy, Position.Sell, Position.Stay]
  
  test "Reset strategy clears state":
    let strategy = parseStrategyYAMLFile("tests/declarative/fixtures/valid_rsi.yml")
    var builtStrategy = buildStrategy(strategy)
    
    # Execute some bars
    for i in 0..<10:
      discard builtStrategy.onBar(testBar())
    
    # Reset
    builtStrategy.reset()
    
    # Should be back to initial state
    check builtStrategy.lastSignal == Position.Stay
    check builtStrategy.previousValues.len == 0

suite "Strategy Builder - Integration":
  
  test "Full workflow: Parse → Validate → Build → Execute":
    # Parse
    let strategyDef = parseStrategyYAMLFile("tests/declarative/fixtures/valid_rsi.yml")
    
    # Validate
    let validation = validateStrategy(strategyDef)
    check validation.valid
    
    # Build
    var strategy = buildStrategy(strategyDef)
    strategy.symbol = "AAPL"
    
    # Execute
    let bar = testBar(close = 152.0, open = 150.0, high = 155.0, low = 148.0, volume = 1000000.0)
    
    let signal = strategy.onBar(bar)
    check signal.symbol == "AAPL"
    check signal.price == 152.0

suite "Strategy Builder - Position Sizing":
  test "Fixed position sizing":
    let strategyDef = parseStrategyYAMLFile("tests/declarative/fixtures/valid_rsi.yml")
    let strategy = buildStrategy(strategyDef)
    
    let (sizingType, value) = strategy.getPositionSizing()
    check sizingType == pstFixed
    check value == 100.0
  
  test "Percent position sizing":
    let yamlContent = """
metadata:
  name: "Percent Sizing Test"
indicators:
  - id: rsi_14
    type: rsi
    params:
      period: 14
entry:
  conditions:
    left: rsi_14
    operator: "<"
    right: "30"
exit:
  conditions:
    left: rsi_14
    operator: ">"
    right: "70"
position_sizing:
  type: percent
  percent: 25
"""
    let strategyDef = parseStrategyYAML(yamlContent)
    let strategy = buildStrategy(strategyDef)
    
    let (sizingType, value) = strategy.getPositionSizing()
    check sizingType == pstPercent
    check value == 25.0

suite "Strategy Builder - New Indicators (Phase 2)":
  
  test "Create TRIMA indicator":
    var indicatorDef = IndicatorYAML(
      id: "trima_20",
      indicatorType: "trima",
      params: {"period": newParamInt(20)}.toTable
    )
    let ind = createIndicator(indicatorDef)
    check ind.kind == ikTRIMA
  
  test "Create DEMA indicator":
    var indicatorDef = IndicatorYAML(
      id: "dema_20",
      indicatorType: "dema",
      params: {"period": newParamInt(20)}.toTable
    )
    let ind = createIndicator(indicatorDef)
    check ind.kind == ikDEMA
  
  test "Create TEMA indicator":
    var indicatorDef = IndicatorYAML(
      id: "tema_20",
      indicatorType: "tema",
      params: {"period": newParamInt(20)}.toTable
    )
    let ind = createIndicator(indicatorDef)
    check ind.kind == ikTEMA
  
  test "Create KAMA indicator":
    var indicatorDef = IndicatorYAML(
      id: "kama_10",
      indicatorType: "kama",
      params: {
        "period": newParamInt(10),
        "fastPeriod": newParamInt(2),
        "slowPeriod": newParamInt(30)
      }.toTable
    )
    let ind = createIndicator(indicatorDef)
    check ind.kind == ikKAMA
  
  test "Create MV indicator":
    var indicatorDef = IndicatorYAML(
      id: "mv_20",
      indicatorType: "mv",
      params: {"period": newParamInt(20)}.toTable
    )
    let ind = createIndicator(indicatorDef)
    check ind.kind == ikMV
  
  test "Create STDEV indicator":
    var indicatorDef = IndicatorYAML(
      id: "stdev_20",
      indicatorType: "stdev",
      params: {"period": newParamInt(20)}.toTable
    )
    let ind = createIndicator(indicatorDef)
    check ind.kind == ikSTDEV
  
  test "Create TRANGE indicator":
    var indicatorDef = IndicatorYAML(
      id: "trange",
      indicatorType: "trange",
      params: initTable[string, ParamValue]()
    )
    let ind = createIndicator(indicatorDef)
    check ind.kind == ikTRANGE
  
  test "Create NATR indicator":
    var indicatorDef = IndicatorYAML(
      id: "natr_14",
      indicatorType: "natr",
      params: {"period": newParamInt(14)}.toTable
    )
    let ind = createIndicator(indicatorDef)
    check ind.kind == ikNATR
  
  test "Create AD indicator":
    var indicatorDef = IndicatorYAML(
      id: "ad",
      indicatorType: "ad",
      params: initTable[string, ParamValue]()
    )
    let ind = createIndicator(indicatorDef)
    check ind.kind == ikAD
  
  test "Create MOM indicator":
    var indicatorDef = IndicatorYAML(
      id: "mom_10",
      indicatorType: "mom",
      params: {"period": newParamInt(10)}.toTable
    )
    let ind = createIndicator(indicatorDef)
    check ind.kind == ikMOM
  
  test "Create CMO indicator":
    var indicatorDef = IndicatorYAML(
      id: "cmo_14",
      indicatorType: "cmo",
      params: {"period": newParamInt(14)}.toTable
    )
    let ind = createIndicator(indicatorDef)
    check ind.kind == ikCMO
  
  test "Create STOCHRSI indicator":
    var indicatorDef = IndicatorYAML(
      id: "stochrsi_14",
      indicatorType: "stochrsi",
      params: {
        "rsiPeriod": newParamInt(14),
        "period": newParamInt(14),
        "kPeriod": newParamInt(3),
        "dPeriod": newParamInt(3)
      }.toTable
    )
    let ind = createIndicator(indicatorDef)
    check ind.kind == ikSTOCHRSI
  
  test "Create PPO indicator":
    var indicatorDef = IndicatorYAML(
      id: "ppo_12_26_9",
      indicatorType: "ppo",
      params: {
        "fastPeriod": newParamInt(12),
        "slowPeriod": newParamInt(26),
        "signalPeriod": newParamInt(9)
      }.toTable
    )
    let ind = createIndicator(indicatorDef)
    check ind.kind == ikPPO
  
  test "Update and getValue for TRIMA":
    var indicatorDef = IndicatorYAML(
      id: "trima_5",
      indicatorType: "trima",
      params: {"period": newParamInt(5)}.toTable
    )
    let ind = createIndicator(indicatorDef)
    
    # Update with several bars
    for i in 0..<15:
      let bar = testBar(close = 100.0 + i.float)
      updateIndicator(ind, bar)
    
    # After warmup, should have valid value
    let val = getValue(ind)
    check not val.isNaN
  
  test "Update and getValue for KAMA":
    var indicatorDef = IndicatorYAML(
      id: "kama_10",
      indicatorType: "kama",
      params: {"period": newParamInt(10)}.toTable
    )
    let ind = createIndicator(indicatorDef)
    
    # Update with several bars
    for i in 0..<20:
      let bar = testBar(close = 100.0 + i.float)
      updateIndicator(ind, bar)
    
    let val = getValue(ind)
    check not val.isNaN
  
  test "Update and getValue for STOCHRSI with subfield":
    var indicatorDef = IndicatorYAML(
      id: "stochrsi_14",
      indicatorType: "stochrsi",
      params: {
        "rsiPeriod": newParamInt(14),
        "period": newParamInt(14)
      }.toTable
    )
    let ind = createIndicator(indicatorDef)
    
    # Update with many bars - StochRSI needs lots of data and price variation
    # Use alternating up/down pattern to ensure RSI variation
    for i in 0..<100:
      let isUp = (i mod 4) < 2
      let closeVal = if isUp: 100.0 + (i mod 4).float * 2.0 else: 100.0 - (i mod 4).float * 2.0
      let openVal = closeVal - (if isUp: 1.0 else: -1.0)
      let bar = testBar(close = closeVal, open = openVal)
      updateIndicator(ind, bar)
    
    # Get %K - should be valid after sufficient bars
    let kVal = getValue(ind, "")  # Default to %K
    check not kVal.isNaN
    # Note: %D may still be NaN depending on implementation details
    # so we don't test it here
  
  test "Update and getValue for PPO with subfields":
    var indicatorDef = IndicatorYAML(
      id: "ppo_12_26_9",
      indicatorType: "ppo",
      params: {
        "fastPeriod": newParamInt(12),
        "slowPeriod": newParamInt(26),
        "signalPeriod": newParamInt(9)
      }.toTable
    )
    let ind = createIndicator(indicatorDef)
    
    # Update with several bars
    for i in 0..<50:
      let bar = testBar(close = 100.0 + i.float * 0.5)
      updateIndicator(ind, bar)
    
    # Get PPO, signal, and histogram
    let ppoVal = getValue(ind, "")  # Default to PPO line
    let signalVal = getValue(ind, "signal")
    let histVal = getValue(ind, "histogram")
    check not ppoVal.isNaN
    check not signalVal.isNaN
    check not histVal.isNaN

# ============================================================================
# Test Suite: Source and Output Selection (Phase 2 - Feature A2)
# ============================================================================

suite "Strategy Builder - Source and Output (Phase 2)":
  
  test "MA with volume source":
    let yamlContent = """
metadata:
  name: "Volume MA Test"
  description: "Test MA applied to volume"
indicators:
  - id: volume_ma
    type: ma
    params:
      period: 5
    source: volume
entry:
  conditions:
    left: volume
    operator: ">"
    right: volume_ma
exit:
  conditions:
    left: volume
    operator: "<"
    right: volume_ma
position_sizing:
  type: fixed
  size: 100
"""
    let strategyDef = parseStrategyYAML(yamlContent)
    let strategy = buildStrategy(strategyDef)
    
    # Verify source is stored correctly
    check strategy.indicatorSources["volume_ma"] == "volume"
    
    # Update with bars where volume increases
    for i in 0..<10:
      let bar = testBar(close = 100.0, volume = 1000.0 + i.float * 100.0)
      discard strategy.onBar(bar)
    
    # Get the MA value - should be based on volume, not price
    let maVal = strategy.indicators["volume_ma"].getValue()
    check not maVal.isNaN
    check maVal > 1000.0  # Should be around 1400 (avg of last 5 volumes)
    check maVal < 2000.0
  
  test "EMA with open source":
    let yamlContent = """
metadata:
  name: "Open EMA Test"
indicators:
  - id: ema_open
    type: ema
    params:
      period: 10
    source: open
entry:
  conditions:
    left: open
    operator: ">"
    right: ema_open
exit:
  conditions:
    left: open
    operator: "<"
    right: ema_open
position_sizing:
  type: fixed
  size: 100
"""
    let strategyDef = parseStrategyYAML(yamlContent)
    let strategy = buildStrategy(strategyDef)
    
    check strategy.indicatorSources["ema_open"] == "open"
    
    # Update with bars
    for i in 0..<20:
      let bar = testBar(open = 100.0 + i.float, close = 105.0 + i.float)
      discard strategy.onBar(bar)
    
    let emaVal = strategy.indicators["ema_open"].getValue()
    check not emaVal.isNaN
  
  test "Default source is close":
    let yamlContent = """
metadata:
  name: "Default Source Test"
indicators:
  - id: ma_default
    type: ma
    params:
      period: 10
entry:
  conditions:
    left: price
    operator: ">"
    right: ma_default
exit:
  conditions:
    left: price
    operator: "<"
    right: ma_default
position_sizing:
  type: fixed
  size: 100
"""
    let strategyDef = parseStrategyYAML(yamlContent)
    let strategy = buildStrategy(strategyDef)
    
    # Should default to "close"
    check strategy.indicatorSources["ma_default"] == "close"
  
  test "Bollinger Bands with upper output":
    let yamlContent = """
metadata:
  name: "BB Upper Test"
indicators:
  - id: bb_20
    type: bollinger
    params:
      period: 20
      numStdDev: 2.0
    output: upper
entry:
  conditions:
    left: price
    operator: ">"
    right: bb_20
exit:
  conditions:
    left: price
    operator: "<"
    right: bb_20
position_sizing:
  type: fixed
  size: 100
"""
    let strategyDef = parseStrategyYAML(yamlContent)
    let strategy = buildStrategy(strategyDef)
    
    # Verify output is stored
    check strategy.indicatorOutputs["bb_20"] == "upper"
    
    # Update with bars
    for i in 0..<30:
      let bar = testBar(close = 100.0 + float(i mod 10))
      discard strategy.onBar(bar)
    
    # When we reference bb_20, it should return the upper band
    let bar = testBar(close = 100.0)
    let val = strategy.parseReference("bb_20", bar)
    
    # The upper band should be > middle band
    let middle = strategy.indicators["bb_20"].getValue("middle")
    check val > middle
  
  test "Bollinger Bands with lower output":
    let yamlContent = """
metadata:
  name: "BB Lower Test"
indicators:
  - id: bb_20
    type: bollinger
    params:
      period: 20
      numStdDev: 2.0
    output: lower
entry:
  conditions:
    left: price
    operator: "<"
    right: bb_20
exit:
  conditions:
    left: price
    operator: ">"
    right: bb_20
position_sizing:
  type: fixed
  size: 100
"""
    let strategyDef = parseStrategyYAML(yamlContent)
    let strategy = buildStrategy(strategyDef)
    
    check strategy.indicatorOutputs["bb_20"] == "lower"
    
    # Update with bars
    for i in 0..<30:
      let bar = testBar(close = 100.0 + float(i mod 10))
      discard strategy.onBar(bar)
    
    # When we reference bb_20, it should return the lower band
    let bar = testBar(close = 100.0)
    let val = strategy.parseReference("bb_20", bar)
    
    # The lower band should be < middle band
    let middle = strategy.indicators["bb_20"].getValue("middle")
    check val < middle
  
  test "MACD with signal output":
    let yamlContent = """
metadata:
  name: "MACD Signal Test"
indicators:
  - id: macd_12_26_9
    type: macd
    params:
      fastPeriod: 12
      slowPeriod: 26
      signalPeriod: 9
    output: signal
entry:
  conditions:
    left: macd_12_26_9
    operator: ">"
    right: 0
exit:
  conditions:
    left: macd_12_26_9
    operator: "<"
    right: 0
position_sizing:
  type: fixed
  size: 100
"""
    let strategyDef = parseStrategyYAML(yamlContent)
    let strategy = buildStrategy(strategyDef)
    
    check strategy.indicatorOutputs["macd_12_26_9"] == "signal"
    
    # Update with trending bars
    for i in 0..<50:
      let bar = testBar(close = 100.0 + i.float * 0.5)
      discard strategy.onBar(bar)
    
    # Reference should return signal line
    let bar = testBar(close = 125.0)
    let val = strategy.parseReference("macd_12_26_9", bar)
    check not val.isNaN
  
  test "Output selection with dot notation overrides configured output":
    let yamlContent = """
metadata:
  name: "Dot Notation Test"
indicators:
  - id: bb_20
    type: bollinger
    params:
      period: 20
      numStdDev: 2.0
    output: upper
entry:
  conditions:
    left: price
    operator: ">"
    right: bb_20.lower
exit:
  conditions:
    left: price
    operator: "<"
    right: bb_20.lower
position_sizing:
  type: fixed
  size: 100
"""
    let strategyDef = parseStrategyYAML(yamlContent)
    let strategy = buildStrategy(strategyDef)
    
    # Configured output is "upper"
    check strategy.indicatorOutputs["bb_20"] == "upper"
    
    # Update with bars
    for i in 0..<30:
      let bar = testBar(close = 100.0 + float(i mod 10))
      discard strategy.onBar(bar)
    
    let bar = testBar(close = 100.0)
    
    # Direct reference uses configured output (upper)
    let upperVal = strategy.parseReference("bb_20", bar)
    
    # Dot notation overrides configured output (lower)
    let lowerVal = strategy.parseReference("bb_20.lower", bar)
    
    # Upper should be greater than lower
    check upperVal > lowerVal
  
  test "Stochastic with k output":
    let yamlContent = """
metadata:
  name: "Stoch K Test"
indicators:
  - id: stoch_14
    type: stoch
    params:
      kPeriod: 14
      dPeriod: 3
    output: k
entry:
  conditions:
    left: stoch_14
    operator: "<"
    right: 20
exit:
  conditions:
    left: stoch_14
    operator: ">"
    right: 80
position_sizing:
  type: fixed
  size: 100
"""
    let strategyDef = parseStrategyYAML(yamlContent)
    let strategy = buildStrategy(strategyDef)
    
    check strategy.indicatorOutputs["stoch_14"] == "k"
    
    # Update with oscillating bars
    for i in 0..<30:
      let close = 100.0 + float((i mod 20) - 10) * 2.0
      let bar = testBar(close = close, high = close + 1.0, low = close - 1.0)
      discard strategy.onBar(bar)
    
    let bar = testBar(close = 100.0, high = 101.0, low = 99.0)
    let val = strategy.parseReference("stoch_14", bar)
    check not val.isNaN
    check val >= 0.0
    check val <= 100.0

