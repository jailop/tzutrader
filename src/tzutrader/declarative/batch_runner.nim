import std/[tables, times, strformat, strutils, options]
import ../core
import ../data
import ../portfolio
import ../trader
import ../strategy
import ./schema
import ./parser
import ./strategy_builder
import ./results

type
  BatchRunnerError* = object of CatchableError
    ## Error during batch test execution

proc applyIndicatorOverrides(
  baseDef: var StrategyYAML,
  overrides: Table[string, IndicatorOverride]
) =
  ## Apply indicator parameter overrides to a strategy definition
  for i in 0 ..< baseDef.indicators.len:
    let indId = baseDef.indicators[i].id
    if overrides.hasKey(indId):
      # Merge parameters
      for paramKey, paramVal in overrides[indId].params:
        baseDef.indicators[i].params[paramKey] = paramVal

proc applyConditionOverrides(
  baseDef: var StrategyYAML,
  condOverrides: ConditionOverride
) =
  ## Apply condition overrides (entry/exit rules)
  if condOverrides.entry.isSome():
    baseDef.entryRule.conditions = condOverrides.entry.get()

  if condOverrides.exit.isSome():
    baseDef.exitRule.conditions = condOverrides.exit.get()

proc applyOverrides*(
  baseDef: StrategyYAML,
  overrides: StrategyOverrides
): StrategyYAML =
  ## Apply parameter overrides to a base strategy definition
  ## Returns a new StrategyYAML with overrides applied
  result = baseDef # Copy
  
  # Apply indicator overrides
  if overrides.indicators.isSome():
    applyIndicatorOverrides(result, overrides.indicators.get())

  # Apply condition overrides
  if overrides.conditions.isSome():
    applyConditionOverrides(result, overrides.conditions.get())

  # Apply position sizing override
  if overrides.positionSizing.isSome():
    result.positionSizing = overrides.positionSizing.get()

proc fetchData*(dataConfig: DataConfigYAML, symbol: string): seq[OHLCV] =
  ## Fetch OHLCV data for a symbol based on data configuration
  case dataConfig.source
  of dsYahoo:
    # Parse dates
    let startTime = parse(dataConfig.startDate, "yyyy-MM-dd").toTime.toUnix
    let endTime = parse(dataConfig.endDate, "yyyy-MM-dd").toTime.toUnix

    # Create data stream and fetch
    var ds = newDataStream(symbol)
    try:
      result = ds.fetchHistoryYfnim(startTime, endTime)
    except:
      raise newException(BatchRunnerError,
        &"Failed to fetch Yahoo Finance data for {symbol}: " &
        getCurrentExceptionMsg())

  of dsCsv:
    # Load from CSV file
    try:
      result = readCSV(dataConfig.csvFile)
    except:
      raise newException(BatchRunnerError,
        &"Failed to load CSV file {dataConfig.csvFile}: " &
        getCurrentExceptionMsg())

  of dsCoinbase:
    raise newException(BatchRunnerError, "Coinbase data source not yet implemented")

  if result.len == 0:
    raise newException(BatchRunnerError, &"No data fetched for {symbol}")

proc runStrategyVariant*(
  variant: StrategyVariantYAML,
  symbol: string,
  data: seq[OHLCV],
  portfolioConfig: PortfolioConfigYAML,
  verbose: bool = false
): BacktestResultSummary =
  ## Run a single strategy variant on one symbol
  ## Returns backtest result summary

  let startExec = cpuTime()

  # Load base strategy
  var strategyDef: StrategyYAML
  try:
    strategyDef = parseStrategyYAMLFile(variant.file)
  except:
    raise newException(BatchRunnerError,
      &"Failed to parse strategy file {variant.file}: " &
      getCurrentExceptionMsg())

  # Apply overrides if any
  if variant.overrides.isSome():
    strategyDef = applyOverrides(strategyDef, variant.overrides.get())

  # Build executable strategy
  var strategy: Strategy
  try:
    strategy = buildStrategy(strategyDef)
  except:
    raise newException(BatchRunnerError,
      &"Failed to build strategy {variant.name}: " & getCurrentExceptionMsg())

  # Create portfolio configuration
  let pfConfig = PortfolioConfig(
    initialCash: portfolioConfig.initialCash,
    commission: portfolioConfig.commission,
    minCommission: if portfolioConfig.minCommission.isSome():
                    portfolioConfig.minCommission.get()
                  else: 0.0,
    riskFreeRate: if portfolioConfig.riskFreeRate.isSome():
                   portfolioConfig.riskFreeRate.get()
                 else: 0.02
  )

  # Create backtester
  let backtester = newBacktester(strategy, pfConfig, verbose)

  # Run backtest
  var report: BacktestReport
  try:
    report = backtester.run(data, symbol)
  except:
    raise newException(BatchRunnerError,
      &"Backtest failed for {variant.name} on {symbol}: " &
      getCurrentExceptionMsg())

  let executionTime = cpuTime() - startExec

  # Convert to summary
  result = fromBacktestReport(
    report,
    variant.name,
    symbol,
    executionTime
  )

proc runBatchTest*(
  batchConfig: BatchTestYAML,
  verbose: bool = false
): BatchResults =
  ## Execute a complete batch test
  ## Runs all strategy variants on all symbols and collects results

  let batchStartTime = cpuTime()
  var batchResults = newBatchResults()

  # Determine symbols to test
  var symbols: seq[string]
  case batchConfig.data.source
  of dsYahoo:
    symbols = batchConfig.data.symbols
  of dsCsv:
    # For CSV, use a single dummy symbol
    symbols = @["CSV_DATA"]
  of dsCoinbase:
    symbols = batchConfig.data.coinbaseSymbols

  if verbose:
    echo &"Starting batch test with {batchConfig.strategies.len} strategies on {symbols.len} symbols"
    echo &"Total combinations: {batchConfig.strategies.len * symbols.len}"

  # Run each strategy variant on each symbol
  var successCount = 0
  var failCount = 0

  for variant in batchConfig.strategies:
    for symbol in symbols:
      if verbose:
        echo &"\n[{successCount + failCount + 1}/{batchConfig.strategies.len * symbols.len}] " &
             &"Running {variant.name} on {symbol}..."

      try:
        # Fetch data for this symbol
        let data = fetchData(batchConfig.data, symbol)

        if verbose:
          echo &"  Fetched {data.len} bars"

        # Run backtest
        let variantResult = runStrategyVariant(
          variant,
          symbol,
          data,
          batchConfig.portfolio,
          verbose = false # Don't show individual backtest details
        )

        # Add to results
        batchResults.results.add(variantResult)
        successCount += 1

        if verbose:
          echo &"  ✓ Completed in {variantResult.executionTime:.2f}s"
          echo &"    Return: {variantResult.totalReturn:.2f}%, Sharpe: {variantResult.sharpeRatio:.2f}"

      except BatchRunnerError as e:
        failCount += 1
        if verbose:
          echo &"  ✗ Failed: {e.msg}"
      except:
        failCount += 1
        if verbose:
          echo &"  ✗ Failed: {getCurrentExceptionMsg()}"

  # Finalize batch results
  let batchTime = cpuTime() - batchStartTime
  batchResults.totalStrategies = batchConfig.strategies.len
  batchResults.totalSymbols = symbols.len
  batchResults.totalCombinations = batchConfig.strategies.len * symbols.len
  batchResults.executionTime = batchTime
  batchResults.timestamp = getTime().toUnix

  if verbose:
    echo &"\n" & "=".repeat(60)
    echo &"Batch test complete!"
    echo &"Success: {successCount}, Failed: {failCount}"
    echo &"Total execution time: {batchTime:.2f}s"
    echo "=".repeat(60)

  result = batchResults

proc saveBatchResults*(
  results: BatchResults,
  outputConfig: BatchOutputYAML,
  verbose: bool = false
) =
  ## Save batch test results according to output configuration

  for format in outputConfig.formats:
    case format.toLowerAscii()
    of "csv":
      # Save CSV comparison
      if outputConfig.comparisonReport.isSome():
        let csvPath = outputConfig.comparisonReport.get()
        if verbose:
          echo &"Saving CSV report to {csvPath}"
        try:
          let csv = results.toCSV()
          writeFile(csvPath, csv)
        except:
          if verbose:
            echo &"Failed to save CSV: {getCurrentExceptionMsg()}"
      else:
        # Use default filename
        let csvPath = "batch_results.csv"
        if verbose:
          echo &"Saving CSV report to {csvPath}"
        try:
          let csv = results.toCSV()
          writeFile(csvPath, csv)
        except:
          if verbose:
            echo &"Failed to save CSV: {getCurrentExceptionMsg()}"

    of "json":
      # Future: JSON output
      if verbose:
        echo "JSON output not yet implemented"

    of "html":
      # Future: HTML report
      if verbose:
        echo "HTML output not yet implemented"

    else:
      if verbose:
        echo &"Unknown output format: {format}"

proc runBatchTestFromFile*(
  filename: string,
  verbose: bool = false
): BatchResults =
  ## Load batch test configuration from file and execute

  if verbose:
    echo &"Loading batch test configuration from {filename}"

  let batchConfig = parseBatchTestYAMLFile(filename)

  if verbose:
    echo &"Configuration: {batchConfig.metadata.name}"
    echo &"Description: {batchConfig.metadata.description}"

  result = runBatchTest(batchConfig, verbose)

  # Save results if output is configured
  if batchConfig.output.formats.len > 0:
    saveBatchResults(result, batchConfig.output, verbose)
