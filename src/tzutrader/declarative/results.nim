## Batch Testing and Results Management
##
## This module provides batch testing capabilities for running multiple strategies
## or strategy variations in parallel, collecting results, and generating reports.
##
## Features:
## - Batch test execution (multiple strategies on multiple symbols)
## - Parameter sweep functionality
## - Result collection and aggregation
## - Performance metrics calculation
## - Ranking and comparison
##
## Phase 4 Feature

import std/[tables, times, math, algorithm, strformat, sequtils, strutils]
import ../trader
import ../core

type
  BacktestResultSummary* = object
    ## Summary of a single backtest run
    strategyName*: string
    symbol*: string
    startDate*: string
    endDate*: string
    initialCash*: float64
    finalValue*: float64
    totalReturn*: float64
    annualizedReturn*: float64
    sharpeRatio*: float64
    maxDrawdown*: float64
    winRate*: float64
    numTrades*: int
    avgWin*: float64
    avgLoss*: float64
    profitFactor*: float64
    executionTime*: float64  # seconds
    parameters*: Table[string, string]  # For tracking sweep parameters
  
  BatchResults* = object
    ## Collection of backtest results
    results*: seq[BacktestResultSummary]
    totalStrategies*: int
    totalSymbols*: int
    totalCombinations*: int
    executionTime*: float64  # Total execution time
    timestamp*: int64  # When batch was run
  
  RankingMetric* = enum
    ## Metrics for ranking strategies
    rmTotalReturn,
    rmAnnualizedReturn,
    rmSharpeRatio,
    rmMaxDrawdown,
    rmWinRate,
    rmProfitFactor,
    rmNumTrades
  
  ComparisonTable* = object
    ## Formatted comparison table
    headers*: seq[string]
    rows*: seq[seq[string]]
    rankings*: Table[string, int]  # Strategy name -> rank

# ============================================================================
# Result Creation and Conversion
# ============================================================================

proc fromBacktestReport*(
  report: BacktestReport,
  strategyName: string,
  symbol: string,
  executionTime: float64 = 0.0,
  parameters: Table[string, string] = initTable[string, string]()
): BacktestResultSummary =
  ## Convert a BacktestReport to a BacktestResultSummary
  result = BacktestResultSummary(
    strategyName: strategyName,
    symbol: symbol,
    startDate: $fromUnix(report.startTime).format("yyyy-MM-dd"),
    endDate: $fromUnix(report.endTime).format("yyyy-MM-dd"),
    initialCash: report.initialCash,
    finalValue: report.finalValue,
    totalReturn: report.totalReturn,
    annualizedReturn: report.annualizedReturn,
    sharpeRatio: report.sharpeRatio,
    maxDrawdown: report.maxDrawdown,
    winRate: report.winRate,
    numTrades: report.totalTrades,
    avgWin: report.avgWin,
    avgLoss: report.avgLoss,
    profitFactor: report.profitFactor,
    executionTime: executionTime,
    parameters: parameters
  )

proc newBatchResults*(): BatchResults =
  ## Create a new empty batch results collection
  result = BatchResults(
    results: @[],
    totalStrategies: 0,
    totalSymbols: 0,
    totalCombinations: 0,
    executionTime: 0.0,
    timestamp: getTime().toUnix()
  )

proc addResult*(batch: var BatchResults, result: BacktestResultSummary) =
  ## Add a result to the batch collection
  batch.results.add(result)
  batch.totalCombinations = batch.results.len

proc finalize*(batch: var BatchResults, executionTime: float64) =
  ## Finalize batch results with execution time
  batch.executionTime = executionTime
  
  # Count unique strategies and symbols
  var strategies: seq[string] = @[]
  var symbols: seq[string] = @[]
  
  for result in batch.results:
    if result.strategyName notin strategies:
      strategies.add(result.strategyName)
    if result.symbol notin symbols:
      symbols.add(result.symbol)
  
  batch.totalStrategies = strategies.len
  batch.totalSymbols = symbols.len

# ============================================================================
# Ranking and Comparison
# ============================================================================

proc sortByMetric*(results: var seq[BacktestResultSummary], metric: RankingMetric, ascending: bool = false) =
  ## Sort results by specified metric
  case metric
  of rmTotalReturn:
    results.sort(proc (a, b: BacktestResultSummary): int =
      cmp(a.totalReturn, b.totalReturn))
  of rmAnnualizedReturn:
    results.sort(proc (a, b: BacktestResultSummary): int =
      cmp(a.annualizedReturn, b.annualizedReturn))
  of rmSharpeRatio:
    results.sort(proc (a, b: BacktestResultSummary): int =
      cmp(a.sharpeRatio, b.sharpeRatio))
  of rmMaxDrawdown:
    results.sort(proc (a, b: BacktestResultSummary): int =
      cmp(a.maxDrawdown, b.maxDrawdown))
  of rmWinRate:
    results.sort(proc (a, b: BacktestResultSummary): int =
      cmp(a.winRate, b.winRate))
  of rmProfitFactor:
    results.sort(proc (a, b: BacktestResultSummary): int =
      cmp(a.profitFactor, b.profitFactor))
  of rmNumTrades:
    results.sort(proc (a, b: BacktestResultSummary): int =
      cmp(a.numTrades, b.numTrades))
  
  if not ascending:
    results.reverse()

proc getBest*(batch: BatchResults, metric: RankingMetric): BacktestResultSummary =
  ## Get the best result by specified metric
  if batch.results.len == 0:
    raise newException(ValueError, "No results in batch")
  
  var sorted = batch.results
  sortByMetric(sorted, metric, ascending = false)
  result = sorted[0]

proc getWorst*(batch: BatchResults, metric: RankingMetric): BacktestResultSummary =
  ## Get the worst result by specified metric
  if batch.results.len == 0:
    raise newException(ValueError, "No results in batch")
  
  var sorted = batch.results
  sortByMetric(sorted, metric, ascending = true)
  result = sorted[0]

proc getTopN*(batch: BatchResults, metric: RankingMetric, n: int): seq[BacktestResultSummary] =
  ## Get top N results by specified metric
  var sorted = batch.results
  sortByMetric(sorted, metric, ascending = false)
  
  let count = min(n, sorted.len)
  result = sorted[0 ..< count]

# ============================================================================
# Statistics and Aggregation
# ============================================================================

proc calculateStats*(batch: BatchResults): tuple[
  avgReturn: float64,
  medianReturn: float64,
  stdReturn: float64,
  avgSharpe: float64,
  avgDrawdown: float64,
  avgWinRate: float64
] =
  ## Calculate aggregate statistics across all results
  if batch.results.len == 0:
    return (0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
  
  var returns: seq[float64] = @[]
  var sharpes: seq[float64] = @[]
  var drawdowns: seq[float64] = @[]
  var winRates: seq[float64] = @[]
  
  for r in batch.results:
    returns.add(r.totalReturn)
    if not r.sharpeRatio.isNaN:
      sharpes.add(r.sharpeRatio)
    drawdowns.add(r.maxDrawdown)
    winRates.add(r.winRate)
  
  # Average return
  result.avgReturn = returns.sum() / returns.len.float64
  
  # Median return
  var sortedReturns = returns
  sortedReturns.sort()
  let mid = sortedReturns.len div 2
  if sortedReturns.len mod 2 == 0:
    result.medianReturn = (sortedReturns[mid - 1] + sortedReturns[mid]) / 2.0
  else:
    result.medianReturn = sortedReturns[mid]
  
  # Standard deviation of returns
  let variance = returns.mapIt((it - result.avgReturn) ^ 2).sum() / returns.len.float64
  result.stdReturn = sqrt(variance)
  
  # Average Sharpe
  if sharpes.len > 0:
    result.avgSharpe = sharpes.sum() / sharpes.len.float64
  else:
    result.avgSharpe = NaN
  
  # Average drawdown
  result.avgDrawdown = drawdowns.sum() / drawdowns.len.float64
  
  # Average win rate
  result.avgWinRate = winRates.sum() / winRates.len.float64

# ============================================================================
# Comparison Table Generation
# ============================================================================

proc generateComparisonTable*(batch: BatchResults, sortBy: RankingMetric = rmTotalReturn): ComparisonTable =
  ## Generate a comparison table for all results
  result.headers = @[
    "Rank",
    "Strategy",
    "Symbol",
    "Total Return %",
    "Annual Return %",
    "Sharpe Ratio",
    "Max Drawdown %",
    "Win Rate %",
    "# Trades",
    "Profit Factor"
  ]
  
  result.rows = @[]
  result.rankings = initTable[string, int]()
  
  # Sort by specified metric
  var sorted = batch.results
  sortByMetric(sorted, sortBy, ascending = false)
  
  # Generate rows
  for i, r in sorted:
    let rank = i + 1
    result.rankings[r.strategyName & "_" & r.symbol] = rank
    
    let row = @[
      $rank,
      r.strategyName,
      r.symbol,
      fmt"{r.totalReturn:.2f}",
      fmt"{r.annualizedReturn:.2f}",
      fmt"{r.sharpeRatio:.2f}",
      fmt"{r.maxDrawdown:.2f}",
      fmt"{r.winRate:.2f}",
      $r.numTrades,
      fmt"{r.profitFactor:.2f}"
    ]
    result.rows.add(row)

# ============================================================================
# CSV Export
# ============================================================================

proc toCsvRow*(r: BacktestResultSummary): string =
  ## Convert result to CSV row
  ## Use comma separator, quote strings that might contain commas
  result = [
    r.strategyName,
    r.symbol,
    r.startDate,
    r.endDate,
    fmt"{r.initialCash:.2f}",
    fmt"{r.finalValue:.2f}",
    fmt"{r.totalReturn:.2f}",
    fmt"{r.annualizedReturn:.2f}",
    fmt"{r.sharpeRatio:.2f}",
    fmt"{r.maxDrawdown:.2f}",
    fmt"{r.winRate:.2f}",
    $r.numTrades,
    fmt"{r.avgWin:.2f}",
    fmt"{r.avgLoss:.2f}",
    fmt"{r.profitFactor:.2f}",
    fmt"{r.executionTime:.4f}"
  ].join(",")

proc toCSV*(batch: BatchResults): string =
  ## Convert batch results to CSV string
  var lines: seq[string] = @[]
  
  # Header
  lines.add([
    "Strategy",
    "Symbol",
    "Start Date",
    "End Date",
    "Initial Cash",
    "Final Value",
    "Total Return %",
    "Annual Return %",
    "Sharpe Ratio",
    "Max Drawdown %",
    "Win Rate %",
    "Num Trades",
    "Avg Win",
    "Avg Loss",
    "Profit Factor",
    "Execution Time (s)"
  ].join(","))
  
  # Data rows
  for r in batch.results:
    lines.add(r.toCsvRow())
  
  result = lines.join("\n")

proc exportToCsv*(batch: BatchResults, filename: string) =
  ## Export batch results to CSV file
  writeFile(filename, batch.toCSV())

# ============================================================================
# Console Output
# ============================================================================

proc printSummary*(batch: BatchResults) =
  ## Print batch results summary to console
  echo "\n" & "=".repeat(80)
  echo "BATCH TEST RESULTS"
  echo "=".repeat(80)
  echo fmt"Total Strategies: {batch.totalStrategies}"
  echo fmt"Total Symbols: {batch.totalSymbols}"
  echo fmt"Total Combinations: {batch.totalCombinations}"
  echo fmt"Execution Time: {batch.executionTime:.2f}s"
  echo ""
  
  # Statistics
  let stats = batch.calculateStats()
  echo "Aggregate Statistics:"
  echo fmt"  Average Return: {stats.avgReturn:.2f}%"
  echo fmt"  Median Return: {stats.medianReturn:.2f}%"
  echo fmt"  Std Dev Return: {stats.stdReturn:.2f}%"
  echo fmt"  Average Sharpe: {stats.avgSharpe:.2f}"
  echo fmt"  Average Drawdown: {stats.avgDrawdown:.2f}%"
  echo fmt"  Average Win Rate: {stats.avgWinRate:.2f}%"
  echo ""
  
  # Best performers
  echo "Top Performers by Total Return:"
  let top5 = batch.getTopN(rmTotalReturn, 5)
  for i, r in top5:
    echo fmt"  {i+1}. {r.strategyName} ({r.symbol}): {r.totalReturn:.2f}%"
  
  echo "\n" & "=".repeat(80)

proc printComparisonTable*(table: ComparisonTable, maxRows: int = 20) =
  ## Print comparison table to console
  # Calculate column widths
  var widths: seq[int] = @[]
  for header in table.headers:
    widths.add(header.len)
  
  for row in table.rows:
    for i, cell in row:
      widths[i] = max(widths[i], cell.len)
  
  # Print header
  var headerLine = ""
  for i, header in table.headers:
    headerLine.add(header.alignLeft(widths[i] + 2))
  echo "\n" & headerLine
  echo "-".repeat(headerLine.len)
  
  # Print rows (limit to maxRows)
  let rowCount = min(maxRows, table.rows.len)
  for i in 0 ..< rowCount:
    let row = table.rows[i]
    var line = ""
    for j, cell in row:
      line.add(cell.alignLeft(widths[j] + 2))
    echo line
  
  if table.rows.len > maxRows:
    echo fmt"... ({table.rows.len - maxRows} more rows)"
