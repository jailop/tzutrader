import std/[tables, times, math, sequtils, strformat, strutils]
import core, data, strategy, portfolio
import declarative/risk_management

type
  BacktestReport* = object
    ## Comprehensive backtest performance report
    symbol*: string               ## Primary symbol tested
    startTime*: int64             ## Backtest start timestamp
    endTime*: int64               ## Backtest end timestamp
    initialCash*: float64         ## Starting capital
    finalValue*: float64          ## Final portfolio value
    totalReturn*: float64         ## Total return percentage
    annualizedReturn*: float64    ## Annualized return percentage
    sharpeRatio*: float64         ## Sharpe ratio (risk-adjusted return)
    maxDrawdown*: float64         ## Maximum drawdown percentage
    maxDrawdownDuration*: int64   ## Max drawdown duration (seconds)
    winRate*: float64             ## Percentage of winning trades
    totalTrades*: int             ## Total number of trades
    winningTrades*: int           ## Number of winning trades
    losingTrades*: int            ## Number of losing trades
    avgWin*: float64              ## Average winning trade
    avgLoss*: float64             ## Average losing trade
    profitFactor*: float64        ## Gross profit / gross loss
    bestTrade*: float64           ## Best single trade P&L
    worstTrade*: float64          ## Worst single trade P&L
    avgTradeReturn*: float64      ## Average return per trade
    totalCommission*: float64     ## Total commissions paid
    # Risk management statistics
    stopLossExits*: int           ## Number of stop-loss exits
    takeProfitExits*: int         ## Number of take-profit exits
    strategyExits*: int           ## Number of strategy-triggered exits
    avgStopLossReturn*: float64   ## Average return on stop-loss exits
    avgTakeProfitReturn*: float64 ## Average return on take-profit exits

  TradeLog* = object
    ## Log entry for a trade event
    timestamp*: int64
    symbol*: string
    action*: Position
    quantity*: float64
    price*: float64
    cash*: float64
    equity*: float64
    reason*: string ## Reason for trade (e.g., "Strategy signal", "Stop-loss", "Take-profit")

  PositionTracker* = object
    ## Track position state for risk management
    symbol*: string
    entryPrice*: float64
    state*: PositionState
    stopLoss*: StopLossRule
    takeProfit*: TakeProfitRule

  Backtester* = ref object
    ## Backtesting engine
    strategy*: Strategy
    portfolio*: Portfolio
    tradeLogs*: seq[TradeLog]
    equityCurve*: seq[tuple[timestamp: int64, equity: float64]]
    verbose*: bool
    # Risk management tracking
    activePositions*: Table[string, PositionTracker]
    riskExits*: seq[TradeLog] ## Exits triggered by risk rules

# ============================================================================
# Backtester Construction
# ============================================================================

proc newBacktester*(strategy: Strategy, config: PortfolioConfig,
    verbose: bool = false): Backtester =
  ## Create a new backtesting engine with portfolio configuration
  ##
  ## Args:
  ##   strategy: Trading strategy to test
  ##   config: Portfolio configuration object
  ##   verbose: Enable verbose logging (default false)
  ##
  ## Returns:
  ##   New Backtester instance
  result = Backtester(
    strategy: strategy,
    portfolio: newPortfolio(config),
    tradeLogs: @[],
    equityCurve: @[],
    verbose: verbose,
    activePositions: initTable[string, PositionTracker](),
    riskExits: @[]
  )

proc newBacktester*(strategy: Strategy, initialCash: float64 = 100000.0,
                   commission: float64 = 0.0,
                       verbose: bool = false): Backtester =
  ## Create a new backtesting engine (legacy overload)
  ##
  ## Args:
  ##   strategy: Trading strategy to test
  ##   initialCash: Starting capital (default $100,000)
  ##   commission: Commission rate (default 0.0)
  ##   verbose: Enable verbose logging (default false)
  ##
  ## Returns:
  ##   New Backtester instance
  result = Backtester(
    strategy: strategy,
    portfolio: newPortfolio(initialCash, commission),
    tradeLogs: @[],
    equityCurve: @[],
    verbose: verbose,
    activePositions: initTable[string, PositionTracker](),
    riskExits: @[]
  )

# ============================================================================
# Signal Execution
# ============================================================================

proc executeSignal(bt: Backtester, signal: Signal, bar: OHLCV) =
  ## Execute a trading signal
  ##
  ## Args:
  ##   signal: Trading signal to execute
  ##   bar: Current price bar

  let symbol = signal.symbol
  let price = signal.price

  case signal.position
  of Position.Buy:
    # Get position sizing from strategy
    let (sizingType, sizingValue) = bt.strategy.getPositionSizing()

    var quantity: float
    case sizingType
    of pstDefault:
      # Default: Use 95% of available cash
      let availableCash = bt.portfolio.cash * 0.95
      quantity = floor(availableCash / price)
    of pstFixed:
      # Fixed: Use exact number of shares
      quantity = sizingValue
    of pstPercent:
      # Percent: Use percentage of portfolio equity
      let portfolioEquity = bt.portfolio.equity()
      let allocationAmount = portfolioEquity * (sizingValue / 100.0)
      quantity = floor(allocationAmount / price)

    if quantity > 0:
      let success = bt.portfolio.buy(symbol, quantity, price, bar.timestamp)

      if success:
        if bt.verbose:
          echo &"[BUY] {bar.timestamp.fromUnix.format(\"yyyy-MM-dd\")} - {symbol}: {quantity:.0f} @ ${price:.2f}"

        bt.tradeLogs.add(TradeLog(
          timestamp: bar.timestamp,
          symbol: symbol,
          action: Position.Buy,
          quantity: quantity,
          price: price,
          cash: bt.portfolio.cash,
          equity: bt.portfolio.equity(),
          reason: "Strategy signal"
        ))

  of Position.Sell:
    # Close entire position if we have one
    if bt.portfolio.hasPosition(symbol):
      let pos = bt.portfolio.getPosition(symbol)
      let success = bt.portfolio.sell(symbol, pos.quantity, price, bar.timestamp)

      if success:
        if bt.verbose:
          echo &"[SELL] {bar.timestamp.fromUnix.format(\"yyyy-MM-dd\")} - {symbol}: {pos.quantity:.0f} @ ${price:.2f}"

        bt.tradeLogs.add(TradeLog(
          timestamp: bar.timestamp,
          symbol: symbol,
          action: Position.Sell,
          quantity: pos.quantity,
          price: price,
          cash: bt.portfolio.cash,
          equity: bt.portfolio.equity(),
          reason: "Strategy signal"
        ))

  of Position.Stay:
    # No action needed
    discard

# ============================================================================
# Risk Management
# ============================================================================

proc executeRiskExit(
  bt: Backtester,
  bar: OHLCV,
  symbol: string,
  reason: string,
  isStopLoss: bool,
  exitPercent: float = 100.0
) =
  ## Execute exit due to risk management trigger
  ##
  ## Args:
  ##   bar: Current price bar
  ##   symbol: Symbol to exit
  ##   reason: Human-readable reason for exit
  ##   isStopLoss: True if stop-loss, false if take-profit
  ##   exitPercent: Percentage of position to exit (default 100%)

  if not bt.portfolio.hasPosition(symbol):
    return

  let pos = bt.portfolio.getPosition(symbol)
  let quantity = if exitPercent >= 100.0:
    pos.quantity
  else:
    floor(pos.quantity * (exitPercent / 100.0))

  if quantity > 0:
    let success = bt.portfolio.sell(symbol, quantity, bar.close, bar.timestamp)

    if success:
      if bt.verbose:
        let exitType = if isStopLoss: "STOP-LOSS" else: "TAKE-PROFIT"
        echo &"[{exitType}] {bar.timestamp.fromUnix.format(\"yyyy-MM-dd\")} - {symbol}: {quantity:.0f} @ ${bar.close:.2f}"
        echo &"  {reason}"

      let tradeLog = TradeLog(
        timestamp: bar.timestamp,
        symbol: symbol,
        action: Position.Sell,
        quantity: quantity,
        price: bar.close,
        cash: bt.portfolio.cash,
        equity: bt.portfolio.equity(),
        reason: reason
      )

      bt.tradeLogs.add(tradeLog)
      bt.riskExits.add(tradeLog)

      # If full exit, remove from active positions
      if exitPercent >= 100.0:
        bt.activePositions.del(symbol)
      # For partial exit, we keep the tracker but could update quantity tracking here if needed

proc checkRiskRules(bt: Backtester, bar: OHLCV, symbol: string) =
  ## Check if stop-loss or take-profit should trigger
  ##
  ## Args:
  ##   bar: Current price bar
  ##   symbol: Symbol to check

  if not bt.activePositions.hasKey(symbol):
    return

  # Skip if we don't have the position anymore
  if not bt.portfolio.hasPosition(symbol):
    bt.activePositions.del(symbol)
    return

  var tracker = bt.activePositions[symbol]

  # Update position state with current price
  tracker.state.updateState(bar.close)
  bt.activePositions[symbol] = tracker # Write back (Nim doesn't have mut refs for table values)
  
  # Get indicator values if needed (for ATR-based stops)
  var indicators = initTable[string, float]()
  # Populate indicators from strategy if available
  if tracker.stopLoss != nil and tracker.stopLoss.kind == slkATRBased:
    let atrRule = ATRBasedStopLoss(tracker.stopLoss)
    let atrValue = bt.strategy.getIndicatorValue(atrRule.atrIndicatorId)
    if not atrValue.isNaN:
      indicators[atrRule.atrIndicatorId] = atrValue

  # Check stop-loss first (higher priority)
  if tracker.stopLoss != nil:
    if tracker.stopLoss.checkStopLoss(tracker.state, indicators):
      # STOP LOSS TRIGGERED
      executeRiskExit(bt, bar, symbol, "Stop-loss triggered", isStopLoss = true)
      return # Exit immediately, don't check take-profit
  
  # Check take-profit
  if tracker.takeProfit != nil:
    let (triggered, exitPercent) = tracker.takeProfit.checkTakeProfit(
        tracker.state, indicators)
    if triggered:
      # TAKE PROFIT TRIGGERED
      let tpReason = if exitPercent >= 100.0:
        "Take-profit triggered (full exit)"
      else:
        &"Take-profit triggered (partial exit: {exitPercent:.0f}%)"
      executeRiskExit(bt, bar, symbol, tpReason, isStopLoss = false, exitPercent)

      # For multi-level take-profit, mark this level as hit
      if tracker.takeProfit.kind == tpkMultiLevel and exitPercent < 100.0:
        # Find which level was hit and mark it
        let profitPct = (tracker.state.currentPrice -
            tracker.state.entryPrice) / tracker.state.entryPrice * 100.0
        let mltp = MultiLevelTakeProfit(tracker.takeProfit)
        for i, level in mltp.levels:
          if profitPct >= level.percentage:
            tracker.state.markLevelHit(i)
            bt.activePositions[symbol] = tracker
            break

# ============================================================================
# Backtesting Engine
# ============================================================================

proc run*(bt: Backtester, data: seq[OHLCV],
    symbol: string = ""): BacktestReport =
  ## Run backtest on historical data
  ##
  ## Args:
  ##   data: Historical OHLCV data
  ##   symbol: Symbol being tested (for reporting)
  ##
  ## Returns:
  ##   Comprehensive backtest report

  if data.len == 0:
    raise newException(ValueError, "Cannot backtest on empty data")

  let sym = if symbol.len > 0: symbol else: "UNKNOWN"

  # Reset strategy and portfolio
  bt.strategy.reset()
  bt.tradeLogs = @[]
  bt.equityCurve = @[]
  bt.activePositions = initTable[string, PositionTracker]()
  bt.riskExits = @[]

  if bt.verbose:
    echo ""
    echo repeat("=", 60)
    echo &"Starting Backtest: {sym}"
    echo &"Period: {data[0].timestamp.fromUnix.format(\"yyyy-MM-dd\")} to {data[^1].timestamp.fromUnix.format(\"yyyy-MM-dd\")}"
    echo &"Bars: {data.len}"
    echo &"Initial Cash: ${bt.portfolio.initialCash:.2f}"
    echo repeat("=", 60)

  # Run strategy on data and execute signals
  for i, bar in data:
    # Check risk management rules FIRST (before strategy signal)
    # This ensures stops are checked before new signals
    if bt.strategy.enableRiskManagement:
      bt.checkRiskRules(bar, sym)

    # Get signal from strategy
    let signal = bt.strategy.onBar(bar)

    # Update portfolio prices
    var prices = initTable[string, float64]()
    prices[sym] = bar.close
    bt.portfolio.updatePrices(prices)

    # Record equity
    bt.equityCurve.add((bar.timestamp, bt.portfolio.equity(prices)))

    # Execute signal if not Stay
    if signal.position != Position.Stay:
      bt.executeSignal(signal, bar)

      # Track position for risk management if Buy signal
      if signal.position == Position.Buy and bt.strategy.enableRiskManagement:
        # Initialize position tracker
        bt.activePositions[sym] = PositionTracker(
          symbol: sym,
          entryPrice: bar.close,
          state: newPositionState(bar.close),
          stopLoss: bt.strategy.stopLossRule,
          takeProfit: bt.strategy.takeProfitRule
        )

  # Close any remaining positions at final price
  let finalBar = data[^1]
  if bt.portfolio.hasPosition(sym):
    let pos = bt.portfolio.getPosition(sym)
    discard bt.portfolio.sell(sym, pos.quantity, finalBar.close,
        finalBar.timestamp)

    if bt.verbose:
      echo &"[CLOSE] Final position closed at ${finalBar.close:.2f}"

  # Calculate final equity
  var finalPrices = initTable[string, float64]()
  finalPrices[sym] = finalBar.close
  let finalEquity = bt.portfolio.equity(finalPrices)

  # Calculate performance metrics
  let metrics = bt.portfolio.calculatePerformance(finalPrices)

  # Calculate additional metrics
  let durationSeconds = data[^1].timestamp - data[0].timestamp
  let durationYears = durationSeconds.float64 / (365.25 * 86400.0)

  let annualizedReturn = if durationYears > 0:
    (pow(finalEquity / bt.portfolio.initialCash, 1.0 / durationYears) - 1.0) * 100.0
  else:
    metrics.totalReturn

  # Calculate total commissions
  var totalCommission = 0.0
  for tx in bt.portfolio.transactions:
    totalCommission += tx.commission

  # Find best and worst trades
  var tradePnLs: seq[float64] = @[]
  var position = 0.0
  var costBasis = 0.0

  for tx in bt.portfolio.transactions:
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
  let avgTradeReturn = if tradePnLs.len > 0: tradePnLs.sum() /
      tradePnLs.len.float64 else: 0.0

  # Calculate max drawdown duration
  var maxDDDuration: int64 = 0
  var peak = bt.portfolio.initialCash
  var peakTime: int64 = data[0].timestamp

  for (timestamp, equity) in bt.equityCurve:
    if equity > peak:
      peak = equity
      peakTime = timestamp
    else:
      let duration = timestamp - peakTime
      if duration > maxDDDuration:
        maxDDDuration = duration

  # Calculate risk management statistics
  var stopLossExits = 0
  var takeProfitExits = 0
  var strategyExits = 0
  var stopLossReturns: seq[float64] = @[]
  var takeProfitReturns: seq[float64] = @[]

  for log in bt.tradeLogs:
    if log.action == Position.Sell:
      if log.reason.contains("Stop-loss"):
        stopLossExits += 1
        # Try to find corresponding entry for return calculation
        # This is simplified - for precise calculation we'd need better tracking
      elif log.reason.contains("Take-profit"):
        takeProfitExits += 1
      elif log.reason.contains("Strategy"):
        strategyExits += 1

  # Calculate average returns for risk exits
  # This is approximate based on tradePnLs - a more precise calculation would track entry/exit pairs
  let avgStopLossReturn = if stopLossExits > 0 and tradePnLs.len > 0:
    # Approximation: assume stop-loss trades are among the losing trades
    let losingTrades = tradePnLs.filterIt(it < 0)
    if losingTrades.len > 0: losingTrades.sum() /
        losingTrades.len.float64 else: 0.0
  else:
    0.0

  let avgTakeProfitReturn = if takeProfitExits > 0 and tradePnLs.len > 0:
    # Approximation: assume take-profit trades are among the winning trades
    let winningTrades = tradePnLs.filterIt(it > 0)
    if winningTrades.len > 0: winningTrades.sum() /
        winningTrades.len.float64 else: 0.0
  else:
    0.0

  # Build report
  result = BacktestReport(
    symbol: sym,
    startTime: data[0].timestamp,
    endTime: data[^1].timestamp,
    initialCash: bt.portfolio.initialCash,
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
    totalCommission: totalCommission,
    stopLossExits: stopLossExits,
    takeProfitExits: takeProfitExits,
    strategyExits: strategyExits,
    avgStopLossReturn: avgStopLossReturn,
    avgTakeProfitReturn: avgTakeProfitReturn
  )

  if bt.verbose:
    echo ""
    echo repeat("=", 60)
    echo "Backtest Complete!"
    echo repeat("=", 60)
    echo $result

# ============================================================================
# Convenience API
# ============================================================================

proc quickBacktest*(symbol: string, strategy: Strategy, data: seq[OHLCV],
                   config: PortfolioConfig,
                       verbose: bool = false): BacktestReport =
  ## Quick backtest with portfolio configuration
  ##
  ## Args:
  ##   symbol: Symbol being tested
  ##   strategy: Trading strategy
  ##   data: Historical OHLCV data
  ##   config: Portfolio configuration object
  ##   verbose: Enable verbose output
  ##
  ## Returns:
  ##   Backtest report

  let bt = newBacktester(strategy, config, verbose)
  result = bt.run(data, symbol)

proc quickBacktest*(symbol: string, strategy: Strategy, data: seq[OHLCV],
                   initialCash: float64 = 100000.0,
                   commission: float64 = 0.0,
                   verbose: bool = false): BacktestReport =
  ## Quick backtest convenience function (legacy overload)
  ##
  ## Args:
  ##   symbol: Symbol being tested
  ##   strategy: Trading strategy
  ##   data: Historical OHLCV data
  ##   initialCash: Starting capital
  ##   commission: Commission rate
  ##   verbose: Enable verbose output
  ##
  ## Returns:
  ##   Backtest report

  let bt = newBacktester(strategy, initialCash, commission, verbose)
  result = bt.run(data, symbol)

proc quickBacktestCSV*(symbol: string, strategy: Strategy, csvPath: string,
                       initialCash: float64 = 100000.0,
                       commission: float64 = 0.0,
                       verbose: bool = false): BacktestReport =
  ## Quick backtest from CSV file
  ##
  ## Args:
  ##   symbol: Symbol being tested
  ##   strategy: Trading strategy
  ##   csvPath: Path to CSV file with OHLCV data
  ##   initialCash: Starting capital
  ##   commission: Commission rate
  ##   verbose: Enable verbose output
  ##
  ## Returns:
  ##   Backtest report

  let data = readCSV(csvPath)
  result = quickBacktest(symbol, strategy, data, initialCash, commission, verbose)

# ============================================================================
# Report Formatting
# ============================================================================

proc `$`*(report: BacktestReport): string =
  ## String representation of backtest report
  let duration = report.endTime - report.startTime
  let durationDays = duration.float64 / 86400.0

  let startDate = report.startTime.fromUnix.format("yyyy-MM-dd")
  let endDate = report.endTime.fromUnix.format("yyyy-MM-dd")

  let ddDuration = report.maxDrawdownDuration.float64 / 86400.0

  result = &"""
Backtest Report: {report.symbol}
{"=" .repeat(60)}
Period: {startDate} to {endDate} ({durationDays:.0f} days)

Capital
  Initial: ${report.initialCash:>15.2f}
  Final:   ${report.finalValue:>15.2f}

Returns
  Total Return:      {report.totalReturn:>10.2f}%
  Annualized Return: {report.annualizedReturn:>10.2f}%
  Sharpe Ratio:      {report.sharpeRatio:>10.2f}

Risk
  Max Drawdown:      {report.maxDrawdown:>10.2f}%
  DD Duration:       {ddDuration:>10.0f} days

Trades
  Total Trades:      {report.totalTrades:>10}
  Winning Trades:    {report.winningTrades:>10}
  Losing Trades:     {report.losingTrades:>10}
  Win Rate:          {report.winRate:>10.1f}%

Trade Statistics
  Profit Factor:     {report.profitFactor:>10.2f}
  Avg Win:          ${report.avgWin:>10.2f}
  Avg Loss:         ${report.avgLoss:>10.2f}
  Best Trade:       ${report.bestTrade:>10.2f}
  Worst Trade:      ${report.worstTrade:>10.2f}
  Avg Trade Return: ${report.avgTradeReturn:>10.2f}

Costs
  Total Commission: ${report.totalCommission:>10.2f}
"""

  # Add risk management section if there were any risk exits
  if report.stopLossExits > 0 or report.takeProfitExits > 0:
    result &= &"""

Risk Management
  Stop-Loss Exits:   {report.stopLossExits:>10}
  Take-Profit Exits: {report.takeProfitExits:>10}
  Strategy Exits:    {report.strategyExits:>10}
  Avg SL Return:    ${report.avgStopLossReturn:>10.2f}
  Avg TP Return:    ${report.avgTakeProfitReturn:>10.2f}
"""

  result &= &"""{"=" .repeat(60)}
"""

proc formatCompact*(report: BacktestReport): string =
  ## Compact one-line summary of backtest report
  result = &"{report.symbol}: Return={report.totalReturn:+.2f}% " &
           &"Sharpe={report.sharpeRatio:.2f} " &
           &"Trades={report.totalTrades} " &
           &"WinRate={report.winRate:.1f}% " &
           &"MaxDD={report.maxDrawdown:.2f}%"
