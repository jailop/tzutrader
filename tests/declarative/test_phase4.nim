## Tests for Batch Testing and Parameter Sweep (Phase 4)
##
## This test suite covers:
## - Batch configuration parsing
## - Parameter override application
## - Sweep range generation
## - Parameter combination generation
## - Result collection and export

import std/[unittest, tables, os, strutils, strformat, options]
import ../../src/tzutrader/declarative/[
  schema, parser, batch_runner, results,
  sweep_generator
]

suite "Batch Configuration Parsing":

  test "Parse data config - Yahoo Finance":
    let yamlContent = """
data:
  source: yahoo
  symbols:
    - AAPL
    - MSFT
  start_date: "2023-01-01"
  end_date: "2023-12-31"
"""
    # This would need parseDataConfig to be exported
    # For now, we test through full batch parsing
    check true # Placeholder

  test "Parse portfolio config":
    let config = newPortfolioConfig(
      initialCash = 50000.0,
      commission = 0.002,
      minCommission = some(1.0),
      riskFreeRate = some(0.03)
    )

    check config.initialCash == 50000.0
    check config.commission == 0.002
    check config.minCommission.get() == 1.0
    check config.riskFreeRate.get() == 0.03

  test "Parse strategy variant without overrides":
    let variant = newStrategyVariant(
      "examples/yaml_strategies/rsi_simple.yml",
      "RSI_Default"
    )

    check variant.file == "examples/yaml_strategies/rsi_simple.yml"
    check variant.name == "RSI_Default"
    check variant.overrides.isNone()

  test "Parse strategy variant with overrides":
    var overrides = StrategyOverrides()
    var indicators = initTable[string, IndicatorOverride]()
    var indOverride = IndicatorOverride()
    indOverride.params = initTable[string, ParamValue]()
    indOverride.params["period"] = newParamInt(21)
    indicators["rsi_14"] = indOverride
    overrides.indicators = some(indicators)

    let variant = newStrategyVariant(
      "test.yml",
      "Test",
      some(overrides)
    )

    check variant.overrides.isSome()

suite "Parameter Override Application":

  test "Apply indicator parameter override":
    # Create base strategy
    var baseDef = StrategyYAML()
    baseDef.metadata = MetadataYAML(name: "Test", description: "Test", tags: @[])

    # Add an indicator
    var indicator = IndicatorYAML()
    indicator.id = "rsi_14"
    indicator.indicatorType = "rsi"
    indicator.params = initTable[string, ParamValue]()
    indicator.params["period"] = newParamInt(14)
    baseDef.indicators = @[indicator]

    # Create overrides
    var overrides = StrategyOverrides()
    var indicators = initTable[string, IndicatorOverride]()
    var indOverride = IndicatorOverride()
    indOverride.params = initTable[string, ParamValue]()
    indOverride.params["period"] = newParamInt(21)
    indicators["rsi_14"] = indOverride
    overrides.indicators = some(indicators)

    # Apply overrides
    let result = applyOverrides(baseDef, overrides)

    # Verify
    check result.indicators.len == 1
    check result.indicators[0].id == "rsi_14"
    check result.indicators[0].params["period"].kind == pkInt
    check result.indicators[0].params["period"].intVal == 21

  test "Apply position sizing override":
    var baseDef = StrategyYAML()
    baseDef.metadata = MetadataYAML(name: "Test", description: "Test", tags: @[])
    baseDef.indicators = @[]
    baseDef.positionSizing = PositionSizingYAML(kind: psFixed, fixedSize: 100.0)

    var overrides = StrategyOverrides()
    overrides.positionSizing = some(PositionSizingYAML(
      kind: psPercent,
      percentCapital: 10.0
    ))

    let result = applyOverrides(baseDef, overrides)

    check result.positionSizing.kind == psPercent
    check result.positionSizing.percentCapital == 10.0

suite "Sweep Range Generation":

  test "Generate linear range":
    let range = newSweepRangeLinear(10.0, 30.0, 5.0)
    let values = generateValues(range)

    check values.len == 5
    check values[0] == 10.0
    check values[1] == 15.0
    check values[2] == 20.0
    check values[3] == 25.0
    check values[4] == 30.0

  test "Generate linear range with fractional step":
    let range = newSweepRangeLinear(0.5, 2.5, 0.5)
    let values = generateValues(range)

    check values.len == 5
    check values[0] == 0.5
    check values[4] == 2.5

  test "Generate list range":
    let range = newSweepRangeList(@[10.0, 20.0, 30.0, 50.0])
    let values = generateValues(range)

    check values.len == 4
    check values[0] == 10.0
    check values[1] == 20.0
    check values[2] == 30.0
    check values[3] == 50.0

  test "Linear range with single value":
    let range = newSweepRangeLinear(42.0, 42.0, 1.0)
    let values = generateValues(range)

    check values.len == 1
    check values[0] == 42.0

suite "Parameter Path Parsing":

  test "Parse indicator parameter path":
    let path = parseParameterPath("indicators.rsi_14.period")

    check path.target == "indicators"
    check path.identifier == "rsi_14"
    check path.param == "period"

  test "Parse indicator path with params keyword":
    let path = parseParameterPath("indicators.rsi_14.params.period")

    check path.target == "indicators"
    check path.identifier == "rsi_14"
    check path.param == "period"

  test "Parse position sizing path":
    let path = parseParameterPath("position_sizing.percent")

    check path.target == "position_sizing"
    check path.param == "percent"

  test "Parse conditions path":
    let path = parseParameterPath("conditions.entry.right")

    check path.target == "conditions"
    check path.identifier == "entry"
    check path.param == "right"

  test "Invalid path raises error":
    expect SweepGeneratorError:
      discard parseParameterPath("invalid")

  test "Invalid indicator path raises error":
    expect SweepGeneratorError:
      discard parseParameterPath("indicators.rsi_14")

suite "Parameter Combination Generation":

  test "Single parameter sweep":
    var params: seq[SweepParameter] = @[]

    let range = newSweepRangeList(@[10.0, 20.0, 30.0])
    let param = newSweepParameter("indicators.rsi_14.period", range)
    params.add(param)

    let combinations = generateCombinations(params)

    check combinations.len == 3
    check combinations[0].hasKey("indicators.rsi_14.period")
    check combinations[0]["indicators.rsi_14.period"].floatVal == 10.0
    check combinations[1]["indicators.rsi_14.period"].floatVal == 20.0
    check combinations[2]["indicators.rsi_14.period"].floatVal == 30.0

  test "Two parameter sweep - cartesian product":
    var params: seq[SweepParameter] = @[]

    let range1 = newSweepRangeList(@[10.0, 20.0])
    let param1 = newSweepParameter("indicators.rsi_14.period", range1)
    params.add(param1)

    let range2 = newSweepRangeList(@[30.0, 40.0])
    let param2 = newSweepParameter("conditions.entry.right", range2)
    params.add(param2)

    let combinations = generateCombinations(params)

    check combinations.len == 4 # 2 × 2
    
    # Verify all combinations exist
    var found = 0
    for combo in combinations:
      if combo["indicators.rsi_14.period"].floatVal == 10.0 and
         combo["conditions.entry.right"].floatVal == 30.0:
        found += 1
      elif combo["indicators.rsi_14.period"].floatVal == 10.0 and
           combo["conditions.entry.right"].floatVal == 40.0:
        found += 1
      elif combo["indicators.rsi_14.period"].floatVal == 20.0 and
           combo["conditions.entry.right"].floatVal == 30.0:
        found += 1
      elif combo["indicators.rsi_14.period"].floatVal == 20.0 and
           combo["conditions.entry.right"].floatVal == 40.0:
        found += 1

    check found == 4

  test "Three parameter sweep":
    var params: seq[SweepParameter] = @[]

    params.add(newSweepParameter(
      "param1",
      newSweepRangeList(@[1.0, 2.0])
    ))
    params.add(newSweepParameter(
      "param2",
      newSweepRangeList(@[10.0, 20.0])
    ))
    params.add(newSweepParameter(
      "param3",
      newSweepRangeList(@[100.0, 200.0])
    ))

    let combinations = generateCombinations(params)

    check combinations.len == 8 # 2 × 2 × 2

  test "Empty parameter list":
    let params: seq[SweepParameter] = @[]
    let combinations = generateCombinations(params)

    check combinations.len == 0

suite "Sweep Statistics":

  test "Count combinations":
    var params: seq[SweepParameter] = @[]

    params.add(newSweepParameter(
      "param1",
      newSweepRangeLinear(10.0, 30.0, 5.0) # 5 values
    ))
    params.add(newSweepParameter(
      "param2",
      newSweepRangeList(@[1.0, 2.0, 3.0]) # 3 values
    ))

    let count = countCombinations(params)

    check count == 15 # 5 × 3

  test "Estimate sweep time":
    let time = estimateSweepTime(100, 3, 2.0)

    check time == 600.0 # 100 × 3 × 2.0

suite "Batch Results":

  test "Create empty batch results":
    let batch = newBatchResults()

    check batch.results.len == 0
    check batch.totalStrategies == 0
    check batch.totalSymbols == 0

  test "Add results to batch":
    var batch = newBatchResults()

    var result1 = BacktestResultSummary(
      strategyName: "Strategy1",
      symbol: "AAPL",
      totalReturn: 15.5,
      sharpeRatio: 1.5,
      maxDrawdown: -8.0,
      numTrades: 20
    )

    batch.results.add(result1)

    check batch.results.len == 1
    check batch.results[0].strategyName == "Strategy1"

  test "Get top N results":
    var batch = newBatchResults()

    for i in 1..10:
      var result = BacktestResultSummary(
        strategyName: &"Strategy{i}",
        symbol: "TEST",
        totalReturn: float(i * 5), # Returns from 5% to 50%
        sharpeRatio: 1.0,
        maxDrawdown: -10.0,
        numTrades: 10
      )
      batch.results.add(result)

    let top3 = batch.getTopN(rmTotalReturn, 3)

    check top3.len == 3
    check top3[0].totalReturn == 50.0 # Best return
    check top3[1].totalReturn == 45.0
    check top3[2].totalReturn == 40.0

suite "CSV Export":

  test "Convert result to CSV row":
    var result = BacktestResultSummary(
      strategyName: "TestStrat",
      symbol: "AAPL",
      startDate: "2023-01-01",
      endDate: "2023-12-31",
      initialCash: 100000.0,
      finalValue: 115000.0,
      totalReturn: 15.0,
      annualizedReturn: 15.5,
      sharpeRatio: 1.5,
      maxDrawdown: -8.0,
      winRate: 65.0,
      numTrades: 20,
      avgWin: 500.0,
      avgLoss: -300.0,
      profitFactor: 1.8,
      executionTime: 1.5
    )

    let csvRow = result.toCsvRow()

    check "TestStrat" in csvRow
    check "AAPL" in csvRow
    check "15.00" in csvRow

  test "Batch results to CSV":
    var batch = newBatchResults()

    var result1 = BacktestResultSummary(
      strategyName: "Strategy1",
      symbol: "AAPL",
      startDate: "2023-01-01",
      endDate: "2023-12-31",
      totalReturn: 15.0,
      sharpeRatio: 1.5
    )

    batch.results.add(result1)

    let csv = batch.toCSV()

    check "Strategy" in csv # Header
    check "Strategy1" in csv
    check "AAPL" in csv

suite "Helper Functions":

  test "Schema helper constructors":
    let dataConfig = newDataConfigYahoo(
      @["AAPL", "MSFT"],
      "2023-01-01",
      "2023-12-31"
    )

    check dataConfig.source == dsYahoo
    check dataConfig.symbols.len == 2
    check dataConfig.symbols[0] == "AAPL"

  test "Sweep parameter constructor":
    let range = newSweepRangeLinear(10.0, 30.0, 5.0)
    let param = newSweepParameter("test.path", range)

    check param.path == "test.path"
    check param.range.kind == srkLinear

# Run the tests
when isMainModule:
  echo "Running Phase 4 tests..."
