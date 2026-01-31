## Comprehensive Integration and Edge Case Tests (Phase 2 - Feature A3)

import std/[unittest, options, tables]
import ../src/tzutrader/core
import ../src/tzutrader/declarative/[parser, validator, strategy_builder, schema]

suite "Integration Tests - Complete Workflows":
  
  test "Parse -> Validate -> Build -> Execute: RSI strategy":
    let yamlContent = """
metadata:
  name: "RSI Integration Test"
indicators:
  - id: rsi_14
    type: rsi
    params:
      period: 14
entry:
  conditions:
    left: rsi_14
    operator: "<"
    right: 30
exit:
  conditions:
    left: rsi_14
    operator: ">"
    right: 70
position_sizing:
  type: fixed
  size: 100
"""
    # Parse
    let strategyDef = parseStrategyYAML(yamlContent)
    check strategyDef.metadata.name == "RSI Integration Test"
    
    # Validate
    let validation = validateStrategy(strategyDef)
    check validation.valid
    
    # Build
    let strategy = buildStrategy(strategyDef)
    check strategy.name == "RSI Integration Test"
    
    # Execute - feed some bars
    for i in 0..<30:
      let bar = OHLCV(
        timestamp: i,
        open: 100.0 + float(i),
        high: 105.0 + float(i),
        low: 95.0 + float(i),
        close: 100.0 + float(i),
        volume: 1000000.0
      )
      let signal = strategy.onBar(bar)
      check signal.symbol == ""
  
  test "Multi-indicator strategy with AND logic":
    let yamlContent = """
metadata:
  name: "Multi Indicator Test"
indicators:
  - id: rsi_14
    type: rsi
    params:
      period: 14
  - id: ma_50
    type: ma
    params:
      period: 50
  - id: volume_ma
    type: ma
    params:
      period: 20
    source: volume
entry:
  conditions:
    all:
      - left: rsi_14
        operator: "<"
        right: 30
      - left: price
        operator: ">"
        right: ma_50
      - left: volume
        operator: ">"
        right: volume_ma
exit:
  conditions:
    left: rsi_14
    operator: ">"
    right: 70
position_sizing:
  type: percent
  percent: 15
"""
    let strategyDef = parseStrategyYAML(yamlContent)
    let validation = validateStrategy(strategyDef)
    check validation.valid
    
    let strategy = buildStrategy(strategyDef)
    check len(strategy.indicators) == 3
    check strategy.indicatorSources["volume_ma"] == "volume"
    
    # Execute
    for i in 0..<60:
      let bar = OHLCV(
        timestamp: i,
        open: 100.0,
        high: 105.0,
        low: 95.0,
        close: 100.0,
        volume: 1000000.0 + float(i) * 10000.0
      )
      discard strategy.onBar(bar)
  
  test "Strategy with crossover operators":
    let yamlContent = """
metadata:
  name: "Crossover Test"
indicators:
  - id: ema_fast
    type: ema
    params:
      period: 12
  - id: ema_slow
    type: ema
    params:
      period: 26
entry:
  conditions:
    left: ema_fast
    operator: crosses_above
    right: ema_slow
exit:
  conditions:
    left: ema_fast
    operator: crosses_below
    right: ema_slow
position_sizing:
  type: fixed
  size: 100
"""
    let strategyDef = parseStrategyYAML(yamlContent)
    let validation = validateStrategy(strategyDef)
    check validation.valid
    
    let strategy = buildStrategy(strategyDef)
    
    # Feed bars to test crossover detection
    for i in 0..<50:
      let bar = OHLCV(
        timestamp: i,
        open: 100.0 + float(i mod 20),
        high: 105.0 + float(i mod 20),
        low: 95.0 + float(i mod 20),
        close: 100.0 + float(i mod 20),
        volume: 1000000.0
      )
      discard strategy.onBar(bar)
  
  test "Strategy with OR logic":
    let yamlContent = """
metadata:
  name: "OR Logic Test"
indicators:
  - id: rsi_14
    type: rsi
    params:
      period: 14
entry:
  conditions:
    any:
      - left: rsi_14
        operator: "<"
        right: 20
      - left: rsi_14
        operator: ">"
        right: 80
exit:
  conditions:
    left: rsi_14
    operator: ">"
    right: 30
position_sizing:
  type: fixed
  size: 100
"""
    let strategyDef = parseStrategyYAML(yamlContent)
    let validation = validateStrategy(strategyDef)
    check validation.valid
    
    let strategy = buildStrategy(strategyDef)
    
    # Execute
    for i in 0..<30:
      let bar = OHLCV(
        timestamp: i,
        open: 100.0,
        high: 105.0,
        low: 95.0,
        close: 100.0,
        volume: 1000000.0
      )
      discard strategy.onBar(bar)

suite "Edge Cases - Indicator Parameters":
  
  test "Indicator with all parameter types":
    let yamlContent = """
metadata:
  name: "Parameter Types Test"
indicators:
  - id: test_ind
    type: bollinger
    params:
      period: 20
      numStdDev: 2.5
entry:
  conditions:
    left: price
    operator: "<"
    right: test_ind.lower
exit:
  conditions:
    left: price
    operator: ">"
    right: test_ind.upper
position_sizing:
  type: fixed
  size: 100
"""
    let strategyDef = parseStrategyYAML(yamlContent)
    let validation = validateStrategy(strategyDef)
    check validation.valid
    check strategyDef.indicators[0].params["period"].kind == pkInt
    check strategyDef.indicators[0].params["numStdDev"].kind == pkFloat
  
  test "Multiple indicators of same type with different params":
    let yamlContent = """
metadata:
  name: "Multiple Same Type"
indicators:
  - id: ma_10
    type: ma
    params:
      period: 10
  - id: ma_20
    type: ma
    params:
      period: 20
  - id: ma_50
    type: ma
    params:
      period: 50
entry:
  conditions:
    all:
      - left: ma_10
        operator: ">"
        right: ma_20
      - left: ma_20
        operator: ">"
        right: ma_50
exit:
  conditions:
    left: ma_10
    operator: "<"
    right: ma_20
position_sizing:
  type: fixed
  size: 100
"""
    let strategyDef = parseStrategyYAML(yamlContent)
    let validation = validateStrategy(strategyDef)
    check validation.valid
    
    let strategy = buildStrategy(strategyDef)
    check len(strategy.indicators) == 3
    check strategy.indicators.hasKey("ma_10")
    check strategy.indicators.hasKey("ma_20")
    check strategy.indicators.hasKey("ma_50")
  
  test "Indicator with source parameter variations":
    let yamlContent = """
metadata:
  name: "Source Variations"
indicators:
  - id: ma_open
    type: ma
    params:
      period: 20
    source: open
  - id: ma_high
    type: ma
    params:
      period: 20
    source: high
  - id: ma_low
    type: ma
    params:
      period: 20
    source: low
  - id: ma_close
    type: ma
    params:
      period: 20
    source: close
entry:
  conditions:
    left: ma_open
    operator: ">"
    right: ma_close
exit:
  conditions:
    left: ma_high
    operator: "<"
    right: ma_low
position_sizing:
  type: fixed
  size: 100
"""
    let strategyDef = parseStrategyYAML(yamlContent)
    let validation = validateStrategy(strategyDef)
    check validation.valid
    
    let strategy = buildStrategy(strategyDef)
    check strategy.indicatorSources["ma_open"] == "open"
    check strategy.indicatorSources["ma_high"] == "high"
    check strategy.indicatorSources["ma_low"] == "low"
    check strategy.indicatorSources["ma_close"] == "close"

suite "Edge Cases - Condition Evaluation":
  
  test "Nested AND/OR conditions":
    let yamlContent = """
metadata:
  name: "Nested Logic"
indicators:
  - id: rsi_14
    type: rsi
    params:
      period: 14
  - id: ma_50
    type: ma
    params:
      period: 50
entry:
  conditions:
    all:
      - any:
          - left: rsi_14
            operator: "<"
            right: 30
          - left: rsi_14
            operator: ">"
            right: 70
      - left: price
        operator: ">"
        right: ma_50
exit:
  conditions:
    left: rsi_14
    operator: ">"
    right: 50
position_sizing:
  type: fixed
  size: 100
"""
    let strategyDef = parseStrategyYAML(yamlContent)
    let validation = validateStrategy(strategyDef)
    check validation.valid
    
    let strategy = buildStrategy(strategyDef)
    
    # Test with a bar
    let bar = OHLCV(
      timestamp: 0,
      open: 100.0,
      high: 105.0,
      low: 95.0,
      close: 100.0,
      volume: 1000000.0
    )
    discard strategy.onBar(bar)
  
  test "Comparison with literal values":
    let yamlContent = """
metadata:
  name: "Literal Comparisons"
indicators:
  - id: rsi_14
    type: rsi
    params:
      period: 14
entry:
  conditions:
    all:
      - left: rsi_14
        operator: "<"
        right: 30
      - left: price
        operator: ">"
        right: 100
      - left: volume
        operator: ">"
        right: 1000000
exit:
  conditions:
    left: rsi_14
    operator: ">"
    right: 70
position_sizing:
  type: fixed
  size: 100
"""
    let strategyDef = parseStrategyYAML(yamlContent)
    let validation = validateStrategy(strategyDef)
    check validation.valid
  
  test "All comparison operators":
    let yamlContent = """
metadata:
  name: "All Operators"
indicators:
  - id: rsi_14
    type: rsi
    params:
      period: 14
entry:
  conditions:
    all:
      - left: rsi_14
        operator: "<"
        right: 30
      - left: volume
        operator: ">"
        right: 1000000
      - left: rsi_14
        operator: "<="
        right: 35
      - left: volume
        operator: ">="
        right: 900000
exit:
  conditions:
    any:
      - left: rsi_14
        operator: "=="
        right: 50
      - left: rsi_14
        operator: "!="
        right: 30
position_sizing:
  type: fixed
  size: 100
"""
    let strategyDef = parseStrategyYAML(yamlContent)
    let validation = validateStrategy(strategyDef)
    check validation.valid

suite "Edge Cases - Position Sizing":
  
  test "Percent position sizing edge values":
    let yamlContent = """
metadata:
  name: "Percent Edge Cases"
indicators:
  - id: rsi_14
    type: rsi
    params:
      period: 14
entry:
  conditions:
    left: rsi_14
    operator: "<"
    right: 30
exit:
  conditions:
    left: rsi_14
    operator: ">"
    right: 70
position_sizing:
  type: percent
  percent: 1
"""
    let strategyDef = parseStrategyYAML(yamlContent)
    let validation = validateStrategy(strategyDef)
    check validation.valid
    check strategyDef.positionSizing.percentCapital == 1.0
  
  test "Large position size":
    let yamlContent = """
metadata:
  name: "Large Position"
indicators:
  - id: rsi_14
    type: rsi
    params:
      period: 14
entry:
  conditions:
    left: rsi_14
    operator: "<"
    right: 30
exit:
  conditions:
    left: rsi_14
    operator: ">"
    right: 70
position_sizing:
  type: fixed
  size: 10000
"""
    let strategyDef = parseStrategyYAML(yamlContent)
    let validation = validateStrategy(strategyDef)
    check validation.valid
    check strategyDef.positionSizing.fixedSize == 10000.0

suite "Edge Cases - Special References":
  
  test "All special keywords work":
    let yamlContent = """
metadata:
  name: "Special Keywords"
indicators:
  - id: ma_20
    type: ma
    params:
      period: 20
entry:
  conditions:
    all:
      - left: open
        operator: ">"
        right: ma_20
      - left: high
        operator: ">"
        right: close
      - left: low
        operator: "<"
        right: open
      - left: volume
        operator: ">"
        right: 1000000
exit:
  conditions:
    left: price
    operator: "<"
    right: ma_20
position_sizing:
  type: fixed
  size: 100
"""
    let strategyDef = parseStrategyYAML(yamlContent)
    let validation = validateStrategy(strategyDef)
    check validation.valid
