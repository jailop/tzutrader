## Unit tests for validator

import std/[unittest, tables, sets, strutils]
import tzutrader/declarative/[schema, parser, validator]

suite "Validator - Metadata":
  
  test "Valid metadata":
    var meta = MetadataYAML(name: "Test Strategy", description: "Test", tags: @[])
    let result = validateMetadata(meta)
    check result.valid
    check result.errors.len == 0
  
  test "Empty name is invalid":
    var meta = MetadataYAML(name: "", description: "Test", tags: @[])
    let result = validateMetadata(meta)
    check not result.valid
    check result.errors.len > 0

suite "Validator - Indicators":
  
  test "Valid indicators":
    var indicators = @[
      IndicatorYAML(id: "rsi_14", indicatorType: "rsi", params: initTable[string, ParamValue]()),
      IndicatorYAML(id: "sma_50", indicatorType: "sma", params: initTable[string, ParamValue]())
    ]
    let result = validateIndicators(indicators)
    check result.valid
  
  test "Duplicate IDs are invalid":
    var indicators = @[
      IndicatorYAML(id: "rsi_14", indicatorType: "rsi", params: initTable[string, ParamValue]()),
      IndicatorYAML(id: "rsi_14", indicatorType: "rsi", params: initTable[string, ParamValue]())
    ]
    let result = validateIndicators(indicators)
    check not result.valid
    check "Duplicate" in result.errors[0]
  
  test "Empty ID is invalid":
    var indicators = @[
      IndicatorYAML(id: "", indicatorType: "rsi", params: initTable[string, ParamValue]())
    ]
    let result = validateIndicators(indicators)
    check not result.valid

suite "Validator - Conditions":
  
  test "Valid simple condition":
    var ids = toHashSet(["rsi_14"])
    let cond = newSimpleCondition("rsi_14", opLessThan, "30")
    let result = validateCondition(cond, ids)
    check result.valid
  
  test "Undefined reference is invalid":
    var ids = toHashSet(["rsi_14"])
    let cond = newSimpleCondition("sma_50", opLessThan, "30")
    let result = validateCondition(cond, ids)
    check not result.valid
    check "Undefined" in result.errors[0]
  
  test "Valid AND condition":
    var ids = toHashSet(["rsi_14", "macd"])
    let c1 = newSimpleCondition("rsi_14", opLessThan, "30")
    let c2 = newSimpleCondition("macd", opGreaterThan, "0")
    let andCond = newAndCondition(@[c1, c2])
    let result = validateCondition(andCond, ids)
    check result.valid
  
  test "Empty AND is invalid":
    var ids = toHashSet(["rsi_14"])
    let andCond = newAndCondition(@[])
    let result = validateCondition(andCond, ids)
    check not result.valid

suite "Validator - Complete Strategy":
  
  test "Valid simple RSI strategy":
    let strategy = parseStrategyYAMLFile("tests/declarative/fixtures/valid_rsi.yml")
    let result = validateStrategy(strategy)
    check result.valid
    check result.errors.len == 0
  
  test "Valid RSI with trend filter":
    let strategy = parseStrategyYAMLFile("tests/declarative/fixtures/valid_rsi_trend.yml")
    let result = validateStrategy(strategy)
    check result.valid
  
  test "Invalid - undefined reference":
    let strategy = parseStrategyYAMLFile("tests/declarative/fixtures/invalid_undefined_ref.yml")
    let result = validateStrategy(strategy)
    check not result.valid
    check result.errors.len > 0
  
  test "Invalid - duplicate IDs":
    let strategy = parseStrategyYAMLFile("tests/declarative/fixtures/invalid_duplicate_ids.yml")
    let result = validateStrategy(strategy)
    check not result.valid
    check "Duplicate" in result.errors[0]
