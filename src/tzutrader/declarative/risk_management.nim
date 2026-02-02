import std/[tables, math, options]

type
  StopLossKind* = enum
    ## Type of stop loss rule
    slkNone,            # No stop loss
    slkFixedPercentage, # Fixed % loss
    slkFixedPrice,      # Absolute price level
    slkTrailing,        # Trailing stop
    slkATRBased         # Based on ATR volatility

  TakeProfitKind* = enum
    ## Type of take profit rule
    tpkNone,            # No take profit
    tpkFixedPercentage, # Fixed % profit
    tpkFixedPrice,      # Absolute price level
    tpkRiskReward,      # Risk/reward ratio
    tpkMultiLevel       # Multiple levels for partial exits

  StopLossRule* = ref object of RootObj
    ## Base stop loss rule
    kind*: StopLossKind

  FixedPercentageStopLoss* = ref object of StopLossRule
    ## Stop loss at fixed % below entry
    percentage*: float # % loss to trigger stop (e.g., 5.0 = 5%)

  FixedPriceStopLoss* = ref object of StopLossRule
    ## Stop loss at absolute price level
    price*: float # Absolute price level

  TrailingStopLoss* = ref object of StopLossRule
    ## Trailing stop that moves with profit
    trailPercentage*: float  # Distance to trail behind high (%)
    activationProfit*: float # Profit % before trailing starts

  ATRBasedStopLoss* = ref object of StopLossRule
    ## Stop loss based on ATR volatility
    atrMultiplier*: float   # Stop distance = ATR * multiplier
    atrIndicatorId*: string # ID of ATR indicator

  TakeProfitRule* = ref object of RootObj
    ## Base take profit rule
    kind*: TakeProfitKind

  FixedPercentageTakeProfit* = ref object of TakeProfitRule
    ## Take profit at fixed % gain
    percentage*: float # % profit to trigger exit (e.g., 10.0 = 10%)

  FixedPriceTakeProfit* = ref object of TakeProfitRule
    ## Take profit at absolute price level
    price*: float # Absolute price level

  RiskRewardTakeProfit* = ref object of TakeProfitRule
    ## Take profit based on risk/reward ratio
    ratio*: float               # Profit target = stop distance * ratio
    stopLossRule*: StopLossRule # Reference to stop loss for calculation

  TakeProfitLevel* = object
    ## Single take profit level for partial exits
    percentage*: float  # % profit target
    exitPercent*: float # % of position to exit (e.g., 50.0 = half)

  MultiLevelTakeProfit* = ref object of TakeProfitRule
    ## Multiple take profit levels
    levels*: seq[TakeProfitLevel]

  PositionState* = object
    ## State tracking for a position (needed for trailing stops)
    entryPrice*: float
    highestPrice*: float  # Highest price since entry (for trailing)
    currentPrice*: float
    levelsHit*: seq[bool] # Track which TP levels have been hit

  RiskManagementError* = object of CatchableError
    ## Error in risk management

proc newNoStopLoss*(): StopLossRule =
  ## Create a rule with no stop loss
  result = StopLossRule(kind: slkNone)

proc newFixedPercentageStopLoss*(percentage: float): FixedPercentageStopLoss =
  ## Create fixed percentage stop loss
  ## percentage: % loss to trigger stop (e.g., 5.0 = exit at 5% loss)
  if percentage <= 0.0 or percentage > 50.0:
    raise newException(RiskManagementError, "Stop loss percentage must be between 0 and 50")

  result = FixedPercentageStopLoss(
    kind: slkFixedPercentage,
    percentage: percentage
  )

proc newFixedPriceStopLoss*(price: float): FixedPriceStopLoss =
  ## Create fixed price stop loss
  if price <= 0.0:
    raise newException(RiskManagementError, "Stop loss price must be positive")

  result = FixedPriceStopLoss(
    kind: slkFixedPrice,
    price: price
  )

proc newTrailingStopLoss*(trailPercentage: float,
    activationProfit: float = 0.0): TrailingStopLoss =
  ## Create trailing stop loss
  ## trailPercentage: Distance to trail behind highest price (%)
  ## activationProfit: Profit % before trailing starts (0 = trail immediately)
  if trailPercentage <= 0.0 or trailPercentage > 50.0:
    raise newException(RiskManagementError, "Trail percentage must be between 0 and 50")

  result = TrailingStopLoss(
    kind: slkTrailing,
    trailPercentage: trailPercentage,
    activationProfit: activationProfit
  )

proc newATRBasedStopLoss*(atrMultiplier: float,
    atrIndicatorId: string = "atr_14"): ATRBasedStopLoss =
  ## Create ATR-based stop loss
  ## Stop distance = ATR * atrMultiplier below entry price
  if atrMultiplier <= 0.0:
    raise newException(RiskManagementError, "ATR multiplier must be positive")

  result = ATRBasedStopLoss(
    kind: slkATRBased,
    atrMultiplier: atrMultiplier,
    atrIndicatorId: atrIndicatorId
  )

proc newNoTakeProfit*(): TakeProfitRule =
  ## Create a rule with no take profit
  result = TakeProfitRule(kind: tpkNone)

proc newFixedPercentageTakeProfit*(percentage: float): FixedPercentageTakeProfit =
  ## Create fixed percentage take profit
  if percentage <= 0.0:
    raise newException(RiskManagementError, "Take profit percentage must be positive")

  result = FixedPercentageTakeProfit(
    kind: tpkFixedPercentage,
    percentage: percentage
  )

proc newFixedPriceTakeProfit*(price: float): FixedPriceTakeProfit =
  ## Create fixed price take profit
  if price <= 0.0:
    raise newException(RiskManagementError, "Take profit price must be positive")

  result = FixedPriceTakeProfit(
    kind: tpkFixedPrice,
    price: price
  )

proc newRiskRewardTakeProfit*(ratio: float,
    stopLossRule: StopLossRule): RiskRewardTakeProfit =
  ## Create risk/reward ratio take profit
  ## Profit target = stop loss distance * ratio
  if ratio <= 0.0:
    raise newException(RiskManagementError, "Risk/reward ratio must be positive")

  result = RiskRewardTakeProfit(
    kind: tpkRiskReward,
    ratio: ratio,
    stopLossRule: stopLossRule
  )

proc newMultiLevelTakeProfit*(levels: seq[
    TakeProfitLevel]): MultiLevelTakeProfit =
  ## Create multi-level take profit
  if levels.len == 0:
    raise newException(RiskManagementError, "Must have at least one take profit level")

  # Validate levels
  var totalExit = 0.0
  for level in levels:
    if level.percentage <= 0.0:
      raise newException(RiskManagementError, "Take profit percentage must be positive")
    if level.exitPercent <= 0.0 or level.exitPercent > 100.0:
      raise newException(RiskManagementError, "Exit percent must be between 0 and 100")
    totalExit += level.exitPercent

  if totalExit > 100.0:
    raise newException(RiskManagementError, "Total exit percent exceeds 100%")

  result = MultiLevelTakeProfit(
    kind: tpkMultiLevel,
    levels: levels
  )

method checkStopLoss*(
  rule: StopLossRule,
  state: PositionState,
  indicators: Table[string, float] = initTable[string, float]()
): bool {.base.} =
  ## Check if stop loss has been triggered
  ## Returns true if position should be exited
  ## Base method - must be overridden
  quit "checkStopLoss() must be overridden"

method checkStopLoss*(
  rule: FixedPercentageStopLoss,
  state: PositionState,
  indicators: Table[string, float] = initTable[string, float]()
): bool =
  ## Check fixed percentage stop loss
  let lossPct = (state.entryPrice - state.currentPrice) / state.entryPrice * 100.0
  result = lossPct >= rule.percentage

method checkStopLoss*(
  rule: FixedPriceStopLoss,
  state: PositionState,
  indicators: Table[string, float] = initTable[string, float]()
): bool =
  ## Check fixed price stop loss
  result = state.currentPrice <= rule.price

method checkStopLoss*(
  rule: TrailingStopLoss,
  state: PositionState,
  indicators: Table[string, float] = initTable[string, float]()
): bool =
  ## Check trailing stop loss
  ## Only activates after minimum profit is reached

  let profitPct = (state.highestPrice - state.entryPrice) / state.entryPrice * 100.0

  # Check if trailing should be active
  if profitPct < rule.activationProfit:
    # Not enough profit yet, no trailing
    return false

  # Calculate stop price based on highest price
  let stopPrice = state.highestPrice * (1.0 - rule.trailPercentage / 100.0)
  result = state.currentPrice <= stopPrice

method checkStopLoss*(
  rule: ATRBasedStopLoss,
  state: PositionState,
  indicators: Table[string, float] = initTable[string, float]()
): bool =
  ## Check ATR-based stop loss

  if not indicators.hasKey(rule.atrIndicatorId):
    # ATR not available, can't calculate stop
    return false

  let atr = indicators[rule.atrIndicatorId]
  if atr.isNaN or atr <= 0.0:
    return false

  # Stop price = entry - (ATR * multiplier)
  let stopPrice = state.entryPrice - (atr * rule.atrMultiplier)
  result = state.currentPrice <= stopPrice

method checkTakeProfit*(
  rule: TakeProfitRule,
  state: PositionState,
  indicators: Table[string, float] = initTable[string, float]()
): tuple[triggered: bool, exitPercent: float] {.base.} =
  ## Check if take profit has been triggered
  ## Returns (triggered, exitPercent) where exitPercent is % of position to exit
  ## Base method - must be overridden
  quit "checkTakeProfit() must be overridden"

method checkTakeProfit*(
  rule: FixedPercentageTakeProfit,
  state: PositionState,
  indicators: Table[string, float] = initTable[string, float]()
): tuple[triggered: bool, exitPercent: float] =
  ## Check fixed percentage take profit
  let profitPct = (state.currentPrice - state.entryPrice) / state.entryPrice * 100.0

  if profitPct >= rule.percentage:
    result = (true, 100.0) # Exit entire position
  else:
    result = (false, 0.0)

method checkTakeProfit*(
  rule: FixedPriceTakeProfit,
  state: PositionState,
  indicators: Table[string, float] = initTable[string, float]()
): tuple[triggered: bool, exitPercent: float] =
  ## Check fixed price take profit
  if state.currentPrice >= rule.price:
    result = (true, 100.0)
  else:
    result = (false, 0.0)

method checkTakeProfit*(
  rule: RiskRewardTakeProfit,
  state: PositionState,
  indicators: Table[string, float] = initTable[string, float]()
): tuple[triggered: bool, exitPercent: float] =
  ## Check risk/reward ratio take profit
  ## Calculate profit target based on stop loss distance

  var stopDistance = 0.0

  # Calculate stop distance based on stop loss rule
  case rule.stopLossRule.kind
  of slkFixedPercentage:
    let slRule = FixedPercentageStopLoss(rule.stopLossRule)
    stopDistance = state.entryPrice * (slRule.percentage / 100.0)

  of slkFixedPrice:
    let slRule = FixedPriceStopLoss(rule.stopLossRule)
    stopDistance = state.entryPrice - slRule.price

  of slkATRBased:
    let slRule = ATRBasedStopLoss(rule.stopLossRule)
    if indicators.hasKey(slRule.atrIndicatorId):
      let atr = indicators[slRule.atrIndicatorId]
      if not atr.isNaN and atr > 0.0:
        stopDistance = atr * slRule.atrMultiplier

  of slkTrailing:
    let slRule = TrailingStopLoss(rule.stopLossRule)
    stopDistance = state.entryPrice * (slRule.trailPercentage / 100.0)

  else:
    # No stop loss or unknown type, use default 5%
    stopDistance = state.entryPrice * 0.05

  # Profit target = entry + (stop distance * risk/reward ratio)
  let profitTarget = state.entryPrice + (stopDistance * rule.ratio)

  if state.currentPrice >= profitTarget:
    result = (true, 100.0)
  else:
    result = (false, 0.0)

method checkTakeProfit*(
  rule: MultiLevelTakeProfit,
  state: PositionState,
  indicators: Table[string, float] = initTable[string, float]()
): tuple[triggered: bool, exitPercent: float] =
  ## Check multi-level take profit
  ## Returns first unhit level that has been reached

  result = (false, 0.0)

  let profitPct = (state.currentPrice - state.entryPrice) / state.entryPrice * 100.0

  for i, level in rule.levels:
    # Skip levels that have already been hit
    if i < state.levelsHit.len and state.levelsHit[i]:
      continue

    # Check if this level is reached
    if profitPct >= level.percentage:
      result = (true, level.exitPercent)
      break

proc newPositionState*(entryPrice: float): PositionState =
  ## Create new position state
  result = PositionState(
    entryPrice: entryPrice,
    highestPrice: entryPrice,
    currentPrice: entryPrice,
    levelsHit: @[]
  )

proc updateState*(state: var PositionState, currentPrice: float) =
  ## Update position state with new price
  state.currentPrice = currentPrice
  if currentPrice > state.highestPrice:
    state.highestPrice = currentPrice

proc markLevelHit*(state: var PositionState, levelIndex: int) =
  ## Mark a take profit level as hit
  # Ensure levelsHit is large enough
  while state.levelsHit.len <= levelIndex:
    state.levelsHit.add(false)

  state.levelsHit[levelIndex] = true

proc calculateStopPrice*(rule: StopLossRule, entryPrice: float,
    indicators: Table[string, float] = initTable[string, float]()): Option[float] =
  ## Calculate the actual stop price level
  ## Returns none if stop price cannot be determined

  case rule.kind
  of slkNone:
    result = none(float)

  of slkFixedPercentage:
    let r = FixedPercentageStopLoss(rule)
    result = some(entryPrice * (1.0 - r.percentage / 100.0))

  of slkFixedPrice:
    let r = FixedPriceStopLoss(rule)
    result = some(r.price)

  of slkTrailing:
    # Trailing stop price changes with time, can't predetermine
    result = none(float)

  of slkATRBased:
    let r = ATRBasedStopLoss(rule)
    if indicators.hasKey(r.atrIndicatorId):
      let atr = indicators[r.atrIndicatorId]
      if not atr.isNaN and atr > 0.0:
        result = some(entryPrice - atr * r.atrMultiplier)
      else:
        result = none(float)
    else:
      result = none(float)

proc calculateTakeProfitPrice*(rule: TakeProfitRule, entryPrice: float,
    indicators: Table[string, float] = initTable[string, float]()): Option[float] =
  ## Calculate the actual take profit price level
  ## For multi-level, returns first level
  ## Returns none if price cannot be determined

  case rule.kind
  of tpkNone:
    result = none(float)

  of tpkFixedPercentage:
    let r = FixedPercentageTakeProfit(rule)
    result = some(entryPrice * (1.0 + r.percentage / 100.0))

  of tpkFixedPrice:
    let r = FixedPriceTakeProfit(rule)
    result = some(r.price)

  of tpkRiskReward:
    # Would need stop loss calculation
    result = none(float)

  of tpkMultiLevel:
    let r = MultiLevelTakeProfit(rule)
    if r.levels.len > 0:
      result = some(entryPrice * (1.0 + r.levels[0].percentage / 100.0))
    else:
      result = none(float)
