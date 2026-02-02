## Unit tests for schema type definitions

import std/unittest
import tzutrader/declarative/schema

suite "Schema Types":

  test "ParamValue constructors":
    let intParam = newParamInt(42)
    check intParam.kind == pkInt
    check intParam.intVal == 42

    let floatParam = newParamFloat(3.14)
    check floatParam.kind == pkFloat
    check floatParam.floatVal == 3.14

    let strParam = newParamString("test")
    check strParam.kind == pkString
    check strParam.strVal == "test"

    let boolParam = newParamBool(true)
    check boolParam.kind == pkBool
    check boolParam.boolVal == true

  test "Simple condition constructor":
    let cond = newSimpleCondition("rsi_14", opLessThan, "30")
    check cond.kind == ckSimple
    check cond.left == "rsi_14"
    check cond.operator == opLessThan
    check cond.right == "30"

  test "AND condition constructor":
    let c1 = newSimpleCondition("rsi_14", opLessThan, "30")
    let c2 = newSimpleCondition("macd", opGreaterThan, "0")
    let andCond = newAndCondition(@[c1, c2])

    check andCond.kind == ckAnd
    check andCond.andConditions.len == 2

  test "OR condition constructor":
    let c1 = newSimpleCondition("rsi_14", opLessThan, "30")
    let c2 = newSimpleCondition("rsi_14", opGreaterThan, "70")
    let orCond = newOrCondition(@[c1, c2])

    check orCond.kind == ckOr
    check orCond.orConditions.len == 2

  test "Operator string conversion":
    check $opLessThan == "<"
    check $opGreaterThan == ">"
    check $opLessEqual == "<="
    check $opGreaterEqual == ">="
    check $opEqual == "=="
    check $opNotEqual == "!="
    check $opCrossesAbove == "crosses_above"
    check $opCrossesBelow == "crosses_below"

  test "ParamValue string conversion":
    check $newParamInt(42) == "42"
    check $newParamFloat(3.14) == "3.14"
    check $newParamString("test") == "test"
    check $newParamBool(true) == "true"
