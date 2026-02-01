## Backtesting Example
##
## This example demonstrates:
## - Running backtests with different strategies
## - Comparing strategy performance
## - Using the convenience API (quickBacktest)
## - Generating and analyzing backtest reports
## - Backtesting from CSV data

import std/[times, sequtils, strformat, os]

import ../src/tzutrader/core
import ../src/tzutrader/strategy
import ../src/tzutrader/trader

# Helper: Generate synthetic price data with a trend
proc generatePriceData(bars: int, startPrice: float, trend: float = 0.001): seq[OHLCV] =
  result = newSeq[OHLCV](bars)
  let baseTime = now() - initDuration(days = bars)
  
  for i in 0..<bars:
    let
      trendFactor = 1.0 + (trend * float(i))
      open = startPrice * trendFactor
      high = open * 1.02
      low = open * 0.98
      close = open + (high - low) * 0.5
      volume = 1000000.0
      timestamp = (baseTime + initDuration(days = i)).toTime().toUnix()
    
    result[i] = OHLCV(
      timestamp: timestamp,
      open: open,
      high: high,
      low: low,
      close: close,
      volume: volume
    )

proc main() =
  echo "="
  echo "TzuTrader Backtesting Example"
  echo "="
  echo ""
  
  # ============================================================================
  # QUICK BACKTEST WITH RSI STRATEGY
  # ============================================================================
  
  echo "1. Quick Backtest with RSI Strategy"
  echo "=" .repeat(60)
  
  # Generate synthetic uptrend data
  let data = generatePriceData(bars = 100, startPrice = 100.0, trend = 0.002)
  
  # Create RSI strategy
  let rsiStrategy = newRSIStrategy(
    period = 14,
    oversold = 30.0,
    overbought = 70.0
  )
  
  # Run quick backtest
  echo &"\nRunning backtest on {data.len} bars..."
  let rsiReport = quickBacktest(
    symbol = "TEST",
    strategy = rsiStrategy,
    data = data,
    initialCash = 10000.0,
    commission = 0.001  # 0.1% commission
  )
  
  echo "\nRSI Strategy Results:"
  echo rsiReport
  echo ""
  
  # ============================================================================
  # FULL BACKTEST WITH MOVING AVERAGE CROSSOVER
  # ============================================================================
  
  echo "2. Full Backtest with Moving Average Crossover"
  echo "=" .repeat(60)
  
  # Create crossover strategy
  let crossStrategy = newCrossoverStrategy(
    fastPeriod = 10,
    slowPeriod = 30
  )
  
  # Create backtester with custom commission
  let backtester = newBacktester(
    strategy = crossStrategy,
    initialCash = 10000.0,
    commission = 0.0015  # 0.15% commission
  )
  
  # Run backtest
  echo &"\nRunning backtest on {data.len} bars..."
  let crossReport = backtester.run(data, symbol = "TEST")
  
  echo "\nMoving Average Crossover Results:"
  echo crossReport
  echo ""
  
  # Show trade logs
  if backtester.tradeLogs.len > 0:
    echo "Trade Log (first 5 trades):"
    echo "-" .repeat(80)
    for i, trade in backtester.tradeLogs:
      if i >= 5: break
      let 
        action = if trade.quantity > 0: "BUY " else: "SELL"
        dateStr = trade.timestamp.fromUnix().format("yyyy-MM-dd")
      echo &"{dateStr} | {action} | " &
           &"Qty: {abs(trade.quantity):6.2f} | Price: ${trade.price:8.2f} | " &
           &"Cash: ${trade.cash:10.2f} | Equity: ${trade.equity:10.2f}"
    echo ""
  
  # ============================================================================
  # COMPARING MULTIPLE STRATEGIES
  # ============================================================================
  
  echo "3. Comparing Multiple Strategies"
  echo "=" .repeat(60)
  
  # Define strategies to compare
  let strategies: seq[tuple[name: string, strat: Strategy]] = @[
    ("RSI (14)", Strategy(newRSIStrategy(14, 30.0, 70.0))),
    ("RSI (21)", Strategy(newRSIStrategy(21, 30.0, 70.0))),
    ("MA Cross (10/30)", Strategy(newCrossoverStrategy(10, 30))),
    ("MA Cross (20/50)", Strategy(newCrossoverStrategy(20, 50))),
    ("MACD", Strategy(newMACDStrategy())),
    ("Bollinger", Strategy(newBollingerStrategy()))
  ]
  
  echo &"\nBacktesting {strategies.len} strategies on {data.len} bars..."
  echo ""
  
  # Run all backtests and collect results
  var results: seq[tuple[name: string, report: BacktestReport]] = @[]
  
  for (name, strat) in strategies:
    let report = quickBacktest("TEST", strat, data, 10000.0, 0.001)
    results.add((name, report))
  
  # Display comparison table
  echo "Strategy Comparison:"
  echo "=" .repeat(100)
  echo "Strategy              | Total Return |   Sharpe |  Max DD | Win Rate | Trades"
  echo "-" .repeat(100)
  
  for (name, report) in results:
    echo &"{name:<20} | {report.totalReturn:>11.2f}% | {report.sharpeRatio:>8.2f} | " &
         &"{report.maxDrawdown:>7.2f}% | {report.winRate:>7.2f}% | {report.totalTrades:>7}"
  
  echo "=" .repeat(100)
  echo ""
  
  # Find best strategy by total return
  var bestIdx = 0
  var bestReturn = results[0].report.totalReturn
  for i, (name, report) in results:
    if report.totalReturn > bestReturn:
      bestReturn = report.totalReturn
      bestIdx = i
  
  echo &"Best Performer: {results[bestIdx].name} with {bestReturn:.2f}% return"
  echo ""
  
  # ============================================================================
  # COMPACT REPORT FORMAT
  # ============================================================================
  
  echo "4. Compact Report Format"
  echo "=" .repeat(60)
  
  echo "\nCompact reports for quick comparison:"
  for (name, report) in results:
    echo &"{name:<20}: {report.formatCompact()}"
  echo ""
  
  # ============================================================================
  # BACKTESTING FROM CSV (if available)
  # ============================================================================
  
  echo "5. Backtesting from CSV File"
  echo "=" .repeat(60)
  
  # Create a sample CSV file for demonstration
  let csvPath = "sample_prices.csv"
  
  if not fileExists(csvPath):
    echo &"\nCreating sample CSV file: {csvPath}"
    
    var csvContent = "timestamp,open,high,low,close,volume\n"
    for bar in data[0..<min(50, data.len)]:
      let dateStr = bar.timestamp.fromUnix().format("yyyy-MM-dd HH:mm:ss")
      csvContent &= &"{dateStr}," &
                    &"{bar.open},{bar.high},{bar.low},{bar.close},{bar.volume}\n"
    
    writeFile(csvPath, csvContent)
    echo "✓ Sample CSV created"
  
  # Run backtest from CSV
  echo &"\nRunning backtest from CSV file..."
  let csvStrategy = newRSIStrategy(14, 30.0, 70.0)
  let csvReport = quickBacktestCSV("TEST", csvStrategy, csvPath, 10000.0, 0.001)
  
  echo "\nCSV Backtest Results:"
  echo csvReport.formatCompact()
  echo ""
  
  # ============================================================================
  # ANALYZING PERFORMANCE METRICS
  # ============================================================================
  
  echo "6. Analyzing Performance Metrics"
  echo "=" .repeat(60)
  
  let report = rsiReport
  
  echo "\nDetailed Metrics Analysis:"
  echo &"  Initial Cash:       ${report.initialCash:>12.2f}"
  echo &"  Final Value:        ${report.finalValue:>12.2f}"
  echo &"  Total Return:       {report.totalReturn:>12.2f}%"
  echo &"  Annualized Return:  {report.annualizedReturn:>12.2f}%"
  echo ""
  echo &"  Total Trades:       {report.totalTrades:>12}"
  echo &"  Winning Trades:     {report.winningTrades:>12}"
  echo &"  Losing Trades:      {report.losingTrades:>12}"
  echo &"  Win Rate:           {report.winRate:>12.2f}%"
  echo ""
  echo &"  Average Win:        ${report.avgWin:>12.2f}"
  echo &"  Average Loss:       ${report.avgLoss:>12.2f}"
  echo &"  Best Trade:         ${report.bestTrade:>12.2f}"
  echo &"  Worst Trade:        ${report.worstTrade:>12.2f}"
  echo &"  Profit Factor:      {report.profitFactor:>12.2f}"
  echo ""
  echo &"  Max Drawdown:       {report.maxDrawdown:>12.2f}%"
  echo &"  Sharpe Ratio:       {report.sharpeRatio:>12.2f}"
  echo &"  Total Commission:   ${report.totalCommission:>12.2f}"
  echo ""
  
  # Performance interpretation
  echo "Performance Interpretation:"
  echo "-" .repeat(60)
  
  if report.totalReturn > 0:
    echo "✓ Strategy is profitable"
  else:
    echo "✗ Strategy is losing money"
  
  if report.sharpeRatio > 1.0:
    echo "✓ Good risk-adjusted returns (Sharpe > 1.0)"
  elif report.sharpeRatio > 0:
    echo "~ Moderate risk-adjusted returns (0 < Sharpe < 1.0)"
  else:
    echo "✗ Poor risk-adjusted returns (Sharpe < 0)"
  
  if report.winRate > 50:
    echo &"✓ High win rate ({report.winRate:.1f}%)"
  else:
    echo &"~ Low win rate ({report.winRate:.1f}%)"
  
  if report.profitFactor > 1.5:
    echo &"✓ Strong profit factor ({report.profitFactor:.2f})"
  elif report.profitFactor > 1.0:
    echo &"~ Moderate profit factor ({report.profitFactor:.2f})"
  else:
    echo &"✗ Weak profit factor ({report.profitFactor:.2f})"
  
  if report.maxDrawdown < 10:
    echo &"✓ Low drawdown ({report.maxDrawdown:.1f}%)"
  elif report.maxDrawdown < 20:
    echo &"~ Moderate drawdown ({report.maxDrawdown:.1f}%)"
  else:
    echo &"✗ High drawdown ({report.maxDrawdown:.1f}%)"
  
  echo ""
  
  echo "="
  echo "Backtesting example complete!"
  echo "="

when isMainModule:
  main()
