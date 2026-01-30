## Unit tests for portfolio module

import std/[unittest, times, tables, math, strutils]

include ../src/tzutrader/core
include ../src/tzutrader/portfolio

suite "Portfolio Construction Tests":
  
  test "Create portfolio with default cash":
    let p = newPortfolio()
    check p.initialCash == 100000.0
    check p.cash == 100000.0
    check p.positions.len == 0
    check p.transactions.len == 0
    check p.commission == 0.0
  
  test "Create portfolio with custom cash":
    let p = newPortfolio(initialCash = 50000.0)
    check p.initialCash == 50000.0
    check p.cash == 50000.0
  
  test "Create portfolio with commission":
    let p = newPortfolio(initialCash = 100000.0, commission = 0.001, minCommission = 1.0)
    check p.commission == 0.001
    check p.minCommission == 1.0

suite "Position Management Tests":
  
  test "Buy creates new position":
    let p = newPortfolio(initialCash = 10000.0)
    let success = p.buy("AAPL", 10.0, 150.0)
    
    check success == true
    check p.hasPosition("AAPL")
    check p.cash == 10000.0 - (10.0 * 150.0)  # No commission
    
    let pos = p.getPosition("AAPL")
    check pos.symbol == "AAPL"
    check pos.quantity == 10.0
    check pos.entryPrice == 150.0
    check pos.side == Long
  
  test "Buy with insufficient cash fails":
    let p = newPortfolio(initialCash = 100.0)
    let success = p.buy("AAPL", 10.0, 150.0)  # Needs $1500
    
    check success == false
    check not p.hasPosition("AAPL")
    check p.cash == 100.0  # Cash unchanged
  
  test "Multiple buys average entry price":
    let p = newPortfolio(initialCash = 10000.0)
    
    discard p.buy("AAPL", 10.0, 100.0)  # $1000 total
    discard p.buy("AAPL", 10.0, 200.0)  # $2000 total
    
    let pos = p.getPosition("AAPL")
    check pos.quantity == 20.0
    check pos.entryPrice == 150.0  # Average of 100 and 200
  
  test "Sell reduces position":
    let p = newPortfolio(initialCash = 10000.0)
    
    discard p.buy("AAPL", 10.0, 100.0)
    let success = p.sell("AAPL", 5.0, 120.0)
    
    check success == true
    check p.hasPosition("AAPL")
    
    let pos = p.getPosition("AAPL")
    check pos.quantity == 5.0
    check pos.entryPrice == 100.0  # Entry price doesn't change
  
  test "Sell entire position closes it":
    let p = newPortfolio(initialCash = 10000.0)
    
    discard p.buy("AAPL", 10.0, 100.0)
    let success = p.sell("AAPL", 10.0, 120.0)
    
    check success == true
    check not p.hasPosition("AAPL")
  
  test "Sell without position fails":
    let p = newPortfolio(initialCash = 10000.0)
    let success = p.sell("AAPL", 10.0, 100.0)
    
    check success == false
  
  test "Sell more than position fails":
    let p = newPortfolio(initialCash = 10000.0)
    
    discard p.buy("AAPL", 10.0, 100.0)
    let success = p.sell("AAPL", 15.0, 120.0)
    
    check success == false
    
    let pos = p.getPosition("AAPL")
    check pos.quantity == 10.0  # Position unchanged
  
  test "Close position":
    let p = newPortfolio(initialCash = 10000.0)
    
    discard p.buy("AAPL", 10.0, 100.0)
    let success = p.closePosition("AAPL", 120.0)
    
    check success == true
    check not p.hasPosition("AAPL")
  
  test "Get position for non-existent symbol returns flat":
    let p = newPortfolio()
    let pos = p.getPosition("AAPL")
    
    check pos.side == Flat
    check pos.quantity == 0.0

suite "Commission Tests":
  
  test "Calculate commission with rate":
    let p = newPortfolio(commission = 0.001)  # 0.1%
    let comm = p.calculateCommission(10.0, 100.0)  # $1000 trade
    
    check comm == 1.0
  
  test "Minimum commission applies":
    let p = newPortfolio(commission = 0.001, minCommission = 5.0)
    let comm = p.calculateCommission(1.0, 100.0)  # $100 trade, 0.1% = $0.10
    
    check comm == 5.0  # Minimum applies
  
  test "Buy with commission deducts from cash":
    let p = newPortfolio(initialCash = 10000.0, commission = 0.01)  # 1%
    
    discard p.buy("AAPL", 10.0, 100.0)
    
    let expectedCash = 10000.0 - 1000.0 - 10.0  # Cost + 1% commission
    check abs(p.cash - expectedCash) < 0.01
  
  test "Sell with commission deducts from proceeds":
    let p = newPortfolio(initialCash = 10000.0, commission = 0.01)
    
    discard p.buy("AAPL", 10.0, 100.0, 0)  # Buy with commission
    let cashAfterBuy = p.cash
    
    discard p.sell("AAPL", 10.0, 120.0, 0)  # Sell with commission
    
    let expectedProceeds = 1200.0 - 12.0  # Proceeds - 1% commission
    let expectedCash = cashAfterBuy + expectedProceeds
    check abs(p.cash - expectedCash) < 0.01

suite "Portfolio Valuation Tests":
  
  test "Equity with no positions":
    let p = newPortfolio(initialCash = 10000.0)
    check p.equity() == 10000.0
  
  test "Equity with positions":
    let p = newPortfolio(initialCash = 10000.0)
    
    discard p.buy("AAPL", 10.0, 100.0)  # Spend $1000
    
    var prices = initTable[string, float64]()
    prices["AAPL"] = 120.0  # Price went up
    
    let expectedEquity = 9000.0 + (10.0 * 120.0)  # Cash + position value
    check p.equity(prices) == expectedEquity
  
  test "Market value calculation":
    let p = newPortfolio(initialCash = 10000.0)
    
    discard p.buy("AAPL", 10.0, 100.0)
    discard p.buy("MSFT", 5.0, 200.0)
    
    var prices = initTable[string, float64]()
    prices["AAPL"] = 120.0
    prices["MSFT"] = 220.0
    
    let expectedValue = (10.0 * 120.0) + (5.0 * 220.0)
    check p.equity(prices) == (10000.0 - 1000.0 - 1000.0) + expectedValue
  
  test "Unrealized PnL calculation":
    let p = newPortfolio(initialCash = 10000.0)
    
    discard p.buy("AAPL", 10.0, 100.0)
    
    var prices = initTable[string, float64]()
    prices["AAPL"] = 120.0
    p.updatePrices(prices)
    
    let pnl = p.unrealizedPnL()
    check pnl == 200.0  # (120 - 100) * 10
  
  test "Realized PnL from sale":
    let p = newPortfolio(initialCash = 10000.0)
    
    discard p.buy("AAPL", 10.0, 100.0)
    discard p.sell("AAPL", 10.0, 120.0)
    
    # Realized PnL should be profit minus commission
    # Profit = (120 - 100) * 10 = 200
    # No commission in this test
    check p.realizedPnL() == 200.0
  
  test "Total PnL combines realized and unrealized":
    let p = newPortfolio(initialCash = 10000.0)
    
    discard p.buy("AAPL", 20.0, 100.0)
    discard p.sell("AAPL", 10.0, 120.0)  # Realize profit on half
    
    var prices = initTable[string, float64]()
    prices["AAPL"] = 130.0
    p.updatePrices(prices)
    
    # Realized: (120 - 100) * 10 = 200
    # Unrealized: (130 - 100) * 10 = 300
    # Total: 500
    let total = p.totalPnL()
    check total == 500.0

suite "Transaction History Tests":
  
  test "Buy records transaction":
    let p = newPortfolio(initialCash = 10000.0)
    
    discard p.buy("AAPL", 10.0, 100.0)
    
    check p.transactions.len == 1
    
    let tx = p.transactions[0]
    check tx.symbol == "AAPL"
    check tx.action == Position.Buy
    check tx.quantity == 10.0
    check tx.price == 100.0
  
  test "Sell records transaction":
    let p = newPortfolio(initialCash = 10000.0)
    
    discard p.buy("AAPL", 10.0, 100.0)
    discard p.sell("AAPL", 5.0, 120.0)
    
    check p.transactions.len == 2
    
    let tx = p.transactions[1]
    check tx.action == Position.Sell
    check tx.quantity == 5.0
  
  test "Multiple trades record all transactions":
    let p = newPortfolio(initialCash = 10000.0)
    
    discard p.buy("AAPL", 10.0, 100.0)
    discard p.buy("MSFT", 5.0, 200.0)
    discard p.sell("AAPL", 5.0, 120.0)
    
    check p.transactions.len == 3

suite "Performance Metrics Tests":
  
  test "Total return calculation":
    let p = newPortfolio(initialCash = 10000.0)
    
    discard p.buy("AAPL", 10.0, 100.0)
    
    var prices = initTable[string, float64]()
    prices["AAPL"] = 150.0  # 50% gain on position
    
    let metrics = p.calculatePerformance(prices)
    
    # Equity = 9000 cash + 1500 position = 10500
    # Return = (10500 - 10000) / 10000 = 5%
    check abs(metrics.totalReturn - 5.0) < 0.1
  
  test "Win rate calculation":
    let p = newPortfolio(initialCash = 10000.0)
    
    # Winning trade
    discard p.buy("AAPL", 10.0, 100.0)
    discard p.sell("AAPL", 10.0, 120.0)
    
    # Losing trade
    discard p.buy("MSFT", 10.0, 200.0)
    discard p.sell("MSFT", 10.0, 180.0)
    
    let metrics = p.calculatePerformance()
    
    check metrics.totalTrades == 2
    check metrics.winningTrades == 1
    check metrics.losingTrades == 1
    check metrics.winRate == 50.0
  
  test "Average win and loss":
    let p = newPortfolio(initialCash = 10000.0)
    
    # Win $200
    discard p.buy("AAPL", 10.0, 100.0)
    discard p.sell("AAPL", 10.0, 120.0)
    
    # Lose $200
    discard p.buy("MSFT", 10.0, 200.0)
    discard p.sell("MSFT", 10.0, 180.0)
    
    let metrics = p.calculatePerformance()
    
    check metrics.avgWin == 200.0
    check metrics.avgLoss == -200.0
  
  test "Profit factor calculation":
    let p = newPortfolio(initialCash = 10000.0)
    
    # Win $400
    discard p.buy("AAPL", 10.0, 100.0)
    discard p.sell("AAPL", 10.0, 140.0)
    
    # Lose $200
    discard p.buy("MSFT", 10.0, 200.0)
    discard p.sell("MSFT", 10.0, 180.0)
    
    let metrics = p.calculatePerformance()
    
    # Profit factor = 400 / 200 = 2.0
    check abs(metrics.profitFactor - 2.0) < 0.1
  
  test "Max drawdown calculation":
    let p = newPortfolio(initialCash = 10000.0)
    
    # Peak at 10000
    discard p.buy("AAPL", 50.0, 100.0)  # Spend 5000, equity still ~10000
    
    # Loss
    discard p.sell("AAPL", 50.0, 80.0)  # Lose $1000
    # Equity now ~9000, drawdown = 10%
    
    let metrics = p.calculatePerformance()
    
    # Should have some drawdown
    check metrics.maxDrawdown > 0.0

suite "Position Update Tests":
  
  test "Update position price updates PnL":
    let p = newPortfolio(initialCash = 10000.0)
    
    discard p.buy("AAPL", 10.0, 100.0)
    
    var prices = initTable[string, float64]()
    prices["AAPL"] = 120.0
    p.updatePrices(prices)
    
    let pos = p.getPosition("AAPL")
    check pos.currentPrice == 120.0
    check pos.unrealizedPnL == 200.0
  
  test "Position market value":
    var pos = newPositionInfo("AAPL", Long, 10.0, 100.0)
    pos.updatePrice(120.0)
    
    check pos.marketValue() == 1200.0

suite "Edge Cases Tests":
  
  test "Buy zero quantity fails":
    let p = newPortfolio(initialCash = 10000.0)
    let success = p.buy("AAPL", 0.0, 100.0)
    
    check success == false
  
  test "Sell zero quantity fails":
    let p = newPortfolio(initialCash = 10000.0)
    
    discard p.buy("AAPL", 10.0, 100.0)
    let success = p.sell("AAPL", 0.0, 100.0)
    
    check success == false
  
  test "Buy negative quantity fails":
    let p = newPortfolio(initialCash = 10000.0)
    let success = p.buy("AAPL", -10.0, 100.0)
    
    check success == false
  
  test "Portfolio with zero initial cash":
    let p = newPortfolio(initialCash = 0.0)
    check p.cash == 0.0
    check p.equity() == 0.0

suite "String Representation Tests":
  
  test "Position to string":
    var pos = newPositionInfo("AAPL", Long, 10.0, 100.0)
    pos.updatePrice(120.0)
    
    let s = $pos
    check "AAPL" in s
    check "10.00" in s
  
  test "Portfolio to string":
    let p = newPortfolio(initialCash = 10000.0)
    discard p.buy("AAPL", 10.0, 100.0)
    
    let s = $p
    check "Portfolio" in s
    check "cash" in s
  
  test "PerformanceMetrics to string":
    let p = newPortfolio(initialCash = 10000.0)
    let metrics = p.calculatePerformance()
    
    let s = $metrics
    check "Performance" in s
    check "return" in s

echo "Portfolio module: All tests defined"
