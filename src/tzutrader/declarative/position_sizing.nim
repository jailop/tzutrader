import std/[tables, math]

type
  PositionSizerKind* = enum
    ## Type of position sizing strategy
    pskFixedPercentage, # Use X% of available capital
    pskFixedShares,     # Buy fixed number of shares
    pskEqualWeight,     # Equal weight across all positions
    pskRiskBased,       # Size based on risk per trade
    pskKelly            # Kelly Criterion

  PositionSizer* = ref object of RootObj
    ## Base position sizer interface
    kind*: PositionSizerKind

  FixedPercentageSizer* = ref object of PositionSizer
    ## Size position as fixed percentage of capital
    percentage*: float # Percentage of capital to use (0-100)

  FixedSharesSizer* = ref object of PositionSizer
    ## Always trade fixed number of shares
    shares*: int # Fixed number of shares

  EqualWeightSizer* = ref object of PositionSizer
    ## Equal weight across N positions
    numPositions*: int # Total number of positions to maintain

  RiskBasedSizer* = ref object of PositionSizer
    ## Size based on risk per trade and ATR
    riskPerTrade*: float    # % of capital to risk per trade
    atrMultiplier*: float   # Stop loss distance = ATR * multiplier
    atrIndicatorId*: string # ID of ATR indicator to use

  KellySizer* = ref object of PositionSizer
    ## Kelly Criterion sizing (advanced)
    winRate*: float       # Historical win rate (0-1)
    avgWinLoss*: float    # Avg win / Avg loss ratio
    kellyFraction*: float # Fraction of Kelly to use (0-1, typically 0.25-0.5)

  SizingError* = object of CatchableError
    ## Error during position sizing calculation

proc newFixedPercentageSizer*(percentage: float): FixedPercentageSizer =
  ## Create fixed percentage sizer
  ## percentage: 0-100 (e.g., 100 = use all capital, 50 = use half)
  if percentage <= 0.0 or percentage > 100.0:
    raise newException(SizingError, "Percentage must be between 0 and 100")

  result = FixedPercentageSizer(
    kind: pskFixedPercentage,
    percentage: percentage
  )

proc newFixedSharesSizer*(shares: int): FixedSharesSizer =
  ## Create fixed shares sizer
  if shares <= 0:
    raise newException(SizingError, "Shares must be positive")

  result = FixedSharesSizer(
    kind: pskFixedShares,
    shares: shares
  )

proc newEqualWeightSizer*(numPositions: int): EqualWeightSizer =
  ## Create equal weight sizer
  if numPositions <= 0:
    raise newException(SizingError, "Number of positions must be positive")

  result = EqualWeightSizer(
    kind: pskEqualWeight,
    numPositions: numPositions
  )

proc newRiskBasedSizer*(riskPerTrade: float, atrMultiplier: float,
    atrIndicatorId: string = "atr_14"): RiskBasedSizer =
  ## Create risk-based sizer
  ## riskPerTrade: % of capital to risk (e.g., 1.0 = risk 1% per trade)
  ## atrMultiplier: Stop loss distance in terms of ATR (e.g., 2.0 = 2*ATR)
  if riskPerTrade <= 0.0 or riskPerTrade > 10.0:
    raise newException(SizingError, "Risk per trade must be between 0 and 10%")
  if atrMultiplier <= 0.0:
    raise newException(SizingError, "ATR multiplier must be positive")

  result = RiskBasedSizer(
    kind: pskRiskBased,
    riskPerTrade: riskPerTrade,
    atrMultiplier: atrMultiplier,
    atrIndicatorId: atrIndicatorId
  )

proc newKellySizer*(winRate: float, avgWinLoss: float,
    kellyFraction: float = 0.25): KellySizer =
  ## Create Kelly Criterion sizer
  ## winRate: Historical win rate (0-1)
  ## avgWinLoss: Average win / Average loss ratio
  ## kellyFraction: Fraction of Kelly to use (0.25 = quarter Kelly, conservative)
  if winRate <= 0.0 or winRate >= 1.0:
    raise newException(SizingError, "Win rate must be between 0 and 1")
  if avgWinLoss <= 0.0:
    raise newException(SizingError, "Avg Win/Loss ratio must be positive")
  if kellyFraction <= 0.0 or kellyFraction > 1.0:
    raise newException(SizingError, "Kelly fraction must be between 0 and 1")

  result = KellySizer(
    kind: pskKelly,
    winRate: winRate,
    avgWinLoss: avgWinLoss,
    kellyFraction: kellyFraction
  )

method calculateShares*(
  sizer: PositionSizer,
  capital: float,
  price: float,
  indicators: Table[string, float] = initTable[string, float]()
): int {.base.} =
  ## Calculate number of shares to trade
  ## Base method - must be overridden
  quit "calculateShares() must be overridden"

method calculateShares*(
  sizer: FixedPercentageSizer,
  capital: float,
  price: float,
  indicators: Table[string, float] = initTable[string, float]()
): int =
  ## Calculate shares for fixed percentage sizing
  if price <= 0.0:
    raise newException(SizingError, "Price must be positive")

  let positionValue = capital * (sizer.percentage / 100.0)
  result = int(positionValue / price)

  # Ensure at least 1 share if we have enough capital
  if result == 0 and capital >= price:
    result = 1

method calculateShares*(
  sizer: FixedSharesSizer,
  capital: float,
  price: float,
  indicators: Table[string, float] = initTable[string, float]()
): int =
  ## Calculate shares for fixed shares sizing
  result = sizer.shares

method calculateShares*(
  sizer: EqualWeightSizer,
  capital: float,
  price: float,
  indicators: Table[string, float] = initTable[string, float]()
): int =
  ## Calculate shares for equal weight sizing
  if price <= 0.0:
    raise newException(SizingError, "Price must be positive")

  let positionValue = capital / sizer.numPositions.float
  result = int(positionValue / price)

  if result == 0 and capital >= price:
    result = 1

method calculateShares*(
  sizer: RiskBasedSizer,
  capital: float,
  price: float,
  indicators: Table[string, float] = initTable[string, float]()
): int =
  ## Calculate shares for risk-based sizing
  ## Position size = (Capital * RiskPerTrade) / (ATR * ATRMultiplier)

  if price <= 0.0:
    raise newException(SizingError, "Price must be positive")

  # Get ATR value from indicators
  if not indicators.hasKey(sizer.atrIndicatorId):
    raise newException(SizingError, "ATR indicator not found: " &
        sizer.atrIndicatorId)

  let atr = indicators[sizer.atrIndicatorId]
  if atr <= 0.0 or atr.isNaN:
    # ATR not available or invalid, fall back to small default position
    return int(capital * 0.01 / price) # 1% of capital
  
  # Calculate risk amount in dollars
  let riskAmount = capital * (sizer.riskPerTrade / 100.0)

  # Calculate stop loss distance
  let stopDistance = atr * sizer.atrMultiplier

  # Position size = risk amount / stop distance
  let positionValue = riskAmount / stopDistance * price
  result = int(positionValue / price)

  if result == 0 and capital >= price:
    result = 1

  # Safety: never risk more than 20% of capital in single position
  let maxShares = int(capital * 0.2 / price)
  if result > maxShares:
    result = maxShares

method calculateShares*(
  sizer: KellySizer,
  capital: float,
  price: float,
  indicators: Table[string, float] = initTable[string, float]()
): int =
  ## Calculate shares using Kelly Criterion
  ## Kelly% = (W * R - (1 - W)) / R
  ## where W = win rate, R = avg win/loss ratio

  if price <= 0.0:
    raise newException(SizingError, "Price must be positive")

  # Calculate Kelly percentage
  let kellyPct = (sizer.winRate * sizer.avgWinLoss - (1.0 - sizer.winRate)) /
      sizer.avgWinLoss

  # Apply fraction (for safety)
  let adjustedKelly = max(0.0, kellyPct * sizer.kellyFraction)

  # Cap at 25% of capital (safety limit)
  let cappedKelly = min(adjustedKelly, 0.25)

  # Calculate position
  let positionValue = capital * cappedKelly
  result = int(positionValue / price)

  if result == 0 and capital >= price and cappedKelly > 0:
    result = 1

proc calculatePositionValue*(shares: int, price: float): float =
  ## Calculate total value of position
  result = shares.float * price

proc calculateMaxShares*(capital: float, price: float,
    maxPercentage: float = 100.0): int =
  ## Calculate maximum shares that can be purchased with given capital
  ## maxPercentage: Maximum % of capital to use (0-100)
  if price <= 0.0:
    return 0

  let availableCapital = capital * (maxPercentage / 100.0)
  result = int(availableCapital / price)
