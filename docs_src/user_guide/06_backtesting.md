# Running Backtests

## What Does a Backtest Do?

A backtest simulates trading a strategy against historical data. Starting with initial capital, the backtest processes each price bar in sequence, following these steps:

1. The strategy analyzes current market conditions
2. The strategy generates a signal (Buy, Sell, or Stay)
3. If the signal is Buy or Sell, the portfolio executes a trade
4. The portfolio tracks positions, cash, and performance
5. Move to the next bar and repeat

At the end, the backtest produces a report showing how the strategy performed, including returns, risk metrics, and trade statistics.

## Setting Up a Backtest

The simplest way to run a backtest is with the `quickBacktest` function:

```nim
import tzutrader

# Load historical data
let data = readCSV("data/AAPL.csv")

# Create a strategy
let strategy = newRSIStrategy(period = 14, oversold = 30, overbought = 70)

# Run backtest
let report = quickBacktest(
  symbol = "AAPL",
  strategy = strategy,
  data = data,
  initialCash = 100000.0,
  commission = 0.001  # 0.1%
)

# View results
echo report.summary()
```

This handles all the complexity of setting up the portfolio, executing trades, and calculating metrics.

## Backtest Parameters

### Initial Capital

The `initialCash` parameter sets starting capital. Choose an amount that reflects realistic trading capital:

```nim
let report = quickBacktest(
  symbol = "AAPL",
  strategy = strategy,
  data = data,
  initialCash = 10000.0,  # $10,000 starting capital
  commission = 0.001
)
```

Smaller accounts face different constraints than large accounts:
- Lower capital means fewer shares per trade
- Commission costs have proportionally larger impact
- Minimum commission fees matter more

### Commission Rates

The `commission` parameter specifies trading costs as a decimal (0.001 = 0.1%):

```nim
# Different commission structures
let report1 = quickBacktest(..., commission = 0.0)      # Zero commission
let report2 = quickBacktest(..., commission = 0.001)    # 0.1% (typical discount broker)
let report3 = quickBacktest(..., commission = 0.0025)   # 0.25% (higher cost)
```

Commission impacts strategy performance significantly:
- High-frequency strategies suffer more from commission costs
- Lower commission makes more trades economically viable
- Always use realistic commission assumptions

Some brokers charge flat fees rather than percentages. In those cases, you can set a minimum commission when creating a portfolio manually (covered in the Portfolio Management chapter).

### Position Sizing

By default, `quickBacktest` invests 100% of available cash on each Buy signal. This is aggressive but simple. For more control over position sizing, use the manual backtesting approach:

```nim
import tzutrader

let data = readCSV("data/AAPL.csv")
let strategy = newRSIStrategy(period = 14, oversold = 30, overbought = 70)
let portfolio = newPortfolio(initialCash = 100000.0, commission = 0.001)

var signals = strategy.analyze(data)

for i, bar in data:
  let signal = signals[i]
  
  if signal.position == Buy:
    # Buy with 50% of available cash
    let amount = portfolio.cash * 0.5
    let shares = amount / bar.close
    discard portfolio.buy("AAPL", shares, bar.close, bar.timestamp)
    
  elif signal.position == Sell:
    # Close entire position
    if portfolio.hasPosition("AAPL"):
      discard portfolio.closePosition("AAPL", bar.close, bar.timestamp)
```

This manual approach gives full control over trading logic, position sizing, and risk management.

## Reading the Backtest Report

A backtest report contains extensive information about strategy performance. Let's examine each section:

### Summary Output

```
=== Backtest Results ===
Symbol: AAPL
Period: 2023-01-01 to 2023-12-31
Initial Capital: $100,000.00
Final Value: $108,245.50
```

This header shows the symbol tested, date range, and basic capital information. The final value includes cash plus the market value of any open positions.

### Return Metrics

```
Total Return: 8.25%
Annualized Return: 8.25%
```

**Total Return** measures overall gain or loss as a percentage. A value of 8.25% means capital grew from $100,000 to $108,245.50.

**Annualized Return** expresses returns on a yearly basis. If the test ran for 6 months and returned 4%, the annualized return would be approximately 8%. This allows comparing strategies tested over different time periods.

### Risk Metrics

```
Sharpe Ratio: 0.87
Maximum Drawdown: -12.34%
```

**Sharpe Ratio** measures risk-adjusted returns. It compares the strategy's excess returns to its volatility:
- Below 1.0: Modest risk-adjusted returns
- 1.0 - 2.0: Good risk-adjusted returns
- Above 2.0: Excellent risk-adjusted returns
- Above 3.0: Exceptional (rare in real trading)

The Sharpe ratio helps identify strategies that generate returns efficiently without excessive volatility.

**Maximum Drawdown** shows the largest peak-to-valley decline during the test period. A value of -12.34% means at some point, the portfolio declined 12.34% from a previous high before recovering.

Drawdown measures worst-case experience:
- Small drawdowns (-5% or less): Low risk
- Moderate drawdowns (-10% to -20%): Typical for stock strategies
- Large drawdowns (-30% or more): High risk, may be difficult to tolerate

### Trading Activity

```
Total Trades: 24
Win Rate: 58.33%
Winning Trades: 14
Losing Trades: 10
Average Win: $825.50
Average Loss: -$412.30
Profit Factor: 1.45
```

**Total Trades** counts executed transactions. More trades mean:
- Higher commission costs
- More market exposure
- Potentially more reliable statistics (larger sample)

**Win Rate** shows the percentage of profitable trades. This example's 58.33% means 14 out of 24 trades made money.

Win rate alone doesn't determine profitability - a strategy with 30% win rate can be profitable if winning trades are much larger than losing trades.

**Average Win/Loss** shows typical profit and loss per trade. This example makes $825.50 on average when winning but only loses $412.30 on average when losing. The asymmetry contributes to overall profitability.

**Profit Factor** is the ratio of gross profits to gross losses. Values above 1.0 indicate profitability:
- 1.0 - 1.5: Modestly profitable
- 1.5 - 2.0: Good profitability
- Above 2.0: Strong profitability

This example's 1.45 means for every dollar lost, the strategy made $1.45 in winning trades.

## Interpreting Results

### What Makes a Good Backtest Result?

There's no universal standard, but consider these guidelines:

**Returns:**
- Compare to buy-and-hold benchmark (simply holding the security)
- Compare to market indices (S&P 500 returns ~10% annually long-term)
- Consider risk-free rate (treasury bonds at ~4-5% currently)

A strategy returning 8% annually might seem modest, but if it does so with lower volatility than buy-and-hold, it may be valuable.

**Risk Metrics:**
- Sharpe ratio above 1.0 is generally acceptable
- Maximum drawdown should be tolerable based on your risk tolerance
- Drawdown recovery time matters (how long to regain losses)

**Trading Activity:**
- Enough trades for statistical significance (ideally 30+)
- Win rate between 40-60% is typical (extremes may indicate issues)
- Profit factor above 1.3 shows meaningful edge

### Red Flags

Be skeptical of results showing:

- **Very high returns (50%+ annually)**: Likely overfitted or unrealistic
- **Very high win rates (80%+)**: May indicate look-ahead bias
- **Very few trades (<10)**: Insufficient sample size
- **Perfect equity curve**: Probably a coding error
- **Returns much higher than buy-and-hold with similar risk**: Unusual, verify carefully

## Common Backtesting Pitfalls

### Overfitting

Overfitting occurs when you optimize a strategy to perform well on historical data, but it fails on new data. This happens when:

- Testing many parameter combinations and choosing the best
- Adding rules specifically to avoid historical losses
- Using very short test periods

**Mitigation:**
- Use out-of-sample testing (test on data not used for development)
- Limit parameter optimization
- Prefer simple strategies over complex ones
- Test across multiple symbols and time periods

### Look-Ahead Bias

Look-ahead bias uses information that wouldn't have been available at the time of the trade. Examples:

- Using closing price to make decisions during the day
- Calculating indicators using future data
- Assuming knowledge of intraday highs/lows when trading on open

TzuTrader processes data chronologically to prevent this, but be careful when writing custom strategies.

### Survivorship Bias

Testing only stocks that still exist today ignores companies that failed or were delisted. This makes results appear better than they would have been in real-time.

**Mitigation:**
- Use datasets that include delisted securities
- Be aware this bias exists in free data sources
- Discount backtest results accordingly

### Ignoring Market Impact

Backtests assume you can buy or sell any amount at the historical price. In reality:

- Large orders move prices against you
- Bid-ask spreads cost money
- Liquidity varies

For small retail accounts trading liquid stocks, market impact is minimal. For larger accounts or illiquid securities, it matters significantly.

## Analyzing the Equity Curve

The equity curve shows portfolio value over time. Access it programmatically:

```nim
let report = quickBacktest(...)

# Access equity curve data
for i, equity in report.equityCurve:
  let timestamp = report.data[i].timestamp
  let date = fromUnix(timestamp)
  echo date, ": $", equity
```

A good equity curve:
- Trends upward consistently
- Has smooth growth without dramatic swings
- Recovers from drawdowns relatively quickly

A problematic equity curve:
- Shows long flat periods
- Has severe drawdowns
- Makes all gains in one or two large jumps

## Next Steps: Comparing Strategies

Once you've run backtests on individual symbols, you may want to compare how a strategy performs across multiple securities. This helps identify robust strategies that work in various market conditions.

The next chapter (Comparing Strategies) covers using the Scanner module to test strategies across multiple symbols and rank results.

## Key Takeaways

- Backtests simulate trading a strategy against historical data
- Use `quickBacktest()` for simple backtests or build custom backtests for more control
- Set realistic initial capital and commission rates
- Interpret results holistically - consider returns, risk metrics, and trading activity together
- Be skeptical of overly good results - they often indicate problems
- Watch for common pitfalls: overfitting, look-ahead bias, and survivorship bias
- Good backtests inform strategy understanding, not guarantee future profits
