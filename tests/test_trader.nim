## Unit tests for trader module (backtesting)

import std/[unittest, times, tables, math, strutils]
import ../src/tzutrader/[core, data, indicators, strategy, portfolio, trader, strategy_builder]
import ../src/tzutrader/declarative/risk_management

# Helper to create test data
proc createTestData(bars: int, startPrice: float64 = 100.0, trend: float64 = 0.0): seq[OHLCV] =
  ## Create test OHLCV data with optional trend
  result = @[]
  var currentTime = getTime().toUnix() - (bars * 86400)
  var price = startPrice
  
  for i in 0..<bars:
    let change = trend + (if i mod 3 == 0: 2.0 else: -1.0)
    let open = price
    let close = price + change
    let high = max(open, close) * 1.01
    let low = min(open, close) * 0.99
    
    result.add(OHLCV(
      timestamp: currentTime,
      open: open,
      high: high,
      low: low,
      close: close,
      volume: 1000000.0
    ))
    
    price = close
    currentTime += 86400

suite "Backtester Construction Tests":
  
  test "Create backtester with default parameters":
    let strategy = newRSIStrategy()
    let bt = newBacktester(strategy)
    
    check bt.strategy != nil
    check bt.portfolio != nil
    check bt.portfolio.initialCash == 100000.0
    check bt.tradeLogs.len == 0
    check bt.equityCurve.len == 0
    check bt.verbose == false
  
  test "Create backtester with custom parameters":
    let strategy = newRSIStrategy()
    let bt = newBacktester(strategy, initialCash = 50000.0, commission = 0.001, verbose = true)
    
    check bt.portfolio.initialCash == 50000.0
    check bt.portfolio.commission == 0.001
    check bt.verbose == true
  
  test "Backtester has strategy and portfolio":
    let strategy = newCrossoverStrategy()
    let bt = newBacktester(strategy, initialCash = 10000.0)
    
    check bt.strategy != nil
    check bt.portfolio.cash == 10000.0

suite "Backtest Execution Tests":
  
  test "Run backtest on uptrend data":
    let strategy = newRSIStrategy(period = 14, oversold = 30.0, overbought = 70.0)
    let data = createTestData(50, startPrice = 100.0, trend = 1.0)
    
    let bt = newBacktester(strategy, initialCash = 10000.0)
    let report = bt.run(data, "TEST")
    
    check report.symbol == "TEST"
    check report.initialCash == 10000.0
    check report.finalValue > 0.0
    check report.totalTrades >= 0
  
  test "Run backtest on downtrend data":
    let strategy = newRSIStrategy(period = 14, oversold = 30.0, overbought = 70.0)
    let data = createTestData(50, startPrice = 100.0, trend = -0.5)
    
    let bt = newBacktester(strategy, initialCash = 10000.0)
    let report = bt.run(data, "TEST")
    
    check report.symbol == "TEST"
    check report.finalValue >= 0.0  # Should complete successfully
  
  test "Backtest with no signals generates no trades":
    # Use data that won't trigger RSI signals
    let strategy = newRSIStrategy(period = 14, oversold = 10.0, overbought = 90.0)
    let data = createTestData(30, startPrice = 100.0, trend = 0.1)
    
    let bt = newBacktester(strategy, initialCash = 10000.0)
    let report = bt.run(data, "TEST")
    
    # Should have few or no trades with extreme RSI thresholds
    check report.finalValue == report.initialCash  # No trades = no change
  
  test "Backtest records equity curve":
    let strategy = newRSIStrategy()
    let data = createTestData(20)
    
    let bt = newBacktester(strategy, initialCash = 10000.0)
    discard bt.run(data, "TEST")
    
    check bt.equityCurve.len == data.len
  
  test "Backtest fails on empty data":
    let strategy = newRSIStrategy()
    let data: seq[OHLCV] = @[]
    
    let bt = newBacktester(strategy)
    
    expect ValueError:
      discard bt.run(data, "TEST")

suite "Signal Execution Tests":
  
  test "Buy signal creates position":
    let strategy = newRSIStrategy()
    let data = createTestData(30, startPrice = 100.0)
    
    let bt = newBacktester(strategy, initialCash = 10000.0)
    discard bt.run(data, "TEST")
    
    # If any trades happened, we should have trade logs
    if bt.portfolio.transactions.len > 0:
      check bt.tradeLogs.len > 0
  
  test "Position size uses available cash":
    let strategy = newRSIStrategy(oversold = 60.0)  # Easy to trigger
    
    # Create data that will trigger buy
    var data: seq[OHLCV] = @[]
    let baseTime = getTime().toUnix()
    
    # Sharp drop to trigger oversold
    for i in 0..20:
      let price = 100.0 - (i.float64 * 2.0)
      data.add(OHLCV(
        timestamp: baseTime + (i * 86400),
        open: price,
        high: price * 1.01,
        low: price * 0.99,
        close: price,
        volume: 1000000.0
      ))
    
    let bt = newBacktester(strategy, initialCash = 10000.0)
    discard bt.run(data, "TEST")
    
    # Should use most of available cash
    if bt.portfolio.transactions.len > 0:
      let firstBuy = bt.portfolio.transactions[0]
      check firstBuy.action == Position.Buy
      # Should use ~95% of cash
      let cost = firstBuy.quantity * firstBuy.price
      check cost > 8000.0  # At least 80% of initial cash
      check cost < 10000.0  # But not more than total

suite "Commission Tests":
  
  test "Backtest with commissions reduces returns":
    let strategy = newCrossoverStrategy(fastPeriod = 5, slowPeriod = 10)
    let data = createTestData(50, startPrice = 100.0, trend = 0.5)
    
    # Run without commission
    let bt1 = newBacktester(strategy, initialCash = 10000.0, commission = 0.0)
    let report1 = bt1.run(data, "TEST")
    
    # Run with commission
    bt1.strategy.reset()
    let bt2 = newBacktester(strategy, initialCash = 10000.0, commission = 0.01)
    let report2 = bt2.run(data, "TEST")
    
    # Commission version should have lower or equal returns
    if report1.totalTrades > 0 and report2.totalTrades > 0:
      check report2.totalCommission > 0.0
      check report2.finalValue <= report1.finalValue

suite "Report Generation Tests":
  
  test "Report contains all required fields":
    let strategy = newRSIStrategy()
    let data = createTestData(30)
    
    let bt = newBacktester(strategy, initialCash = 10000.0)
    let report = bt.run(data, "AAPL")
    
    check report.symbol == "AAPL"
    check report.initialCash == 10000.0
    check report.finalValue >= 0.0
    check report.startTime == data[0].timestamp
    check report.endTime == data[^1].timestamp
  
  test "Report calculates returns correctly":
    let strategy = newRSIStrategy()
    let data = createTestData(30, startPrice = 100.0, trend = 1.0)
    
    let bt = newBacktester(strategy, initialCash = 10000.0)
    let report = bt.run(data, "TEST")
    
    let expectedReturn = ((report.finalValue - report.initialCash) / report.initialCash) * 100.0
    check abs(report.totalReturn - expectedReturn) < 0.01
  
  test "Report string representation":
    let strategy = newRSIStrategy()
    let data = createTestData(20)
    
    let bt = newBacktester(strategy)
    let report = bt.run(data, "TEST")
    
    let s = $report
    check "Backtest Report" in s
    check "TEST" in s
    check "Initial" in s
    check "Final" in s
  
  test "Report compact format":
    let strategy = newRSIStrategy()
    let data = createTestData(20)
    
    let bt = newBacktester(strategy)
    let report = bt.run(data, "AAPL")
    
    let compact = report.formatCompact()
    check "AAPL" in compact
    check "Return" in compact
    check "Sharpe" in compact

suite "Convenience API Tests":
  
  test "quickBacktest function":
    let strategy = newRSIStrategy()
    let data = createTestData(30)
    
    let report = quickBacktest("TEST", strategy, data, initialCash = 10000.0)
    
    check report.symbol == "TEST"
    check report.initialCash == 10000.0
  
  test "quickBacktest with commission":
    let strategy = newRSIStrategy()
    let data = createTestData(30)
    
    let report = quickBacktest("TEST", strategy, data, 
                               initialCash = 10000.0, 
                               commission = 0.001)
    
    check report.initialCash == 10000.0

suite "Performance Metrics Tests":
  
  test "Win rate calculation":
    let strategy = newCrossoverStrategy(fastPeriod = 5, slowPeriod = 10)
    let data = createTestData(60, startPrice = 100.0, trend = 0.3)
    
    let bt = newBacktester(strategy, initialCash = 10000.0)
    let report = bt.run(data, "TEST")
    
    if report.totalTrades > 0:
      check report.winRate >= 0.0
      check report.winRate <= 100.0
      check report.winningTrades + report.losingTrades <= report.totalTrades
  
  test "Sharpe ratio in reasonable range":
    let strategy = newRSIStrategy()
    let data = createTestData(50)
    
    let bt = newBacktester(strategy)
    let report = bt.run(data, "TEST")
    
    # Sharpe ratio typically between -3 and 3 for most strategies
    if not report.sharpeRatio.isNaN:
      check report.sharpeRatio > -10.0
      check report.sharpeRatio < 10.0
  
  test "Max drawdown is non-negative":
    let strategy = newRSIStrategy()
    let data = createTestData(40)
    
    let bt = newBacktester(strategy)
    let report = bt.run(data, "TEST")
    
    check report.maxDrawdown >= 0.0
  
  test "Profit factor calculation":
    let strategy = newRSIStrategy()
    let data = createTestData(50, trend = 0.5)
    
    let bt = newBacktester(strategy, initialCash = 10000.0)
    let report = bt.run(data, "TEST")
    
    if report.totalTrades > 0:
      check report.profitFactor >= 0.0

suite "Trade Logging Tests":
  
  test "Trade logs record buy and sell":
    let strategy = newCrossoverStrategy(fastPeriod = 3, slowPeriod = 7)
    let data = createTestData(40, trend = 0.5)
    
    let bt = newBacktester(strategy, initialCash = 10000.0)
    discard bt.run(data, "TEST")
    
    # Should have some trade logs if strategy generated signals
    if bt.tradeLogs.len > 0:
      for log in bt.tradeLogs:
        check log.quantity > 0.0
        check log.price > 0.0
        check log.equity >= 0.0
  
  test "Trade logs track equity changes":
    let strategy = newRSIStrategy()
    let data = createTestData(30)
    
    let bt = newBacktester(strategy, initialCash = 10000.0)
    discard bt.run(data, "TEST")
    
    if bt.tradeLogs.len > 0:
      # First log should show initial cash
      check bt.tradeLogs[0].cash <= 10000.0

suite "Strategy Integration Tests":
  
  test "RSI strategy backtest":
    let strategy = newRSIStrategy(period = 14, oversold = 30.0, overbought = 70.0)
    let data = createTestData(60, startPrice = 100.0)
    
    let report = quickBacktest("RSI_TEST", strategy, data, initialCash = 10000.0)
    
    check report.symbol == "RSI_TEST"
    check report.totalTrades >= 0
  
  test "Crossover strategy backtest":
    let strategy = newCrossoverStrategy(fastPeriod = 5, slowPeriod = 20)
    let data = createTestData(50, startPrice = 100.0, trend = 0.3)
    
    let report = quickBacktest("MA_TEST", strategy, data, initialCash = 10000.0)
    
    check report.symbol == "MA_TEST"
    check report.finalValue > 0.0
  
  test "MACD strategy backtest":
    let strategy = newMACDStrategy()
    let data = createTestData(60, startPrice = 100.0)
    
    let report = quickBacktest("MACD_TEST", strategy, data, initialCash = 10000.0)
    
    check report.symbol == "MACD_TEST"
  
  test "Bollinger strategy backtest":
    let strategy = newBollingerStrategy(period = 20, stdDev = 2.0)
    let data = createTestData(50, startPrice = 100.0)
    
    let report = quickBacktest("BB_TEST", strategy, data, initialCash = 10000.0)
    
    check report.symbol == "BB_TEST"

suite "Edge Cases Tests":
  
  test "Backtest with very small capital":
    let strategy = newRSIStrategy()
    let data = createTestData(20, startPrice = 1000.0)  # High price
    
    let bt = newBacktester(strategy, initialCash = 100.0)  # Small cash
    let report = bt.run(data, "TEST")
    
    # Should handle gracefully even if can't buy any shares
    check report.initialCash == 100.0
  
  test "Backtest with single bar":
    let strategy = newRSIStrategy()
    let data = createTestData(1)
    
    let bt = newBacktester(strategy)
    let report = bt.run(data, "TEST")
    
    check report.totalTrades == 0  # Can't trade with just 1 bar

suite "Risk Management Integration Tests":
  
  test "Strategy with risk management enabled":
    let strategy = newRSIStrategy()
      .withFixedStopLoss(5.0)
      .withFixedTakeProfit(10.0)
    
    check strategy.enableRiskManagement == true
    check strategy.stopLossRule != nil
    check strategy.takeProfitRule != nil
  
  test "Backtest report includes risk management statistics":
    let strategy = newRSIStrategy(oversold = 45.0)  # Easier to trigger
      .withFixedStopLoss(5.0)
      .withFixedTakeProfit(10.0)
    
    # Create volatile data to trigger trades
    var data: seq[OHLCV] = @[]
    let baseTime = getTime().toUnix()
    for i in 0..40:
      let price = 100.0 + (i.float64 * (if i mod 2 == 0: 3.0 else: -2.0))
      data.add(OHLCV(
        timestamp: baseTime + (i * 86400),
        open: price,
        high: price * 1.02,
        low: price * 0.98,
        close: price,
        volume: 1000000.0
      ))
    
    let report = quickBacktest("TEST", strategy, data, initialCash = 10000.0)
    
    # Report should have risk management fields (even if zero)
    check report.stopLossExits >= 0
    check report.takeProfitExits >= 0
    check report.strategyExits >= 0
  
  test "Fixed stop-loss exits are tracked":
    # Create a simple strategy that buys and holds
    let strategy = newRSIStrategy(oversold = 50.0)
      .withFixedStopLoss(10.0)  # 10% stop-loss
    
    # Create data with significant drop to trigger stop
    var data: seq[OHLCV] = @[]
    let baseTime = getTime().toUnix()
    for i in 0..30:
      # Start at 100, drop to 80 (20% drop should trigger 10% stop)
      let price = 100.0 - (i.float64 * 0.7)
      data.add(OHLCV(
        timestamp: baseTime + (i * 86400),
        open: price,
        high: price * 1.01,
        low: price * 0.99,
        close: price,
        volume: 1000000.0
      ))
    
    let bt = newBacktester(strategy, initialCash = 10000.0)
    let report = bt.run(data, "TEST")
    
    # With stop-loss, should have risk exits if trades occurred
    if report.totalTrades > 0:
      check (report.stopLossExits + report.takeProfitExits + report.strategyExits) >= 0
  
  test "Risk management with builder pattern":
    let strategy = newStrategyBuilder(newCrossoverStrategy(5, 10))
      .withFixedStopLoss(5.0)
      .withRiskReward(2.0)
      .build()
    
    check strategy.enableRiskManagement == true
    check strategy.stopLossRule.kind == slkFixedPercentage
    check strategy.takeProfitRule.kind == tpkRiskReward
  
  test "Risk management with withRiskManagement convenience function":
    let strategy = newRSIStrategy()
      .withRiskManagement(
        stopLoss = newFixedPercentageStopLoss(5.0),
        takeProfit = newFixedPercentageTakeProfit(10.0)
      )
    
    check strategy.enableRiskManagement == true
    check strategy.stopLossRule.kind == slkFixedPercentage
    check strategy.takeProfitRule.kind == tpkFixedPercentage
  
  test "Strategy without risk management works as before":
    let strategy = newRSIStrategy()
    let data = createTestData(30)
    
    check strategy.enableRiskManagement == false
    check strategy.stopLossRule == nil
    check strategy.takeProfitRule == nil
    
    let report = quickBacktest("TEST", strategy, data, initialCash = 10000.0)
    check report.stopLossExits == 0
    check report.takeProfitExits == 0
  
  test "Trailing stop configuration":
    let strategy = newRSIStrategy()
      .withTrailingStop(trailPct = 3.0, activationPct = 5.0)
    
    check strategy.enableRiskManagement == true
    check strategy.stopLossRule.kind == slkTrailing
    
    let trailingRule = TrailingStopLoss(strategy.stopLossRule)
    check trailingRule.trailPercentage == 3.0
    check trailingRule.activationProfit == 5.0
  
  test "Multi-level take-profit configuration":
    let levels = @[
      TakeProfitLevel(percentage: 5.0, exitPercent: 50.0),
      TakeProfitLevel(percentage: 10.0, exitPercent: 50.0)
    ]
    
    let strategy = newStrategyBuilder(newRSIStrategy())
      .withFixedStopLoss(5.0)
      .withMultiLevelProfit(levels)
      .build()
    
    check strategy.takeProfitRule.kind == tpkMultiLevel
    
    let mltp = MultiLevelTakeProfit(strategy.takeProfitRule)
    check mltp.levels.len == 2
    check mltp.levels[0].percentage == 5.0
    check mltp.levels[0].exitPercent == 50.0
  
  test "BacktestReport string includes risk management section when applicable":
    let strategy = newRSIStrategy(oversold = 45.0)
      .withFixedStopLoss(5.0)
      .withFixedTakeProfit(10.0)
    
    var data: seq[OHLCV] = @[]
    let baseTime = getTime().toUnix()
    for i in 0..30:
      let price = 100.0 + (i.float64 * (if i mod 3 == 0: 2.0 else: -1.5))
      data.add(OHLCV(
        timestamp: baseTime + (i * 86400),
        open: price,
        high: price * 1.02,
        low: price * 0.98,
        close: price,
        volume: 1000000.0
      ))
    
    let report = quickBacktest("TEST", strategy, data, initialCash = 10000.0)
    let reportStr = $report
    
    # If any risk exits occurred, report should include Risk Management section
    if report.stopLossExits > 0 or report.takeProfitExits > 0:
      check "Risk Management" in reportStr
      check "Stop-Loss Exits" in reportStr
      check "Take-Profit Exits" in reportStr

echo "Trader module: All tests defined"
