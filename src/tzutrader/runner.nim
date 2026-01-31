## Runner module for tzutrader - Modern multi-data strategy execution
##
## This module provides a modern strategy execution interface that:
## - Automatically fetches data based on strategy requirements
## - Supports multiple data types simultaneously (OHLCV + Quote + OrderBook, etc.)
## - Synchronizes multiple data streams by timestamp
## - Maintains 100% backward compatibility with existing strategies
##
## Key differences from trader.nim (legacy):
## - trader.nim: User manually fetches data, passes seq[OHLCV]
## - runner.nim: Automatic data fetching based on strategy.getDataRequirements()
##
## Both interfaces coexist - no breaking changes!

import std/[tables, times, math, strformat, strutils]
import core, data, strategy, portfolio, trader
import strategies/base
import data_sync
import datastreamers/[types, api, yahoo_streamer]

# Re-export types from trader for convenience
export trader.BacktestReport, trader.TradeLog

type
  Runner* = ref object
    ## Modern strategy execution engine with multi-data support
    strategy*: Strategy
    portfolio*: Portfolio
    tradeLogs*: seq[TradeLog]
    equityCurve*: seq[tuple[timestamp: int64, equity: float64]]
    verbose*: bool
    syncStrategy*: SyncStrategy  ## How to synchronize multiple streams

# ============================================================================
# Runner Construction
# ============================================================================

proc newRunner*(strategy: Strategy, config: PortfolioConfig, 
                verbose: bool = false,
                syncStrategy: SyncStrategy = ssLeading): Runner =
  ## Create a new runner with portfolio configuration
  ## 
  ## Args:
  ##   strategy: Trading strategy to execute
  ##   config: Portfolio configuration object
  ##   verbose: Enable verbose logging (default false)
  ##   syncStrategy: Stream synchronization strategy (default ssLeading)
  ## 
  ## Returns:
  ##   New Runner instance
  result = Runner(
    strategy: strategy,
    portfolio: newPortfolio(config),
    tradeLogs: @[],
    equityCurve: @[],
    verbose: verbose,
    syncStrategy: syncStrategy
  )

proc newRunner*(strategy: Strategy, initialCash: float64 = 100000.0,
                commission: float64 = 0.0, verbose: bool = false,
                syncStrategy: SyncStrategy = ssLeading): Runner =
  ## Create a new runner (legacy overload)
  ## 
  ## Args:
  ##   strategy: Trading strategy to execute
  ##   initialCash: Starting capital (default $100,000)
  ##   commission: Commission rate (default 0.0)
  ##   verbose: Enable verbose logging (default false)
  ##   syncStrategy: Stream synchronization strategy (default ssLeading)
  ## 
  ## Returns:
  ##   New Runner instance
  result = Runner(
    strategy: strategy,
    portfolio: newPortfolio(initialCash, commission),
    tradeLogs: @[],
    equityCurve: @[],
    verbose: verbose,
    syncStrategy: syncStrategy
  )

# ============================================================================
# Data Fetching
# ============================================================================

proc fetchDataForRequirement(req: DataRequirement, symbol: string,
                             startDate: string, endDate: string,
                             providers: seq[DataProvider]): seq[DataValue] =
  ## Fetch data based on a requirement specification
  ## 
  ## Args:
  ##   req: Data requirement specification
  ##   symbol: Symbol to fetch
  ##   startDate: Start date (YYYY-MM-DD)
  ##   endDate: End date (YYYY-MM-DD)
  ## 
  ## Returns:
  ##   Sequence of DataValue objects
  
  result = @[]
  
  case req.dataKind
  of dkOHLCV:
    # Try preferred providers in order
    var data: seq[OHLCV] = @[]
    var success = false
    
    for provider in providers:
      case provider
      of dpYahoo:
        try:
          # Use streamYahoo from datastreamers/api
          var stream = streamYahoo[OHLCV](symbol, startDate, endDate)
          for bar in stream:
            data.add(bar)
          if data.len > 0:
            success = true
          break
        except Exception as e:
          discard  # Try next provider
      of dpCSV:
        # For CSV, check if path is in metadata
        if req.metadata.hasKey("csv_path"):
          try:
            data = readCSV(req.metadata["csv_path"])
            success = true
            break
          except:
            discard
      else:
        discard
    
    if not success and req.required:
      raise newException(ValueError, 
        &"Failed to fetch required OHLCV data for {symbol}")
    
    # Convert to DataValue
    for bar in data:
      result.add(newDataValue(bar))
  
  of dkQuote:
    # For now, quotes are not implemented in fetchers
    # This would be implemented when quote streaming is added
    if req.required:
      raise newException(ValueError, 
        "Quote data fetching not yet implemented")
  
  else:
    if req.required:
      raise newException(ValueError, 
        &"Data fetching not implemented for {req.dataKind}")

# ============================================================================
# Signal Execution
# ============================================================================

proc executeSignal(runner: Runner, signal: Signal, currentPrice: float64, 
                   timestamp: int64, symbol: string) =
  ## Execute a trading signal
  ## 
  ## Args:
  ##   signal: Trading signal to execute
  ##   currentPrice: Current price for execution
  ##   timestamp: Current timestamp
  ##   symbol: Symbol being traded
  
  let price = signal.price
  
  case signal.position
  of Position.Buy:
    # Get position sizing from strategy
    let (sizingType, sizingValue) = runner.strategy.getPositionSizing()
    
    var quantity: float
    case sizingType
    of pstDefault:
      # Default: Use 95% of available cash
      let availableCash = runner.portfolio.cash * 0.95
      quantity = floor(availableCash / price)
    of pstFixed:
      # Fixed: Use exact number of shares
      quantity = sizingValue
    of pstPercent:
      # Percent: Use percentage of portfolio equity
      let portfolioEquity = runner.portfolio.equity()
      let allocationAmount = portfolioEquity * (sizingValue / 100.0)
      quantity = floor(allocationAmount / price)
    
    if quantity > 0:
      let success = runner.portfolio.buy(symbol, quantity, price, timestamp)
      
      if success:
        if runner.verbose:
          echo &"[BUY] {timestamp.fromUnix.format(\"yyyy-MM-dd\")} - {symbol}: {quantity:.0f} @ ${price:.2f}"
        
        runner.tradeLogs.add(TradeLog(
          timestamp: timestamp,
          symbol: symbol,
          action: Position.Buy,
          quantity: quantity,
          price: price,
          cash: runner.portfolio.cash,
          equity: runner.portfolio.equity()
        ))
  
  of Position.Sell:
    # Close entire position if we have one
    if runner.portfolio.hasPosition(symbol):
      let pos = runner.portfolio.getPosition(symbol)
      let success = runner.portfolio.sell(symbol, pos.quantity, price, timestamp)
      
      if success:
        if runner.verbose:
          echo &"[SELL] {timestamp.fromUnix.format(\"yyyy-MM-dd\")} - {symbol}: {pos.quantity:.0f} @ ${price:.2f}"
        
        runner.tradeLogs.add(TradeLog(
          timestamp: timestamp,
          symbol: symbol,
          action: Position.Sell,
          quantity: pos.quantity,
          price: price,
          cash: runner.portfolio.cash,
          equity: runner.portfolio.equity()
        ))
  
  of Position.Stay:
    # No action needed
    discard

# ============================================================================
# Strategy Execution
# ============================================================================

proc run*(runner: Runner, symbol: string, 
          startDate: string, endDate: string): BacktestReport =
  ## Run strategy with automatic data fetching
  ## 
  ## This is the main entry point for the modern runner interface.
  ## It automatically:
  ## 1. Queries strategy for data requirements
  ## 2. Fetches all required data types
  ## 3. Synchronizes multiple data streams
  ## 4. Executes strategy callbacks (on/onData)
  ## 5. Generates performance report
  ## 
  ## Args:
  ##   symbol: Symbol to trade
  ##   startDate: Start date (YYYY-MM-DD)
  ##   endDate: End date (YYYY-MM-DD)
  ## 
  ## Returns:
  ##   Comprehensive backtest report
  
  # Reset strategy and portfolio
  runner.strategy.reset()
  runner.tradeLogs = @[]
  runner.equityCurve = @[]
  
  if runner.verbose:
    echo ""
    echo repeat("=", 60)
    echo &"Starting Runner: {symbol}"
    echo &"Period: {startDate} to {endDate}"
    echo &"Initial Cash: ${runner.portfolio.initialCash:.2f}"
    echo repeat("=", 60)
  
  # 1. Get data requirements from strategy
  let requirements = runner.strategy.getDataRequirements()
  
  if requirements.len == 0:
    raise newException(ValueError, "Strategy returned no data requirements")
  
  if runner.verbose:
    echo &"Data requirements: {requirements.len}"
    for req in requirements:
      echo &"  - {req.dataKind} (required={req.required})"
  
  # 2. Fetch all required data
  var streamSet = newStreamSet(runner.syncStrategy)
  
  for req in requirements:
    # Use default providers if none specified
    var providers = req.providers
    if providers.len == 0:
      # Add default providers based on dataKind
      case req.dataKind
      of dkOHLCV:
        providers = @[dpYahoo, dpCoinbase]
      of dkQuote:
        providers = @[dpYahoo]
      else:
        discard
    
    let data = fetchDataForRequirement(req, symbol, startDate, endDate, providers)
    
    if data.len == 0 and req.required:
      raise newException(ValueError, 
        &"No data fetched for required {req.dataKind}")
    
    if data.len > 0:
      let stream = newDataStream(req.dataKind, req.required, data)
      streamSet.addStream(stream)
      
      if runner.verbose:
        echo &"  Fetched {data.len} {req.dataKind} data points"
  
  if streamSet.streams.len == 0:
    raise newException(ValueError, "No data streams available")
  
  # 3. Synchronize and execute
  var barCount = 0
  
  for ctx in streamSet.synchronize():
    barCount += 1
    
    # Get signal from strategy
    var signal: Signal
    
    if requirements.len == 1 and requirements[0].dataKind == dkOHLCV:
      # Single OHLCV data - use on() callback (new interface)
      let bar = ctx.getOHLCV()
      signal = runner.strategy.on(bar)
    else:
      # Multi-data or non-OHLCV - use onData(ctx) callback
      signal = runner.strategy.onData(ctx)
    
    # Get current price from OHLCV data (required for portfolio valuation)
    let bar = ctx.getOHLCV()  # Leading stream must be OHLCV
    
    # Update portfolio prices
    var prices = initTable[string, float64]()
    prices[symbol] = bar.close
    runner.portfolio.updatePrices(prices)
    
    # Record equity
    runner.equityCurve.add((ctx.timestamp, runner.portfolio.equity(prices)))
    
    # Execute signal if not Stay
    if signal.position != Position.Stay:
      runner.executeSignal(signal, bar.close, ctx.timestamp, symbol)
  
  if runner.verbose:
    echo &"Processed {barCount} data points"
  
  # 4. Close any remaining positions at final price
  if streamSet.streams.len > 0:
    # Get final OHLCV bar
    var finalBar: OHLCV
    for stream in streamSet.streams:
      if stream.kind == dkOHLCV and stream.data.len > 0:
        finalBar = stream.data[^1].ohlcv
        break
    
    if runner.portfolio.hasPosition(symbol):
      let pos = runner.portfolio.getPosition(symbol)
      discard runner.portfolio.sell(symbol, pos.quantity, finalBar.close, finalBar.timestamp)
      
      if runner.verbose:
        echo &"[CLOSE] Final position closed at ${finalBar.close:.2f}"
    
    # Calculate final equity
    var finalPrices = initTable[string, float64]()
    finalPrices[symbol] = finalBar.close
    let finalEquity = runner.portfolio.equity(finalPrices)
    
    # Calculate performance metrics
    let metrics = runner.portfolio.calculatePerformance(finalPrices)
    
    # Calculate additional metrics
    let durationSeconds = finalBar.timestamp - streamSet.streams[0].data[0].getTimestamp()
    let durationYears = durationSeconds.float64 / (365.25 * 86400.0)
    
    let annualizedReturn = if durationYears > 0:
      (pow(finalEquity / runner.portfolio.initialCash, 1.0 / durationYears) - 1.0) * 100.0
    else:
      metrics.totalReturn
    
    # Calculate total commissions
    var totalCommission = 0.0
    for tx in runner.portfolio.transactions:
      totalCommission += tx.commission
    
    # Find best and worst trades
    var tradePnLs: seq[float64] = @[]
    var position = 0.0
    var costBasis = 0.0
    
    for tx in runner.portfolio.transactions:
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
    var peak = runner.portfolio.initialCash
    var peakTime: int64 = streamSet.streams[0].data[0].getTimestamp()
    
    for (timestamp, equity) in runner.equityCurve:
      if equity > peak:
        peak = equity
        peakTime = timestamp
      else:
        let duration = timestamp - peakTime
        if duration > maxDDDuration:
          maxDDDuration = duration
    
    # Build report
    result = BacktestReport(
      symbol: symbol,
      startTime: streamSet.streams[0].data[0].getTimestamp(),
      endTime: finalBar.timestamp,
      initialCash: runner.portfolio.initialCash,
      finalValue: finalEquity,
      totalReturn: metrics.totalReturn,
      annualizedReturn: annualizedReturn,
      sharpeRatio: metrics.sharpeRatio,
      maxDrawdown: metrics.maxDrawdown,
      maxDrawdownDuration: maxDDDuration,
      winRate: metrics.winRate,
      totalTrades: metrics.totalTrades,
      winningTrades: metrics.winningTrades,
      losingTrades: metrics.losingTrades,
      avgWin: metrics.avgWin,
      avgLoss: metrics.avgLoss,
      profitFactor: metrics.profitFactor,
      bestTrade: bestTrade,
      worstTrade: worstTrade,
      avgTradeReturn: avgTradeReturn,
      totalCommission: totalCommission
    )
    
    if runner.verbose:
      echo ""
      echo repeat("=", 60)
      echo "Runner Complete!"
      echo repeat("=", 60)
      echo $result

proc runWithData*(runner: Runner, symbol: string, 
                  data: seq[OHLCV]): BacktestReport =
  ## Run strategy with pre-loaded OHLCV data (backward compatibility)
  ## 
  ## This provides backward compatibility with the trader.nim interface.
  ## Users can still manually fetch data and pass it to the runner.
  ## 
  ## Args:
  ##   symbol: Symbol being traded
  ##   data: Pre-loaded OHLCV data
  ## 
  ## Returns:
  ##   Comprehensive backtest report
  
  if data.len == 0:
    raise newException(ValueError, "Cannot run on empty data")
  
  # Reset strategy and portfolio
  runner.strategy.reset()
  runner.tradeLogs = @[]
  runner.equityCurve = @[]
  
  if runner.verbose:
    echo ""
    echo repeat("=", 60)
    echo &"Starting Runner: {symbol}"
    echo &"Period: {data[0].timestamp.fromUnix.format(\"yyyy-MM-dd\")} to {data[^1].timestamp.fromUnix.format(\"yyyy-MM-dd\")}"
    echo &"Bars: {data.len}"
    echo &"Initial Cash: ${runner.portfolio.initialCash:.2f}"
    echo repeat("=", 60)
  
  # Run strategy on data
  for i, bar in data:
    # Get signal from strategy (use on() - new interface)
    let signal = runner.strategy.on(bar)
    
    # Update portfolio prices
    var prices = initTable[string, float64]()
    prices[symbol] = bar.close
    runner.portfolio.updatePrices(prices)
    
    # Record equity
    runner.equityCurve.add((bar.timestamp, runner.portfolio.equity(prices)))
    
    # Execute signal if not Stay
    if signal.position != Position.Stay:
      runner.executeSignal(signal, bar.close, bar.timestamp, symbol)
  
  # Close any remaining positions at final price
  let finalBar = data[^1]
  if runner.portfolio.hasPosition(symbol):
    let pos = runner.portfolio.getPosition(symbol)
    discard runner.portfolio.sell(symbol, pos.quantity, finalBar.close, finalBar.timestamp)
    
    if runner.verbose:
      echo &"[CLOSE] Final position closed at ${finalBar.close:.2f}"
  
  # Calculate final equity
  var finalPrices = initTable[string, float64]()
  finalPrices[symbol] = finalBar.close
  let finalEquity = runner.portfolio.equity(finalPrices)
  
  # Calculate performance metrics (reuse logic from run())
  let metrics = runner.portfolio.calculatePerformance(finalPrices)
  
  let durationSeconds = data[^1].timestamp - data[0].timestamp
  let durationYears = durationSeconds.float64 / (365.25 * 86400.0)
  
  let annualizedReturn = if durationYears > 0:
    (pow(finalEquity / runner.portfolio.initialCash, 1.0 / durationYears) - 1.0) * 100.0
  else:
    metrics.totalReturn
  
  var totalCommission = 0.0
  for tx in runner.portfolio.transactions:
    totalCommission += tx.commission
  
  var tradePnLs: seq[float64] = @[]
  var position = 0.0
  var costBasis = 0.0
  
  for tx in runner.portfolio.transactions:
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
  
  var maxDDDuration: int64 = 0
  var peak = runner.portfolio.initialCash
  var peakTime: int64 = data[0].timestamp
  
  for (timestamp, equity) in runner.equityCurve:
    if equity > peak:
      peak = equity
      peakTime = timestamp
    else:
      let duration = timestamp - peakTime
      if duration > maxDDDuration:
        maxDDDuration = duration
  
  result = BacktestReport(
    symbol: symbol,
    startTime: data[0].timestamp,
    endTime: data[^1].timestamp,
    initialCash: runner.portfolio.initialCash,
    finalValue: finalEquity,
    totalReturn: metrics.totalReturn,
    annualizedReturn: annualizedReturn,
    sharpeRatio: metrics.sharpeRatio,
    maxDrawdown: metrics.maxDrawdown,
    maxDrawdownDuration: maxDDDuration,
    winRate: metrics.winRate,
    totalTrades: metrics.totalTrades,
    winningTrades: metrics.winningTrades,
    losingTrades: metrics.losingTrades,
    avgWin: metrics.avgWin,
    avgLoss: metrics.avgLoss,
    profitFactor: metrics.profitFactor,
    bestTrade: bestTrade,
    worstTrade: worstTrade,
    avgTradeReturn: avgTradeReturn,
    totalCommission: totalCommission
  )
  
  if runner.verbose:
    echo ""
    echo repeat("=", 60)
    echo "Runner Complete!"
    echo repeat("=", 60)
    echo $result
