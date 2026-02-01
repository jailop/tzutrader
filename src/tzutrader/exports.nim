## Export Module - Report Export to JSON/CSV
##
## This module provides utilities for exporting backtest reports
## and scan results to various formats.

import std/[json, strformat]
import trader, scanner

proc toJson*(report: BacktestReport): JsonNode =
  ## Convert BacktestReport to JSON
  ## 
  ## Returns:
  ##   JsonNode representation of the report
  result = %* {
    "symbol": report.symbol,
    "start_time": report.startTime,
    "end_time": report.endTime,
    "initial_cash": report.initialCash,
    "final_value": report.finalValue,
    "total_return": report.totalReturn,
    "annualized_return": report.annualizedReturn,
    "sharpe_ratio": report.sharpeRatio,
    "max_drawdown": report.maxDrawdown,
    "max_drawdown_duration": report.maxDrawdownDuration,
    "win_rate": report.winRate,
    "total_trades": report.totalTrades,
    "winning_trades": report.winningTrades,
    "losing_trades": report.losingTrades,
    "avg_win": report.avgWin,
    "avg_loss": report.avgLoss,
    "profit_factor": report.profitFactor,
    "best_trade": report.bestTrade,
    "worst_trade": report.worstTrade,
    "avg_trade_return": report.avgTradeReturn,
    "total_commission": report.totalCommission
  }

proc toJson*(scanResult: ScanResult): JsonNode =
  ## Convert ScanResult to JSON
  ## 
  ## Returns:
  ##   JsonNode representation of the scan result
  %* {
    "symbol": scanResult.symbol,
    "report": scanResult.report.toJson(),
    "signals_count": scanResult.signals.len
  }

proc toJson*(results: seq[ScanResult]): JsonNode =
  ## Convert sequence of ScanResults to JSON array
  ## 
  ## Returns:
  ##   JsonNode array of scan results
  result = newJArray()
  for r in results:
    result.add(r.toJson())

proc exportJson*(report: BacktestReport, filename: string) =
  ## Export BacktestReport to JSON file
  ## 
  ## Args:
  ##   report: Report to export
  ##   filename: Output file path
  let jsonNode = report.toJson()
  writeFile(filename, jsonNode.pretty())

proc exportJson*(results: seq[ScanResult], filename: string) =
  ## Export scan results to JSON file
  ## 
  ## Args:
  ##   results: Scan results to export
  ##   filename: Output file path
  let jsonNode = results.toJson()
  writeFile(filename, jsonNode.pretty())

proc toCsvHeader*(): string =
  ## Get CSV header for BacktestReport
  ## 
  ## Returns:
  ##   CSV header string
  "symbol,start_time,end_time,initial_cash,final_value," &
  "total_return,annualized_return,sharpe_ratio," &
  "max_drawdown,max_drawdown_duration,win_rate," &
  "total_trades,winning_trades,losing_trades," &
  "avg_win,avg_loss,profit_factor," &
  "best_trade,worst_trade,avg_trade_return,total_commission"

proc toCsvRow*(report: BacktestReport): string =
  ## Convert BacktestReport to CSV row
  ## 
  ## Returns:
  ##   CSV row string
  &"{report.symbol}," &
  &"{report.startTime}," &
  &"{report.endTime}," &
  &"{report.initialCash}," &
  &"{report.finalValue}," &
  &"{report.totalReturn}," &
  &"{report.annualizedReturn}," &
  &"{report.sharpeRatio}," &
  &"{report.maxDrawdown}," &
  &"{report.maxDrawdownDuration}," &
  &"{report.winRate}," &
  &"{report.totalTrades}," &
  &"{report.winningTrades}," &
  &"{report.losingTrades}," &
  &"{report.avgWin}," &
  &"{report.avgLoss}," &
  &"{report.profitFactor}," &
  &"{report.bestTrade}," &
  &"{report.worstTrade}," &
  &"{report.avgTradeReturn}," &
  &"{report.totalCommission}"

proc exportCsv*(report: BacktestReport, filename: string) =
  ## Export BacktestReport to CSV file
  ## 
  ## Args:
  ##   report: Report to export
  ##   filename: Output file path
  var csv = toCsvHeader() & "\n"
  csv &= report.toCsvRow() & "\n"
  writeFile(filename, csv)

proc exportCsv*(results: seq[ScanResult], filename: string) =
  ## Export scan results to CSV file
  ## 
  ## Args:
  ##   results: Scan results to export
  ##   filename: Output file path
  var csv = toCsvHeader() & "\n"
  
  for r in results:
    csv &= r.report.toCsvRow() & "\n"
  
  writeFile(filename, csv)

proc toJson*(log: TradeLog): JsonNode =
  ## Convert TradeLog to JSON
  ## 
  ## Returns:
  ##   JsonNode representation of the trade log
  %* {
    "timestamp": log.timestamp,
    "symbol": log.symbol,
    "action": $log.action,
    "quantity": log.quantity,
    "price": log.price,
    "cash": log.cash,
    "equity": log.equity
  }

proc exportTradeLog*(logs: seq[TradeLog], filename: string) =
  ## Export trade logs to JSON file
  ## 
  ## Args:
  ##   logs: Trade logs to export
  ##   filename: Output file path
  var jsonArray = newJArray()
  for log in logs:
    jsonArray.add(log.toJson())
  
  writeFile(filename, jsonArray.pretty())

proc exportTradeLogCsv*(logs: seq[TradeLog], filename: string) =
  ## Export trade logs to CSV file
  ## 
  ## Args:
  ##   logs: Trade logs to export
  ##   filename: Output file path
  var csv = "timestamp,symbol,action,quantity,price,cash,equity\n"
  
  for log in logs:
    csv &= &"{log.timestamp}," &
           &"{log.symbol}," &
           &"{log.action}," &
           &"{log.quantity}," &
           &"{log.price}," &
           &"{log.cash}," &
           &"{log.equity}\n"
  
  writeFile(filename, csv)
