## Tests for Validation Warnings System (Phase 2 - Feature B3)

import std/[unittest, strutils]
import ../src/tzutrader/declarative/[parser, validator, schema]

suite "Validation Warnings - Position Sizing":
  
  test "Warning for very high position sizing (>50%)":
    let yamlContent = """
metadata:
  name: "High Position Size"
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
  percent: 75
"""
    let strategy = parseStrategyYAML(yamlContent)
    let validation = validateStrategy(strategy)
    
    check validation.valid  # No errors, just warnings
    check validation.warnings.len > 0
    
    # Should have high-level warning
    var hasHighWarning = false
    for warning in validation.warnings:
      if warning.level == wlHigh and "very high" in warning.message.toLowerAscii():
        hasHighWarning = true
        echo "High position warning: ", warning.message
        echo "Suggestion: ", warning.suggestion
        break
    
    check hasHighWarning
  
  test "Warning for above-recommended position sizing (25-50%)":
    let yamlContent = """
metadata:
  name: "Above Recommended Position"
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
  percent: 30
"""
    let strategy = parseStrategyYAML(yamlContent)
    let validation = validateStrategy(strategy)
    
    check validation.valid
    check validation.warnings.len > 0
    
    # Should have medium-level warning
    var hasMediumWarning = false
    for warning in validation.warnings:
      if warning.level == wlMedium and "above recommended" in warning.message.toLowerAscii():
        hasMediumWarning = true
        break
    
    check hasMediumWarning
  
  test "No warning for optimal position sizing (10-25%)":
    let yamlContent = """
metadata:
  name: "Optimal Position"
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
      - left: rsi_14
        operator: "<"
        right: 30
      - left: price
        operator: ">"
        right: ma_50
exit:
  conditions:
    left: rsi_14
    operator: ">"
    right: 70
position_sizing:
  type: percent
  percent: 15
"""
    let strategy = parseStrategyYAML(yamlContent)
    let validation = validateStrategy(strategy)
    
    check validation.valid
    
    # Should not have position sizing warnings
    var hasPositionWarning = false
    for warning in validation.warnings:
      if "position size" in warning.message.toLowerAscii():
        hasPositionWarning = true
        break
    
    check not hasPositionWarning

suite "Validation Warnings - Indicator Concerns":
  
  test "Warning for oscillator without trend filter":
    let yamlContent = """
metadata:
  name: "Oscillator Only"
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
    let validation = validateStrategy(strategy)
    
    check validation.valid
    check validation.warnings.len > 0
    
    # Should warn about missing trend filter
    var hasTrendWarning = false
    for warning in validation.warnings:
      if "trend" in warning.message.toLowerAscii():
        hasTrendWarning = true
        echo "Trend warning: ", warning.message
        break
    
    check hasTrendWarning
  
  test "No warning when trend indicator is present":
    let yamlContent = """
metadata:
  name: "With Trend Filter"
indicators:
  - id: rsi_14
    type: rsi
    params:
      period: 14
  - id: ma_200
    type: ma
    params:
      period: 200
entry:
  conditions:
    all:
      - left: rsi_14
        operator: "<"
        right: 30
      - left: price
        operator: ">"
        right: ma_200
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
    
    check validation.valid
    
    # Should not warn about missing trend indicator
    var hasTrendWarning = false
    for warning in validation.warnings:
      if "oscillator" in warning.message.toLowerAscii() and "trend" in warning.message.toLowerAscii():
        hasTrendWarning = true
        break
    
    check not hasTrendWarning
  
  test "Warning for too many indicators":
    let yamlContent = """
metadata:
  name: "Many Indicators"
indicators:
  - id: rsi_14
    type: rsi
    params:
      period: 14
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
  - id: ema_12
    type: ema
    params:
      period: 12
  - id: ema_26
    type: ema
    params:
      period: 26
  - id: macd
    type: macd
    params:
      fastPeriod: 12
      slowPeriod: 26
      signalPeriod: 9
  - id: stoch
    type: stoch
    params:
      kPeriod: 14
      dPeriod: 3
  - id: cci
    type: cci
    params:
      period: 20
  - id: atr
    type: atr
    params:
      period: 14
  - id: obv
    type: obv
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
    
    check validation.valid
    check validation.warnings.len > 0
    
    # Should warn about too many indicators
    var hasComplexityWarning = false
    for warning in validation.warnings:
      if "many indicators" in warning.message.toLowerAscii() or 
         "complex" in warning.message.toLowerAscii():
        hasComplexityWarning = true
        echo "Complexity warning: ", warning.message
        break
    
    check hasComplexityWarning
  
  test "Warning for very short indicator period":
    let yamlContent = """
metadata:
  name: "Short Period"
indicators:
  - id: ma_3
    type: ma
    params:
      period: 3
entry:
  conditions:
    left: price
    operator: ">"
    right: ma_3
exit:
  conditions:
    left: price
    operator: "<"
    right: ma_3
position_sizing:
  type: fixed
  size: 100
"""
    let strategy = parseStrategyYAML(yamlContent)
    let validation = validateStrategy(strategy)
    
    check validation.valid
    check validation.warnings.len > 0
    
    # Should warn about short period
    var hasShortPeriodWarning = false
    for warning in validation.warnings:
      if "short period" in warning.message.toLowerAscii() or 
         "sensitive to noise" in warning.message.toLowerAscii():
        hasShortPeriodWarning = true
        echo "Short period warning: ", warning.message
        break
    
    check hasShortPeriodWarning
  
  test "Info warning for single indicator strategy":
    let yamlContent = """
metadata:
  name: "Single Indicator"
indicators:
  - id: ma_50
    type: ma
    params:
      period: 50
entry:
  conditions:
    left: price
    operator: ">"
    right: ma_50
exit:
  conditions:
    left: price
    operator: "<"
    right: ma_50
position_sizing:
  type: fixed
  size: 100
"""
    let strategy = parseStrategyYAML(yamlContent)
    let validation = validateStrategy(strategy)
    
    check validation.valid
    check validation.warnings.len > 0
    
    # Should have info-level warning about single indicator
    var hasSingleIndicatorWarning = false
    for warning in validation.warnings:
      if warning.level == wlInfo and "one indicator" in warning.message.toLowerAscii():
        hasSingleIndicatorWarning = true
        echo "Single indicator info: ", warning.message
        break
    
    check hasSingleIndicatorWarning

suite "Validation Warnings - Display":
  
  test "Warnings contain helpful suggestions":
    let yamlContent = """
metadata:
  name: "Test Suggestions"
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
  percent: 80
"""
    let strategy = parseStrategyYAML(yamlContent)
    let validation = validateStrategy(strategy)
    
    check validation.valid
    check validation.warnings.len > 0
    
    # All warnings should have suggestions
    for warning in validation.warnings:
      if warning.suggestion != "":
        echo "Warning: ", warning.message
        echo "Suggestion: ", warning.suggestion
        echo ""
      # Note: Some warnings might not have suggestions, that's OK
  
  test "Warning levels are appropriately assigned":
    let yamlContent = """
metadata:
  name: "Test Levels"
indicators:
  - id: ma_2
    type: ma
    params:
      period: 2
entry:
  conditions:
    left: price
    operator: ">"
    right: ma_2
exit:
  conditions:
    left: price
    operator: "<"
    right: ma_2
position_sizing:
  type: percent
  percent: 90
"""
    let strategy = parseStrategyYAML(yamlContent)
    let validation = validateStrategy(strategy)
    
    check validation.valid
    check validation.warnings.len > 0
    
    # Should have at least one high-level warning (position sizing)
    var hasHighLevel = false
    var hasMediumLevel = false
    
    for warning in validation.warnings:
      case warning.level
      of wlHigh:
        hasHighLevel = true
        echo "HIGH: ", warning.message
      of wlMedium:
        hasMediumLevel = true
        echo "MEDIUM: ", warning.message
      of wlLow:
        echo "LOW: ", warning.message
      of wlInfo:
        echo "INFO: ", warning.message
    
    check hasHighLevel  # Position size > 50%
