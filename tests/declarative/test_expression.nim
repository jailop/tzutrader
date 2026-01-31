## Tests for expression parser and evaluator

import std/[unittest, tables, math]
import tzutrader/declarative/expression

suite "Expression Parser - Literals and References":
  
  test "Parse number literal":
    let expr = parseExpression("42")
    check expr.kind == ekLiteral
    check expr.value == 42.0
  
  test "Parse float literal":
    let expr = parseExpression("3.14159")
    check expr.kind == ekLiteral
    check expr.value == 3.14159
  
  test "Parse reference":
    let expr = parseExpression("rsi_14")
    check expr.kind == ekReference
    check expr.refName == "rsi_14"
  
  test "Parse reference with dot notation":
    let expr = parseExpression("macd.signal")
    check expr.kind == ekReference
    check expr.refName == "macd.signal"

suite "Expression Parser - Arithmetic":
  
  test "Parse addition":
    let expr = parseExpression("1 + 2")
    check expr.kind == ekBinary
    check expr.op == boAdd
  
  test "Parse subtraction":
    let expr = parseExpression("5 - 3")
    check expr.kind == ekBinary
    check expr.op == boSub
  
  test "Parse multiplication":
    let expr = parseExpression("2 * 3")
    check expr.kind == ekBinary
    check expr.op == boMul
  
  test "Parse division":
    let expr = parseExpression("10 / 2")
    check expr.kind == ekBinary
    check expr.op == boDiv
  
  test "Parse complex expression with precedence":
    let expr = parseExpression("2 + 3 * 4")
    # Should parse as 2 + (3 * 4) due to precedence
    check expr.kind == ekBinary
    check expr.op == boAdd
    check expr.left.kind == ekLiteral
    check expr.right.kind == ekBinary
    check expr.right.op == boMul
  
  test "Parse expression with parentheses":
    let expr = parseExpression("(2 + 3) * 4")
    check expr.kind == ekBinary
    check expr.op == boMul

suite "Expression Parser - Comparison":
  
  test "Parse less than":
    let expr = parseExpression("x < 30")
    check expr.kind == ekBinary
    check expr.op == boLess
  
  test "Parse greater than":
    let expr = parseExpression("x > 70")
    check expr.kind == ekBinary
    check expr.op == boGreater
  
  test "Parse equality":
    let expr = parseExpression("x == 50")
    check expr.kind == ekBinary
    check expr.op == boEqual

suite "Expression Parser - Logical":
  
  test "Parse AND":
    let expr = parseExpression("(x < 30) and (y > 70)")
    check expr.kind == ekBinary
    check expr.op == boAnd
  
  test "Parse OR":
    let expr = parseExpression("(x < 30) or (y > 70)")
    check expr.kind == ekBinary
    check expr.op == boOr
  
  test "Parse NOT":
    let expr = parseExpression("not (x > 70)")
    check expr.kind == ekUnary
    check expr.unaryOp == uoNot

suite "Expression Parser - Functions":
  
  test "Parse abs function":
    let expr = parseExpression("abs(x)")
    check expr.kind == ekUnary
    check expr.unaryOp == uoAbs
  
  test "Parse sqrt function":
    let expr = parseExpression("sqrt(x)")
    check expr.kind == ekUnary
    check expr.unaryOp == uoSqrt
  
  test "Parse max function":
    let expr = parseExpression("max(x, y)")
    check expr.kind == ekFunction
    check expr.funcOp == foMax
    check expr.args.len == 2
  
  test "Parse min function":
    let expr = parseExpression("min(x, y, z)")
    check expr.kind == ekFunction
    check expr.funcOp == foMin
    check expr.args.len == 3

suite "Expression Evaluator - Basic Operations":
  
  test "Evaluate literal":
    let expr = parseExpression("42")
    let result = evaluateExpression(expr, initTable[string, float64]())
    check result == 42.0
  
  test "Evaluate reference":
    let expr = parseExpression("rsi_14")
    let values = {"rsi_14": 25.0}.toTable
    let result = evaluateExpression(expr, values)
    check result == 25.0
  
  test "Evaluate addition":
    let expr = parseExpression("10 + 20")
    let result = evaluateExpression(expr, initTable[string, float64]())
    check result == 30.0
  
  test "Evaluate with references":
    let expr = parseExpression("rsi_14 + rsi_21")
    let values = {"rsi_14": 25.0, "rsi_21": 30.0}.toTable
    let result = evaluateExpression(expr, values)
    check result == 55.0
  
  test "Evaluate average":
    let expr = parseExpression("(rsi_14 + rsi_21) / 2")
    let values = {"rsi_14": 20.0, "rsi_21": 30.0}.toTable
    let result = evaluateExpression(expr, values)
    check result == 25.0
  
  test "Evaluate complex expression":
    let expr = parseExpression("price * volume / 1000")
    let values = {"price": 100.0, "volume": 5000.0}.toTable
    let result = evaluateExpression(expr, values)
    check result == 500.0

suite "Expression Evaluator - Comparisons":
  
  test "Evaluate less than (true)":
    let expr = parseExpression("x < 30")
    let values = {"x": 25.0}.toTable
    let result = evaluateExpression(expr, values)
    check result == 1.0  # True
  
  test "Evaluate less than (false)":
    let expr = parseExpression("x < 30")
    let values = {"x": 35.0}.toTable
    let result = evaluateExpression(expr, values)
    check result == 0.0  # False
  
  test "Evaluate greater than":
    let expr = parseExpression("x > 70")
    let values = {"x": 75.0}.toTable
    let result = evaluateExpression(expr, values)
    check result == 1.0  # True

suite "Expression Evaluator - Logical":
  
  test "Evaluate AND (both true)":
    let expr = parseExpression("(x < 30) and (y > 70)")
    let values = {"x": 25.0, "y": 75.0}.toTable
    let result = evaluateExpression(expr, values)
    check result == 1.0  # True
  
  test "Evaluate AND (one false)":
    let expr = parseExpression("(x < 30) and (y > 70)")
    let values = {"x": 35.0, "y": 75.0}.toTable
    let result = evaluateExpression(expr, values)
    check result == 0.0  # False
  
  test "Evaluate OR":
    let expr = parseExpression("(x < 30) or (y > 70)")
    let values = {"x": 35.0, "y": 75.0}.toTable
    let result = evaluateExpression(expr, values)
    check result == 1.0  # True
  
  test "Evaluate NOT":
    let expr = parseExpression("not (x > 70)")
    let values = {"x": 50.0}.toTable
    let result = evaluateExpression(expr, values)
    check result == 1.0  # True (x is not > 70)

suite "Expression Evaluator - Functions":
  
  test "Evaluate abs":
    let expr = parseExpression("abs(x)")
    let values = {"x": -25.0}.toTable
    let result = evaluateExpression(expr, values)
    check result == 25.0
  
  test "Evaluate sqrt":
    let expr = parseExpression("sqrt(x)")
    let values = {"x": 16.0}.toTable
    let result = evaluateExpression(expr, values)
    check result == 4.0
  
  test "Evaluate max":
    let expr = parseExpression("max(x, y)")
    let values = {"x": 25.0, "y": 75.0}.toTable
    let result = evaluateExpression(expr, values)
    check result == 75.0
  
  test "Evaluate min":
    let expr = parseExpression("min(x, y, z)")
    let values = {"x": 25.0, "y": 75.0, "z": 10.0}.toTable
    let result = evaluateExpression(expr, values)
    check result == 10.0

suite "Expression Evaluator - Error Handling":
  
  test "Undefined reference raises error":
    let expr = parseExpression("undefined_var")
    expect EvalError:
      discard evaluateExpression(expr, initTable[string, float64]())
  
  test "Division by zero returns NaN":
    let expr = parseExpression("10 / 0")
    let result = evaluateExpression(expr, initTable[string, float64]())
    check result.isNaN
  
  test "NaN propagation":
    let expr = parseExpression("x + y")
    let values = {"x": NaN, "y": 10.0}.toTable
    let result = evaluateExpression(expr, values)
    check result.isNaN
