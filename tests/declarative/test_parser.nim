## Unit tests for YAML parser

import std/[unittest, tables, options]
import tzutrader/declarative/[schema, parser]

suite "YAML Parser - Valid Files":
  
  test "Parse simple RSI strategy":
    let strategy = parseStrategyYAMLFile("tests/declarative/fixtures/valid_rsi.yml")
    
    # Check metadata
    check strategy.metadata.name == "Simple RSI Strategy"
    check strategy.metadata.description == "Buy when oversold, sell when overbought"
    check strategy.metadata.author.isSome()
    check strategy.metadata.author.get() == "TzuTrader"
    check "rsi" in strategy.metadata.tags
    
    # Check indicators
    check strategy.indicators.len == 1
    check strategy.indicators[0].id == "rsi_14"
    check strategy.indicators[0].indicatorType == "rsi"
    check strategy.indicators[0].params["period"].kind == pkInt
    check strategy.indicators[0].params["period"].intVal == 14
    
    # Check entry rule
    check strategy.entryRule.conditions.kind == ckSimple
    check strategy.entryRule.conditions.left == "rsi_14"
    check strategy.entryRule.conditions.operator == opLessThan
    check strategy.entryRule.conditions.right == "30"
    
    # Check exit rule
    check strategy.exitRule.conditions.kind == ckSimple
    check strategy.exitRule.conditions.left == "rsi_14"
    check strategy.exitRule.conditions.operator == opGreaterThan
    check strategy.exitRule.conditions.right == "70"
    
    # Check position sizing
    check strategy.positionSizing.kind == psFixed
    check strategy.positionSizing.fixedSize == 100.0
  
  test "Parse RSI with trend filter (AND logic)":
    let strategy = parseStrategyYAMLFile("tests/declarative/fixtures/valid_rsi_trend.yml")
    
    # Check indicators
    check strategy.indicators.len == 2
    check strategy.indicators[0].id == "rsi_14"
    check strategy.indicators[1].id == "sma_200"
    
    # Check entry rule uses AND
    check strategy.entryRule.conditions.kind == ckAnd
    check strategy.entryRule.conditions.andConditions.len == 2
    
    let cond1 = strategy.entryRule.conditions.andConditions[0]
    check cond1.kind == ckSimple
    check cond1.left == "rsi_14"
    check cond1.operator == opLessThan
    
    let cond2 = strategy.entryRule.conditions.andConditions[1]
    check cond2.kind == ckSimple
    check cond2.left == "price"
    check cond2.operator == opGreaterThan
    check cond2.right == "sma_200"
  
  test "Parse MACD crossover strategy":
    let strategy = parseStrategyYAMLFile("tests/declarative/fixtures/valid_macd.yml")
    
    # Check indicators
    check strategy.indicators.len == 1
    check strategy.indicators[0].id == "macd_12_26_9"
    check strategy.indicators[0].indicatorType == "macd"
    check strategy.indicators[0].params["fast"].intVal == 12
    check strategy.indicators[0].params["slow"].intVal == 26
    check strategy.indicators[0].params["signal"].intVal == 9
    
    # Check entry uses crosses_above
    check strategy.entryRule.conditions.operator == opCrossesAbove
    check strategy.exitRule.conditions.operator == opCrossesBelow

suite "YAML Parser - Invalid Files":
  
  test "Parse file with empty name (validation will catch it)":
    # Parser should successfully parse, but name will be empty
    let strategy = parseStrategyYAMLFile("tests/declarative/fixtures/invalid_no_name.yml")
    check strategy.metadata.name == ""  # Parser allows it, validator will reject
  
  test "Parse file with syntax error":
    expect ParseError:
      discard parseStrategyYAML("invalid: yaml: ]: syntax")

suite "YAML Parser - Parameter Types":
  
  test "Parse different parameter types":
    let yamlContent = """
metadata:
  name: "Test"
  description: "Test param types"

indicators:
  - id: test_ind
    type: test
    params:
      int_param: 42
      float_param: 3.14
      string_param: hello
      bool_param: true

entry:
  conditions:
    left: test_ind
    operator: ">"
    right: "0"

exit:
  conditions:
    left: test_ind
    operator: "<"
    right: "0"

position_sizing:
  type: fixed
  size: 100
"""
    
    let strategy = parseStrategyYAML(yamlContent)
    let params = strategy.indicators[0].params
    
    check params["int_param"].kind == pkInt
    check params["int_param"].intVal == 42
    
    check params["float_param"].kind == pkFloat
    check params["float_param"].floatVal == 3.14
    
    check params["string_param"].kind == pkString
    check params["string_param"].strVal == "hello"
    
    check params["bool_param"].kind == pkBool
    check params["bool_param"].boolVal == true

suite "YAML Parser - Position Sizing":
  test "Parse fixed position sizing":
    let strategy = parseStrategyYAMLFile("tests/declarative/fixtures/valid_rsi.yml")
    check strategy.positionSizing.kind == psFixed
    check strategy.positionSizing.fixedSize == 100.0
  
  test "Parse percent position sizing":
    let yamlContent = """
metadata:
  name: "Test Percent Sizing"
indicators:
  - id: rsi_14
    type: rsi
    params:
      period: 14
entry:
  conditions:
    - left: rsi_14
      operator: "<"
      right: "30"
exit:
  conditions:
    - left: rsi_14
      operator: ">"
      right: "70"
position_sizing:
  type: percent
  percent: 25
"""
    let strategy = parseStrategyYAML(yamlContent)
    check strategy.positionSizing.kind == psPercent
    check strategy.positionSizing.percentCapital == 25.0
  
  test "Invalid percent value raises error":
    let yamlContent = """
metadata:
  name: "Invalid Percent"
indicators:
  - id: rsi_14
    type: rsi
    params:
      period: 14
entry:
  conditions:
    - left: rsi_14
      operator: "<"
      right: "30"
exit:
  conditions:
    - left: rsi_14
      operator: ">"
      right: "70"
position_sizing:
  type: percent
  percent: 150
"""
    expect(parser.ParseError):
      discard parseStrategyYAML(yamlContent)


