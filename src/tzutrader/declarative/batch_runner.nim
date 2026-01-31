## Batch Test Runner
##
## This module executes batch tests - running multiple strategies across
## multiple symbols with different configurations.

import std/[tables, times, strformat, os, strutils, sequtils, options]
import ../core, ../data, ../strategy, ../portfolio, ../trader
import ./schema, ./batch_parser, ./parser, ./strategy_builder

type
  BatchRunError* = object of CatchableError
    ## Error during batch test execution
  
  StrategyResult* = object
    ## Result of running a single strategy on a single symbol
    strategyName*: string           ## Strategy configuration name
    symbol*: string                 ## Symbol tested
    report*: BacktestReport         ## Backtest report
    strategyFile*: string           ## Path to strategy file
  
  BatchTestResult* = object
    ## Complete results from a batch test
    batchConfig*: BatchTestYAML     ## Original batch configuration
    results*: seq[StrategyResult]   ## All individual results
    executionTime*: float64         ## Total execution time (seconds)

# ============================================================================
# Strategy Loading and Override Application
# ============================================================================

proc applyOverrides(strategyDef: var StrategyYAML, overrides: seq[ParameterOverride]) =
  ## Apply parameter overrides to a strategy definition
  ## Modifies the strategy in-place
  
  for override in overrides:
    # Find the indicator to override
    var found = false
    for i in 0..<strategyDef.indicators.len:
      if strategyDef.indicators[i].id == override.indicatorId:
        # Apply the parameter override
        strategyDef.indicators[i].params[override.paramName] = override.paramValue
        found = true
        break
    
    if not found:
      raise newException(BatchRunError, 
        "Cannot apply override: indicator '" & override.indicatorId & "' not found in strategy")

proc loadStrategyWithOverrides*(file: string, overrides: seq[ParameterOverride]): StrategyYAML =
  ## Load a strategy from file and apply parameter overrides
  ## 
  ## Args:
  ##   file: Path to strategy YAML file
  ##   overrides: Parameter overrides to apply
  ## 
  ## Returns:
  ##   Modified StrategyYAML object
  
  if not fileExists(file):
    raise newException(BatchRunError, "Strategy file not found: " & file)
  
  # Load base strategy
  result = parseStrategyYAMLFile(file)
  
  # Apply overrides
  if overrides.len > 0:
    applyOverrides(result, overrides)

# ============================================================================
# Data Loading
# ============================================================================

proc loadBatchData(config: DataSourceYAML): Table[string, seq[OHLCV]] =
  ## Load historical data for all symbols in the batch configuration
  ## 
  ## Args:
  ##   config: Data source configuration
  ## 
  ## Returns:
  ##   Table mapping symbols to their OHLCV data
  
  result = initTable[string, seq[OHLCV]]()
  
  case config.source
  of "yahoo":
    # Load data from Yahoo Finance for each symbol
    for symbol in config.symbols:
      try:
        let streamer = newYFHistory(symbol, config.startDate, config.endDate)
        let data = toSeq(streamer.items())
        
        if data.len == 0:
          raise newException(BatchRunError, 
            "No data returned for symbol: " & symbol)
        
        result[symbol] = data
        
      except CatchableError as e:
        raise newException(BatchRunError, 
          "Failed to fetch data for " & symbol & ": " & e.msg)
  
  of "csv":
    # Load data from CSV file
    if config.csvPath.isNone():
      raise newException(BatchRunError, 
        "csv_path is required when source is 'csv'")
    
    let csvPath = config.csvPath.get()
    if not fileExists(csvPath):
      raise newException(BatchRunError, "CSV file not found: " & csvPath)
    
    try:
      let data = readCSV(csvPath)
      # For CSV, we use the first symbol name or "CSV_DATA"
      let symbol = if config.symbols.len > 0: config.symbols[0] else: "CSV_DATA"
      result[symbol] = data
    except CatchableError as e:
      raise newException(BatchRunError, 
        "Failed to load CSV data: " & e.msg)
  
  of "coinbase":
    # Coinbase data loading would go here
    # For now, raise an error as it's not implemented
    raise newException(BatchRunError, 
      "Coinbase data source not yet implemented in batch runner")
  
  else:
    raise newException(BatchRunError, 
      "Unsupported data source: " & config.source)

# ============================================================================
# Strategy Execution
# ============================================================================

proc runStrategy(
  strategyName: string,
  strategyFile: string,
  strategyDef: StrategyYAML,
  symbol: string,
  data: seq[OHLCV],
  portfolioConfig: PortfolioConfigYAML,
  verbose: bool = false
): StrategyResult =
  ## Run a single strategy on a single symbol
  ## 
  ## Args:
  ##   strategyName: Name for this strategy configuration
  ##   strategyFile: Path to original strategy file
  ##   strategyDef: Loaded and modified strategy definition
  ##   symbol: Symbol to test
  ##   data: Historical OHLCV data
  ##   portfolioConfig: Portfolio configuration
  ##   verbose: Enable verbose output
  ## 
  ## Returns:
  ##   StrategyResult with backtest report
  
  if verbose:
    echo &"  Running {strategyName} on {symbol}..."
  
  # Build the strategy from the YAML definition
  let strategy = buildStrategy(strategyDef)
  
  # Create portfolio configuration
  let config = PortfolioConfig(
    initialCash: portfolioConfig.initialCash,
    commission: portfolioConfig.commission,
    minCommission: 0.0,  # Could be added to schema later
    riskFreeRate: 0.02   # Could be added to schema later
  )
  
  # Create backtester
  let backtester = newBacktester(
    strategy = Strategy(strategy),
    config = config,
    verbose = false  # Suppress individual trade logs in batch mode
  )
  
  # Run backtest
  let report = backtester.run(data, symbol = symbol)
  
  # Return result
  result = StrategyResult(
    strategyName: strategyName,
    symbol: symbol,
    report: report,
    strategyFile: strategyFile
  )

# ============================================================================
# Batch Execution
# ============================================================================

proc runBatchTest*(config: BatchTestYAML, verbose: bool = false): BatchTestResult =
  ## Execute a complete batch test
  ## 
  ## Args:
  ##   config: Batch test configuration
  ##   verbose: Enable verbose output
  ## 
  ## Returns:
  ##   BatchTestResult with all results
  
  let startTime = cpuTime()
  
  if verbose:
    echo "="
    echo "TzuTrader Batch Test"
    echo "="
    echo &"Strategies: {config.strategies.len}"
    echo &"Symbols: {config.data.symbols.len}"
    echo &"Date Range: {config.data.startDate} to {config.data.endDate}"
    echo ""
  
  # Load all historical data
  if verbose:
    echo "Loading historical data..."
  
  let dataTable = loadBatchData(config.data)
  
  if verbose:
    echo &"  Loaded data for {dataTable.len} symbols"
    for symbol, data in dataTable:
      echo &"    {symbol}: {data.len} bars"
    echo ""
  
  # Run all strategy-symbol combinations
  var results: seq[StrategyResult] = @[]
  
  let totalRuns = config.strategies.len * dataTable.len
  var currentRun = 0
  
  if verbose:
    echo &"Running {totalRuns} backtests..."
    echo ""
  
  for strategyConfig in config.strategies:
    # Load strategy with overrides
    let strategyDef = loadStrategyWithOverrides(
      strategyConfig.file,
      strategyConfig.overrides
    )
    
    # Run on each symbol
    for symbol, data in dataTable:
      currentRun += 1
      
      if verbose:
        echo &"[{currentRun}/{totalRuns}] {strategyConfig.name} on {symbol}"
      
      try:
        let result = runStrategy(
          strategyName = strategyConfig.name,
          strategyFile = strategyConfig.file,
          strategyDef = strategyDef,
          symbol = symbol,
          data = data,
          portfolioConfig = config.portfolio,
          verbose = verbose
        )
        
        results.add(result)
        
      except CatchableError as e:
        if verbose:
          echo &"  ERROR: {e.msg}"
        # Continue with other runs even if one fails
        # Could optionally add failed results to the output
  
  let endTime = cpuTime()
  let executionTime = endTime - startTime
  
  if verbose:
    echo ""
    echo &"Batch test complete in {executionTime:.2f} seconds"
    echo ""
  
  result = BatchTestResult(
    batchConfig: config,
    results: results,
    executionTime: executionTime
  )

# ============================================================================
# Convenience Functions
# ============================================================================

proc runBatchTestFromFile*(filename: string, verbose: bool = false): BatchTestResult =
  ## Run a batch test from a YAML file
  ## 
  ## Args:
  ##   filename: Path to batch test YAML file
  ##   verbose: Enable verbose output
  ## 
  ## Returns:
  ##   BatchTestResult with all results
  
  if not fileExists(filename):
    raise newException(BatchRunError, "Batch test file not found: " & filename)
  
  let config = parseBatchTestYAMLFile(filename)
  result = runBatchTest(config, verbose)

# ============================================================================
# Result Formatting
# ============================================================================

proc formatSummary*(batchResult: BatchTestResult): string =
  ## Format a summary of batch test results
  ## 
  ## Args:
  ##   batchResult: Batch test result
  ## 
  ## Returns:
  ##   Formatted string summary
  
  result = ""
  result &= "="
  result &= "\n"
  result &= "Batch Test Summary"
  result &= "\n"
  result &= "="
  result &= "\n"
  result &= &"Total Runs: {batchResult.results.len}\n"
  result &= &"Execution Time: {batchResult.executionTime:.2f}s\n"
  result &= "\n"
  
  if batchResult.results.len > 0:
    result &= "Results:\n"
    result &= "-" .repeat(100)
    result &= "\n"
    result &= "Strategy                 | Symbol  | Return    | Sharpe  | Max DD  | Win Rate | Trades\n"
    result &= "-" .repeat(100)
    result &= "\n"
    
    for sr in batchResult.results:
      let r = sr.report
      result &= &"{sr.strategyName:<24} | {sr.symbol:<7} | {r.totalReturn:>8.2f}% | {r.sharpeRatio:>7.2f} | "
      result &= &"{r.maxDrawdown:>6.2f}% | {r.winRate:>7.2f}% | {r.totalTrades:>6}\n"
    
    result &= "="
