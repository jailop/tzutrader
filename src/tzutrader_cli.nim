## TzuTrader CLI - Command-line Backtesting Tool
##
## Usage:
##   tzutrader backtest <csv_file> [options]
##   tzutrader scan <csv_dir> <symbols> [options]
##
## Examples:
##   tzutrader backtest data/AAPL.csv --strategy=rsi --initial-cash=10000
##   tzutrader scan data/ AAPL,MSFT,GOOG --strategy=macd --export=results.json

import std/[parseopt, strutils, strformat, os, tables, json]

include tzutrader/core
include tzutrader/data
include tzutrader/indicators
include tzutrader/strategy
include tzutrader/portfolio
include tzutrader/trader
include tzutrader/scanner
include tzutrader/exports

const
  Version = "0.7.0"
  Usage = """
TzuTrader CLI v$1

USAGE:
  tzutrader backtest <csv_file> [options]
  tzutrader scan <csv_dir> <symbols> [options]
  tzutrader --help
  tzutrader --version

COMMANDS:
  backtest    Run backtest on a single symbol
  scan        Scan multiple symbols and rank results

BACKTEST OPTIONS:
  --strategy=<name>       Strategy to use: rsi, macd, crossover, bollinger (default: rsi)
  --initial-cash=<amount> Initial capital (default: 100000)
  --commission=<rate>     Commission rate, e.g., 0.001 for 0.1% (default: 0.0)
  --export=<file>         Export results to JSON or CSV file
  --verbose               Show detailed progress

RSI STRATEGY OPTIONS:
  --rsi-period=<n>        RSI period (default: 14)
  --rsi-oversold=<n>      Oversold threshold (default: 30)
  --rsi-overbought=<n>    Overbought threshold (default: 70)

MACD STRATEGY OPTIONS:
  --macd-fast=<n>         Fast period (default: 12)
  --macd-slow=<n>         Slow period (default: 26)
  --macd-signal=<n>       Signal period (default: 9)

CROSSOVER STRATEGY OPTIONS:
  --ma-fast=<n>           Fast MA period (default: 10)
  --ma-slow=<n>           Slow MA period (default: 30)

BOLLINGER STRATEGY OPTIONS:
  --bb-period=<n>         Bollinger period (default: 20)
  --bb-stddev=<n>         Standard deviations (default: 2.0)

SCAN OPTIONS:
  --rank-by=<metric>      Rank by: return, sharpe, winrate, profitfactor (default: return)
  --min-return=<pct>      Filter: minimum return percentage
  --min-sharpe=<ratio>    Filter: minimum Sharpe ratio
  --min-winrate=<pct>     Filter: minimum win rate percentage
  --max-drawdown=<pct>    Filter: maximum drawdown percentage
  --top=<n>               Show only top N results

EXAMPLES:
  # Simple RSI backtest
  tzutrader backtest data/AAPL.csv

  # MACD backtest with custom parameters
  tzutrader backtest data/AAPL.csv --strategy=macd --initial-cash=50000

  # Scan multiple symbols
  tzutrader scan data/ AAPL,MSFT,GOOG --strategy=crossover

  # Scan and export top 10 by Sharpe ratio
  tzutrader scan data/ AAPL,MSFT,GOOG --rank-by=sharpe --top=10 --export=results.csv
""" % [Version]

type
  CliCommand = enum
    cmdNone
    cmdBacktest
    cmdScan
    cmdHelp
    cmdVersion

  CliConfig = object
    command: CliCommand
    csvFile: string
    csvDir: string
    symbols: seq[string]
    strategyName: string
    initialCash: float64
    commission: float64
    exportFile: string
    verbose: bool
    # RSI params
    rsiPeriod: int
    rsiOversold: float64
    rsiOverbought: float64
    # MACD params
    macdFast: int
    macdSlow: int
    macdSignal: int
    # Crossover params
    maFast: int
    maSlow: int
    # Bollinger params
    bbPeriod: int
    bbStddev: float64
    # Scan params
    rankBy: string
    minReturn: float64
    minSharpe: float64
    minWinRate: float64
    maxDrawdown: float64
    topN: int

proc defaultConfig(): CliConfig =
  CliConfig(
    command: cmdNone,
    strategyName: "rsi",
    initialCash: 100000.0,
    commission: 0.0,
    verbose: false,
    rsiPeriod: 14,
    rsiOversold: 30.0,
    rsiOverbought: 70.0,
    macdFast: 12,
    macdSlow: 26,
    macdSignal: 9,
    maFast: 10,
    maSlow: 30,
    bbPeriod: 20,
    bbStddev: 2.0,
    rankBy: "return",
    minReturn: NegInf,
    minSharpe: NegInf,
    minWinRate: 0.0,
    maxDrawdown: Inf,
    topN: 0  # 0 means show all
  )

proc parseArgs(): CliConfig =
  result = defaultConfig()
  
  var p = initOptParser()
  var positionalArgs: seq[string] = @[]
  
  while true:
    p.next()
    case p.kind:
    of cmdEnd: break
    of cmdShortOption, cmdLongOption:
      case p.key:
      of "help", "h":
        result.command = cmdHelp
      of "version", "v":
        result.command = cmdVersion
      of "strategy":
        result.strategyName = p.val
      of "initial-cash":
        result.initialCash = parseFloat(p.val)
      of "commission":
        result.commission = parseFloat(p.val)
      of "export":
        result.exportFile = p.val
      of "verbose":
        result.verbose = true
      of "rsi-period":
        result.rsiPeriod = parseInt(p.val)
      of "rsi-oversold":
        result.rsiOversold = parseFloat(p.val)
      of "rsi-overbought":
        result.rsiOverbought = parseFloat(p.val)
      of "macd-fast":
        result.macdFast = parseInt(p.val)
      of "macd-slow":
        result.macdSlow = parseInt(p.val)
      of "macd-signal":
        result.macdSignal = parseInt(p.val)
      of "ma-fast":
        result.maFast = parseInt(p.val)
      of "ma-slow":
        result.maSlow = parseInt(p.val)
      of "bb-period":
        result.bbPeriod = parseInt(p.val)
      of "bb-stddev":
        result.bbStddev = parseFloat(p.val)
      of "rank-by":
        result.rankBy = p.val
      of "min-return":
        result.minReturn = parseFloat(p.val)
      of "min-sharpe":
        result.minSharpe = parseFloat(p.val)
      of "min-winrate":
        result.minWinRate = parseFloat(p.val)
      of "max-drawdown":
        result.maxDrawdown = parseFloat(p.val)
      of "top":
        result.topN = parseInt(p.val)
      else:
        echo &"Unknown option: --{p.key}"
        quit(1)
    of cmdArgument:
      positionalArgs.add(p.key)
  
  # Parse command and positional arguments
  if positionalArgs.len > 0:
    case positionalArgs[0]:
    of "backtest":
      result.command = cmdBacktest
      if positionalArgs.len < 2:
        echo "Error: backtest requires a CSV file"
        quit(1)
      result.csvFile = positionalArgs[1]
    of "scan":
      result.command = cmdScan
      if positionalArgs.len < 3:
        echo "Error: scan requires a directory and symbol list"
        quit(1)
      result.csvDir = positionalArgs[1]
      result.symbols = positionalArgs[2].split(',')
    of "help":
      result.command = cmdHelp
    of "version":
      result.command = cmdVersion
    else:
      echo &"Unknown command: {positionalArgs[0]}"
      echo "Try 'tzutrader --help' for usage information"
      quit(1)

proc createStrategy(config: CliConfig): Strategy =
  case config.strategyName:
  of "rsi":
    result = newRSIStrategy(config.rsiPeriod, config.rsiOversold, config.rsiOverbought)
  of "macd":
    result = newMACDStrategy(config.macdFast, config.macdSlow, config.macdSignal)
  of "crossover":
    result = newCrossoverStrategy(config.maFast, config.maSlow)
  of "bollinger":
    result = newBollingerStrategy(config.bbPeriod, config.bbStddev)
  else:
    echo &"Unknown strategy: {config.strategyName}"
    echo "Available strategies: rsi, macd, crossover, bollinger"
    quit(1)

proc runBacktest(config: CliConfig) =
  if config.verbose:
    echo &"Running backtest on {config.csvFile}"
    echo &"Strategy: {config.strategyName}"
    echo &"Initial cash: ${config.initialCash}"
    echo &"Commission: {config.commission * 100}%"
    echo ""
  
  # Check if file exists
  if not fileExists(config.csvFile):
    echo &"Error: File not found: {config.csvFile}"
    quit(1)
  
  # Create strategy
  let strategy = createStrategy(config)
  
  # Run backtest
  let symbol = config.csvFile.splitFile().name  # Extract filename without extension
  
  try:
    let report = quickBacktestCSV(
      symbol,
      strategy,
      config.csvFile,
      config.initialCash,
      config.commission,
      config.verbose
    )
    
    # Display results
    echo report
    
    # Export if requested
    if config.exportFile != "":
      if config.exportFile.endsWith(".json"):
        report.exportJson(config.exportFile)
        echo &"\nResults exported to {config.exportFile}"
      elif config.exportFile.endsWith(".csv"):
        report.exportCsv(config.exportFile)
        echo &"\nResults exported to {config.exportFile}"
      else:
        echo "Warning: Unknown export format (use .json or .csv extension)"
  
  except:
    echo &"Error running backtest: {getCurrentExceptionMsg()}"
    quit(1)

proc runScan(config: CliConfig) =
  if config.verbose:
    echo &"Scanning {config.symbols.len} symbols from {config.csvDir}"
    echo &"Strategy: {config.strategyName}"
    echo ""
  
  # Check if directory exists
  if not dirExists(config.csvDir):
    echo &"Error: Directory not found: {config.csvDir}"
    quit(1)
  
  # Create strategy
  let strategy = createStrategy(config)
  
  # Create scanner
  let scanner = newScanner(
    strategy,
    config.symbols,
    config.initialCash,
    config.commission,
    config.verbose
  )
  
  # Run scan
  var results = scanner.scanFromCSV(config.csvDir)
  
  if results.len == 0:
    echo "No results - check that CSV files exist for the specified symbols"
    quit(0)
  
  # Apply filters
  results = results.filter(
    minReturn = config.minReturn,
    minSharpe = config.minSharpe,
    minWinRate = config.minWinRate,
    maxDrawdown = config.maxDrawdown
  )
  
  if results.len == 0:
    echo "No results after filtering"
    quit(0)
  
  # Rank results
  let rankMetric = case config.rankBy:
    of "return": TotalReturn
    of "sharpe": SharpeRatio
    of "winrate": WinRate
    of "profitfactor": ProfitFactor
    else:
      echo &"Unknown ranking metric: {config.rankBy}"
      TotalReturn
  
  results.rankBy(rankMetric)
  
  # Get top N if requested
  if config.topN > 0:
    results = results.topN(config.topN)
  
  # Display summary
  echo results.summary()
  
  # Export if requested
  if config.exportFile != "":
    if config.exportFile.endsWith(".json"):
      results.exportJson(config.exportFile)
      echo &"\nResults exported to {config.exportFile}"
    elif config.exportFile.endsWith(".csv"):
      results.exportCsv(config.exportFile)
      echo &"\nResults exported to {config.exportFile}"
    else:
      echo "Warning: Unknown export format (use .json or .csv extension)"

proc main() =
  let config = parseArgs()
  
  case config.command:
  of cmdHelp, cmdNone:
    echo Usage
  of cmdVersion:
    echo &"TzuTrader CLI v{Version}"
  of cmdBacktest:
    runBacktest(config)
  of cmdScan:
    runScan(config)

when isMainModule:
  main()
