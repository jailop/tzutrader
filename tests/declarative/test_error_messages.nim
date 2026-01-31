## Test Error Messages with Line Numbers (Phase 2 - Feature B2)

import std/[unittest, strutils, options]
import ../../src/tzutrader/declarative/[parser, validator, schema]

suite "Error Messages - Line Numbers (Phase 2)":
  
  test "Parser error includes line number":
    let yamlContent = """
metadata:
  name: "Test Strategy"
indicators:
  - id: rsi_14
    type: rsi
    params:
      period: 14
entry:
  conditions:
    left: rsi_14
    operator: "INVALID_OP"
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
    try:
      let strategy = parseStrategyYAML(yamlContent)
      check false  # Should have raised ParseError
    except ParseError as e:
      # Error message should include line number
      check e.msg.contains("line")
      echo "Parser error message: ", e.msg
  
  test "Validator error includes line number for duplicate indicator":
    let yamlContent = """
metadata:
  name: "Test Strategy"
indicators:
  - id: rsi_14
    type: rsi
    params:
      period: 14
  - id: rsi_14
    type: rsi
    params:
      period: 20
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
    let strategy = parseStrategyYAML(yamlContent)
    let validation = validateStrategy(strategy)
    
    check not validation.valid
    check validation.errors.len > 0
    
    # At least one error should include line number
    var hasLineNumber = false
    for err in validation.errors:
      if "line" in err.toLowerAscii():
        hasLineNumber = true
        echo "Validation error with line number: ", err
        break
    
    check hasLineNumber
  
  test "Validator error includes line number for undefined reference":
    let yamlContent = """
metadata:
  name: "Test Strategy"
indicators:
  - id: rsi_14
    type: rsi
    params:
      period: 14
entry:
  conditions:
    left: undefined_indicator
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
    let strategy = parseStrategyYAML(yamlContent)
    let validation = validateStrategy(strategy)
    
    check not validation.valid
    check validation.errors.len > 0
    
    # Error should include line number
    var hasLineNumber = false
    for err in validation.errors:
      if "line" in err.toLowerAscii():
        hasLineNumber = true
        echo "Undefined reference error with line number: ", err
        break
    
    check hasLineNumber
  
  test "Location information is captured in parsed indicators":
    let yamlContent = """
metadata:
  name: "Test Strategy"
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
    let strategy = parseStrategyYAML(yamlContent)
    
    # Check that indicator has location info
    check strategy.indicators.len > 0
    check strategy.indicators[0].location.isSome()
    
    let loc = strategy.indicators[0].location.get()
    check loc.line > 0
    check loc.column > 0
    echo "Indicator location: line ", loc.line, ", column ", loc.column
  
  test "Location information is captured in conditions":
    let yamlContent = """
metadata:
  name: "Test Strategy"
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
    let strategy = parseStrategyYAML(yamlContent)
    
    # Check that conditions have location info
    check strategy.entryRule.conditions.location.isSome()
    
    let loc = strategy.entryRule.conditions.location.get()
    check loc.line > 0
    check loc.column > 0
    echo "Entry condition location: line ", loc.line, ", column ", loc.column
