# Reference Guide: Portfolio Management

## Overview

The portfolio module tracks cash, positions, transactions, and performance metrics. It handles the accounting side of trading—executing orders, calculating commissions, tracking profit and loss, and measuring performance.

While strategies decide what to trade, portfolios manage the mechanics of trading and keep score.

**Module:** `tzutrader/portfolio.nim`

## Portfolio Fundamentals

A portfolio represents your trading account: how much cash you have, what positions you hold, and your trading history. The `Portfolio` object maintains this state throughout a backtest or live trading session.

**Core responsibilities:**

- **Cash management:** Track available capital
- **Position tracking:** Monitor open positions and their values
- **Order execution:** Process buy and sell orders with commissions
- **P&L calculation:** Compute realized and unrealized profits/losses
- **Performance measurement:** Generate comprehensive metrics

## Portfolio Type

### Structure

```nim
type
  Portfolio* = ref object
    initialCash*: float64
    cash*: float64
    positions*: Table[string, PositionInfo]
    transactions*: seq[Transaction]
    commission*: float64
    minCommission*: float64
    totalRealizedPnL*: float64
```

**Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `initialCash` | float64 | Starting capital (never changes) |
| `cash` | float64 | Current available cash |
| `positions` | Table | Open positions indexed by symbol |
| `transactions` | seq[Transaction] | Complete trade history |
| `commission` | float64 | Commission rate (0.001 = 0.1%) |
| `minCommission` | float64 | Minimum commission per trade |
| `totalRealizedPnL` | float64 | Cumulative realized P&L |

### Constructor

```nim
proc newPortfolio*(initialCash: float64 = 100000.0, 
                   commission: float64 = 0.0, 
                   minCommission: float64 = 0.0): Portfolio
```

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `initialCash` | float64 | 100000.0 | Starting capital ($) |
| `commission` | float64 | 0.0 | Commission rate (decimal) |
| `minCommission` | float64 | 0.0 | Minimum fee per trade ($) |

**Commission models:**

- **Percentage:** `commission = 0.001` (0.1% per trade)
- **Minimum:** `minCommission = 1.0` ($1 minimum, even for small trades)
- **Combined:** Charge percentage or minimum, whichever is higher

**Example:**

```nim
import tzutrader

# No commissions (unrealistic but useful for testing)
let p1 = newPortfolio(initialCash = 100000.0)

# 0.1% commission, $1 minimum
let p2 = newPortfolio(
  initialCash = 50000.0,
  commission = 0.001,
  minCommission = 1.0
)

# Flat $5 per trade
let p3 = newPortfolio(
  initialCash = 100000.0,
  commission = 0.0,
  minCommission = 5.0
)
```

## Position Information

### PositionInfo Type

```nim
type
  PositionInfo* = object
    symbol*: string
    side*: PositionSide
    quantity*: float64
    entryPrice*: float64
    entryTime*: int64
    currentPrice*: float64
    unrealizedPnL*: float64
    realizedPnL*: float64
```

**Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `symbol` | string | Symbol identifier |
| `side` | PositionSide | Long, Short, or Flat |
| `quantity` | float64 | Number of shares held |
| `entryPrice` | float64 | Average entry price |
| `entryTime` | int64 | When position opened (Unix timestamp) |
| `currentPrice` | float64 | Latest market price |
| `unrealizedPnL` | float64 | Current open P&L |
| `realizedPnL` | float64 | P&L from partial closes |

### PositionSide Enum

```nim
type
  PositionSide* = enum
    Long = "LONG"
    Short = "SHORT"
    Flat = "FLAT"
```

**Values:**

- `Long`: Own the asset (buy to open, sell to close)
- `Short`: Borrowed asset (sell to open, buy to close) - **Not currently implemented**
- `Flat`: No position

**Note:** TzuTrader currently supports only long positions. Short selling may be added in future versions.

### Position Methods

#### marketValue

```nim
proc marketValue*(pos: PositionInfo): float64
```

Calculates current market value of the position.

**Formula (Long):**

$$\text{Market Value} = \text{quantity} \times \text{currentPrice}$$

**Example:**

```nim
# Position: 100 shares at $150
let pos = portfolio.getPosition("AAPL")
echo "Market value: $", pos.marketValue()
# Output: Market value: $15000
```

#### totalPnL

```nim
proc totalPnL*(pos: PositionInfo): float64
```

Returns total P&L combining realized and unrealized.

**Formula:**

$$\text{Total P\&L} = \text{realizedPnL} + \text{unrealizedPnL}$$

#### updatePrice

```nim
proc updatePrice*(pos: var PositionInfo, currentPrice: float64)
```

Updates position with new market price and recalculates unrealized P&L.

**Unrealized P&L Formula (Long):**

$$\text{Unrealized P\&L} = (\text{currentPrice} - \text{entryPrice}) \times \text{quantity}$$

## Order Execution

### Buying

```nim
proc buy*(p: Portfolio, symbol: string, quantity: float64, price: float64, 
          timestamp: int64 = 0): bool
```

Executes a buy order (opens or adds to long position).

**Parameters:**

- `symbol`: Symbol to buy
- `quantity`: Number of shares (must be > 0)
- `price`: Price per share
- `timestamp`: Optional timestamp (uses current time if 0)

**Returns:** `true` if executed, `false` if insufficient cash

**Execution logic:**

1. Calculate total cost including commission:

$$\text{Total Cost} = (\text{quantity} \times \text{price}) + \text{commission}$$

2. Check if sufficient cash available
3. Deduct cost from cash
4. Create or update position with new average entry price
5. Record transaction

**Average Entry Price:**

When adding to an existing position, the entry price becomes a quantity-weighted average:

$$\text{New Entry} = \frac{(\text{existing qty} \times \text{existing price}) + (\text{new qty} \times \text{new price})}{\text{existing qty} + \text{new qty}}$$

**Example:**

```nim
import tzutrader

let portfolio = newPortfolio(initialCash = 100000.0, commission = 0.001)

# Buy 100 shares of AAPL at $150
if portfolio.buy("AAPL", 100.0, 150.0):
  echo "Order executed"
  echo "Cash remaining: $", portfolio.cash
  
# Buy 50 more shares at $155 (adds to position)
if portfolio.buy("AAPL", 50.0, 155.0):
  let pos = portfolio.getPosition("AAPL")
  echo "Position: ", pos.quantity, " shares"
  echo "Average entry: $", pos.entryPrice
  # Entry price is now weighted average of $150 and $155
```

### Selling

```nim
proc sell*(p: Portfolio, symbol: string, quantity: float64, price: float64,
           timestamp: int64 = 0): bool
```

Executes a sell order (closes or reduces long position).

**Parameters:**

- `symbol`: Symbol to sell
- `quantity`: Number of shares (must be > 0)
- `price`: Price per share
- `timestamp`: Optional timestamp

**Returns:** `true` if executed, `false` if insufficient position

**Execution logic:**

1. Verify position exists and has sufficient quantity
2. Calculate proceeds after commission:

$$\text{Net Proceeds} = (\text{quantity} \times \text{price}) - \text{commission}$$

3. Calculate realized P&L:

$$\text{Realized P\&L} = (\text{price} - \text{entryPrice}) \times \text{quantity} - \text{commission}$$

4. Add proceeds to cash
5. Reduce or close position
6. Record transaction

**Example:**

```nim
import tzutrader

# Assuming we have a position
if portfolio.sell("AAPL", 50.0, 160.0):
  echo "Sold 50 shares at $160"
  echo "Realized P&L: $", 
       (160.0 - pos.entryPrice) * 50.0 - commission
```

### Closing Entire Position

```nim
proc closePosition*(p: Portfolio, symbol: string, price: float64,
                    timestamp: int64 = 0): bool
```

Closes the entire position in one trade.

**Example:**

```nim
# Close entire AAPL position at current price
if portfolio.closePosition("AAPL", 165.0):
  echo "Position closed"
```

This is equivalent to calling `sell` with the full position quantity.

## Portfolio Queries

### Checking Positions

```nim
proc hasPosition*(p: Portfolio, symbol: string): bool
```

Returns `true` if portfolio holds the symbol.

```nim
proc getPosition*(p: Portfolio, symbol: string): PositionInfo
```

Returns position info (flat position if none exists).

**Example:**

```nim
if portfolio.hasPosition("AAPL"):
  let pos = portfolio.getPosition("AAPL")
  echo "Holding ", pos.quantity, " shares at $", pos.entryPrice
else:
  echo "No position in AAPL"
```

### Portfolio Valuation

#### equity

```nim
proc equity*(p: Portfolio, currentPrices: Table[string, float64] = initTable[string, float64]()): float64
```

Calculates total portfolio value (cash plus position values).

**Formula:**

$$\text{Equity} = \text{cash} + \sum_{i} (\text{quantity}_i \times \text{price}_i)$$

**Parameters:**

- `currentPrices`: Optional table of current prices for marking positions to market

**Example:**

```nim
import tzutrader, std/tables

# Get equity with default prices
let equity1 = portfolio.equity()

# Get equity with updated prices
var prices = initTable[string, float64]()
prices["AAPL"] = 170.0
prices["MSFT"] = 350.0
let equity2 = portfolio.equity(prices)

echo "Portfolio value: $", equity2
```

#### marketValue

```nim
proc marketValue*(p: Portfolio): float64
```

Returns total value of all positions (excludes cash).

**Example:**

```nim
echo "Cash: $", portfolio.cash
echo "Positions: $", portfolio.marketValue()
echo "Total: $", portfolio.equity()
```

### Profit and Loss

#### unrealizedPnL

```nim
proc unrealizedPnL*(p: Portfolio): float64
```

Returns total unrealized P&L across all open positions.

**Formula:**

$$\text{Unrealized P\&L} = \sum_{i} (\text{currentPrice}_i - \text{entryPrice}_i) \times \text{quantity}_i$$

#### realizedPnL

```nim
proc realizedPnL*(p: Portfolio): float64
```

Returns cumulative realized P&L from all closed and partially closed positions.

#### totalPnL

```nim
proc totalPnL*(p: Portfolio): float64
```

Returns combined realized and unrealized P&L.

**Formula:**

$$\text{Total P\&L} = \text{realizedPnL} + \text{unrealizedPnL}$$

**Example:**

```nim
echo "Unrealized: $", portfolio.unrealizedPnL()
echo "Realized: $", portfolio.realizedPnL()
echo "Total P&L: $", portfolio.totalPnL()

let returnPct = (portfolio.totalPnL() / portfolio.initialCash) * 100.0
echo "Return: ", returnPct, "%"
```

## Commission Calculation

```nim
proc calculateCommission*(p: Portfolio, quantity: float64, price: float64): float64
```

Calculates commission for a hypothetical trade.

**Formula:**

$$\text{Commission} = \max(\text{tradeValue} \times \text{rate}, \text{minCommission})$$

where:

$$\text{tradeValue} = |\text{quantity}| \times \text{price}$$

**Example:**

```nim
let portfolio = newPortfolio(
  commission = 0.001,      # 0.1%
  minCommission = 1.0      # $1 minimum
)

# Small trade: 10 shares at $10 = $100
let comm1 = portfolio.calculateCommission(10.0, 10.0)
# comm1 = max($100 * 0.001, $1) = max($0.10, $1) = $1

# Large trade: 1000 shares at $100 = $100,000
let comm2 = portfolio.calculateCommission(1000.0, 100.0)
# comm2 = max($100,000 * 0.001, $1) = max($100, $1) = $100
```

## Price Updates

```nim
proc updatePrices*(p: Portfolio, prices: Table[string, float64])
```

Updates all position prices with current market prices.

**Usage:**

During backtesting, call this method at each bar to mark positions to market:

```nim
import tzutrader, std/tables

for bar in data:
  var prices = initTable[string, float64]()
  prices["AAPL"] = bar.close
  
  portfolio.updatePrices(prices)
  
  # Now portfolio.equity() and unrealizedPnL() reflect current prices
```

## Performance Metrics

```nim
proc calculatePerformance*(p: Portfolio, 
                           currentPrices: Table[string, float64] = initTable[string, float64](),
                           riskFreeRate: float64 = 0.02): PerformanceMetrics
```

Calculates comprehensive performance statistics.

**Parameters:**

- `currentPrices`: Current market prices for open positions
- `riskFreeRate`: Annual risk-free rate for Sharpe ratio (default 2%)

**Returns:** `PerformanceMetrics` object

### PerformanceMetrics Type

```nim
type
  PerformanceMetrics* = object
    totalReturn*: float64
    annualizedReturn*: float64
    sharpeRatio*: float64
    maxDrawdown*: float64
    winRate*: float64
    totalTrades*: int
    winningTrades*: int
    losingTrades*: int
    avgWin*: float64
    avgLoss*: float64
    profitFactor*: float64
```

**Metric Formulas:**

#### Total Return

$$\text{Total Return} = \frac{\text{currentEquity} - \text{initialCash}}{\text{initialCash}} \times 100$$

#### Win Rate

$$\text{Win Rate} = \frac{\text{winningTrades}}{\text{totalTrades}} \times 100$$

#### Profit Factor

$$\text{Profit Factor} = \frac{\sum \text{winningTrades}}{|\sum \text{losingTrades}|}$$

#### Sharpe Ratio (Simplified)

$$\text{Sharpe} = \frac{\bar{r} - r_f}{\sigma_r} \times \sqrt{252}$$

where:
- $\bar{r}$ = average return per transaction
- $r_f$ = risk-free rate per period
- $\sigma_r$ = standard deviation of returns
- $\sqrt{252}$ = annualization factor (252 trading days)

**Note:** The portfolio's Sharpe calculation uses transaction-based returns. For more accurate Sharpe ratios based on time-series returns, use the backtester's equity curve.

#### Maximum Drawdown

$$\text{Max Drawdown} = \max_t \left( \frac{\text{Peak}_t - \text{Equity}_t}{\text{Peak}_t} \times 100 \right)$$

where $\text{Peak}_t$ is the highest equity observed up to time $t$.

**Example:**

```nim
import tzutrader, std/tables

var prices = initTable[string, float64]()
prices["AAPL"] = 170.0

let metrics = portfolio.calculatePerformance(prices, riskFreeRate = 0.02)

echo "Total Return: ", metrics.totalReturn, "%"
echo "Sharpe Ratio: ", metrics.sharpeRatio
echo "Win Rate: ", metrics.winRate, "%"
echo "Profit Factor: ", metrics.profitFactor
echo "Max Drawdown: ", metrics.maxDrawdown, "%"
```

## Transaction History

The portfolio maintains a complete transaction log:

```nim
type
  Transaction* = object
    timestamp*: int64
    symbol*: string
    action*: Position
    quantity*: float64
    price*: float64
    commission*: float64
```

See [Core Types Reference](01_core.md) for complete Transaction specification.

**Accessing history:**

```nim
echo "Transaction history:"
for tx in portfolio.transactions:
  echo tx.timestamp.fromUnix.format("yyyy-MM-dd"), ": ",
       tx.action, " ", tx.quantity, " ", tx.symbol, 
       " @ $", tx.price, " (fee: $", tx.commission, ")"
```

## Common Portfolio Patterns

### Position Sizing by Capital Percentage

```nim
# Use 10% of capital per position
let portfolioValue = portfolio.equity()
let positionSize = portfolioValue * 0.10
let quantity = floor(positionSize / price)

if portfolio.buy(symbol, quantity, price):
  echo "Bought ", quantity, " shares"
```

### Equal Weight Allocation

```nim
# Allocate equally across N symbols
let portfolioValue = portfolio.equity()
let allocationPerSymbol = portfolioValue / symbols.len.float64

for symbol in symbols:
  let quantity = floor(allocationPerSymbol / prices[symbol])
  discard portfolio.buy(symbol, quantity, prices[symbol])
```

### Stop Loss Management

```nim
# Check unrealized loss and exit if exceeds threshold
for symbol, pos in portfolio.positions:
  let lossPct = (pos.unrealizedPnL / (pos.quantity * pos.entryPrice)) * 100.0
  
  if lossPct < -5.0:  # -5% stop loss
    echo "Stop loss triggered for ", symbol
    discard portfolio.closePosition(symbol, pos.currentPrice)
```

### Rebalancing

```nim
# Rebalance to maintain equal weights
let targetAllocation = 1.0 / symbols.len.float64
let portfolioValue = portfolio.equity(prices)

for symbol in symbols:
  let currentValue = if portfolio.hasPosition(symbol):
    portfolio.getPosition(symbol).marketValue()
  else:
    0.0
  
  let currentWeight = currentValue / portfolioValue
  let targetValue = portfolioValue * targetAllocation
  
  if currentWeight < targetAllocation - 0.05:
    # Underweight: buy
    let buyValue = targetValue - currentValue
    let quantity = floor(buyValue / prices[symbol])
    discard portfolio.buy(symbol, quantity, prices[symbol])
  elif currentWeight > targetAllocation + 0.05:
    # Overweight: sell
    let sellValue = currentValue - targetValue
    let quantity = floor(sellValue / prices[symbol])
    discard portfolio.sell(symbol, quantity, prices[symbol])
```

## Display and Debugging

```nim
proc `$`*(p: Portfolio): string
```

Returns human-readable portfolio summary:

```nim
echo portfolio
# Output: Portfolio(cash=$85000.00, positions=2, equity=$103500.00)
```

```nim
proc `$`*(pos: PositionInfo): string
```

Returns position summary:

```nim
let pos = portfolio.getPosition("AAPL")
echo pos
# Output: Position(AAPL, LONG, qty=100.00, entry=$150.00, current=$155.00, PnL=$500.00)
```

```nim
proc `$`*(m: PerformanceMetrics): string
```

Returns metrics summary:

```nim
let metrics = portfolio.calculatePerformance()
echo metrics
# Output: Performance(return=15.30%, trades=42, winRate=58.3%, sharpe=1.45, maxDD=-12.50%)
```

## See Also

- [Core Types Reference](01_core.md) - Transaction and Position types
- [Backtesting Reference](06_backtesting.md) - Using portfolios in backtests
- [User Guide: Portfolio Management](../user_guide/05_portfolio.md) - Conceptual introduction
- [User Guide: Best Practices](../user_guide/09_best_practices.md) - Position sizing and risk management
