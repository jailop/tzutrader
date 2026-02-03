import std/[tables, times, math, sequtils, strformat]
import core

type
  PositionSide* = enum
    ## Position direction
    Long = "LONG"   ## Long position (own the asset)
    Short = "SHORT" ## Short position (borrowed/sold)
    Flat = "FLAT"   ## No position

  PortfolioConfig* = object
    ## Configuration for portfolio initialization
    ## All fields have defaults suitable for auto-generation by cligen
    initialCash*: float64 ## Starting capital (default: 100000.0)
    commission*: float64 ## Commission rate as decimal (default: 0.0, e.g., 0.001 = 0.1%)
    minCommission*: float64 ## Minimum commission per trade (default: 0.0)
    riskFreeRate*: float64 ## Risk-free rate for Sharpe ratio (default: 0.02 = 2%)

  PositionInfo* = object
    ## Information about an open position
    symbol*: string         ## Symbol/ticker
    side*: PositionSide     ## Long, Short, or Flat
    quantity*: float64      ## Number of shares/units
    entryPrice*: float64    ## Average entry price
    entryTime*: int64       ## First entry timestamp
    currentPrice*: float64  ## Latest market price
    unrealizedPnL*: float64 ## Unrealized profit/loss
    realizedPnL*: float64   ## Realized profit/loss from partial closes

  Portfolio* = ref object
    ## Portfolio with cash and position tracking
    initialCash*: float64                   ## Starting cash
    cash*: float64                          ## Current available cash
    positions*: Table[string, PositionInfo] ## Open positions by symbol
    transactions*: seq[Transaction]         ## Transaction history
    commission*: float64                    ## Commission rate (0.001 = 0.1%)
    minCommission*: float64                 ## Minimum commission per trade
    totalRealizedPnL*: float64              ## Total realized P&L from all closed trades
    riskFreeRate*: float64                  ## Risk-free rate for performance metrics

  PerformanceMetrics* = object
    ## Portfolio performance metrics
    totalReturn*: float64      ## Total return percentage
    annualizedReturn*: float64 ## Annualized return percentage
    sharpeRatio*: float64      ## Sharpe ratio (risk-adjusted return)
    maxDrawdown*: float64      ## Maximum drawdown percentage
    winRate*: float64          ## Percentage of winning trades
    totalTrades*: int          ## Total number of trades
    winningTrades*: int        ## Number of winning trades
    losingTrades*: int         ## Number of losing trades
    avgWin*: float64           ## Average winning trade
    avgLoss*: float64          ## Average losing trade
    profitFactor*: float64     ## Ratio of gross profit to gross loss

proc defaultPortfolioConfig*(): PortfolioConfig =
  ## Create default portfolio configuration
  ## These defaults are used when parameters are not specified in CLI
  result = PortfolioConfig(
    initialCash: 100000.0,
    commission: 0.0,
    minCommission: 0.0,
    riskFreeRate: 0.02
  )

proc newPortfolio*(config: PortfolioConfig): Portfolio =
  ## Create a new portfolio from configuration object
  ##
  ## Args:
  ##   config: Portfolio configuration with all parameters
  ##
  ## Returns:
  ##   New Portfolio instance
  result = Portfolio(
    initialCash: config.initialCash,
    cash: config.initialCash,
    positions: initTable[string, PositionInfo](),
    transactions: @[],
    commission: config.commission,
    minCommission: config.minCommission,
    totalRealizedPnL: 0.0,
    riskFreeRate: config.riskFreeRate
  )

proc newPortfolio*(initialCash: float64 = 100000.0,
                   commission: float64 = 0.0,
                   minCommission: float64 = 0.0): Portfolio =
  ## Create a new portfolio with initial cash (legacy overload)
  ##
  ## Args:
  ##   initialCash: Starting capital (default $100,000)
  ##   commission: Commission rate as decimal (default 0.0, e.g., 0.001 = 0.1%)
  ##   minCommission: Minimum commission per trade (default $0)
  ##
  ## Returns:
  ##   New Portfolio instance
  let config = PortfolioConfig(
    initialCash: initialCash,
    commission: commission,
    minCommission: minCommission,
    riskFreeRate: 0.02
  )
  result = newPortfolio(config)

proc newPositionInfo(symbol: string, side: PositionSide, quantity: float64,
                     entryPrice: float64, entryTime: int64 = 0): PositionInfo =
  ## Create a new position info object
  let timestamp = if entryTime == 0: getTime().toUnix() else: entryTime
  result = PositionInfo(
    symbol: symbol,
    side: side,
    quantity: quantity,
    entryPrice: entryPrice,
    entryTime: timestamp,
    currentPrice: entryPrice,
    unrealizedPnL: 0.0,
    realizedPnL: 0.0
  )

proc updatePrice*(pos: var PositionInfo, currentPrice: float64) =
  ## Update position with current market price and recalculate P&L
  pos.currentPrice = currentPrice

  case pos.side
  of Long:
    pos.unrealizedPnL = (currentPrice - pos.entryPrice) * pos.quantity
  of Short:
    pos.unrealizedPnL = (pos.entryPrice - currentPrice) * pos.quantity
  of Flat:
    pos.unrealizedPnL = 0.0

proc marketValue*(pos: PositionInfo): float64 =
  ## Get current market value of position
  case pos.side
  of Long:
    result = pos.quantity * pos.currentPrice
  of Short:
    # For short positions, value is negative (liability)
    result = -pos.quantity * pos.currentPrice
  of Flat:
    result = 0.0

proc totalPnL*(pos: PositionInfo): float64 =
  ## Get total P&L (realized + unrealized)
  result = pos.realizedPnL + pos.unrealizedPnL

proc hasPosition*(p: Portfolio, symbol: string): bool =
  ## Check if portfolio has an open position in symbol
  result = p.positions.hasKey(symbol) and p.positions[symbol].quantity > 0.0

proc getPosition*(p: Portfolio, symbol: string): PositionInfo =
  ## Get position info for a symbol (returns flat position if none exists)
  if p.hasPosition(symbol):
    result = p.positions[symbol]
  else:
    result = newPositionInfo(symbol, Flat, 0.0, 0.0)

proc equity*(p: Portfolio, currentPrices: Table[string, float64] = initTable[
    string, float64]()): float64 =
  ## Calculate total portfolio equity (cash + position values)
  ##
  ## Args:
  ##   currentPrices: Optional table of current prices for positions
  ##
  ## Returns:
  ##   Total equity value
  result = p.cash

  for symbol, pos in p.positions:
    # Update price if provided
    if currentPrices.hasKey(symbol):
      var updatedPos = pos
      updatedPos.updatePrice(currentPrices[symbol])
      result += updatedPos.marketValue()
    else:
      result += pos.marketValue()

proc marketValue*(p: Portfolio): float64 =
  ## Get total market value of all positions (excludes cash)
  result = 0.0
  for pos in p.positions.values:
    result += pos.marketValue()

proc unrealizedPnL*(p: Portfolio): float64 =
  ## Get total unrealized P&L across all positions
  result = 0.0
  for pos in p.positions.values:
    result += pos.unrealizedPnL

proc realizedPnL*(p: Portfolio): float64 =
  ## Get total realized P&L from all closed and partially closed positions
  result = p.totalRealizedPnL
  # Also include realized PnL from currently open positions (partial closes)
  for pos in p.positions.values:
    result += pos.realizedPnL

proc totalPnL*(p: Portfolio): float64 =
  ## Get total P&L (realized + unrealized)
  result = p.realizedPnL() + p.unrealizedPnL()

proc calculateCommission*(p: Portfolio, quantity: float64,
    price: float64): float64 =
  ## Calculate commission for a trade
  ##
  ## Args:
  ##   quantity: Number of shares/units
  ##   price: Price per share
  ##
  ## Returns:
  ##   Commission amount
  let tradeValue = abs(quantity) * price
  result = max(tradeValue * p.commission, p.minCommission)

proc buy*(p: Portfolio, symbol: string, quantity: float64, price: float64,
          timestamp: int64 = 0): bool =
  ## Execute a buy order (open or add to long position)
  ##
  ## Args:
  ##   symbol: Symbol to buy
  ##   quantity: Number of shares (must be positive)
  ##   price: Price per share
  ##   timestamp: Optional transaction timestamp (uses current time if 0)
  ##
  ## Returns:
  ##   True if order executed successfully, False if insufficient cash
  if quantity <= 0:
    return false

  let comm = p.calculateCommission(quantity, price)
  let totalCost = quantity * price + comm

  # Check if we have enough cash
  if p.cash < totalCost:
    return false

  # Deduct cash
  p.cash -= totalCost

  # Update or create position
  let txTime = if timestamp == 0: getTime().toUnix() else: timestamp

  if p.hasPosition(symbol):
    var pos = p.positions[symbol]

    # Calculate new average entry price
    let totalQuantity = pos.quantity + quantity
    let totalCost = (pos.quantity * pos.entryPrice) + (quantity * price)
    pos.entryPrice = totalCost / totalQuantity
    pos.quantity = totalQuantity
    pos.updatePrice(price)

    p.positions[symbol] = pos
  else:
    # Create new position
    var pos = newPositionInfo(symbol, Long, quantity, price, txTime)
    pos.updatePrice(price)
    p.positions[symbol] = pos

  # Record transaction
  p.transactions.add(Transaction(
    timestamp: txTime,
    symbol: symbol,
    action: Position.Buy,
    quantity: quantity,
    price: price,
    commission: comm
  ))

  result = true

proc sell*(p: Portfolio, symbol: string, quantity: float64, price: float64,
           timestamp: int64 = 0): bool =
  ## Execute a sell order (close or reduce long position)
  ##
  ## Args:
  ##   symbol: Symbol to sell
  ##   quantity: Number of shares (must be positive)
  ##   price: Price per share
  ##   timestamp: Optional transaction timestamp (uses current time if 0)
  ##
  ## Returns:
  ##   True if order executed successfully, False if insufficient position
  if quantity <= 0:
    return false

  # Check if we have the position
  if not p.hasPosition(symbol):
    return false

  var pos = p.positions[symbol]

  # Check if we have enough shares
  if pos.quantity < quantity:
    return false

  let comm = p.calculateCommission(quantity, price)
  let proceeds = quantity * price - comm

  # Calculate realized P&L for this sale
  let realizedPnL = (price - pos.entryPrice) * quantity - comm
  pos.realizedPnL += realizedPnL

  # Add proceeds to cash
  p.cash += proceeds

  # Update position
  pos.quantity -= quantity
  pos.updatePrice(price)

  if pos.quantity > 0:
    p.positions[symbol] = pos
  else:
    # Position fully closed - move realized PnL to portfolio total
    p.totalRealizedPnL += pos.realizedPnL
    p.positions.del(symbol)

  # Record transaction
  let txTime = if timestamp == 0: getTime().toUnix() else: timestamp
  p.transactions.add(Transaction(
    timestamp: txTime,
    symbol: symbol,
    action: Position.Sell,
    quantity: quantity,
    price: price,
    commission: comm
  ))

  result = true

proc closePosition*(p: Portfolio, symbol: string, price: float64,
                    timestamp: int64 = 0): bool =
  ## Close entire position in a symbol
  ##
  ## Args:
  ##   symbol: Symbol to close
  ##   price: Closing price
  ##   timestamp: Optional transaction timestamp
  ##
  ## Returns:
  ##   True if position closed, False if no position exists
  if not p.hasPosition(symbol):
    return false

  let pos = p.positions[symbol]
  result = p.sell(symbol, pos.quantity, price, timestamp)

proc updatePrices*(p: Portfolio, prices: Table[string, float64]) =
  ## Update all position prices with current market prices
  ##
  ## Args:
  ##   prices: Table of symbol -> current price
  for symbol, price in prices:
    if p.hasPosition(symbol):
      var pos = p.positions[symbol]
      pos.updatePrice(price)
      p.positions[symbol] = pos

proc calculatePerformance*(p: Portfolio,
                           currentPrices: Table[string, float64] = initTable[
                               string, float64]()): PerformanceMetrics =
  ## Calculate comprehensive performance metrics
  ##
  ## Args:
  ##   currentPrices: Current market prices for open positions
  ##
  ## Returns:
  ##   Performance metrics (uses portfolio's riskFreeRate for Sharpe ratio)

  result = PerformanceMetrics()

  # Calculate total return
  let currentEquity = p.equity(currentPrices)
  result.totalReturn = ((currentEquity - p.initialCash) / p.initialCash) * 100.0

  # Analyze trades
  var wins: seq[float64] = @[]
  var losses: seq[float64] = @[]

  # Group transactions by symbol to track round trips
  var roundTrips: Table[string, seq[Transaction]] = initTable[string, seq[
      Transaction]]()

  for tx in p.transactions:
    if not roundTrips.hasKey(tx.symbol):
      roundTrips[tx.symbol] = @[]
    roundTrips[tx.symbol].add(tx)

  # Calculate per-trade P&L
  for symbol, txs in roundTrips:
    var position = 0.0
    var costBasis = 0.0

    for tx in txs:
      case tx.action
      of Position.Buy:
        let totalCost = tx.quantity * tx.price + tx.commission
        costBasis += totalCost
        position += tx.quantity
      of Position.Sell:
        if position > 0:
          let avgCost = costBasis / position
          let pnl = (tx.price - avgCost) * tx.quantity - tx.commission

          if pnl > 0:
            wins.add(pnl)
          else:
            losses.add(pnl)

          # Update position
          let percentSold = tx.quantity / position
          costBasis *= (1.0 - percentSold)
          position -= tx.quantity
      else:
        discard

  # Calculate trade statistics
  result.totalTrades = wins.len + losses.len
  result.winningTrades = wins.len
  result.losingTrades = losses.len

  if result.totalTrades > 0:
    result.winRate = (result.winningTrades.float64 /
        result.totalTrades.float64) * 100.0

  if wins.len > 0:
    result.avgWin = wins.sum() / wins.len.float64

  if losses.len > 0:
    result.avgLoss = losses.sum() / losses.len.float64

  # Calculate profit factor
  let grossProfit = if wins.len > 0: wins.sum() else: 0.0
  let grossLoss = if losses.len > 0: abs(losses.sum()) else: 0.0

  if grossLoss > 0:
    result.profitFactor = grossProfit / grossLoss
  else:
    result.profitFactor = if grossProfit > 0: Inf else: 0.0

  # Calculate max drawdown
  var peak = p.initialCash
  var maxDD = 0.0

  # Build equity curve from transactions
  var equity = p.initialCash
  for tx in p.transactions:
    case tx.action
    of Position.Buy:
      equity -= (tx.quantity * tx.price + tx.commission)
    of Position.Sell:
      equity += (tx.quantity * tx.price - tx.commission)
    else:
      discard

    if equity > peak:
      peak = equity

    let drawdown = ((peak - equity) / peak) * 100.0
    if drawdown > maxDD:
      maxDD = drawdown

  result.maxDrawdown = maxDD

  # Calculate Sharpe ratio (simplified - assumes daily returns)
  # For more accurate Sharpe, we'd need time-series of returns
  if result.totalTrades > 1:
    var returns: seq[float64] = @[]
    var prevEquity = p.initialCash

    for tx in p.transactions:
      var currentEquity = prevEquity
      case tx.action
      of Position.Buy:
        currentEquity -= (tx.quantity * tx.price + tx.commission)
      of Position.Sell:
        currentEquity += (tx.quantity * tx.price - tx.commission)
      else:
        discard

      let ret = (currentEquity - prevEquity) / prevEquity
      returns.add(ret)
      prevEquity = currentEquity

    if returns.len > 1:
      let avgReturn = returns.sum() / returns.len.float64
      let variance = returns.mapIt(pow(it - avgReturn, 2.0)).sum() / (
          returns.len - 1).float64
      let stdDev = sqrt(variance)

      if stdDev > 0:
        # Annualized Sharpe (assuming 252 trading days)
        result.sharpeRatio = (avgReturn - p.riskFreeRate / 252.0) / stdDev *
            sqrt(252.0)

  # Calculate annualized return (simplified)
  # For accurate annualization, we'd need actual time period
  result.annualizedReturn = result.totalReturn # Placeholder

proc `$`*(pos: PositionInfo): string =
  ## String representation of Position
  result = &"Position({pos.symbol}, {pos.side}, qty={pos.quantity:.2f}, " &
           &"entry=${pos.entryPrice:.2f}, current=${pos.currentPrice:.2f}, " &
           &"PnL=${pos.totalPnL():.2f})"

proc `$`*(p: Portfolio): string =
  ## String representation of Portfolio
  result = &"Portfolio(cash=${p.cash:.2f}, positions={p.positions.len}, " &
           &"equity=${p.equity():.2f})"

proc `$`*(m: PerformanceMetrics): string =
  ## String representation of PerformanceMetrics
  result = &"Performance(return={m.totalReturn:.2f}%, trades={m.totalTrades}, " &
           &"winRate={m.winRate:.1f}%, sharpe={m.sharpeRatio:.2f}, " &
           &"maxDD={m.maxDrawdown:.2f}%)"
