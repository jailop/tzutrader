## Risk Management Example
##
## This example demonstrates how to use stop-loss and take-profit features
## in backtesting. It shows various risk management strategies including:
##
## - Fixed percentage stops and take-profits
## - Trailing stops
## - Risk/reward ratio take-profits
## - Multi-level take-profits
##
## The examples use a simple RSI strategy with different risk management
## configurations to show how they affect backtest results.

import std/[times, strformat, strutils]
import ../src/tzutrader

proc generateTestData(): seq[OHLCV] =
  ## Generate synthetic price data for testing
  result = newSeq[OHLCV](200)
  let baseTime = getTime()
  var price = 100.0

  for i in 0..<200:
    # Add some volatility and trend
    let noise = (float(i mod 20) - 10.0) / 10.0
    let trend = float(i) * 0.05
    price = 100.0 + trend + noise * 2.0

    let barTime = baseTime - initDuration(days = 200 - i)

    result[i] = OHLCV(
      timestamp: barTime.toUnix(),
      open: price * 0.99,
      high: price * 1.02,
      low: price * 0.98,
      close: price,
      volume: 1000000.0
    )

proc main() =
  echo "=".repeat(70)
  echo "Risk Management Examples"
  echo "=".repeat(70)
  echo ""

  let data = generateTestData()
  let symbol = "TEST"
  let initialCash = 100000.0

  echo "Example 1: RSI Strategy with NO Risk Management"
  echo "-".repeat(70)

  let strategy1 = newRSIStrategy(period = 14, oversold = 30.0,
      overbought = 70.0)
  strategy1.symbol = symbol

  let report1 = quickBacktest(symbol, strategy1, data, initialCash,
      verbose = false)

  echo &"Total Return:      {report1.totalReturn:>10.2f}%"
  echo &"Max Drawdown:      {report1.maxDrawdown:>10.2f}%"
  echo &"Total Trades:      {report1.totalTrades:>10}"
  echo &"Win Rate:          {report1.winRate:>10.1f}%"
  echo &"Stop-Loss Exits:   {report1.stopLossExits:>10}"
  echo &"Take-Profit Exits: {report1.takeProfitExits:>10}"
  echo ""

  echo "Example 2: RSI Strategy with Fixed 5% Stop-Loss and 10% Take-Profit"
  echo "-".repeat(70)

  let strategy2 = newRSIStrategy(period = 14, oversold = 30.0,
      overbought = 70.0)
    .withFixedStopLoss(5.0)    # 5% stop-loss
    .withFixedTakeProfit(10.0) # 10% take-profit
  strategy2.symbol = symbol

  let report2 = quickBacktest(symbol, strategy2, data, initialCash,
      verbose = false)

  echo &"Total Return:      {report2.totalReturn:>10.2f}%"
  echo &"Max Drawdown:      {report2.maxDrawdown:>10.2f}%"
  echo &"Total Trades:      {report2.totalTrades:>10}"
  echo &"Win Rate:          {report2.winRate:>10.1f}%"
  echo &"Stop-Loss Exits:   {report2.stopLossExits:>10}"
  echo &"Take-Profit Exits: {report2.takeProfitExits:>10}"
  echo &"Strategy Exits:    {report2.strategyExits:>10}"
  echo &"Avg SL Return:    ${report2.avgStopLossReturn:>10.2f}"
  echo &"Avg TP Return:    ${report2.avgTakeProfitReturn:>10.2f}"
  echo ""

  echo "Example 3: RSI Strategy with Trailing Stop (3% trail, 5% activation)"
  echo "-".repeat(70)

  let strategy3 = newRSIStrategy(period = 14, oversold = 30.0,
      overbought = 70.0)
    .withTrailingStop(trailPct = 3.0, activationPct = 5.0)
  strategy3.symbol = symbol

  let report3 = quickBacktest(symbol, strategy3, data, initialCash,
      verbose = false)

  echo &"Total Return:      {report3.totalReturn:>10.2f}%"
  echo &"Max Drawdown:      {report3.maxDrawdown:>10.2f}%"
  echo &"Total Trades:      {report3.totalTrades:>10}"
  echo &"Win Rate:          {report3.winRate:>10.1f}%"
  echo &"Stop-Loss Exits:   {report3.stopLossExits:>10}"
  echo &"Take-Profit Exits: {report3.takeProfitExits:>10}"
  echo ""

  echo "Example 4: RSI Strategy with 5% Stop and 2:1 Risk/Reward"
  echo "-".repeat(70)

  # Using builder pattern for complex configuration
  let strategy4 = newStrategyBuilder(newRSIStrategy(period = 14,
      oversold = 30.0, overbought = 70.0))
    .withFixedStopLoss(5.0) # 5% stop-loss
    .withRiskReward(2.0)    # 2:1 risk/reward = 10% take-profit
    .build()
  strategy4.symbol = symbol

  let report4 = quickBacktest(symbol, strategy4, data, initialCash,
      verbose = false)

  echo &"Total Return:      {report4.totalReturn:>10.2f}%"
  echo &"Max Drawdown:      {report4.maxDrawdown:>10.2f}%"
  echo &"Total Trades:      {report4.totalTrades:>10}"
  echo &"Win Rate:          {report4.winRate:>10.1f}%"
  echo &"Stop-Loss Exits:   {report4.stopLossExits:>10}"
  echo &"Take-Profit Exits: {report4.takeProfitExits:>10}"
  echo ""

  echo "Example 5: RSI Strategy with Multi-Level Take-Profit"
  echo "-".repeat(70)
  echo "  - Exit 50% at 5% profit"
  echo "  - Exit 50% at 10% profit"
  echo ""

  let strategy5 = newStrategyBuilder(newRSIStrategy(period = 14,
      oversold = 30.0, overbought = 70.0))
    .withFixedStopLoss(5.0)
    .withMultiLevelProfit(@[
      TakeProfitLevel(percentage: 5.0, exitPercent: 50.0), # Exit 50% at 5%
      TakeProfitLevel(percentage: 10.0, exitPercent: 50.0) # Exit rest at 10%
    ])
    .build()
  strategy5.symbol = symbol

  let report5 = quickBacktest(symbol, strategy5, data, initialCash,
      verbose = false)

  echo &"Total Return:      {report5.totalReturn:>10.2f}%"
  echo &"Max Drawdown:      {report5.maxDrawdown:>10.2f}%"
  echo &"Total Trades:      {report5.totalTrades:>10}"
  echo &"Win Rate:          {report5.winRate:>10.1f}%"
  echo &"Stop-Loss Exits:   {report5.stopLossExits:>10}"
  echo &"Take-Profit Exits: {report5.takeProfitExits:>10}"
  echo ""

  echo "Example 6: Using withRiskManagement() Convenience Function"
  echo "-".repeat(70)

  let strategy6 = newRSIStrategy(period = 14, oversold = 30.0,
      overbought = 70.0)
    .withRiskManagement(
      stopLoss = newFixedPercentageStopLoss(5.0),
      takeProfit = newFixedPercentageTakeProfit(10.0)
    )
  strategy6.symbol = symbol

  let report6 = quickBacktest(symbol, strategy6, data, initialCash,
      verbose = false)

  echo &"Total Return:      {report6.totalReturn:>10.2f}%"
  echo &"Max Drawdown:      {report6.maxDrawdown:>10.2f}%"
  echo &"Total Trades:      {report6.totalTrades:>10}"
  echo &"Win Rate:          {report6.winRate:>10.1f}%"
  echo ""

  echo "=".repeat(70)
  echo "Comparison Summary"
  echo "=".repeat(70)
  echo ""
  echo "Configuration                                      Return   MaxDD  Trades"
  echo "-".repeat(70)
  echo &"No Risk Management                                 {report1.totalReturn:>6.2f}% {report1.maxDrawdown:>6.2f}% {report1.totalTrades:>6}"
  echo &"Fixed 5% SL / 10% TP                               {report2.totalReturn:>6.2f}% {report2.maxDrawdown:>6.2f}% {report2.totalTrades:>6}"
  echo &"Trailing Stop (3%, activate at 5%)                 {report3.totalReturn:>6.2f}% {report3.maxDrawdown:>6.2f}% {report3.totalTrades:>6}"
  echo &"5% SL with 2:1 Risk/Reward                         {report4.totalReturn:>6.2f}% {report4.maxDrawdown:>6.2f}% {report4.totalTrades:>6}"
  echo &"Multi-Level TP (50% @ 5%, 50% @ 10%)               {report5.totalReturn:>6.2f}% {report5.maxDrawdown:>6.2f}% {report5.totalTrades:>6}"
  echo &"withRiskManagement() (5% SL / 10% TP)              {report6.totalReturn:>6.2f}% {report6.maxDrawdown:>6.2f}% {report6.totalTrades:>6}"
  echo ""

  echo "=".repeat(70)
  echo "Key Observations:"
  echo "=".repeat(70)
  echo "- Risk management typically reduces maximum drawdown"
  echo "- Stop-losses protect against large losses but may increase trade count"
  echo "- Take-profits lock in gains but may exit winning positions early"
  echo "- Trailing stops allow profits to run while protecting gains"
  echo "- Multi-level exits balance between taking profits and letting winners run"
  echo "- Risk/reward ratios ensure consistent profit targets relative to risk"
  echo ""

when isMainModule:
  main()
