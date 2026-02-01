# Risk Management in Backtesting

## Why Risk Management Matters

In real trading, knowing when to exit is just as important as knowing when to enter. A great entry signal can turn into a losing trade if you don't have a plan to protect your capital and lock in profits.

Risk management rules define your exit strategy:

- **Stop-Loss**: Exit when losses reach a threshold, protecting your capital
- **Take-Profit**: Exit when gains reach a target, locking in profits

Without these rules, your backtest assumes you'll hold positions indefinitely or only exit when your strategy signals. In reality, disciplined traders set stops and profit targets for every trade.

TzuTrader integrates risk management directly into the backtesting engine, so your backtest reflects realistic trading discipline.

## How It Works

When you add risk management to a strategy, the backtester checks stop-loss and take-profit conditions on every bar, independent of your strategy's signals. If a threshold is hit, the position exits automatically.

This happens in the natural order:

1. **Check risk rules first** - Stop-loss and take-profit are evaluated
2. **If triggered, exit immediately** - Position closed, no strategy signal needed
3. **Otherwise, get strategy signal** - Your strategy runs normally
4. **Execute any new trades** - Buy/sell signals are processed

This ensures stops take priority over strategy signals, just like in real trading.

## Adding Risk Management to a Strategy

There are three ways to add risk management, all equally effective. Choose the style you find most readable.

### Quick Method: Direct Extension

The simplest approach chains methods directly onto your strategy:

```nim
import tzutrader

let strategy = newRSIStrategy(14, 30.0, 70.0)
  .withFixedStopLoss(5.0)       # 5% stop-loss
  .withFixedTakeProfit(10.0)    # 10% take-profit

let report = quickBacktest("AAPL", strategy, data)
```

This is clean and concise for simple configurations.

### Builder Pattern: Complex Configurations

For more complex setups, the builder pattern provides a clear, step-by-step approach:

```nim
import tzutrader

let strategy = newStrategyBuilder(newMACDStrategy())
  .withTrailingStop(trailPct = 3.0, activationPct = 5.0)
  .withRiskReward(ratio = 2.0)
  .build()

let report = quickBacktest("AAPL", strategy, data)
```

The builder makes it obvious what each parameter does and allows you to chain multiple configurations.

### Explicit Configuration

For maximum control, use the `withRiskManagement()` function with explicit rule objects:

```nim
import tzutrader

let strategy = newRSIStrategy(14, 30.0, 70.0)
  .withRiskManagement(
    stopLoss = newFixedPercentageStopLoss(5.0),
    takeProfit = newFixedPercentageTakeProfit(10.0)
  )

let report = quickBacktest("AAPL", strategy, data)
```

This gives you access to all parameters and makes it clear you're configuring a stop-loss rule and a take-profit rule.

## Stop-Loss Types

### Fixed Percentage Stop-Loss

Exit when loss reaches a percentage below your entry price.

```nim
# Exit at 5% loss
let strategy = newRSIStrategy(14, 30.0, 70.0)
  .withFixedStopLoss(5.0)
```

**When to use**: You want consistent risk on every trade. If you enter at $100, you'll exit at $95 (5% loss).

**Example**: You buy at $100. Price drops to $95. Stop triggers, you exit with a 5% loss.

### Fixed Price Stop-Loss

Exit when price falls to or below a specific level.

```nim
# Exit if price hits $95
let strategy = newRSIStrategy(14, 30.0, 70.0)
  .withPriceStopLoss(95.0)
```

**When to use**: You have a specific support level in mind. This is less common because it doesn't adapt to your entry price.

**Example**: Regardless of entry price, if price touches $95, you exit.

### Trailing Stop-Loss

The stop follows price higher, locking in profits as they accumulate. The stop stays a fixed percentage below the highest price reached.

```nim
# Trail 3% below the high, activate after 5% profit
let strategy = newRSIStrategy(14, 30.0, 70.0)
  .withTrailingStop(trailPct = 3.0, activationPct = 5.0)
```

**When to use**: You want to let profits run while protecting gains. The trailing stop "ratchets up" as price rises.

**Example**: 
- You buy at $100
- Price rises to $110 (10% profit)
- Trailing stop is now at $106.70 (3% below $110)
- Price drops to $106.70, stop triggers
- You exit with a 6.7% profit instead of holding all the way back down

The `activationPct` parameter (optional) delays trailing until minimum profit is reached. This prevents getting stopped out early in choppy markets.

### ATR-Based Stop-Loss

The stop distance adapts to market volatility using the Average True Range indicator. More volatile markets get wider stops.

```nim
# Stop at 2x ATR below entry
let strategy = newRSIStrategy(14, 30.0, 70.0)
  .withATRStop(multiplier = 2.0, indicatorId = "atr_14")
```

**When to use**: You want stops that adapt to market conditions. Volatile markets need wider stops; calm markets can use tighter stops.

**Example**: If ATR is $3 and you use 2x multiplier, your stop is $6 below entry. As volatility changes, future trades adjust automatically.

**Note**: Your strategy must implement `getIndicatorValue()` to provide ATR values. Most built-in strategies don't track ATR, so this is mainly for custom strategies.

## Take-Profit Types

### Fixed Percentage Take-Profit

Exit when profit reaches a percentage above your entry price.

```nim
# Exit at 10% profit
let strategy = newRSIStrategy(14, 30.0, 70.0)
  .withFixedTakeProfit(10.0)
```

**When to use**: You have a consistent profit target. If you enter at $100, you'll exit at $110 (10% gain).

**Example**: You buy at $100. Price rises to $110. Take-profit triggers, you exit with a 10% profit.

### Fixed Price Take-Profit

Exit when price reaches a specific level.

```nim
# Exit if price hits $110
let strategy = newRSIStrategy(14, 30.0, 70.0)
  .withPriceTakeProfit(110.0)
```

**When to use**: You have a specific resistance level in mind. This is less common because it doesn't adapt to your entry price.

### Risk/Reward Ratio Take-Profit

Profit target is calculated automatically based on your stop distance. If you risk $5 with a 2:1 ratio, your profit target is $10.

```nim
# 5% stop-loss with 2:1 risk/reward = 10% take-profit
let strategy = newStrategyBuilder(newRSIStrategy(14, 30.0, 70.0))
  .withFixedStopLoss(5.0)
  .withRiskReward(2.0)
  .build()
```

**When to use**: You want consistent risk/reward on every trade. This is considered good trading discipline.

**Example**: 
- You set a 5% stop-loss (risking $5)
- With 2:1 ratio, profit target is 10% (potential $10 gain)
- You risk $5 to make $10

**Important**: You must configure a stop-loss before using risk/reward, because the profit target depends on the stop distance.

### Multi-Level Take-Profit (Scaling Out)

Exit portions of your position at different profit levels. This balances between taking profits early and letting winners run.

```nim
# Exit 50% at 5% profit, remaining 50% at 10% profit
let levels = @[
  TakeProfitLevel(percentage: 5.0, exitPercent: 50.0),
  TakeProfitLevel(percentage: 10.0, exitPercent: 50.0)
]

let strategy = newStrategyBuilder(newRSIStrategy(14, 30.0, 70.0))
  .withFixedStopLoss(5.0)
  .withMultiLevelProfit(levels)
  .build()
```

**When to use**: You want to lock in some profit early while still participating if the trend continues.

**Example**:
- You buy 100 shares at $100
- Price hits $105 (5% profit): Sell 50 shares, lock in profit
- Price hits $110 (10% profit): Sell remaining 50 shares
- Final result: Mixed exit at average of $107.50 per share

## Understanding the Tradeoffs

### Stop-Losses Protect Capital But Can Exit Early

Stop-losses prevent catastrophic losses, but they also mean you'll get stopped out sometimes before the trade recovers.

**Tight stops (2-3%)**: 
- More stop-outs, higher trade count
- Limited losses on losing trades
- May exit winners too early

**Wide stops (10-15%)**:
- Fewer stop-outs, lower trade count  
- Larger losses on losing trades
- Give winners more room to develop

There's no perfect answer. Match your stop width to:
- Market volatility (more volatile = wider stops)
- Your risk tolerance (how much loss can you accept)
- Your strategy's holding period (day trades = tighter, swing trades = wider)

### Take-Profits Lock In Gains But Can Exit Too Soon

Take-profits guarantee you capture some profit, but they also mean you'll miss larger moves.

**Fixed take-profits (10%)** work well when:
- You have a clear profit target
- The market tends to reverse after hitting levels
- You want consistent, predictable results

**Letting profits run** (no take-profit or trailing stop) works well when:
- Strong trends are common
- Your strategy identifies trend starts
- You can tolerate seeing profits evaporate

**Scaling out** (multi-level) balances both approaches:
- Lock in some profit early (reduces regret)
- Keep some exposure for larger moves
- Commonly used by professional traders

## Combining Stop-Loss and Take-Profit

The most robust approach uses both:

```nim
# Conservative: Tight stops, modest targets
let conservative = newRSIStrategy(14, 30.0, 70.0)
  .withFixedStopLoss(3.0)
  .withFixedTakeProfit(6.0)

# Aggressive: Wider stops, larger targets
let aggressive = newRSIStrategy(14, 30.0, 70.0)
  .withFixedStopLoss(10.0)
  .withFixedTakeProfit(20.0)

# Balanced: Risk/reward ratio
let balanced = newRSIStrategy(14, 30.0, 70.0)
  .withFixedStopLoss(5.0)
  .withRiskReward(2.0)  # 5% stop, 10% target

# Professional: Trailing with scaling out
let professional = newStrategyBuilder(newRSIStrategy(14, 30.0, 70.0))
  .withTrailingStop(trailPct = 5.0, activationPct = 10.0)
  .withMultiLevelProfit(@[
    TakeProfitLevel(percentage: 8.0, exitPercent: 50.0),
    TakeProfitLevel(percentage: 15.0, exitPercent: 50.0)
  ])
  .build()
```

## Reading Backtest Results

When risk management is active, the backtest report includes an additional section:

```
Risk Management
  Stop-Loss Exits:   12
  Take-Profit Exits:  8
  Strategy Exits:     3
  Avg SL Return:    $-234.50
  Avg TP Return:    $ 456.75
```

**Stop-Loss Exits**: Number of positions closed by stop-loss triggers. High numbers suggest stops may be too tight or the strategy enters poor trades.

**Take-Profit Exits**: Number of positions closed by take-profit triggers. High numbers suggest your profit targets are realistic.

**Strategy Exits**: Number of positions closed by your strategy's sell signals (not risk management). This shows how often your strategy gets to make the exit decision.

**Avg SL Return**: Average profit/loss on stop-loss exits. Usually negative (losses), but should be limited by your stop percentage.

**Avg TP Return**: Average profit on take-profit exits. Should be close to your profit target.

## Comparing With and Without Risk Management

Run two backtests to see the impact:

```nim
import tzutrader

let data = readCSV("data/AAPL.csv")

# Without risk management
let baseStrategy = newRSIStrategy(14, 30.0, 70.0)
let baseReport = quickBacktest("AAPL", baseStrategy, data)

# With risk management
let riskStrategy = newRSIStrategy(14, 30.0, 70.0)
  .withFixedStopLoss(5.0)
  .withFixedTakeProfit(10.0)
let riskReport = quickBacktest("AAPL", riskStrategy, data)

echo "Base strategy:"
echo "  Total Return: ", baseReport.totalReturn, "%"
echo "  Max Drawdown: ", baseReport.maxDrawdown, "%"
echo "  Trades: ", baseReport.totalTrades

echo "\nWith risk management:"
echo "  Total Return: ", riskReport.totalReturn, "%"
echo "  Max Drawdown: ", riskReport.maxDrawdown, "%"
echo "  Trades: ", riskReport.totalTrades
echo "  Stop-loss exits: ", riskReport.stopLossExits
echo "  Take-profit exits: ", riskReport.takeProfitExits
```

Typically, risk management will:
- **Reduce maximum drawdown** (stops limit losses)
- **Increase trade count** (stops exit earlier)
- **Change total return** (could go up or down)
- **Reduce variance** (more consistent results)

## Common Patterns

### Pattern 1: Symmetric Risk/Reward

Risk and reward are equal (1:1 ratio):

```nim
let strategy = newRSIStrategy(14, 30.0, 70.0)
  .withFixedStopLoss(5.0)
  .withFixedTakeProfit(5.0)
```

This works when your win rate is high (>50%). You need to win more often than you lose to profit.

### Pattern 2: Asymmetric Risk/Reward

Reward is larger than risk (2:1 or 3:1 ratio):

```nim
let strategy = newRSIStrategy(14, 30.0, 70.0)
  .withFixedStopLoss(5.0)
  .withFixedTakeProfit(10.0)  # or use .withRiskReward(2.0)
```

This works when you capture good trends. You can afford a lower win rate (even 40%) because winners are larger.

### Pattern 3: Trailing with Minimum Target

Don't start trailing until you've hit a minimum profit:

```nim
let strategy = newRSIStrategy(14, 30.0, 70.0)
  .withTrailingStop(trailPct = 3.0, activationPct = 8.0)
```

This ensures you lock in at least 5% profit (8% - 3% trailing) before the stop can trigger.

### Pattern 4: Partial Profits with Trailing Stop

Take some profit early, let the rest ride with a trailing stop:

```nim
let strategy = newStrategyBuilder(newRSIStrategy(14, 30.0, 70.0))
  .withTrailingStop(trailPct = 5.0)
  .withMultiLevelProfit(@[
    TakeProfitLevel(percentage: 7.0, exitPercent: 50.0)
  ])
  .build()
```

This combines the security of taking early profits with the potential for larger gains.

## Strategy Signal Exits vs Risk Exits

Your strategy can still generate sell signals even with risk management active. The backtest checks rules in this order:

1. **Stop-loss** (highest priority - prevents large losses)
2. **Take-profit** (second priority - locks in gains)
3. **Strategy signal** (third priority - your strategy's decision)

If your strategy generates a sell signal but the stop-loss already closed the position, the sell signal is ignored (you can't sell what you don't own).

This means **risk management takes priority**, just like in real trading where you can't override a stop-loss order.

## When to Skip Risk Management

Risk management isn't always necessary:

**Skip it when**:
- You're testing entry timing only (just want to know when strategy triggers)
- Your strategy already has exits built in (e.g., sells on RSI overbought)
- You're comparing strategies and want consistent conditions
- You're doing initial exploration (add it later for refinement)

**Use it when**:
- Testing how strategy performs with realistic discipline
- Comparing different risk parameters (tight vs wide stops)
- Preparing for real trading (backtest should match your plan)
- You want to understand worst-case drawdown with stops

## Complete Example

Here's a complete workflow comparing different risk approaches:

```nim
import tzutrader

# Load data
let data = readCSV("data/AAPL.csv")

# Base strategy
let baseStrategy = newRSIStrategy(14, 30.0, 70.0)

# Test configurations
let configs = @[
  ("No stops", baseStrategy),
  ("Fixed 5%/10%", baseStrategy.withFixedStopLoss(5.0).withFixedTakeProfit(10.0)),
  ("Trailing 3%", baseStrategy.withTrailingStop(3.0)),
  ("Risk/Reward 2:1", newStrategyBuilder(baseStrategy).withFixedStopLoss(5.0).withRiskReward(2.0).build())
]

# Run backtests
echo "Configuration            Return   MaxDD  Trades  SL-Exits  TP-Exits"
echo "=" .repeat(70)

for (name, strategy) in configs:
  let report = quickBacktest("AAPL", strategy, data, initialCash = 100000.0)
  echo &"{name:<24} {report.totalReturn:>6.2f}% {report.maxDrawdown:>6.2f}% {report.totalTrades:>6} {report.stopLossExits:>8} {report.takeProfitExits:>8}"
```

This gives you a clear comparison of how different risk approaches affect your strategy's performance.

## Next Steps

Now that you understand risk management in backtesting:

1. **Start simple**: Add a basic 5% stop-loss to your strategy
2. **Compare results**: Run with and without stops to see the impact  
3. **Optimize**: Try different stop/target combinations
4. **Match your trading style**: Choose risk rules you'll actually use in real trading

Risk management is personal. What works for one trader may not work for another. The key is testing different approaches in backtest before risking real money.

Remember: The best risk management system is the one you'll actually follow when trading live.
