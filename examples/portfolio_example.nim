## Portfolio Management Example
##
## This example demonstrates:
## - Creating and managing a portfolio
## - Executing buy/sell orders
## - Tracking positions and P&L
## - Calculating performance metrics
## - Simulating a simple trading strategy with portfolio

import std/[times, sequtils, strformat, tables, math]

import ../src/tzutrader/core
import ../src/tzutrader/portfolio

proc main() =
  echo "="
  echo "TzuTrader Portfolio Management Example"
  echo "="
  echo ""
  
  # ============================================================================
  # BASIC PORTFOLIO OPERATIONS
  # ============================================================================
  
  echo "1. Basic Portfolio Operations"
  echo "=" .repeat(60)
  
  # Create a portfolio with $10,000 initial capital
  let p = newPortfolio(initialCash = 10000.0)
  echo &"Created portfolio with ${p.initialCash:.2f} initial cash"
  echo &"Current cash: ${p.cash:.2f}"
  echo &"Current equity: ${p.equity():.2f}"
  echo ""
  
  # ============================================================================
  # EXECUTING TRADES
  # ============================================================================
  
  echo "2. Executing Trades"
  echo "=" .repeat(60)
  
  # Buy some shares
  echo "\nBuying 10 shares of AAPL at $150..."
  let buySuccess = p.buy("AAPL", 10.0, 150.0)
  
  if buySuccess:
    echo &"✓ Purchase successful"
    echo &"  Cash remaining: ${p.cash:.2f}"
    echo &"  Position: {p.getPosition(\"AAPL\")}"
  else:
    echo "✗ Purchase failed (insufficient funds)"
  
  # Buy another position
  echo "\nBuying 5 shares of MSFT at $300..."
  discard p.buy("MSFT", 5.0, 300.0)
  
  echo &"\nPortfolio Summary:"
  echo &"  Cash: ${p.cash:.2f}"
  echo &"  Number of positions: {p.positions.len}"
  echo &"  Market value: ${p.marketValue():.2f}"
  echo &"  Total equity: ${p.equity():.2f}"
  
  # ============================================================================
  # PRICE UPDATES AND P&L
  # ============================================================================
  
  echo "\n3. Price Updates and P&L Tracking"
  echo "=" .repeat(60)
  
  # Simulate price changes
  var currentPrices = initTable[string, float64]()
  currentPrices["AAPL"] = 165.0  # +$15 per share
  currentPrices["MSFT"] = 290.0  # -$10 per share
  
  echo "\nUpdating prices..."
  echo &"  AAPL: $150 → $165 (+10.0%)"
  echo &"  MSFT: $300 → $290 (-3.3%)"
  
  p.updatePrices(currentPrices)
  
  echo &"\nPosition Details:"
  for symbol in ["AAPL", "MSFT"]:
    let pos = p.getPosition(symbol)
    let pnlPercent = (pos.unrealizedPnL / (pos.quantity * pos.entryPrice)) * 100.0
    echo &"  {symbol}: {pos.quantity:.0f} shares @ ${pos.entryPrice:.2f}"
    echo &"    Current: ${pos.currentPrice:.2f}"
    echo &"    P&L: ${pos.unrealizedPnL:.2f} ({pnlPercent:+.1f}%)"
  
  echo &"\nPortfolio P&L:"
  echo &"  Unrealized P&L: ${p.unrealizedPnL():.2f}"
  echo &"  Realized P&L: ${p.realizedPnL():.2f}"
  echo &"  Total P&L: ${p.totalPnL():.2f}"
  echo &"  Total equity: ${p.equity(currentPrices):.2f}"
  
  # ============================================================================
  # CLOSING POSITIONS
  # ============================================================================
  
  echo "\n4. Closing Positions"
  echo "=" .repeat(60)
  
  # Sell half of AAPL position
  echo "\nSelling 5 shares of AAPL at $165..."
  discard p.sell("AAPL", 5.0, 165.0)
  
  echo &"✓ Sold successfully"
  echo &"  Realized P&L from sale: ${(165.0 - 150.0) * 5.0:.2f}"
  echo &"  Remaining position: {p.getPosition(\"AAPL\").quantity:.0f} shares"
  
  # Close entire MSFT position
  echo "\nClosing entire MSFT position at $290..."
  discard p.closePosition("MSFT", 290.0)
  
  echo &"✓ Position closed"
  echo &"  Realized P&L from close: ${(290.0 - 300.0) * 5.0:.2f}"
  echo &"  Has MSFT position: {p.hasPosition(\"MSFT\")}"
  
  # ============================================================================
  # TRANSACTION HISTORY
  # ============================================================================
  
  echo "\n5. Transaction History"
  echo "=" .repeat(60)
  
  echo &"\nTotal transactions: {p.transactions.len}"
  for i, tx in p.transactions:
    let dt = tx.timestamp.fromUnix.format("yyyy-MM-dd HH:mm:ss")
    echo &"  {i+1}. {dt} - {tx.action} {tx.quantity:.0f} {tx.symbol} @ ${tx.price:.2f}"
  
  # ============================================================================
  # PERFORMANCE METRICS
  # ============================================================================
  
  echo "\n6. Performance Metrics"
  echo "=" .repeat(60)
  
  currentPrices["AAPL"] = 170.0  # Further increase
  let metrics = p.calculatePerformance(currentPrices)
  
  echo &"\nPortfolio Performance:"
  echo &"  Total Return: {metrics.totalReturn:+.2f}%"
  echo &"  Total Trades: {metrics.totalTrades}"
  echo &"  Winning Trades: {metrics.winningTrades}"
  echo &"  Losing Trades: {metrics.losingTrades}"
  echo &"  Win Rate: {metrics.winRate:.1f}%"
  
  if metrics.winningTrades > 0:
    echo &"  Average Win: ${metrics.avgWin:.2f}"
  if metrics.losingTrades > 0:
    echo &"  Average Loss: ${metrics.avgLoss:.2f}"
  
  if metrics.profitFactor != Inf:
    echo &"  Profit Factor: {metrics.profitFactor:.2f}"
  else:
    echo &"  Profit Factor: ∞ (no losing trades)"
  
  echo &"  Max Drawdown: {metrics.maxDrawdown:.2f}%"
  
  if not metrics.sharpeRatio.isNaN:
    echo &"  Sharpe Ratio: {metrics.sharpeRatio:.2f}"
  
  # ============================================================================
  # PORTFOLIO WITH COMMISSIONS
  # ============================================================================
  
  echo "\n7. Portfolio with Commissions"
  echo "=" .repeat(60)
  
  # Create portfolio with 0.1% commission and $1 minimum
  let p2 = newPortfolio(initialCash = 10000.0, commission = 0.001, minCommission = 1.0)
  
  echo "\nPortfolio with 0.1% commission ($1 minimum)"
  
  # Small trade - minimum commission applies
  echo "\nBuying 1 share of AAPL at $150..."
  discard p2.buy("AAPL", 1.0, 150.0)
  let comm1 = p2.calculateCommission(1.0, 150.0)
  echo &"  Trade value: $150"
  echo &"  Commission (0.1%): ${150.0 * 0.001:.2f}"
  echo &"  Actual commission: ${comm1:.2f} (minimum applied)"
  echo &"  Cash after trade: ${p2.cash:.2f}"
  
  # Larger trade - percentage commission applies
  echo "\nBuying 100 shares of MSFT at $300..."
  discard p2.buy("MSFT", 100.0, 300.0)
  let comm2 = p2.calculateCommission(100.0, 300.0)
  echo &"  Trade value: $30,000"
  echo &"  Commission (0.1%): ${comm2:.2f}"
  echo &"  Cash after trade: ${p2.cash:.2f}"
  
  # ============================================================================
  # SIMULATED TRADING STRATEGY
  # ============================================================================
  
  echo "\n8. Simulated Trading Strategy"
  echo "=" .repeat(60)
  
  echo "\nSimulating a simple buy-low-sell-high strategy..."
  
  # Create a new portfolio for the simulation
  let tradingPortfolio = newPortfolio(initialCash = 50000.0, commission = 0.001)
  
  # Simulate some price movements and trades
  type TradingDay = tuple[day: int, price: float64]
  
  let priceSeries: seq[TradingDay] = @[
    (1, 100.0),
    (2, 95.0),   # Drop - buy signal
    (3, 90.0),   # Further drop - buy more
    (4, 92.0),
    (5, 110.0),  # Rally - sell half
    (6, 120.0),  # Further rally - sell rest
  ]
  
  var sharesBought = 0.0
  
  for dayData in priceSeries:
    let day = dayData.day
    let price = dayData.price
    echo &"\nDay {day}: Price = ${price:.2f}"
    
    # Simple strategy: buy when price < 95, sell when price > 105
    if price < 95.0 and tradingPortfolio.cash > 1000.0:
      let sharesToBuy = 50.0
      if tradingPortfolio.buy("STOCK", sharesToBuy, price):
        sharesBought += sharesToBuy
        echo &"  → BUY {sharesToBuy:.0f} shares at ${price:.2f}"
        echo &"     Cash: ${tradingPortfolio.cash:.2f}"
    
    elif price > 105.0 and tradingPortfolio.hasPosition("STOCK"):
      let pos = tradingPortfolio.getPosition("STOCK")
      let sharesToSell = pos.quantity / 2.0  # Sell half
      if tradingPortfolio.sell("STOCK", sharesToSell, price):
        echo &"  → SELL {sharesToSell:.0f} shares at ${price:.2f}"
        echo &"     Cash: ${tradingPortfolio.cash:.2f}"
        echo &"     Realized P&L: ${tradingPortfolio.realizedPnL():.2f}"
    
    # Update prices
    var prices = initTable[string, float64]()
    prices["STOCK"] = price
    tradingPortfolio.updatePrices(prices)
    
    echo &"     Equity: ${tradingPortfolio.equity(prices):.2f}"
  
  # Final performance
  echo &"\n  Final Results:"
  var finalPrices = initTable[string, float64]()
  finalPrices["STOCK"] = 120.0
  
  let finalMetrics = tradingPortfolio.calculatePerformance(finalPrices)
  echo &"    Total Return: {finalMetrics.totalReturn:+.2f}%"
  echo &"    Total Trades: {finalMetrics.totalTrades}"
  echo &"    Win Rate: {finalMetrics.winRate:.1f}%"
  echo &"    Profit Factor: {finalMetrics.profitFactor:.2f}"
  
  echo ""
  echo "=" .repeat(60)
  echo "Portfolio example complete!"

when isMainModule:
  main()
