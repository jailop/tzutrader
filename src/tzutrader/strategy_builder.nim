## Strategy Builder for Risk Management Configuration
##
## This module provides a fluent API for configuring trading strategies with
## risk management rules (stop-loss and take-profit).
##
## The builder pattern makes it easy to add risk management to any strategy
## without modifying the strategy itself.
##
## Example:
## ```nim
## import tzutrader
## import tzutrader/strategy_builder
##
## # Simple fixed stop and take-profit
## let strategy = newRSIStrategy(14, 30.0, 70.0)
##   .withFixedStopLoss(5.0)      # 5% stop-loss
##   .withFixedTakeProfit(10.0)   # 10% take-profit
##
## # Trailing stop with risk/reward
## let strategy2 = newStrategyBuilder(newMACDStrategy())
##   .withTrailingStop(trailPct = 3.0, activationPct = 5.0)
##   .withRiskReward(ratio = 2.0)
##   .build()
##
## # ATR-based stop with multi-level take-profit
## let strategy3 = newCrossoverStrategy(10, 20)
##   .withATRStop(multiplier = 2.0, indicatorId = "atr_14")
##   .withMultiLevelProfit(@[
##     TakeProfitLevel(percentage: 5.0, exitPercent: 50.0),
##     TakeProfitLevel(percentage: 10.0, exitPercent: 50.0)
##   ])
## ```

import strategies/base
import declarative/risk_management

export risk_management  # Re-export for user convenience

type
  StrategyBuilder* = ref object
    ## Builder for configuring strategies with risk management
    strategy: Strategy
    stopLoss: StopLossRule
    takeProfit: TakeProfitRule

# ============================================================================
# Builder Construction
# ============================================================================

proc newStrategyBuilder*(strategy: Strategy): StrategyBuilder =
  ## Create a new strategy builder
  ## 
  ## Args:
  ##   strategy: Strategy instance to configure
  ## 
  ## Returns:
  ##   New StrategyBuilder instance
  result = StrategyBuilder(
    strategy: strategy,
    stopLoss: nil,
    takeProfit: nil
  )

# ============================================================================
# Stop-Loss Configuration (Generic)
# ============================================================================

proc withStopLoss*(sb: StrategyBuilder, rule: StopLossRule): StrategyBuilder =
  ## Add a custom stop-loss rule
  ## 
  ## Args:
  ##   rule: Stop-loss rule instance
  ## 
  ## Returns:
  ##   Builder instance for chaining
  sb.stopLoss = rule
  result = sb

# ============================================================================
# Stop-Loss Configuration (Convenience Methods)
# ============================================================================

proc withFixedStopLoss*(sb: StrategyBuilder, percentage: float): StrategyBuilder =
  ## Add fixed percentage stop-loss
  ## 
  ## Exits position when loss reaches specified percentage below entry price.
  ## 
  ## Args:
  ##   percentage: Loss percentage to trigger stop (e.g., 5.0 = 5%)
  ## 
  ## Returns:
  ##   Builder instance for chaining
  ## 
  ## Example:
  ##   strategy.withFixedStopLoss(5.0)  # Exit at 5% loss
  sb.stopLoss = newFixedPercentageStopLoss(percentage)
  result = sb

proc withPriceStopLoss*(sb: StrategyBuilder, price: float): StrategyBuilder =
  ## Add fixed price stop-loss
  ## 
  ## Exits position when price falls to or below specified level.
  ## 
  ## Args:
  ##   price: Absolute price level for stop
  ## 
  ## Returns:
  ##   Builder instance for chaining
  ## 
  ## Example:
  ##   strategy.withPriceStopLoss(95.0)  # Exit at $95
  sb.stopLoss = newFixedPriceStopLoss(price)
  result = sb

proc withTrailingStop*(sb: StrategyBuilder, trailPct: float, activationPct: float = 0.0): StrategyBuilder =
  ## Add trailing stop-loss
  ## 
  ## Stop follows price up at specified distance, locking in profits.
  ## Optionally waits for minimum profit before activating.
  ## 
  ## Args:
  ##   trailPct: Distance to trail behind high (%)
  ##   activationPct: Minimum profit before trailing starts (default 0)
  ## 
  ## Returns:
  ##   Builder instance for chaining
  ## 
  ## Example:
  ##   # Trail 3% behind high, activate immediately
  ##   strategy.withTrailingStop(3.0)
  ##   
  ##   # Trail 3% behind high, activate after 5% profit
  ##   strategy.withTrailingStop(trailPct = 3.0, activationPct = 5.0)
  sb.stopLoss = newTrailingStopLoss(trailPct, activationPct)
  result = sb

proc withATRStop*(sb: StrategyBuilder, multiplier: float, indicatorId: string = "atr_14"): StrategyBuilder =
  ## Add ATR-based stop-loss (volatility-adjusted)
  ## 
  ## Stop distance adapts to market volatility using ATR indicator.
  ## Requires strategy to implement getIndicatorValue() method.
  ## 
  ## Args:
  ##   multiplier: ATR multiplier for stop distance
  ##   indicatorId: ID of ATR indicator (default "atr_14")
  ## 
  ## Returns:
  ##   Builder instance for chaining
  ## 
  ## Example:
  ##   # Stop at 2x ATR below entry
  ##   strategy.withATRStop(multiplier = 2.0)
  sb.stopLoss = newATRBasedStopLoss(multiplier, indicatorId)
  result = sb

# ============================================================================
# Take-Profit Configuration (Generic)
# ============================================================================

proc withTakeProfit*(sb: StrategyBuilder, rule: TakeProfitRule): StrategyBuilder =
  ## Add a custom take-profit rule
  ## 
  ## Args:
  ##   rule: Take-profit rule instance
  ## 
  ## Returns:
  ##   Builder instance for chaining
  sb.takeProfit = rule
  result = sb

# ============================================================================
# Take-Profit Configuration (Convenience Methods)
# ============================================================================

proc withFixedTakeProfit*(sb: StrategyBuilder, percentage: float): StrategyBuilder =
  ## Add fixed percentage take-profit
  ## 
  ## Exits entire position when profit reaches specified percentage.
  ## 
  ## Args:
  ##   percentage: Profit percentage to trigger exit (e.g., 10.0 = 10%)
  ## 
  ## Returns:
  ##   Builder instance for chaining
  ## 
  ## Example:
  ##   strategy.withFixedTakeProfit(10.0)  # Exit at 10% profit
  sb.takeProfit = newFixedPercentageTakeProfit(percentage)
  result = sb

proc withPriceTakeProfit*(sb: StrategyBuilder, price: float): StrategyBuilder =
  ## Add fixed price take-profit
  ## 
  ## Exits position when price reaches specified level.
  ## 
  ## Args:
  ##   price: Absolute price level for take-profit
  ## 
  ## Returns:
  ##   Builder instance for chaining
  ## 
  ## Example:
  ##   strategy.withPriceTakeProfit(110.0)  # Exit at $110
  sb.takeProfit = newFixedPriceTakeProfit(price)
  result = sb

proc withRiskReward*(sb: StrategyBuilder, ratio: float): StrategyBuilder =
  ## Add risk/reward ratio take-profit
  ## 
  ## Profit target is calculated as: entry + (stop_distance * ratio)
  ## Requires stop-loss to be configured first.
  ## 
  ## Args:
  ##   ratio: Risk/reward ratio (e.g., 2.0 = take profit at 2x stop distance)
  ## 
  ## Returns:
  ##   Builder instance for chaining
  ## 
  ## Raises:
  ##   ValueError if no stop-loss is configured
  ## 
  ## Example:
  ##   # 5% stop with 2:1 risk/reward = 10% take-profit
  ##   strategy.withFixedStopLoss(5.0).withRiskReward(2.0)
  if sb.stopLoss == nil:
    raise newException(ValueError, "Risk/reward requires stop-loss to be configured first")
  sb.takeProfit = newRiskRewardTakeProfit(ratio, sb.stopLoss)
  result = sb

proc withMultiLevelProfit*(sb: StrategyBuilder, levels: seq[TakeProfitLevel]): StrategyBuilder =
  ## Add multi-level take-profit (partial exits)
  ## 
  ## Allows scaling out of positions at multiple profit levels.
  ## Each level specifies a profit target and what % of position to exit.
  ## 
  ## Args:
  ##   levels: Sequence of take-profit levels
  ## 
  ## Returns:
  ##   Builder instance for chaining
  ## 
  ## Example:
  ##   # Exit 50% at 5% profit, remaining 50% at 10% profit
  ##   strategy.withMultiLevelProfit(@[
  ##     TakeProfitLevel(percentage: 5.0, exitPercent: 50.0),
  ##     TakeProfitLevel(percentage: 10.0, exitPercent: 50.0)
  ##   ])
  sb.takeProfit = newMultiLevelTakeProfit(levels)
  result = sb

# ============================================================================
# Builder Finalization
# ============================================================================

proc build*(sb: StrategyBuilder): Strategy =
  ## Build and return the configured strategy
  ## 
  ## Applies risk management configuration to strategy and returns it.
  ## 
  ## Returns:
  ##   Configured strategy instance
  sb.strategy.setRiskManagement(sb.stopLoss, sb.takeProfit)
  result = sb.strategy

# ============================================================================
# Convenience Functions (Alternative to Builder Pattern)
# ============================================================================

proc withRiskManagement*(
  strategy: Strategy,
  stopLoss: StopLossRule = nil,
  takeProfit: TakeProfitRule = nil
): Strategy =
  ## Convenience function to add risk management directly to a strategy
  ## 
  ## This provides a simpler API when you don't need the builder pattern.
  ## 
  ## Args:
  ##   strategy: Strategy instance
  ##   stopLoss: Stop-loss rule (nil = no stop-loss)
  ##   takeProfit: Take-profit rule (nil = no take-profit)
  ## 
  ## Returns:
  ##   Same strategy instance (for chaining)
  ## 
  ## Example:
  ##   let strategy = newRSIStrategy(14, 30.0, 70.0)
  ##     .withRiskManagement(
  ##       stopLoss = newFixedPercentageStopLoss(5.0),
  ##       takeProfit = newFixedPercentageTakeProfit(10.0)
  ##     )
  strategy.setRiskManagement(stopLoss, takeProfit)
  result = strategy

proc withFixedStopLoss*(strategy: Strategy, percentage: float): Strategy =
  ## Convenience: Add fixed percentage stop-loss to strategy
  ## 
  ## Args:
  ##   strategy: Strategy instance
  ##   percentage: Stop-loss percentage
  ## 
  ## Returns:
  ##   Same strategy instance (for chaining)
  ## 
  ## Example:
  ##   let strategy = newRSIStrategy(14, 30.0, 70.0)
  ##     .withFixedStopLoss(5.0)
  ##     .withFixedTakeProfit(10.0)
  strategy.setRiskManagement(
    stopLoss = newFixedPercentageStopLoss(percentage),
    takeProfit = strategy.takeProfitRule  # Preserve existing take-profit
  )
  result = strategy

proc withFixedTakeProfit*(strategy: Strategy, percentage: float): Strategy =
  ## Convenience: Add fixed percentage take-profit to strategy
  ## 
  ## Args:
  ##   strategy: Strategy instance
  ##   percentage: Take-profit percentage
  ## 
  ## Returns:
  ##   Same strategy instance (for chaining)
  ## 
  ## Example:
  ##   let strategy = newRSIStrategy(14, 30.0, 70.0)
  ##     .withFixedStopLoss(5.0)
  ##     .withFixedTakeProfit(10.0)
  strategy.setRiskManagement(
    stopLoss = strategy.stopLossRule,  # Preserve existing stop-loss
    takeProfit = newFixedPercentageTakeProfit(percentage)
  )
  result = strategy

proc withTrailingStop*(strategy: Strategy, trailPct: float, activationPct: float = 0.0): Strategy =
  ## Convenience: Add trailing stop to strategy
  ## 
  ## Args:
  ##   strategy: Strategy instance
  ##   trailPct: Trail percentage
  ##   activationPct: Activation profit percentage
  ## 
  ## Returns:
  ##   Same strategy instance (for chaining)
  strategy.setRiskManagement(
    stopLoss = newTrailingStopLoss(trailPct, activationPct),
    takeProfit = strategy.takeProfitRule
  )
  result = strategy
