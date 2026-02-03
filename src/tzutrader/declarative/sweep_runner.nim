import std/[tables, times, strformat, algorithm, options, strutils]
import ../portfolio
import ../trader
import ../strategy
import ./schema
import ./parser
import ./strategy_builder
import ./results
import ./sweep_generator
import ./batch_runner

type
  SweepRunnerError* = object of CatchableError
    ## Error during sweep execution

proc runParameterSweep*(
  sweepConfig: ParameterSweepYAML,
  verbose: bool = false
): BatchResults =
  ## Execute a complete parameter sweep
  ## Tests all parameter combinations and collects results

  let sweepStartTime = cpuTime()
  var batchResults = newBatchResults()

  # Count combinations
  let numCombinations = countCombinations(sweepConfig.parameters)

  if verbose:
    echo &"Parameter Sweep: {sweepConfig.metadata.name}"
    echo &"Base Strategy: {sweepConfig.baseStrategy}"
    echo &"Parameters: {sweepConfig.parameters.len}"
    echo &"Combinations: {numCombinations}"
    echo ""

  # Determine symbols
  var symbols: seq[string]
  case sweepConfig.data.source
  of dsYahoo:
    symbols = sweepConfig.data.symbols
  of dsCsv:
    symbols = @["CSV_DATA"]
  of dsCoinbase:
    symbols = sweepConfig.data.coinbaseSymbols

  let totalTests = numCombinations * symbols.len

  if verbose:
    echo &"Total backtests: {totalTests}"
    let estimatedTime = estimateSweepTime(numCombinations, symbols.len)
    echo &"Estimated time: {estimatedTime:.1f}s ({estimatedTime/60:.1f} minutes)"
    echo ""

  # Generate all variants
  let variants = generateSweepVariants(
    sweepConfig.baseStrategy,
    sweepConfig.parameters
  )

  # Run each variant on each symbol
  var successCount = 0
  var failCount = 0
  var testNum = 0

  for variantIdx, variantData in variants:
    let (variant, paramSet) = variantData

    # Build strategy
    var strategy: Strategy
    try:
      strategy = buildStrategy(variant)
    except:
      if verbose:
        echo &"✗ Failed to build strategy: {getCurrentExceptionMsg()}"
      failCount += symbols.len
      continue

    for symbol in symbols:
      testNum += 1

      if verbose:
        echo &"[{testNum}/{totalTests}] Combination {variantIdx + 1}/{numCombinations} on {symbol}"
        echo &"  Parameters: {paramSet}"

      try:
        # Fetch data
        let data = fetchData(sweepConfig.data, symbol)

        # Create portfolio config
        let pfConfig = PortfolioConfig(
          initialCash: sweepConfig.portfolio.initialCash,
          commission: sweepConfig.portfolio.commission,
          minCommission: if sweepConfig.portfolio.minCommission.isSome():
                          sweepConfig.portfolio.minCommission.get()
                        else: 0.0,
          riskFreeRate: if sweepConfig.portfolio.riskFreeRate.isSome():
                         sweepConfig.portfolio.riskFreeRate.get()
                       else: 0.02
        )

        # Run backtest
        let backtester = newBacktester(strategy, pfConfig, verbose = false)
        let report = backtester.run(data, symbol)

        # Convert to summary
        let strategyName = &"Sweep_{variantIdx + 1}"
        var btResult = fromBacktestReport(report, strategyName, symbol, 0.0)

        # Add parameter values to result
        btResult.parameters = toTable(paramSet)

        # Add to results
        batchResults.results.add(btResult)
        successCount += 1

        if verbose:
          echo &"  ✓ Return: {btResult.totalReturn:.2f}%, Sharpe: {btResult.sharpeRatio:.2f}"

      except:
        failCount += 1
        if verbose:
          echo &"  ✗ Failed: {getCurrentExceptionMsg()}"

  # Finalize results
  let sweepTime = cpuTime() - sweepStartTime
  batchResults.totalStrategies = numCombinations
  batchResults.totalSymbols = symbols.len
  batchResults.totalCombinations = totalTests
  batchResults.executionTime = sweepTime
  batchResults.timestamp = getTime().toUnix

  if verbose:
    echo ""
    echo "=".repeat(60)
    echo &"Parameter sweep complete!"
    echo &"Success: {successCount}, Failed: {failCount}"
    echo &"Total time: {sweepTime:.2f}s"
    echo "=".repeat(60)

  result = batchResults

proc exportSweepResultsCSV*(
  results: BatchResults,
  filename: string,
  includeParams: bool = true
) =
  ## Export sweep results to CSV with parameter columns

  if results.results.len == 0:
    writeFile(filename, "No results\n")
    return

  # Build header
  var headers = @[
    "Strategy",
    "Symbol",
    "Total Return %",
    "Annual Return %",
    "Sharpe Ratio",
    "Max Drawdown %",
    "Win Rate %",
    "Num Trades",
    "Profit Factor"
  ]

  # Add parameter columns
  if includeParams and results.results.len > 0:
    # Collect all unique parameter names
    var paramNames: seq[string] = @[]
    for r in results.results:
      for paramName in r.parameters.keys:
        if paramName notin paramNames:
          paramNames.add(paramName)

    paramNames.sort()
    headers.add(paramNames)

  # Build rows
  var lines: seq[string] = @[headers.join(",")]

  for r in results.results:
    var row = @[
      r.strategyName,
      r.symbol,
      &"{r.totalReturn:.2f}",
      &"{r.annualizedReturn:.2f}",
      &"{r.sharpeRatio:.2f}",
      &"{r.maxDrawdown:.2f}",
      &"{r.winRate:.2f}",
      $r.numTrades,
      &"{r.profitFactor:.2f}"
    ]

    # Add parameter values
    if includeParams and results.results.len > 0:
      var paramNames: seq[string] = @[]
      for r2 in results.results:
        for paramName in r2.parameters.keys:
          if paramName notin paramNames:
            paramNames.add(paramName)
      paramNames.sort()

      for paramName in paramNames:
        if r.parameters.hasKey(paramName):
          row.add(r.parameters[paramName])
        else:
          row.add("")

    lines.add(row.join(","))

  writeFile(filename, lines.join("\n"))

proc findBestParameters*(
  results: BatchResults,
  metric: RankingMetric = rmTotalReturn,
  topN: int = 10
): seq[BacktestResultSummary] =
  ## Find the best parameter combinations based on a metric
  result = results.getTopN(metric, topN)

proc printBestParameters*(
  results: BatchResults,
  metric: RankingMetric = rmTotalReturn,
  topN: int = 10
) =
  ## Print the best parameter combinations to console

  let best = findBestParameters(results, metric, topN)

  echo ""
  echo "=".repeat(70)
  echo &"Top {topN} Parameter Combinations by {metric}"
  echo "=".repeat(70)

  for i, r in best:
    echo &"\n{i + 1}. {r.strategyName} on {r.symbol}"
    echo &"   Return: {r.totalReturn:.2f}%, Sharpe: {r.sharpeRatio:.2f}, " &
         &"Drawdown: {r.maxDrawdown:.2f}%"

    if r.parameters.len > 0:
      echo "   Parameters:"
      for paramName, paramValue in r.parameters:
        echo &"     {paramName}: {paramValue}"

  echo ""
  echo "=".repeat(70)

proc runParameterSweepFromFile*(
  filename: string,
  verbose: bool = false
): BatchResults =
  ## Load parameter sweep configuration from file and execute

  if verbose:
    echo &"Loading parameter sweep configuration from {filename}"

  let sweepConfig = parseParameterSweepYAMLFile(filename)

  if verbose:
    echo &"Configuration: {sweepConfig.metadata.name}"
    echo &"Description: {sweepConfig.metadata.description}"

  result = runParameterSweep(sweepConfig, verbose)

  # Save results
  if verbose:
    echo &"\nSaving results to {sweepConfig.output.fullResults}"

  exportSweepResultsCSV(result, sweepConfig.output.fullResults,
      includeParams = true)

  # Save best results
  let bestN = if result.results.len > 50: 50 else: result.results.len
  let best = result.getTopN(rmTotalReturn, bestN)

  var bestResults = newBatchResults()
  bestResults.results = best
  bestResults.totalStrategies = result.totalStrategies
  bestResults.totalSymbols = result.totalSymbols
  bestResults.totalCombinations = result.totalCombinations
  bestResults.executionTime = result.executionTime
  bestResults.timestamp = result.timestamp

  if verbose:
    echo &"Saving top {bestN} results to {sweepConfig.output.bestResults}"

  exportSweepResultsCSV(bestResults, sweepConfig.output.bestResults,
      includeParams = true)
