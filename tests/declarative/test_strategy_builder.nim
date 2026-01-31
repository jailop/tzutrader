## Unit tests for strategy builder

import std/[unittest, tables, times]
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

