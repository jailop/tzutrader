## Reporter for Batch Test Results
##
## This module generates reports from batch test results in various formats:
## - HTML comparison reports with charts
## - CSV exports for spreadsheet analysis
## - JSON data for programmatic access

import std/[times, strformat, os, json, strutils, algorithm]
import ./batch_runner, ./schema

type
  ReportFormat* = enum
    ## Output format for reports
    rfHTML = "html"
    rfCSV = "csv"
    rfJSON = "json"
  
  ReportError* = object of CatchableError
    ## Error during report generation

# ============================================================================
# CSV Report Generation
# ============================================================================

proc generateCSV*(results: seq[StrategyResult]): string =
  ## Generate CSV report from batch test results
  ## 
  ## Args:
  ##   results: Strategy results to report
  ## 
  ## Returns:
  ##   CSV-formatted string
  
  result = ""
  
  # Header
  result &= "Strategy,Symbol,Initial Cash,Final Value,Total Return %,"
  result &= "Annualized Return %,Sharpe Ratio,Max Drawdown %,"
  result &= "Win Rate %,Total Trades,Winning Trades,Losing Trades,"
  result &= "Avg Win,Avg Loss,Profit Factor,Best Trade,Worst Trade,"
  result &= "Total Commission,Strategy File\n"
  
  # Data rows
  for sr in results:
    let r = sr.report
    result &= &"{sr.strategyName},{sr.symbol},{r.initialCash:.2f},{r.finalValue:.2f},"
    result &= &"{r.totalReturn:.2f},{r.annualizedReturn:.2f},{r.sharpeRatio:.4f},"
    result &= &"{r.maxDrawdown:.2f},{r.winRate:.2f},{r.totalTrades},"
    result &= &"{r.winningTrades},{r.losingTrades},{r.avgWin:.2f},"
    result &= &"{r.avgLoss:.2f},{r.profitFactor:.4f},{r.bestTrade:.2f},"
    result &= &"{r.worstTrade:.2f},{r.totalCommission:.2f},{sr.strategyFile}\n"

proc saveCSV*(results: seq[StrategyResult], filename: string) =
  ## Save CSV report to file
  ## 
  ## Args:
  ##   results: Strategy results to report
  ##   filename: Output file path
  
  let csv = generateCSV(results)
  
  # Create directory if needed
  let dir = parentDir(filename)
  if dir != "" and not dirExists(dir):
    createDir(dir)
  
  writeFile(filename, csv)

# ============================================================================
# JSON Report Generation
# ============================================================================

proc toJsonNode(sr: StrategyResult): JsonNode =
  ## Convert StrategyResult to JSON
  result = %* {
    "strategy_name": sr.strategyName,
    "symbol": sr.symbol,
    "strategy_file": sr.strategyFile,
    "results": {
      "start_time": sr.report.startTime,
      "end_time": sr.report.endTime,
      "initial_cash": sr.report.initialCash,
      "final_value": sr.report.finalValue,
      "total_return_pct": sr.report.totalReturn,
      "annualized_return_pct": sr.report.annualizedReturn,
      "sharpe_ratio": sr.report.sharpeRatio,
      "max_drawdown_pct": sr.report.maxDrawdown,
      "max_drawdown_duration_sec": sr.report.maxDrawdownDuration,
      "win_rate_pct": sr.report.winRate,
      "total_trades": sr.report.totalTrades,
      "winning_trades": sr.report.winningTrades,
      "losing_trades": sr.report.losingTrades,
      "avg_win": sr.report.avgWin,
      "avg_loss": sr.report.avgLoss,
      "profit_factor": sr.report.profitFactor,
      "best_trade": sr.report.bestTrade,
      "worst_trade": sr.report.worstTrade,
      "avg_trade_return": sr.report.avgTradeReturn,
      "total_commission": sr.report.totalCommission
    }
  }

proc generateJSON*(results: seq[StrategyResult]): string =
  ## Generate JSON report from batch test results
  ## 
  ## Args:
  ##   results: Strategy results to report
  ## 
  ## Returns:
  ##   JSON-formatted string
  
  var jsonResults = newJArray()
  for sr in results:
    jsonResults.add(toJsonNode(sr))
  
  let reportJson = %* {
    "batch_test_results": jsonResults,
    "total_runs": results.len,
    "generated_at": now().format("yyyy-MM-dd HH:mm:ss")
  }
  
  result = reportJson.pretty()

proc saveJSON*(results: seq[StrategyResult], filename: string) =
  ## Save JSON report to file
  ## 
  ## Args:
  ##   results: Strategy results to report
  ##   filename: Output file path
  
  let jsonStr = generateJSON(results)
  
  # Create directory if needed
  let dir = parentDir(filename)
  if dir != "" and not dirExists(dir):
    createDir(dir)
  
  writeFile(filename, jsonStr)

# ============================================================================
# HTML Report Generation
# ============================================================================

proc generateHTML*(results: seq[StrategyResult], batchConfig: BatchTestYAML): string =
  ## Generate HTML comparison report from batch test results
  ## 
  ## Args:
  ##   results: Strategy results to report
  ##   batchConfig: Original batch configuration
  ## 
  ## Returns:
  ##   HTML-formatted string
  
  result = """
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>TzuTrader Batch Test Results</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
      margin: 0;
      padding: 20px;
      background: #f5f5f5;
    }
    .container {
      max-width: 1400px;
      margin: 0 auto;
      background: white;
      padding: 30px;
      border-radius: 8px;
      box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }
    h1 {
      color: #333;
      border-bottom: 3px solid #4CAF50;
      padding-bottom: 10px;
    }
    h2 {
      color: #555;
      margin-top: 30px;
    }
    .config-section {
      background: #f9f9f9;
      padding: 15px;
      border-radius: 5px;
      margin: 20px 0;
    }
    .config-item {
      margin: 5px 0;
    }
    .config-label {
      font-weight: bold;
      color: #666;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      margin: 20px 0;
      font-size: 14px;
    }
    th {
      background: #4CAF50;
      color: white;
      padding: 12px 8px;
      text-align: left;
      font-weight: 600;
    }
    td {
      padding: 10px 8px;
      border-bottom: 1px solid #ddd;
    }
    tr:hover {
      background: #f5f5f5;
    }
    .positive {
      color: #4CAF50;
      font-weight: 600;
    }
    .negative {
      color: #f44336;
      font-weight: 600;
    }
    .neutral {
      color: #757575;
    }
    .summary-cards {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
      gap: 15px;
      margin: 20px 0;
    }
    .card {
      background: #f9f9f9;
      padding: 15px;
      border-radius: 5px;
      border-left: 4px solid #4CAF50;
    }
    .card-value {
      font-size: 24px;
      font-weight: bold;
      color: #333;
    }
    .card-label {
      font-size: 12px;
      color: #666;
      text-transform: uppercase;
    }
    .footer {
      margin-top: 40px;
      padding-top: 20px;
      border-top: 1px solid #ddd;
      color: #666;
      font-size: 12px;
      text-align: center;
    }
    .sort-icon {
      cursor: pointer;
      user-select: none;
    }
  </style>
</head>
<body>
  <div class="container">
    <h1>TzuTrader Batch Test Results</h1>
"""
  
  # Configuration section
  result &= """
    <div class="config-section">
      <h2>Test Configuration</h2>
"""
  
  result &= &"      <div class=\"config-item\"><span class=\"config-label\">Data Source:</span> {batchConfig.data.source}</div>\n"
  result &= &"      <div class=\"config-item\"><span class=\"config-label\">Symbols:</span> {batchConfig.data.symbols.join(\", \")}</div>\n"
  result &= &"      <div class=\"config-item\"><span class=\"config-label\">Date Range:</span> {batchConfig.data.startDate} to {batchConfig.data.endDate}</div>\n"
  result &= &"      <div class=\"config-item\"><span class=\"config-label\">Initial Cash:</span> ${batchConfig.portfolio.initialCash:.2f}</div>\n"
  result &= &"      <div class=\"config-item\"><span class=\"config-label\">Commission:</span> {batchConfig.portfolio.commission * 100:.2f}%</div>\n"
  result &= &"      <div class=\"config-item\"><span class=\"config-label\">Strategies Tested:</span> {batchConfig.strategies.len}</div>\n"
  result &= &"      <div class=\"config-item\"><span class=\"config-label\">Total Runs:</span> {results.len}</div>\n"
  
  result &= """
    </div>
"""
  
  # Summary cards
  if results.len > 0:
    var totalReturn = 0.0
    var totalSharpe = 0.0
    var totalTrades = 0
    var profitable = 0
    
    for sr in results:
      totalReturn += sr.report.totalReturn
      totalSharpe += sr.report.sharpeRatio
      totalTrades += sr.report.totalTrades
      if sr.report.totalReturn > 0:
        profitable += 1
    
    let avgReturn = totalReturn / float(results.len)
    let avgSharpe = totalSharpe / float(results.len)
    let profitableRate = (float(profitable) / float(results.len)) * 100.0
    
    result &= """
    <h2>Summary Statistics</h2>
    <div class="summary-cards">
"""
    
    result &= &"""
      <div class="card">
        <div class="card-label">Average Return</div>
        <div class="card-value">{avgReturn:.2f}%</div>
      </div>
      <div class="card">
        <div class="card-label">Average Sharpe</div>
        <div class="card-value">{avgSharpe:.2f}</div>
      </div>
      <div class="card">
        <div class="card-label">Total Trades</div>
        <div class="card-value">{totalTrades}</div>
      </div>
      <div class="card">
        <div class="card-label">Profitable Rate</div>
        <div class="card-value">{profitableRate:.1f}%</div>
      </div>
"""
    
    result &= """
    </div>
"""
  
  # Results table
  result &= """
    <h2>Detailed Results</h2>
    <table>
      <thead>
        <tr>
          <th>Strategy</th>
          <th>Symbol</th>
          <th>Return %</th>
          <th>Sharpe</th>
          <th>Max DD %</th>
          <th>Win Rate %</th>
          <th>Trades</th>
          <th>Profit Factor</th>
          <th>Avg Win</th>
          <th>Avg Loss</th>
        </tr>
      </thead>
      <tbody>
"""
  
  # Sort results by total return (descending)
  var sortedResults = results
  sortedResults.sort(proc(a, b: StrategyResult): int =
    if a.report.totalReturn > b.report.totalReturn: -1
    elif a.report.totalReturn < b.report.totalReturn: 1
    else: 0
  )
  
  for sr in sortedResults:
    let r = sr.report
    let returnClass = if r.totalReturn > 0: "positive" elif r.totalReturn < 0: "negative" else: "neutral"
    let sharpeClass = if r.sharpeRatio > 1.0: "positive" elif r.sharpeRatio < 0: "negative" else: "neutral"
    
    result &= "        <tr>\n"
    result &= &"          <td>{sr.strategyName}</td>\n"
    result &= &"          <td>{sr.symbol}</td>\n"
    result &= &"          <td class=\"{returnClass}\">{r.totalReturn:.2f}%</td>\n"
    result &= &"          <td class=\"{sharpeClass}\">{r.sharpeRatio:.2f}</td>\n"
    result &= &"          <td>{r.maxDrawdown:.2f}%</td>\n"
    result &= &"          <td>{r.winRate:.2f}%</td>\n"
    result &= &"          <td>{r.totalTrades}</td>\n"
    result &= &"          <td>{r.profitFactor:.2f}</td>\n"
    result &= &"          <td>${r.avgWin:.2f}</td>\n"
    result &= &"          <td>${r.avgLoss:.2f}</td>\n"
    result &= "        </tr>\n"
  
  result &= """
      </tbody>
    </table>
"""
  
  # Footer
  result &= &"""
    <div class="footer">
      Generated by TzuTrader on {now().format("yyyy-MM-dd HH:mm:ss")}
    </div>
  </div>
</body>
</html>
"""

proc saveHTML*(results: seq[StrategyResult], batchConfig: BatchTestYAML, filename: string) =
  ## Save HTML report to file
  ## 
  ## Args:
  ##   results: Strategy results to report
  ##   batchConfig: Original batch configuration
  ##   filename: Output file path
  
  let html = generateHTML(results, batchConfig)
  
  # Create directory if needed
  let dir = parentDir(filename)
  if dir != "" and not dirExists(dir):
    createDir(dir)
  
  writeFile(filename, html)

# ============================================================================
# Main Report Generation
# ============================================================================

proc generateReport*(
  batchResult: BatchTestResult,
  format: ReportFormat = rfHTML
): string =
  ## Generate a report from batch test results
  ## 
  ## Args:
  ##   batchResult: Batch test result
  ##   format: Output format (HTML, CSV, or JSON)
  ## 
  ## Returns:
  ##   Formatted report string
  
  case format
  of rfHTML:
    return generateHTML(batchResult.results, batchResult.batchConfig)
  of rfCSV:
    return generateCSV(batchResult.results)
  of rfJSON:
    return generateJSON(batchResult.results)

proc saveReport*(
  batchResult: BatchTestResult,
  filename: string,
  format: ReportFormat = rfHTML
) =
  ## Save a report to file
  ## 
  ## Args:
  ##   batchResult: Batch test result
  ##   filename: Output file path
  ##   format: Output format (HTML, CSV, or JSON)
  
  case format
  of rfHTML:
    saveHTML(batchResult.results, batchResult.batchConfig, filename)
  of rfCSV:
    saveCSV(batchResult.results, filename)
  of rfJSON:
    saveJSON(batchResult.results, filename)
