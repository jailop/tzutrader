# Introduction to Algorithmic Trading

Algorithmic trading uses computer programs to execute trades based on predefined rules. Instead of manually monitoring markets and placing orders, you write code that makes decisions automatically.

## Why Backtest?

Before risking real money, you need to know if your trading idea actually works. Backtesting runs your strategy against historical data to see how it would have performed. Think of it as a simulation that helps you understand:

- Does the strategy make money or lose money?
- How often does it trade?
- What's the worst drawdown you might face?
- Is it better than just buying and holding?

## The Reality Check

Here's what you need to know upfront:

**Most strategies don't work.** Even strategies that look profitable in backtests often fail in live trading. This isn't a flaw in backtesting—it's the nature of markets. If trading were easy, everyone would be doing it successfully.

**Past performance doesn't guarantee future results.** Markets change. A strategy that worked for 10 years can suddenly stop working. Economic conditions shift, new participants enter, and market dynamics evolve.

**Backtesting has blind spots.** No backtest perfectly simulates real trading. There's always a gap between simulation and reality.

## Common Pitfalls in Backtesting

### Lookahead Bias

Using information that wouldn't have been available at the time of the trade. For example, using tomorrow's closing price to decide today's trade. This is a critical error that makes strategies look better than they are.

tzutrader processes data in a streaming fashion to help avoid this, but you still need to be careful in your strategy logic.

### Overfitting

Tweaking parameters until a strategy performs well on historical data, but then it fails on new data. This happens when you optimize too much for the specific quirks of your test dataset.

**Warning signs:**

- Too many parameters (>5)
- Very specific parameter values (e.g., exactly 23.7)
- Excellent backtest results but poor out-of-sample performance

### Survivorship Bias

Testing only on assets that still exist today, ignoring those that went bankrupt or were delisted. This makes your results look better than they would have been in reality.

### Ignoring Transaction Costs

Every trade has costs: commissions, spreads, slippage. A strategy that trades frequently can be profitable before costs but lose money after accounting for them.

### Data Quality Issues

Bad data leads to bad results. Ensure your historical data is:

- Complete (no missing periods)
- Accurate (correct prices)
- Adjusted for splits and dividends
- From a reliable source

## Building a Strategy

A trading strategy needs three components:

1. **Entry rules**: When to open a position
2. **Exit rules**: When to close a position
3. **Position sizing**: How much to trade

Example of a simple strategy:

- **Entry**: Buy when 20-day SMA crosses above 50-day SMA
- **Exit**: Sell when 20-day SMA crosses below 50-day SMA
- **Size**: Use all available capital

This is simple but probably not profitable. Real strategies are more nuanced, often combining multiple indicators and conditions.

## What Makes a Good Strategy?

There's no universal answer, but some characteristics of robust strategies:

- **Simple logic**: Complexity doesn't equal profitability
- **Economic rationale**: Understand *why* it should work, not just that it did
- **Consistent across timeframes**: Works on different periods, not just one cherry-picked range
- **Reasonable metrics**: Be skeptical of 90%+ win rates or 100%+ annual returns
- **Handles costs**: Still profitable after realistic transaction costs

## The Honest Truth

Most retail traders lose money. Professional trading is competitive, with well-funded firms using sophisticated technology. You're not going to get rich quick with a simple moving average crossover.

That said, backtesting is valuable for:

- Learning about market behavior
- Understanding risk and position management
- Testing ideas systematically
- Avoiding obvious mistakes

Treat it as education, not a guaranteed path to profits. If you do trade live, start small and be prepared to lose money while you learn.

## Using tzutrader

tzutrader is designed to help you backtest ideas honestly:

- Streaming data processing prevents lookahead bias
- Built-in transaction cost modeling
- Clear performance metrics including drawdowns
- Simple architecture that's easy to understand and audit

It won't make bad strategies good, but it will help you evaluate them fairly. The goal is to fail fast on bad ideas and refine promising ones—before you risk real money.

### The Unix Philosophy Approach

Like Unix tools (`grep`, `sort`, `awk`), tzutrader provides small components that do one thing well:

```bash
# Unix pipeline: each tool does one thing
cat data.txt | grep "pattern" | sort | uniq -c

# tzutrader: each component does one thing
# Indicator calculates values
# Strategy generates signals  
# Portfolio executes trades
cat data.csv | ./backtest | tr ' ' '\n' | column -t
```

You compose simple pieces into complex systems. This makes it easier to:

- Understand each component in isolation
- Test components independently
- Replace one part without rewriting everything
- Build exactly what you need

The trade-off is you write more code. But you understand what that code does, because you wrote it. No hidden magic, no black boxes.
