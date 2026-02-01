## Scanner Module - Multi-Symbol Analysis
##
## This module provides utilities for scanning multiple symbols with strategies
## and ranking results based on performance metrics.

import std/[tables, algorithm, strformat, sequtils, os, strutils, math]
import core, data, strategy, trader

type
  ScanResult* = object
    ## Result from scanning a single symbol
    symbol*: string
    report*: BacktestReport
    signals*: seq[Signal]
    
  Scanner* = object
    ## Multi-symbol scanner for strategy analysis
    strategy*: Strategy
    symbols*: seq[string]
    initialCash*: float64
    commission*: float64
    verbose*: bool

  RankBy* = enum
    ## Metrics to rank scan results by
    TotalReturn
    AnnualizedReturn
    SharpeRatio
    WinRate
    ProfitFactor
    MaxDrawdown  # Lower is better
    TotalTrades

proc newScanner*(strategy: Strategy, symbols: seq[string],
                 initialCash: float64 = 100000.0,
                 commission: float64 = 0.0,
                 verbose: bool = false): Scanner =
  ## Create a new multi-symbol scanner
  ## 
  ## Args:
  ##   strategy: Trading strategy to apply to all symbols
  ##   symbols: List of symbols to scan
  ##   initialCash: Initial capital for each backtest
  ##   commission: Commission rate (e.g., 0.001 for 0.1%)
  ##   verbose: Print progress messages
  ## 
  ## Returns:
  ##   Scanner instance ready to run
  result = Scanner(
    strategy: strategy,
    symbols: symbols,
    initialCash: initialCash,
    commission: commission,
    verbose: verbose
  )

proc scan*(scanner: Scanner, dataMap: Table[string, seq[OHLCV]]): seq[ScanResult] =
  ## Scan multiple symbols with the strategy
  ## 
  ## Args:
  ##   dataMap: Table mapping symbols to their OHLCV data
  ## 
  ## Returns:
  ##   Sequence of ScanResult for each symbol
  result = @[]
  
  for symbol in scanner.symbols:
    if not dataMap.hasKey(symbol):
      if scanner.verbose:
        echo &"Warning: No data for symbol {symbol}, skipping"
      continue
    
    let data = dataMap[symbol]
    
    if data.len == 0:
      if scanner.verbose:
        echo &"Warning: Empty data for symbol {symbol}, skipping"
      continue
    
    if scanner.verbose:
      echo &"Scanning {symbol}..."
    
    # Run backtest for this symbol
    let report = quickBacktest(
      symbol = symbol,
      strategy = scanner.strategy,
      data = data,
      initialCash = scanner.initialCash,
      commission = scanner.commission,
      verbose = false
    )
    
    # Get signals using streaming mode
    scanner.strategy.reset()  # Reset strategy state for new symbol
    var signals: seq[Signal] = @[]
    for bar in data:
      signals.add(scanner.strategy.onBar(bar))
    
    result.add(ScanResult(
      symbol: symbol,
      report: report,
      signals: signals
    ))

proc scanFromCSV*(scanner: Scanner, csvDir: string): seq[ScanResult] =
  ## Scan symbols by loading CSV files from a directory
  ## 
  ## Expected file naming: {symbol}.csv
  ## 
  ## Args:
  ##   csvDir: Directory containing CSV files
  ## 
  ## Returns:
  ##   Sequence of ScanResult for each symbol
  var dataMap = initTable[string, seq[OHLCV]]()
  
  for symbol in scanner.symbols:
    let csvPath = csvDir / &"{symbol}.csv"
    
    if not fileExists(csvPath):
      if scanner.verbose:
        echo &"Warning: CSV file not found for {symbol}: {csvPath}"
      continue
    
    try:
      let data = readCSV(csvPath)
      dataMap[symbol] = data
      
      if scanner.verbose:
        echo &"Loaded {data.len} bars for {symbol}"
    except:
      if scanner.verbose:
        echo &"Error reading CSV for {symbol}: {getCurrentExceptionMsg()}"
      continue
  
  result = scanner.scan(dataMap)

proc rankBy*(results: var seq[ScanResult], metric: RankBy, ascending: bool = false) =
  ## Rank scan results by a performance metric
  ## 
  ## Args:
  ##   results: Scan results to rank (modified in place)
  ##   metric: Metric to rank by
  ##   ascending: If true, rank ascending (low to high), else descending
  proc compareResults(a, b: ScanResult): int =
    var aVal, bVal: float64
    
    case metric:
    of TotalReturn:
      aVal = a.report.totalReturn
      bVal = b.report.totalReturn
    of AnnualizedReturn:
      aVal = a.report.annualizedReturn
      bVal = b.report.annualizedReturn
    of SharpeRatio:
      aVal = a.report.sharpeRatio
      bVal = b.report.sharpeRatio
    of WinRate:
      aVal = a.report.winRate
      bVal = b.report.winRate
    of ProfitFactor:
      aVal = a.report.profitFactor
      bVal = b.report.profitFactor
    of MaxDrawdown:
      # For drawdown, lower is better, so invert comparison
      aVal = -a.report.maxDrawdown
      bVal = -b.report.maxDrawdown
    of TotalTrades:
      aVal = float64(a.report.totalTrades)
      bVal = float64(b.report.totalTrades)
    
    if ascending:
      if aVal < bVal: -1
      elif aVal > bVal: 1
      else: 0
    else:
      if aVal > bVal: -1
      elif aVal < bVal: 1
      else: 0
  
  results.sort(compareResults)

proc topN*(results: seq[ScanResult], n: int): seq[ScanResult] =
  ## Get top N results (assumes already ranked)
  ## 
  ## Args:
  ##   results: Ranked scan results
  ##   n: Number of top results to return
  ## 
  ## Returns:
  ##   Top N results
  let count = min(n, results.len)
  result = results[0..<count]

proc filter*(results: seq[ScanResult],
             minReturn: float64 = NegInf,
             minSharpe: float64 = NegInf,
             minWinRate: float64 = 0.0,
             minTrades: int = 0,
             maxDrawdown: float64 = Inf): seq[ScanResult] =
  ## Filter scan results by criteria
  ## 
  ## Args:
  ##   minReturn: Minimum total return percentage
  ##   minSharpe: Minimum Sharpe ratio
  ##   minWinRate: Minimum win rate percentage
  ##   minTrades: Minimum number of trades
  ##   maxDrawdown: Maximum drawdown percentage
  ## 
  ## Returns:
  ##   Filtered results
  result = results.filter(proc(r: ScanResult): bool =
    r.report.totalReturn >= minReturn and
    r.report.sharpeRatio >= minSharpe and
    r.report.winRate >= minWinRate and
    r.report.totalTrades >= minTrades and
    r.report.maxDrawdown <= maxDrawdown
  )

proc summary*(results: seq[ScanResult]): string =
  ## Generate a summary table of scan results
  ## 
  ## Returns:
  ##   Formatted string with results table
  result = ""
  result &= strutils.repeat('=', 110) & "\n"
  result &= "SCAN RESULTS SUMMARY\n"
  result &= strutils.repeat('=', 110) & "\n"
  result &= "Symbol      | Return     | Annual     | Sharpe   | Win%    | PF     | DD%     | Trades\n"
  result &= strutils.repeat('-', 110) & "\n"
  
  for r in results:
    result &= &"{r.symbol:<10} | " &
              &"{r.report.totalReturn:>9.2f}% | " &
              &"{r.report.annualizedReturn:>9.2f}% | " &
              &"{r.report.sharpeRatio:>8.2f} | " &
              &"{r.report.winRate:>6.2f}% | " &
              &"{r.report.profitFactor:>6.2f} | " &
              &"{r.report.maxDrawdown:>6.2f}% | " &
              &"{r.report.totalTrades:>7}\n"
  
  result &= strutils.repeat('=', 110) & "\n"
  result &= &"Total symbols scanned: {results.len}\n"
  
  if results.len > 0:
    let avgReturn = results.mapIt(it.report.totalReturn).sum() / float64(results.len)
    let avgSharpe = results.mapIt(it.report.sharpeRatio).sum() / float64(results.len)
    let avgWinRate = results.mapIt(it.report.winRate).sum() / float64(results.len)
    
    result &= &"Average Return: {avgReturn:.2f}%\n"
    result &= &"Average Sharpe: {avgSharpe:.2f}\n"
    result &= &"Average Win Rate: {avgWinRate:.2f}%\n"

proc `$`*(scanResult: ScanResult): string =
  ## String representation of a scan result
  &"{scanResult.symbol}: {scanResult.report.formatCompact()}"
