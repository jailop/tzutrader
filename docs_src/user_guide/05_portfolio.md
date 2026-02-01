# Managing Your Portfolio

## What is Portfolio Management?

Portfolio management involves tracking capital, positions, and trades. A
portfolio starts with initial cash and changes as trades are executed -
cash decreases when buying, positions are opened, and both adjust when
selling.

Effective portfolio management includes:

- Tracking available cash and open positions
- Calculating profit and loss (realized and unrealized)
- Managing commission costs
- Measuring performance
- Recording transaction history

In TzuTrader, the `Portfolio` object handles all these responsibilities.

## Creating a Portfolio

Create a portfolio with initial capital and commission settings:

```nim
import tzutrader

let portfolio = newPortfolio(
  initialCash = 100000.0,  # Starting with $100,000
  commission = 0.001,      # 0.1% commission rate
  minCommission = 0.0      # No minimum commission
)
```

Parameters:

- `initialCash`: Starting capital (default $100,000)
- `commission`: Commission rate as decimal (0.001 = 0.1%)
- `minCommission`: Minimum commission per trade (default $0)

The portfolio tracks both cash and positions. Initially, all capital is in cash with no positions.

## Understanding Commission

Every trade incurs commission costs that reduce profitability. TzuTrader supports two commission models:

### Percentage Commission

Most common for stocks. Pay a percentage of trade value:

```nim
# 0.1% commission
let portfolio = newPortfolio(initialCash = 100000.0, commission = 0.001)

# Buying $10,000 worth of stock costs $10 commission
# Selling $10,000 worth of stock costs another $10 commission
```

### Minimum Commission

Some brokers charge a flat fee per trade (e.g., $1 minimum):

```nim
let portfolio = newPortfolio(
  initialCash = 100000.0,
  commission = 0.001,      # 0.1% rate
  minCommission = 1.0      # But at least $1
)

# Small trade: $500 * 0.001 = $0.50, but charged $1.00 (minimum)
# Large trade: $50,000 * 0.001 = $50.00, charged $50.00 (above minimum)
```

Impact on strategy:

- High-frequency strategies pay more commission
- Small position sizes become economically unviable with high commissions
- Always use realistic commission assumptions in backtests

## Executing Trades

### Buying Securities

Open or increase a position:

```nim
import tzutrader

let portfolio = newPortfolio(initialCash = 100000.0, commission = 0.001)

# Buy 100 shares of AAPL at $150
let success = portfolio.buy(
  symbol = "AAPL",
  quantity = 100.0,
  price = 150.0
)

if success:
  echo "Purchase successful"
  echo "Cash remaining: $", portfolio.cash
else:
  echo "Purchase failed (insufficient funds)"
```

The `buy()` method:

- Returns `true` if successful, `false` if insufficient cash
- Deducts cost plus commission from cash
- Creates or increases position
- Records transaction in history

Cost calculation:

```
Total cost = (quantity × price) + commission
Commission = max(quantity × price × commission_rate, min_commission)
```

### Selling Securities

Close or reduce a position:

```nim
# Sell 50 shares of AAPL at $160
let success = portfolio.sell(
  symbol = "AAPL",
  quantity = 50.0,
  price = 160.0
)

if success:
  echo "Sale successful"
  echo "Cash now: $", portfolio.cash
else:
  echo "Sale failed (insufficient position)"
```

The `sell()` method:

- Returns `true` if successful, `false` if insufficient shares
- Adds proceeds minus commission to cash
- Reduces or closes position
- Records transaction and realized P&L

Proceeds calculation:

```
Proceeds = (quantity × price) - commission
```

### Closing Positions

Close an entire position at once:

```nim
# Close entire AAPL position at current price
let success = portfolio.closePosition(
  symbol = "AAPL",
  price = 160.0
)
```

This is equivalent to selling all shares of the position.

## Position Tracking

Check current positions:

```nim
# Check if we have a position
if portfolio.hasPosition("AAPL"):
  let position = portfolio.getPosition("AAPL")
  echo "Quantity: ", position.quantity
  echo "Entry price: $", position.entryPrice
  echo "Current price: $", position.currentPrice
  echo "Unrealized P&L: $", position.unrealizedPnL
```

Position information includes:

- `quantity`: Number of shares held
- `entryPrice`: Average purchase price
- `currentPrice`: Latest market price
- `unrealizedPnL`: Profit/loss if sold at current price
- `realizedPnL`: Profit/loss from partial sales

### Updating Market Prices

Positions need current prices to calculate unrealized P&L:

```nim
import std/tables

# Update prices for all positions
var prices = initTable[string, float64]()
prices["AAPL"] = 165.0
prices["MSFT"] = 310.0

portfolio.updatePrices(prices)

# Now position.currentPrice and unrealizedPnL are updated
```

## Capital Allocation

### Available Cash

Check available cash before buying:

```nim
echo "Available: $", portfolio.cash

if portfolio.cash >= targetCost:
  # Can afford the trade
  discard portfolio.buy(symbol, quantity, price)
```

### Position Sizing

The amount invested in each trade affects risk and returns. Common approaches:

#### Fixed Dollar Amount

Invest the same dollar amount in each trade:

```nim
let targetAmount = 10000.0  # $10,000 per position
let shares = targetAmount / price
discard portfolio.buy(symbol, shares, price)
```

Pros: Simple, consistent exposure
Cons: Doesn't adapt to account size changes

#### Fixed Percentage

Invest a percentage of current capital:

```nim
let pctToInvest = 0.10  # 10% of portfolio
let amount = portfolio.equity(prices) * pctToInvest
let shares = amount / price
discard portfolio.buy(symbol, shares, price)
```

Pros: Adapts to account size, compounds gains
Cons: Position sizes vary over time

#### All-In

Invest all available cash (used by `quickBacktest`):

```nim
let shares = portfolio.cash / price
discard portfolio.buy(symbol, shares, price)
```

Pros: Maximum exposure, simple
Cons: High risk, no diversification

Choose based on risk tolerance and strategy type. Conservative traders use smaller percentages (5-10%), aggressive traders use larger allocations.

## Profit and Loss (P&L)

### Realized P&L

Profit or loss from closed trades (trades that have been sold):

```nim
echo "Realized P&L: $", portfolio.totalRealizedPnL
```

This only includes completed round-trips (buy then sell).

### Unrealized P&L

Profit or loss from open positions (not yet sold):

```nim
let unrealizedPnL = portfolio.unrealizedPnL()
echo "Unrealized P&L: $", unrealizedPnL
```

This shows what you would gain or lose if you closed all positions at current prices.

### Total Equity

Total portfolio value (cash + position values):

```nim
let totalEquity = portfolio.equity(prices)
echo "Total equity: $", totalEquity
```

Calculation:

```
Equity = cash + sum(position_quantity × current_price for all positions)
```

This is the bottom line - what the portfolio is worth right now.

## Performance Metrics

Calculate comprehensive performance statistics:

```nim
let metrics = portfolio.calculatePerformance(prices)

echo "Total Return: ", metrics.totalReturn, "%"
echo "Annualized Return: ", metrics.annualizedReturn, "%"
echo "Sharpe Ratio: ", metrics.sharpeRatio
echo "Max Drawdown: ", metrics.maxDrawdown, "%"
echo "Win Rate: ", metrics.winRate, "%"
echo "Total Trades: ", metrics.totalTrades
echo "Profit Factor: ", metrics.profitFactor
```

Key metrics explained:

### Total Return

Percentage gain or loss:
```
Total Return = ((Final Equity - Initial Cash) / Initial Cash) × 100
```

### Annualized Return

Average yearly return (useful for comparing different time periods):
```
Annualized Return = (1 + Total Return) ^ (1 / years) - 1
```

### Sharpe Ratio

Risk-adjusted returns (return per unit of volatility):
```
Sharpe Ratio = (Return - Risk-Free Rate) / Standard Deviation of Returns
```

Higher is better. Values above 1.0 indicate good risk-adjusted performance.

### Maximum Drawdown

Largest peak-to-valley decline:
```
Max Drawdown = (Trough Value - Peak Value) / Peak Value × 100
```

Measures worst-case scenario. Lower is better.

### Win Rate

Percentage of profitable trades:
```
Win Rate = (Winning Trades / Total Trades) × 100
```

### Profit Factor

Ratio of gross profits to gross losses:
```
Profit Factor = Total Winning $ / Total Losing $
```

Values above 1.0 indicate profitability. Above 1.5 is good.

## Transaction History

Access complete transaction history:

```nim
for tx in portfolio.transactions:
  echo tx  # Prints transaction details
```

Each transaction includes:

- Timestamp
- Symbol
- Action (Buy or Sell)
- Quantity
- Price
- Commission

This history is useful for:

- Audit trails
- Tax reporting
- Strategy analysis
- Debugging

## Example: Manual Portfolio Management

Here's a complete example managing a portfolio manually:

```nim
import tzutrader
import std/tables

# Create portfolio
let portfolio = newPortfolio(
  initialCash = 50000.0,
  commission = 0.001
)

# Buy two positions
discard portfolio.buy("AAPL", 100.0, 150.0)
discard portfolio.buy("MSFT", 50.0, 300.0)

echo "Cash after purchases: $", portfolio.cash
echo "Positions: ", portfolio.positions.len

# Update prices
var prices = initTable[string, float64]()
prices["AAPL"] = 160.0  # Gained $10
prices["MSFT"] = 295.0  # Lost $5

portfolio.updatePrices(prices)

echo "Unrealized P&L: $", portfolio.unrealizedPnL()
echo "Total Equity: $", portfolio.equity(prices)

# Close one position
discard portfolio.closePosition("AAPL", 160.0)

echo "Realized P&L: $", portfolio.totalRealizedPnL
echo "Remaining positions: ", portfolio.positions.len

# Calculate final metrics
let metrics = portfolio.calculatePerformance(prices)
echo "Total Return: ", metrics.totalReturn, "%"
echo "Win Rate: ", metrics.winRate, "%"
```

## Position Management Considerations

### Concentration Risk

Holding too much in one position increases risk:

```nim
# Check position concentration
let totalValue = portfolio.equity(prices)
let applePosition = portfolio.getPosition("AAPL")
let appleValue = applePosition.quantity * applePosition.currentPrice
let concentration = (appleValue / totalValue) * 100

echo "AAPL represents ", concentration, "% of portfolio"
```

Most traders limit single positions to 10-20% of the portfolio.

### Diversification

Spreading capital across multiple positions reduces risk:

```nim
echo "Number of positions: ", portfolio.positions.len

# Generally want 5-15 positions for retail accounts
```

Too few positions = high concentration risk
Too many positions = diluted returns, harder to manage

## Integration with Backtesting

When using `quickBacktest`, portfolio management is handled automatically:

```nim
let report = quickBacktest(
  symbol = "AAPL",
  strategy = strategy,
  data = data,
  initialCash = 100000.0,
  commission = 0.001
)
```

The backtester:

- Creates a portfolio
- Executes buy/sell signals
- Updates prices each bar
- Tracks performance
- Generates the report

For custom control, build your own backtest loop with explicit portfolio management.

## Next Steps

The next chapter covers comparing strategies across multiple symbols using the Scanner module. This helps identify robust strategies that work across different securities.

## Key Takeaways

- Portfolios track cash, positions, and transaction history
- Commission costs reduce profitability - use realistic assumptions
- Use `buy()`, `sell()`, and `closePosition()` to execute trades
- Track realized P&L (closed trades) and unrealized P&L (open positions)
- Total equity = cash + position values at current prices
- Position sizing affects risk - consider fixed dollars, fixed
  percentages, or all-in
- Performance metrics provide comprehensive strategy evaluation
- Concentration risk matters - avoid putting all capital in one position
- Diversification reduces risk but requires more capital
- Portfolio management integrates with backtesting automatically
