## Unit Tests for Phase 3 Features
##
## Tests for:
## - Expression parser and evaluator
## - Position sizing strategies
## - Risk management (stop loss / take profit)
## - Indicator value caching
## - NOT condition logic

import std/[unittest, tables, math]
import ../../src/tzutrader/declarative/[expression, position_sizing,
    risk_management, condition_eval]

suite "Expression Parser Tests":
  test "tokenize simple expression":
    let tokens = tokenize("rsi_14 < 30")
    check tokens.len == 4 # rsi_14, <, 30, EOF
    check tokens[0].kind == tkIdentifier
    check tokens[0].value == "rsi_14"
    check tokens[1].kind == tkOperator
    check tokens[1].value == "<"
    check tokens[2].kind == tkNumber
    check tokens[2].value == "30"

  test "parse arithmetic expression":
    let expr = parseExpressionString("(rsi_14 + rsi_21) / 2")
    check expr.kind == exBinary
    check expr.operator == "/"

  test "evaluate simple arithmetic":
    let context = {"rsi_14": 30.0, "rsi_21": 40.0}.toTable
    let result = evaluateExpression("(rsi_14 + rsi_21) / 2", context)
    check result == 35.0

  test "evaluate comparison expression":
    let context = {"rsi_14": 25.0}.toTable
    let result = evaluateExpression("rsi_14 < 30", context)
    check result == 1.0 # true

  test "evaluate boolean AND":
    let context = {"rsi_14": 25.0, "macd": 5.0}.toTable
    let result = evaluateExpression("(rsi_14 < 30) and (macd > 0)", context)
    check result == 1.0 # true

  test "evaluate boolean OR":
    let context = {"rsi_14": 75.0, "macd": -5.0}.toTable
    let result = evaluateExpression("(rsi_14 > 70) or (macd > 0)", context)
    check result == 1.0 # true (rsi condition is true)

  test "evaluate with functions":
    let context = {"a": -10.0, "b": 5.0, "c": 8.0}.toTable
    check evaluateExpression("abs(a)", context) == 10.0
    check evaluateExpression("min(b, c)", context) == 5.0
    check evaluateExpression("max(b, c)", context) == 8.0
    check evaluateExpression("sqrt(4)", context) == 2.0

  test "division by zero error":
    let context = {"a": 10.0}.toTable
    expect ExpressionError:
      discard evaluateExpression("a / 0", context)

  test "undefined identifier error":
    let context = {"a": 10.0}.toTable
    expect ExpressionError:
      discard evaluateExpression("a + b", context)

  test "parentheses precedence":
    let context = {"a": 2.0, "b": 3.0, "c": 4.0}.toTable
    let result1 = evaluateExpression("a + b * c", context)
    let result2 = evaluateExpression("(a + b) * c", context)
    check result1 == 14.0 # 2 + (3 * 4)
    check result2 == 20.0 # (2 + 3) * 4

suite "Position Sizing Tests":
  test "fixed percentage sizing":
    let sizer = newFixedPercentageSizer(50.0)         # 50% of capital
    let shares = sizer.calculateShares(capital = 10000.0, price = 100.0)
    check shares == 50 # $5000 / $100 = 50 shares

  test "fixed percentage 100%":
    let sizer = newFixedPercentageSizer(100.0)
    let shares = sizer.calculateShares(capital = 10000.0, price = 50.0)
    check shares == 200 # $10000 / $50 = 200 shares

  test "fixed shares sizing":
    let sizer = newFixedSharesSizer(100)
    let shares = sizer.calculateShares(capital = 10000.0, price = 50.0)
    check shares == 100 # Always 100 shares

  test "equal weight sizing":
    let sizer = newEqualWeightSizer(4) # 4 equal positions
    let shares = sizer.calculateShares(capital = 10000.0, price = 50.0)
    check shares == 50 # $2500 / $50 = 50 shares per position

  test "risk-based sizing":
    let sizer = newRiskBasedSizer(
      riskPerTrade = 2.0,  # Risk 2% of capital
      atrMultiplier = 2.0, # Stop at 2*ATR
      atrIndicatorId = "atr_14"
    )

    let indicators = {"atr_14": 5.0}.toTable
    let shares = sizer.calculateShares(
      capital = 10000.0,
      price = 100.0,
      indicators = indicators
    )

    # Risk = $200 (2% of $10000)
    # Stop distance = 5.0 * 2.0 = $10
    # Position value = $200 / $10 * $100 = $2000
    # Shares = $2000 / $100 = 20
    check shares == 20

  test "kelly criterion sizing":
    let sizer = newKellySizer(
      winRate = 0.6,       # 60% win rate
      avgWinLoss = 1.5,    # Avg win 1.5x avg loss
      kellyFraction = 0.25 # Use quarter Kelly
    )

    let shares = sizer.calculateShares(capital = 10000.0, price = 100.0)
    check shares > 0
    check shares < 26 # Should be capped well below 25% of capital

suite "Risk Management Tests":
  test "fixed percentage stop loss":
    let stopLoss = newFixedPercentageStopLoss(5.0)         # 5% stop

    var state = newPositionState(entryPrice = 100.0)

    # Price drops 3% - should not trigger
    state.updateState(97.0)
    check not stopLoss.checkStopLoss(state)

    # Price drops 5% - should trigger
    state.updateState(95.0)
    check stopLoss.checkStopLoss(state)

  test "fixed price stop loss":
    let stopLoss = newFixedPriceStopLoss(95.0)

    var state = newPositionState(entryPrice = 100.0)

    # Price above stop - no trigger
    state.updateState(96.0)
    check not stopLoss.checkStopLoss(state)

    # Price at or below stop - trigger
    state.updateState(95.0)
    check stopLoss.checkStopLoss(state)

  test "trailing stop loss":
    let stopLoss = newTrailingStopLoss(
      trailPercentage = 5.0,  # Trail 5% below high
      activationProfit = 10.0 # Activate after 10% profit
    )

    var state = newPositionState(entryPrice = 100.0)

    # Not enough profit yet - no trailing
    state.updateState(105.0)
    check not stopLoss.checkStopLoss(state)

    # Reach activation profit
    state.updateState(112.0)
    check state.highestPrice == 112.0
    check not stopLoss.checkStopLoss(state)

    # Price drops but still above trailing stop (112 * 0.95 = 106.4)
    state.updateState(107.0)
    check not stopLoss.checkStopLoss(state)

    # Price drops below trailing stop
    state.updateState(106.0)
    check stopLoss.checkStopLoss(state)

  test "ATR-based stop loss":
    let stopLoss = newATRBasedStopLoss(atrMultiplier = 2.0,
        atrIndicatorId = "atr_14")
    let indicators = {"atr_14": 5.0}.toTable

    var state = newPositionState(entryPrice = 100.0)

    # Stop price = 100 - (5 * 2) = 90
    state.updateState(91.0)
    check not stopLoss.checkStopLoss(state, indicators)

    state.updateState(89.0)
    check stopLoss.checkStopLoss(state, indicators)

  test "fixed percentage take profit":
    let takeProfit = newFixedPercentageTakeProfit(10.0)         # 10% profit

    var state = newPositionState(entryPrice = 100.0)

    # Not yet at target
    state.updateState(109.0)
    let (triggered1, _) = takeProfit.checkTakeProfit(state)
    check not triggered1

    # Hit target
    state.updateState(110.0)
    let (triggered2, exitPct) = takeProfit.checkTakeProfit(state)
    check triggered2
    check exitPct == 100.0 # Exit entire position

  test "multi-level take profit":
    let levels = @[
      TakeProfitLevel(percentage: 5.0, exitPercent: 33.0), # Take 1/3 at 5%
      TakeProfitLevel(percentage: 10.0, exitPercent: 33.0), # Take 1/3 at 10%
      TakeProfitLevel(percentage: 15.0, exitPercent: 34.0) # Take remainder at 15%
    ]
    let takeProfit = newMultiLevelTakeProfit(levels)

    var state = newPositionState(entryPrice = 100.0)

    # Hit first level
    state.updateState(105.0)
    let (trig1, exit1) = takeProfit.checkTakeProfit(state)
    check trig1
    check exit1 == 33.0

    # Mark first level as hit, check second level
    state.markLevelHit(0)
    state.updateState(110.0)
    let (trig2, exit2) = takeProfit.checkTakeProfit(state)
    check trig2
    check exit2 == 33.0

suite "Indicator Cache Tests":
  test "create and update cache":
    var cache = newIndicatorCache(maxHistory = 10)

    let snapshot1 = {"rsi": 30.0, "macd": 5.0}.toTable
    cache.update(snapshot1)

    check cache.getValue("rsi") == 30.0
    check cache.getValue("macd") == 5.0

  test "historical value access":
    var cache = newIndicatorCache(maxHistory = 10)

    # Add 3 snapshots
    cache.update({"rsi": 25.0}.toTable)
    cache.update({"rsi": 30.0}.toTable)
    cache.update({"rsi": 35.0}.toTable)

    check cache.getValue("rsi", lookback = 0) == 35.0 # Current
    check cache.getValue("rsi", lookback = 1) == 30.0 # Previous
    check cache.getValue("rsi", lookback = 2) == 25.0 # 2 bars ago

  test "missing value returns NaN":
    var cache = newIndicatorCache()
    cache.update({"rsi": 30.0}.toTable)

    let val = cache.getValue("unknown_indicator")
    check val.isNaN

  test "insufficient history returns NaN":
    var cache = newIndicatorCache()
    cache.update({"rsi": 30.0}.toTable)

    # Only 1 bar of history, asking for 2 bars back
    let val = cache.getValue("rsi", lookback = 2)
    check val.isNaN

suite "Historical Reference Parsing Tests":
  test "parse simple reference":
    let (name, lookback) = parseHistoricalReference("rsi_14")
    check name == "rsi_14"
    check lookback == 0

  test "parse historical reference":
    let (name, lookback) = parseHistoricalReference("rsi_14[1]")
    check name == "rsi_14"
    check lookback == 1

  test "parse multi-bar lookback":
    let (name, lookback) = parseHistoricalReference("price[5]")
    check name == "price"
    check lookback == 5

when isMainModule:
  echo "Running Phase 3 unit tests..."
