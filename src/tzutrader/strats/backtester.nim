## Generic Backtester for Concept-based Strategies
##
## This module provides backtesting functionality for strategies conforming
## to the StrategyLike concept. It uses generics to preserve type information
## through the backtest, enabling proper compile-time dispatch.
##
## **Key Advantages Over Traditional Backtester:**
## - Type information preserved through generics
## - No virtual method overhead
## - Compiler can inline all strategy calls
## - Better error messages (type errors caught at compile-time)
## - More idiomatic Nim code

import std/[tables, times, math, strformat, strutils, sequtils]
import ../core
import ../portfolio
import core

type
  BacktestReportGeneric* = object
    ## Comprehensive backtest performance report
    symbol*: string
    strategyName*: string
    startTime*: int64
    endTime*: int64
    initialCash*: float64
    finalValue*: float64
    totalReturn*: float64
    annualizedReturn*: float64
    sharpeRatio*: float64
    maxDrawdown*: float64
    maxDrawdownDuration*: int64
    winRate*: float64
    totalTrades*: int
    winningTrades*: int
    losingTrades*: int
    avgWin*: float64
    avgLoss*: float64
    profitFactor*: float64
    bestTrade*: float64
    worstTrade*: float64
    avgTradeReturn*: float64
    totalCommission*: float64

  TradeLogGeneric* = object
    ## Log entry for a trade event
    timestamp*: int64
    symbol*: string
    action*: Position
    quantity*: float64
    price*: float64
    cash*: float64
    equity*: float64

proc quickBacktestGeneric*[S](
  symbol: string,
  strategy: S,
  data: seq[OHLCV],
  config: PortfolioConfig,
  verbose: bool = false
): string =
  ## Quick backtest function for concept-based strategies
  ##
  ## This is the main entry point for running backtests with generic strategies.
  ## It uses the concept-based dispatch to call the strategy's onData method
  ## with zero runtime overhead.
  ##
  ## Args:
  ##   symbol: Trading symbol
  ##   strategy: Concrete strategy instance (preserves type)
  ##   data: Historical OHLCV data
  ##   config: Portfolio configuration
  ##   verbose: Enable verbose logging
  ##
  ## Returns:
  ##   Formatted backtest report as string
  
  if data.len == 0:
    return "Error: Cannot backtest on empty data"
  
  var strat = strategy  # Make mutable copy for reset
  var portfolio = newPortfolio(config)
  var tradeLogs: seq[TradeLogGeneric] = @[]
  var equityCurve: seq[tuple[timestamp: int64, equity: float64]] = @[]
  # Reset strategy
  resetStrategy(strat)
  if verbose:
    echo ""
    echo repeat("=", 60)
    echo &"Starting Backtest: {symbol}"
    echo &"Strategy: {getStrategyName(strat)}"
    let startDate = fromUnix(data[0].timestamp).format("yyyy-MM-dd")
    let endDate = fromUnix(data[^1].timestamp).format("yyyy-MM-dd")
    echo &"Period: {startDate} to {endDate}"
    echo &"Bars: {data.len}"
    echo &"Initial Cash: ${config.initialCash:.2f}"
    echo repeat("=", 60)
    
  # Run strategy on data and execute signals
  for bar in data:
    # Get signal from strategy using generic dispatch
    let signal = processBar(strat, bar)
    
    # Update portfolio prices
    var prices = initTable[string, float64]()
    prices[symbol] = bar.close
    portfolio.updatePrices(prices)
    
    # Record equity
    equityCurve.add((bar.timestamp, portfolio.equity(prices)))
    
    # Execute signal if not Stay
    if signal.position != Position.Stay:
      case signal.position
      of Position.Buy:
      let (sizingType, sizingValue) = getSizingConfig(strat)
      
      var quantity: float
      case sizingType
      of pstDefault:
          let availableCash = portfolio.cash * 0.95
          quantity = floor(availableCash / signal.price)
      of pstFixed:
          quantity = sizingValue
      of pstPercent:
          let portfolioEquity = portfolio.equity()
          let allocationAmount = portfolioEquity * (sizingValue / 100.0)
          quantity = floor(allocationAmount / signal.price)
      
      if quantity > 0:
          let success = portfolio.buy(symbol, quantity, signal.price, bar.timestamp)
          
          if success:
            if verbose:
              echo &"[BUY] {fromUnix(bar.timestamp).format(\"yyyy-MM-dd\")} - {symbol}: {quantity:.0f} @ ${signal.price:.2f}"
            
            tradeLogs.add(TradeLogGeneric(
              timestamp: bar.timestamp,
              symbol: symbol,
              action: Position.Buy,
              quantity: quantity,
              price: signal.price,
              cash: portfolio.cash,
              equity: portfolio.equity()
            ))
      
      of Position.Sell:
      if portfolio.hasPosition(symbol):
          let pos = portfolio.getPosition(symbol)
          let success = portfolio.sell(symbol, pos.quantity, signal.price, bar.timestamp)
          
          if success:
            if verbose:
              echo &"[SELL] {fromUnix(bar.timestamp).format(\"yyyy-MM-dd\")} - {symbol}: {pos.quantity:.0f} @ ${signal.price:.2f}"
            
            tradeLogs.add(TradeLogGeneric(
              timestamp: bar.timestamp,
              symbol: symbol,
              action: Position.Sell,
              quantity: pos.quantity,
              price: signal.price,
              cash: portfolio.cash,
              equity: portfolio.equity()
            ))
      
      of Position.Stay:
      discard
  
  # Close any remaining positions at final price
  let finalBar = data[^1]
  if portfolio.hasPosition(symbol):
    let pos = portfolio.getPosition(symbol)
    discard portfolio.sell(symbol, pos.quantity, finalBar.close, finalBar.timestamp)
    
    if verbose:
      echo &"[CLOSE] Final position closed at ${finalBar.close:.2f}"
  
  # Calculate final equity
  var finalPrices = initTable[string, float64]()
  finalPrices[symbol] = finalBar.close
  let finalEquity = portfolio.equity(finalPrices)
  
  # Calculate performance metrics
  let metrics = portfolio.calculatePerformance(finalPrices)
  
  # Calculate additional metrics
  let durationSeconds = data[^1].timestamp - data[0].timestamp
  let durationYears = durationSeconds.float64 / (365.25 * 86400.0)
  
  let annualizedReturn = if durationYears > 0:
    (pow(finalEquity / config.initialCash, 1.0 / durationYears) - 1.0) * 100.0
  else:
    metrics.totalReturn
  
  # Calculate total commissions
  var totalCommission = 0.0
  for tx in portfolio.transactions:
    totalCommission += tx.commission
  
  # Calculate trade statistics
  var tradePnLs: seq[float64] = @[]
  var position = 0.0
  var costBasis = 0.0
  
  for tx in portfolio.transactions:
    case tx.action
    of Position.Buy:
      let totalCost = tx.quantity * tx.price + tx.commission
      costBasis += totalCost
      position += tx.quantity
    of Position.Sell:
      if position > 0:
      let avgCost = costBasis / position
      let pnl = (tx.price - avgCost) * tx.quantity - tx.commission
      tradePnLs.add(pnl)
      
      let percentSold = tx.quantity / position
      costBasis *= (1.0 - percentSold)
      position -= tx.quantity
    else:
      discard
  
  let bestTrade = if tradePnLs.len > 0: tradePnLs.max() else: 0.0
  let worstTrade = if tradePnLs.len > 0: tradePnLs.min() else: 0.0
  let avgTradeReturn = if tradePnLs.len > 0: tradePnLs.sum() / tradePnLs.len.float64 else: 0.0
  
  # Calculate max drawdown duration
  var maxDDDuration: int64 = 0
  var peak = config.initialCash
  var peakTime: int64 = data[0].timestamp
  
  for (timestamp, equity) in equityCurve:
    if equity > peak:
      peak = equity
      peakTime = timestamp
    else:
      let duration = timestamp - peakTime
      if duration > maxDDDuration:
      maxDDDuration = duration
  
  let winningTrades = tradePnLs.countIt(it > 0)
  let losingTrades = tradePnLs.len - winningTrades
  let winRate = if tradePnLs.len > 0: (winningTrades.float64 / tradePnLs.len.float64) * 100.0 else: 0.0
  
  let grossProfit = tradePnLs.filterIt(it > 0).sum()
  let grossLoss = abs(tradePnLs.filterIt(it < 0).sum())
  let profitFactor = if grossLoss > 0: grossProfit / grossLoss else: 0.0
  
  let avgWin = if winningTrades > 0: tradePnLs.filterIt(it > 0).sum() / winningTrades.float64 else: 0.0
  let avgLoss = if losingTrades > 0: abs(tradePnLs.filterIt(it < 0).sum()) / losingTrades.float64 else: 0.0
   
  # Extract dates for the report
  let startDateStr = fromUnix(data[0].timestamp).format("yyyy-MM-dd")
  let endDateStr = fromUnix(data[^1].timestamp).format("yyyy-MM-dd")
  
   # Format and return report
  var report = &"""
╔═══════════════════════════════════════════════════════════════════════╗
║                        BACKTEST REPORT - {getStrategyName(strat)}
╚═══════════════════════════════════════════════════════════════════════╝

📊 RETURNS:
   Total Return:           {metrics.totalReturn:>8.2f}%
   Annualized Return:      {annualizedReturn:>8.2f}%
   Initial Capital:        ${config.initialCash:>12.2f}
   Final Value:            ${finalEquity:>12.2f}
   Profit/Loss:            ${finalEquity - config.initialCash:>12.2f}

📈 RISK METRICS:
   Max Drawdown:           {metrics.maxDrawdown:>8.2f}%
   Max DD Duration:        {(maxDDDuration.float64 / 86400.0):>8.1f} days
   Sharpe Ratio:           {metrics.sharpeRatio:>8.2f}

💰 TRADING STATS:
   Total Trades:           {tradePnLs.len:>8}
   Winning Trades:         {winningTrades:>8}
   Losing Trades:          {losingTrades:>8}
   Win Rate:               {winRate:>8.2f}%
   Best Trade:             ${bestTrade:>12.2f}
   Worst Trade:            ${worstTrade:>12.2f}
   Avg Win:                ${avgWin:>12.2f}
   Avg Loss:               ${avgLoss:>12.2f}
   Avg Trade Return:       ${avgTradeReturn:>12.2f}
   Profit Factor:          {profitFactor:>8.2f}

💳 COSTS:
   Total Commission:       ${totalCommission:>12.2f}

 📅 PERIOD:
   Start Date:             {startDateStr}
   End Date:               {endDateStr}
   Duration:               {(durationSeconds.float64 / 86400.0):>8.1f} days
   Bars Processed:         {data.len:>8}

"""
  
  result = report

proc runBacktestGeneric*[S](
  symbol: string,
  strategy: S,
  data: seq[OHLCV],
  initialCash: float64 = 100000.0,
  commission: float64 = 0.0,
  verbose: bool = false
): string =
  ## Simplified backtest function with default configuration
  ##
  ## Args:
  ##   symbol: Trading symbol
  ##   strategy: Concrete strategy instance
  ##   data: Historical OHLCV data
  ##   initialCash: Starting capital (default $100,000)
  ##   commission: Commission rate (default 0)
  ##   verbose: Enable verbose logging
  ##
  ## Returns:
  ##   Formatted backtest report as string
  
  let config = PortfolioConfig(
    initialCash: initialCash,
    commission: commission,
    minCommission: 0.0,
    riskFreeRate: 0.02
  )
  
  quickBacktestGeneric(symbol, strategy, data, config, verbose)
