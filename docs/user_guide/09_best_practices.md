# Best Practices

## Testing Methodology

### Start with Research

Before writing any code, develop a hypothesis about why a strategy should work:

**Good hypothesis**: "Stocks showing RSI below 30 are temporarily oversold and tend to revert to mean prices within days."

**Bad hypothesis**: "I'll test different indicators until I find something that worked well historically."

The first approach has economic logic behind it. The second is data mining that will likely produce overfit results.

### Use Realistic Data

Your backtest results are only as good as your data:

**Data quality checklist:**
- [ ] Data covers sufficient time period (at least 2-3 years)
- [ ] Data includes various market conditions (bull, bear, sideways)
- [ ] Historical data is adjusted for splits and dividends
- [ ] No obvious errors or gaps in the data
- [ ] Time period is recent enough to be relevant
- [ ] Data includes transaction costs

Avoid using only bull market data - your strategy needs to handle different environments.

### Test on Multiple Symbols

A strategy that only works on one symbol is likely curve-fit:

```nim
# Test across different sectors
let symbols = @[
  "AAPL",  # Technology
  "JPM",   # Financials
  "XOM",   # Energy
  "JNJ",   # Healthcare  
  "WMT",   # Consumer
  "CAT",   # Industrials
  "DUK",   # Utilities
]
```

If the strategy performs well on tech stocks but fails elsewhere, you don't have a robust strategy - you have a tech sector bet.

### Document Everything

Keep records of:
- Strategy logic and reasoning
- Parameters tested and why
- Backtest results (including failures)
- Modifications made and their effects

This documentation helps you:
- Avoid retesting the same ideas
- Understand what worked and why
- Learn from failures
- Track strategy evolution

### Set Realistic Expectations

Institutional traders target:
- **Conservative**: 8-12% annual returns
- **Moderate**: 12-20% annual returns
- **Aggressive**: 20%+ annual returns (higher risk)

If your backtest shows 50%+ annual returns, something is probably wrong:
- Data quality issue
- Look-ahead bias
- Unrealistic assumptions
- Overfitted parameters

## Realistic Commission Assumptions

Commission costs significantly impact strategy profitability, especially for active strategies.

### Current Commission Rates

**Discount brokers** (Interactive Brokers, Charles Schwab, TD Ameritrade):
- $0 commission for stocks
- But: payment for order flow means slightly worse fills
- Effective cost: ~0.01-0.05% per trade

**Pro tip**: Zero-commission doesn't mean zero cost. You still pay bid-ask spread.

### Conservative Assumptions

Use these rates for backtesting:

```nim
# Conservative (recommended)
let portfolio = newPortfolio(
  initialCash = 100000.0,
  commission = 0.001,    # 0.1% per trade
  minCommission = 0.0
)

# More conservative for small accounts
let portfolio = newPortfolio(
  initialCash = 10000.0,
  commission = 0.002,    # 0.2% per trade
  minCommission = 1.0    # $1 minimum
)
```

**Why conservative?**
- Accounts for slippage (difference between expected and actual fill price)
- Includes bid-ask spread costs
- Provides safety margin

If a strategy is only marginally profitable with conservative costs, it's not worth trading.

### Account for Slippage

Slippage is the difference between expected and actual execution price:

```nim
# Not modeled in TzuTrader, but be aware:
# Expected: Buy at $100.00
# Actual: Buy at $100.05 (0.05% slippage)
# 
# On $10,000 trade: $5 slippage
# Over 100 trades/year: $500 in slippage costs
```

**Slippage increases with:**
- Larger position sizes
- Less liquid stocks
- Market volatility
- Market orders (vs limit orders)

## Position Sizing Rules

Position sizing affects both returns and risk.

### Fixed Percentage Method

Invest a fixed percentage of portfolio value:

```nim
let positionSize = 0.10  # 10% per position

# Adjust size as portfolio grows/shrinks
let amount = portfolio.equity(prices) * positionSize
let shares = amount / currentPrice
```

**Advantages:**
- Compounds gains automatically
- Reduces exposure as portfolio shrinks (loss mitigation)
- Simple to implement

**Disadvantages:**
- Position sizes vary over time
- May become too small (or large) over time

### Maximum Position Limits

Limit exposure to any single position:

```nim
# Never exceed 20% in single position
let maxPosition = portfolio.equity(prices) * 0.20

if positionValue > maxPosition:
  echo "Position too large - consider reducing"
```

This protects against concentration risk.

### Account for Volatility

Size positions inversely to volatility:

```nim
# Higher volatility = smaller position
# (Requires ATR calculation)

let atrValue = atr(highs, lows, closes, period = 14)[^1]
let volatilityPct = (atrValue / currentPrice) * 100

# Base size: 10%, adjust by volatility
let volatilityFactor = 2.0 / volatilityPct  # Lower when volatile
let positionSize = min(0.10 * volatilityFactor, 0.20)  # Cap at 20%
```

This helps maintain consistent risk across different securities.

## Risk Management

### Stop-Loss Considerations

Stop-losses limit downside but can hurt performance if set too tight:

```nim
# Example: 2x ATR stop-loss
let stopDistance = atrValue * 2.0
let stopPrice = entryPrice - stopDistance

# When price hits stopPrice, exit position
```

**Trade-offs:**
- Too tight: Stopped out by normal volatility
- Too loose: Large losses when wrong
- No stop: Unlimited loss potential

TzuTrader doesn't automatically implement stops (strategies control all exits), but you can build this into custom strategies.

### Drawdown Management

Monitor maximum drawdown:

```nim
let metrics = portfolio.calculatePerformance(prices)

if metrics.maxDrawdown < -20.0:
  echo "WARNING: Drawdown exceeds 20%"
  echo "Consider reducing position sizes or stopping trading"
```

Many traders halt trading when drawdown exceeds a threshold (e.g., -20%) to reassess the strategy.

### Diversification

Spread risk across:
- **Multiple symbols**: 5-15 positions for retail accounts
- **Multiple sectors**: Don't concentrate in one industry
- **Multiple timeframes**: Mix short and longer-term positions (if comfortable)

## When a Strategy Isn't Working

### Recognize the Signs

Stop trading a strategy when:
- Actual results diverge significantly from backtest
- Market conditions have fundamentally changed
- Drawdown exceeds your tolerance
- You lose confidence and can't follow the rules
- Better alternatives are identified

### Diagnose the Problem

Common failure modes:

**1. Overfitting**
- Symptoms: Great backtest, poor live results
- Solution: Simplify strategy, use out-of-sample testing

**2. Market Regime Change**
- Symptoms: Strategy worked for years, suddenly fails
- Solution: Adapt strategy or wait for favorable conditions

**3. Execution Issues**
- Symptoms: Backtested trades at better prices than reality
- Solution: Use more conservative assumptions, improve execution

**4. Psychological Factors**
- Symptoms: Can't follow the rules consistently
- Solution: Simplify strategy, reduce position sizes, increase confidence through testing

### Iterative Improvement

Improve strategies gradually:

```nim
# Version 1: Basic RSI
let v1 = newRSIStrategy(period = 14, oversold = 30, overbought = 70)

# Version 2: Add filters (custom strategy)
# Only take signals when price is above 200-day MA
# (Prevents trading against major trend)

# Version 3: Improve exits
# Exit when RSI returns to neutral (50), not just overbought
```

Make one change at a time and validate it improves results.

## Moving from Backtesting to Live Trading

### Paper Trading First

Before risking real capital, run your strategy in paper trading mode (simulated trading with live data).

**What to test:**
- Execution logic works correctly
- Data feeds are reliable
- Commission costs match assumptions
- You can emotionally handle the strategy

**Duration:** At least 1-3 months of paper trading before using real capital.

### Start Small

When going live:
- Use 10-25% of planned capital initially
- Verify results match expectations
- Gradually increase capital as confidence grows

```nim
# Planned: $100,000 portfolio
# Start with: $10,000-$25,000
# Scale up over 6-12 months if successful
```

### Monitor Performance

Track key metrics regularly:

```nim
# Compare live vs backtest results monthly
let liveReturn = /* actual live return */
let backtestReturn = /* expected from backtest */

let deviation = abs(liveReturn - backtestReturn)

if deviation > 5.0:  # More than 5% difference
  echo "WARNING: Live results deviating from backtest"
  echo "Review execution quality and assumptions"
```

Significant deviation signals a problem.

### Accept That Live Trading Differs

Live trading includes factors backtests don't capture:
- Emotional stress
- Partial fills
- System outages
- News events
- Execution delays

Expect live results to be somewhat worse than backtests. If they're much worse, investigate why.

## Common Mistakes to Avoid

### Mistake 1: Data Snooping

Testing hundreds of indicators/parameters until finding something that worked:

**Problem:** You're guaranteed to find something that "worked" by chance.

**Solution:** Have a hypothesis first, limit testing, use out-of-sample validation.

### Mistake 2: Ignoring Transaction Costs

Assuming you can trade without friction:

**Problem:** Costs eliminate profits from active strategies.

**Solution:** Always include realistic commissions and slippage.

### Mistake 3: Optimizing for One Metric

Maximizing returns while ignoring risk:

**Problem:** High returns often come with unacceptable risk.

**Solution:** Consider multiple metrics (returns, Sharpe, drawdown).

### Mistake 4: Survivorship Bias

Testing only on stocks that still exist today:

**Problem:** Ignores failed companies, inflates results.

**Solution:** Use datasets including delisted securities.

### Mistake 5: Small Sample Size

Drawing conclusions from few trades:

**Problem:** Results may be due to luck.

**Solution:** Require at least 30-50 trades before trusting results.

### Mistake 6: Ignoring Market Conditions

Assuming one strategy works in all environments:

**Problem:** Different conditions favor different approaches.

**Solution:** Recognize strategy limitations, adapt or wait.

## General Trading Wisdom

### Trading is a Business

Treat it professionally:
- Keep detailed records
- Track expenses (data, software, education)
- Monitor performance objectively
- Set business hours if day trading
- Have a business plan

### Simplicity Often Wins

Complex strategies with many rules:
- Are harder to understand
- Break more easily
- Often perform worse than simple approaches
- Are more likely overfit

Start simple. Add complexity only when clearly justified.

### Continuous Learning

Markets evolve. Successful traders:
- Read current research
- Learn from mistakes
- Test new ideas
- Adapt strategies
- Stay humble

### Know Your Limitations

Retail traders have disadvantages:
- Slower execution than institutions
- Limited capital
- Higher relative costs
- Less sophisticated infrastructure

But also advantages:
- Flexibility (can trade anything)
- No redemption pressure
- Simpler compliance
- Can use strategies institutions can't

Play to your strengths.

## Final Thoughts

TzuTrader provides tools for building and testing trading bots. The library handles the mechanics of backtesting, but success depends on:
- Sound strategy logic
- Rigorous testing methodology
- Realistic assumptions
- Proper risk management
- Disciplined execution

No library can guarantee profitable trading. Markets are challenging, and most traders fail. However, systematic approaches using tools like TzuTrader offer better chances than discretionary trading or guesswork.

If you're serious about algorithmic trading:
1. Study market structure and behavior
2. Develop clear hypotheses
3. Test rigorously with realistic assumptions
4. Start small and scale gradually
5. Learn continuously from results

Trading should never risk money you can't afford to lose. TzuTrader is an educational and research tool. Use it to learn, experiment, and develop skills before risking significant capital.

## Additional Resources

### Further Reading

**Books:**
- "Evidence-Based Technical Analysis" by David Aronson
- "Algorithmic Trading" by Ernest Chan
- "Trading Systems and Methods" by Perry Kaufman
- "Quantitative Trading" by Ernest Chan

**Papers:**
- Academic finance journals (SSRN, Journal of Finance)
- Strategy research from quantitative firms

**Online:**
- QuantConnect forums
- Elite Trader forums
- r/algotrading subreddit

### Continuing with TzuTrader

**Next steps:**
- Review the Reference Guide for detailed API specifications
- Examine the examples/ directory for working code
- Read the API documentation for function details
- Experiment with custom strategies
- Join the community (if available) to share ideas

Good luck with your trading bot development!

## Key Takeaways

- Start with a clear hypothesis about why a strategy should work
- Use realistic data covering multiple market conditions
- Test across many symbols and sectors for robustness
- Document all testing to learn from successes and failures
- Use conservative commission assumptions (0.1-0.2% per trade)
- Implement proper position sizing based on portfolio size and volatility
- Monitor drawdown and diversify across positions
- Paper trade before risking real capital, start small when going live
- Avoid common mistakes: overfitting, ignoring costs, small samples
- Treat trading as a professional business with discipline
- Simple strategies often outperform complex ones
- Learn continuously and adapt to changing markets
- Never risk money you can't afford to lose
