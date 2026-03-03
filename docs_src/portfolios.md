# Portfolios

A portfolio manages capital, positions, and trade execution. It receives signals from strategies and decides how to act on them, tracking performance along the way.

## BasicPortfolio

The `BasicPortfolio` class provides simple position management with risk controls:

```cpp
BasicPortfolio portfolio(
    100000.0,  // initial_capital
    0.001,     // transaction_cost_pct (0.1%)
    0.10,      // stop_loss_pct (10%)
    0.20       // take_profit_pct (20%)
);
```

### How It Works

**On BUY signals:**

- Uses all available cash to purchase
- Applies transaction costs
- Opens a new position
- Tracks entry price and timestamp

**On SELL signals:**

- Closes all positions
- Applies transaction costs
- Records profit/loss
- Updates performance metrics

**On every update:**

- Checks stop-loss conditions
- Checks take-profit conditions
- Automatically liquidates if thresholds are hit

This is an "all-in" approach: you're either fully invested or fully in cash. Not realistic for professional trading, but simple for testing strategy ideas.

## Position Management

```cpp
struct Position {
    double quantity;
    double price;
    int64_t timestamp;
};
```

Positions track:

- How much you own
- Your entry price
- When you entered

The portfolio uses this to calculate returns and trigger risk management rules.

## Risk Management

### Stop-Loss

Automatically sells if the price drops by a certain percentage from your entry:

```cpp
double return_pct = (current_price - entry_price) / entry_price;
if (return_pct <= -stop_loss_pct) {
    liquidate_position();  // Cut losses
}
```

Example: With a 10% stop-loss, if you buy at $100 and price drops to $90, the position is automatically closed.

**Why it matters:** Limits maximum loss on any single trade. Prevents holding losers too long.

**Limitation:** Can get stopped out right before a reversal. Markets are noisy.

### Take-Profit

Automatically sells if the price rises by a certain percentage from your entry:

```cpp
if (return_pct >= take_profit_pct) {
    liquidate_position();  // Lock in gains
}
```

Example: With a 20% take-profit, if you buy at $100 and price rises to $120, the position is automatically closed.

**Why it matters:** Locks in profits before they disappear. Prevents greed from turning winners into losers.

**Limitation:** Caps your upside. You might miss bigger moves.

### Setting Appropriate Levels

**Tight stops (5%)**: Less risk per trade, but more false exits on noise.

**Wide stops (20%)**: More room for normal fluctuation, but larger losses when wrong.

**Tight profits (10%)**: Frequent small wins, but misses big moves.

**Wide profits (50%)**: Rare but large wins, many small losses along the way.

There's no universal "best" setting. It depends on your strategy, asset volatility, and risk tolerance. Test different values in your backtests.

## Transaction Costs

Every trade has costs:

```cpp
double cost = quantity * price * transaction_cost_pct;
cash -= cost;  // Deducted from your capital
```

**Why it matters:** A strategy that trades 100 times per year with 0.1% costs loses 10% to fees alone. High-frequency strategies need very low costs to be profitable.

**Typical costs:**

- Stock broker: 0.05% - 0.5%
- Crypto exchange: 0.1% - 0.5%
- Futures: $1-5 per contract

Model costs realistically. Strategies that look profitable before costs often aren't after.

## Performance Metrics

The portfolio tracks:

- **Total return**: (final_value - initial_value) / initial_value
- **Annual return**: Total return annualized based on time period
- **Win rate**: Winning trades / total trades
- **Max drawdown**: Largest peak-to-trough decline
- **Sharpe ratio**: Risk-adjusted return (higher is better)
- **Buy and hold return**: What you'd make just holding the asset

### Understanding Metrics

**Total return of 50%** sounds great, but over what period? 1 year or 10 years makes a huge difference.

**Win rate of 60%** doesn't guarantee profitability. You can win 60% of trades but lose money if your losers are bigger than your winners.

**Max drawdown of 50%** means at some point you were down 50% from your peak. Can you stomach that psychologically?

**Sharpe ratio above 1** is decent, above 2 is very good, above 3 is exceptional (and possibly too good to be true).

**Beating buy and hold** is the minimum bar. If your complex strategy can't beat simply buying and holding, what's the point?

## Output Format

The portfolio prints performance metrics:

```
init_time:1419984000 curr_time:1767052000 init_cash:100000.0000
curr_cash:197422.2894 num_trades:92 num_closed:46 num_wins:28
num_losses:18 win_rate:0.6087 num_stop_loss:18 num_take_profit:7
quantity:0.0000 holdings:0.0000 valuation:197422.2894
total_costs:14952.7706 profit:97422.2894 total_return:0.9742
annual_return:0.0638 buy_and_hold_return:277.2788
buy_and_hold_annual:0.6677 max_drawdown:0.5280 sharpe:0.3694
```

Format it nicely with Unix tools:

```bash
cat data/prices.csv | ./backtest | tr ' ' '\n' | column -t -s ':'
```

## Creating Custom Portfolios

You can implement custom portfolio logic by inheriting from the `Portfolio` template:

```cpp
class MyPortfolio: public tzu::Portfolio<MyPortfolio> {
private:
    double cash;
    double quantity;
    double avg_price;
    
public:
    MyPortfolio(double initial_cash) 
        : cash(initial_cash), quantity(0), avg_price(0) {}
    
    void update(const tzu::Signal& signal) {
        if (signal.side == tzu::Side::BUY && cash > 0) {
            // Custom buy logic
            double shares = cash / signal.price;
            quantity += shares;
            cash = 0;
            avg_price = signal.price;
        } else if (signal.side == tzu::Side::SELL && quantity > 0) {
            // Custom sell logic
            cash += quantity * signal.price;
            quantity = 0;
        }
    }
    
    friend std::ostream& operator<<(std::ostream& os, const MyPortfolio& p) {
        os << "cash:" << p.cash << " quantity:" << p.quantity;
        return os;
    }
};
```

## Advanced Portfolio Ideas

### Position Sizing

Instead of all-in, use a fixed percentage of capital per trade:

```cpp
double position_size = cash * 0.10;  // Risk 10% per trade
double shares = position_size / signal.price;
```

### Kelly Criterion

Size positions based on win probability and win/loss ratio:

```cpp
double kelly = (win_rate * avg_win - (1 - win_rate) * avg_loss) / avg_win;
double position_size = cash * kelly * safety_factor;  // e.g., 0.5 for half-Kelly
```

### Multiple Positions

Hold positions in different assets simultaneously:

```cpp
std::vector<Position> positions;  // Track multiple positions
std::map<std::string, double> holdings;  // By symbol
```

### Partial Exits

Scale out of positions gradually:

```cpp
if (profit_target_1_hit) {
    sell(quantity * 0.33);  // Take 1/3 off
}
if (profit_target_2_hit) {
    sell(quantity * 0.50);  // Take half of remaining
}
```

### Trailing Stop-Loss

Adjust stop level as price moves in your favor:

```cpp
if (current_price > highest_price) {
    highest_price = current_price;
    stop_loss_price = highest_price * (1 - trailing_stop_pct);
}
```

### Limit Orders

Instead of market orders, use limit prices:

```cpp
if (signal.side == Side::BUY) {
    limit_price = signal.price * 0.99;  // Buy 1% below signal
    // In reality, order may not fill if price doesn't reach limit
}
```

Modeling this accurately is complex. You need to simulate whether orders fill based on subsequent price action.

## Common Portfolio Mistakes

### Ignoring Costs

Transaction costs add up quickly. Model them realistically.

### Over-leveraging

Using all your capital on every trade amplifies both gains and losses. Consider position sizing.

### No Risk Management

Trading without stop-losses can lead to catastrophic losses. Always have an exit plan.

### Unrealistic Fills

Assuming you can always buy/sell exactly at the signal price. In reality there's slippage, especially in illiquid markets.

### Not Tracking Metrics

How do you know if your strategy is working if you don't measure? Track all relevant performance metrics.

## The Psychology Factor

Backtests don't capture psychology. Seeing a 30% drawdown on paper is different from watching your actual money decline 30%. Many strategies fail not because the logic is wrong, but because traders can't stick with them through drawdowns.

When designing portfolios, consider:

- Can you handle the max drawdown psychologically?
- Is the trade frequency manageable?
- Are the rules clear enough to follow without second-guessing?

A slightly worse strategy that you can actually execute beats a theoretically better one that you'll abandon after the first losing streak.

## Position Management Best Practices

**Size positions appropriately:** Don't bet everything on one trade.

**Use stop-losses:** Protect against large losses.

**Track costs:** Model transaction costs realistically.

**Calculate metrics:** Measure performance objectively.

**Test different approaches:** Try various position sizing and risk management methods.

**Be honest:** Don't cherry-pick metrics that make your strategy look good.

The portfolio is where your strategy meets reality. Good strategy with poor portfolio management can still lose money. Pay attention to this layer.
