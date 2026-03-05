# User Guide

**Note:** tzutrader is an experimental project. The API and architecture are subject to change as I explore different design patterns and refine the library's approach.

## Overview

tzutrader is a C++ backtesting library built around composability and streaming data processing. Rather than loading entire datasets into memory, it processes market data point-by-point, similar to how live trading systems operate. This approach helps avoid look-ahead bias and keeps memory usage low.

The library follows a modular design where you combine different components:

- **Data streamers** read and parse input data (e.g., CSV files)
- **Indicators** calculate technical values (SMA, RSI, MACD, etc.)
- **Strategies** generate trading signals based on indicators
- **Portfolios** manage positions, cash, and track performance
- **Runners** orchestrate the backtesting process

## Understanding the Architecture

### Component Flow

The typical flow in a backtest is:

```
Data Streamer → Strategy → Portfolio → Performance Metrics
                    ↓
               Indicators
```

1. The **data streamer** reads market data one row at a time
2. The **strategy** receives each data point, updates its indicators, and generates signals
3. The **portfolio** receives signals and decides whether to execute trades
4. Performance metrics are calculated as the backtest progresses

### Core Data Types

The library defines several data structures in `defs.h`:

- `Ohlcv`: Open-High-Low-Close-Volume candlestick data
- `Tick`: Individual trade data with timestamp, price, volume, and side
- `SingleValue`: Generic time-series data with timestamp and value
- `Signal`: Trading signals with timestamp, side (BUY/SELL/NONE), price, and volume
- `Side`: Enum representing BUY, SELL, or NONE

### Streaming Philosophy

All components work with streaming data. Indicators maintain internal state (circular buffers) to compute values efficiently as new data arrives. Strategies generate signals without looking ahead. This design mimics real-world trading constraints.

## Working with Indicators

### Using Built-in Indicators

Indicators follow a consistent interface with two main methods:

- `get()`: Returns the current indicator value
- `update(value)`: Processes a new data point and returns the updated value

Example using Simple Moving Average:

```cpp
#include "tzu.h"
using namespace tzu;

// Create a 20-period SMA
SMA sma(20);

// Update with values
double result = sma.update(100.5);
// Returns NaN until 20 values are provided

// After 20 updates, returns the average
for (int i = 0; i < 20; i++) {
    sma.update(prices[i]);
}
double avg = sma.get();  // Now contains valid average
```

### Available Indicators

**SMA (Simple Moving Average)**
```cpp
SMA sma(window_size);
```
Computes the arithmetic mean over a fixed window. Returns NaN until the window is full.

**EMA (Exponential Moving Average)**
```cpp
EMA ema(period, smoothing);  // smoothing defaults to 2.0
```
Gives more weight to recent values using exponential smoothing.

**RSI (Relative Strength Index)**
```cpp
RSI rsi(period);
```
Measures momentum by comparing average gains to average losses. Takes `Ohlcv` data as input. Returns a value between 0 and 100.

**MACD (Moving Average Convergence Divergence)**
```cpp
MACD macd(short_period, long_period, signal_period);
```
Returns a `MACDResult` struct containing the MACD line, signal line, and histogram.

**MVar (Moving Variance)**
```cpp
MVar mvar(window_size, degrees_of_freedom);
```
Computes variance over a rolling window. Use `dof=1` for sample variance, `dof=0` for population variance.

### Creating Custom Indicators

To create a custom indicator, inherit from the `Indicator` base class template:

```cpp
#include "tzu.h"

class CustomIndicator: public tzu::Indicator<CustomIndicator, double, double> {
private:
    // Internal state
    double sum = 0.0;
    size_t count = 0;
    
public:
    CustomIndicator() {}
    
    double get() const noexcept {
        return count > 0 ? sum / count : std::nan("");
    }
    
    double update(double value) {
        sum += value;
        count++;
        return get();
    }
};
```

**Key principles for custom indicators:**

- Use circular buffers or running sums to avoid storing all historical data
- Return `std::nan("")` when there isn't enough data to compute a valid value
- Keep state minimal and update incrementally
- Make the `get()` method `const` and `noexcept`

Example of an indicator with a rolling window:

```cpp
class CustomRolling: public tzu::Indicator<CustomRolling, double, double> {
private:
    std::vector<double> buffer;
    size_t pos = 0;
    size_t len = 0;
    double sum = 0.0;
    size_t window;
    
public:
    CustomRolling(size_t window_size) 
        : buffer(window_size, std::nan("")), window(window_size) {}
    
    double get() const noexcept {
        return len < window ? std::nan("") : sum / window;
    }
    
    double update(double value) {
        if (len < window) {
            len++;
        } else {
            // Remove oldest value from sum
            sum -= buffer[pos];
        }
        
        sum += value;
        buffer[pos] = value;
        pos = (pos + 1) % window;
        
        return get();
    }
};
```

### Combining Indicators

You can build more complex indicators by composing simpler ones:

```cpp
class BollingerBands {
private:
    SMA sma;
    MVar mvar;
    double num_std;
    
public:
    BollingerBands(size_t period, double num_std = 2.0)
        : sma(period), mvar(period, 1), num_std(num_std) {}
    
    struct Result {
        double middle;
        double upper;
        double lower;
    };
    
    Result update(double value) {
        double middle = sma.update(value);
        double variance = mvar.update(value);
        
        if (std::isnan(middle) || std::isnan(variance)) {
            return {std::nan(""), std::nan(""), std::nan("")};
        }
        
        double std_dev = std::sqrt(variance);
        return {
            middle,
            middle + num_std * std_dev,
            middle - num_std * std_dev
        };
    }
};
```

## Building Strategies

### Strategy Interface

Strategies generate trading signals based on market data and indicator values. They inherit from the `Strategy` template:

```cpp
template <class T, typename In>
class Strategy {
public:
    Signal update(const In& data);
};
```

### Using Built-in Strategies

**SMACrossover Strategy**
```cpp
SMACrossover strat(short_period, long_period, threshold);
```
Generates buy signals when the short SMA crosses above the long SMA, and sell signals on the opposite crossover. The threshold parameter adds a percentage buffer to avoid false signals.

**RSIStrat Strategy**
```cpp
RSIStrat strat(period, oversold, overbought);
```
Buys when RSI falls below the oversold threshold (default 30) and sells when it rises above the overbought threshold (default 70).

**MACDStrat Strategy**
```cpp
MACDStrat strat(short_period, long_period, signal_period, smoothing, threshold);
```
Generates signals based on MACD line and signal line crossovers.

### Creating Custom Strategies

Here's a simple custom strategy:

```cpp
class MyStrategy: public tzu::Strategy<MyStrategy, tzu::Ohlcv> {
private:
    tzu::SMA fast;
    tzu::SMA slow;
    tzu::Side last_side;
    
public:
    MyStrategy(size_t fast_period = 10, size_t slow_period = 30)
        : fast(fast_period), slow(slow_period), last_side(tzu::Side::NONE) {}
    
    tzu::Signal update(const tzu::Ohlcv& data) {
        double fast_val = fast.update(data.close);
        double slow_val = slow.update(data.close);
        
        tzu::Signal signal = {data.timestamp, tzu::Side::NONE, data.close};
        
        // Wait until indicators are ready
        if (std::isnan(fast_val) || std::isnan(slow_val)) {
            return signal;
        }
        
        // Generate signals on crossovers
        if (fast_val > slow_val && last_side != tzu::Side::BUY) {
            signal.side = tzu::Side::BUY;
            last_side = tzu::Side::BUY;
        } else if (fast_val < slow_val && last_side != tzu::Side::SELL) {
            signal.side = tzu::Side::SELL;
            last_side = tzu::Side::SELL;
        }
        
        return signal;
    }
};
```

**Important points:**

- Track `last_side` to avoid generating repeated signals
- Return `Side::NONE` when indicators aren't ready or no action is needed
- Always return a `Signal` object with timestamp and price
- Handle NaN values from indicators appropriately

### More Complex Strategy Example

A strategy using multiple indicators with custom logic:

```cpp
class MultiIndicatorStrategy: public tzu::Strategy<MultiIndicatorStrategy, tzu::Ohlcv> {
private:
    tzu::RSI rsi;
    tzu::SMA sma_short;
    tzu::SMA sma_long;
    tzu::Side last_side;
    
public:
    MultiIndicatorStrategy()
        : rsi(14), sma_short(20), sma_long(50), last_side(tzu::Side::NONE) {}
    
    tzu::Signal update(const tzu::Ohlcv& data) {
        double rsi_val = rsi.update(data);
        double short_ma = sma_short.update(data.close);
        double long_ma = sma_long.update(data.close);
        
        tzu::Signal signal = {data.timestamp, tzu::Side::NONE, data.close};
        
        if (std::isnan(rsi_val) || std::isnan(short_ma) || std::isnan(long_ma)) {
            return signal;
        }
        
        // Buy when RSI is oversold AND short MA is above long MA
        if (rsi_val < 30 && short_ma > long_ma && last_side != tzu::Side::BUY) {
            signal.side = tzu::Side::BUY;
            last_side = tzu::Side::BUY;
        }
        // Sell when RSI is overbought OR short MA crosses below long MA
        else if ((rsi_val > 70 || short_ma < long_ma) && last_side != tzu::Side::SELL) {
            signal.side = tzu::Side::SELL;
            last_side = tzu::Side::SELL;
        }
        
        return signal;
    }
};
```

### Strategy Design Tips

- Keep strategies stateful but simple
- Avoid lookahead bias - only use data available up to the current timestamp
- Test indicator values for NaN before using them
- Consider adding parameters for thresholds and periods as constructor arguments
- Use `last_side` tracking to prevent signal spam
- Return clear signals that the portfolio can act on

## Portfolio Management

### BasicPortfolio

The `BasicPortfolio` class handles position management, transaction costs, and risk management:

```cpp
BasicPortfolio portfolio(
    initial_capital,      // Starting cash
    transaction_cost_pct, // e.g., 0.001 for 0.1%
    stop_loss_pct,       // e.g., 0.10 for 10%
    take_profit_pct      // e.g., 0.20 for 20%
);
```

**Features:**

- All-in positions: uses all available cash on buy signals
- Automatic liquidation on sell signals
- Stop-loss and take-profit monitoring on each update
- Transaction cost tracking
- Performance metrics calculation

### Creating Custom Portfolios

You can implement custom portfolio logic by inheriting from the `Portfolio` template:

```cpp
class MyPortfolio: public tzu::Portfolio<MyPortfolio> {
private:
    double cash;
    double quantity;
    double avg_price;
    // ... other state
    
public:
    MyPortfolio(double initial_cash) : cash(initial_cash), quantity(0), avg_price(0) {}
    
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

**Portfolio customization ideas:**

- Position sizing based on Kelly criterion or risk percentage
- Multiple simultaneous positions across different assets
- Partial position exits
- Trailing stop-loss implementation
- Dynamic risk adjustment based on volatility
- Order types (limit, stop orders)

## Running Backtests

### Basic Setup

The `BasicRunner` orchestrates the backtesting process:

```cpp
#include "tzu.h"
using namespace tzu;

int main() {
    // Create strategy
    RSIStrat strategy(14, 30, 70);
    
    // Create portfolio
    BasicPortfolio portfolio(100000.0, 0.001, 0.10, 0.20);
    
    // Create data streamer
    Csv<Ohlcv> csv(std::cin);
    
    // Create runner
    BasicRunner<BasicPortfolio, RSIStrat, Csv<Ohlcv>> runner(
        portfolio, strategy, csv
    );
    
    // Run backtest
    runner.run(false);  // false = quiet mode, true = verbose
    
    return 0;
}
```

Run the backtest:

```bash
cat data/prices.csv | ./my_backtest
```

### Output Format

The portfolio outputs performance metrics:

```
init_time:1419984000 curr_time:1767052000 init_cash:100000.0000
curr_cash:197422.2894 num_trades:92 num_closed:46 num_wins:28
num_losses:18 win_rate:0.6087 num_stop_loss:18 num_take_profit:7
quantity:0.0000 holdings:0.0000 valuation:197422.2894
total_costs:14952.7706 profit:97422.2894 total_return:0.9742
annual_return:0.0638 buy_and_hold_return:277.2788
buy_and_hold_annual:0.6677 max_drawdown:0.5280 sharpe:0.3694
```

Format output nicely:

```bash
cat data/prices.csv | ./my_backtest | tr ' ' '\n' | column -t -s ':'
```

### Verbose Mode

Enable verbose mode to see portfolio state after each update:

```cpp
runner.run(true);
```

This prints the portfolio state on every data point, useful for debugging strategies.

## Data Input

### CSV Format

The `Csv` streamer expects comma-separated values. For OHLCV data:

```
timestamp,open,high,low,close,volume
1419984000,320.0,325.0,315.0,322.0,1000.0
1419984060,322.0,328.0,321.0,326.0,1500.0
```

Timestamps are Unix timestamps, that can be seconds, milliseconds,
microseconds, or nanoseconds. The library's user should manage a
consistent timestamp unit across the data and strategy logic.

### Custom Data Parsers

To parse custom CSV formats, specialize the `CsvParseTraits` template:

```cpp
struct MyDataType {
    int64_t timestamp;
    double value1;
    double value2;
};

template<>
struct tzu::CsvParseTraits<MyDataType> {
    static bool parse(const char* line_buffer, MyDataType& out) {
        char* end;
        int64_t ts = std::strtol(line_buffer, &end, 10);
        double v1 = std::strtod(end, &end);
        double v2 = std::strtod(end, &end);
        
        if (*end != '\0' && *end != '\n') return false;
        
        out = MyDataType{ts, v1, v2};
        return true;
    }
};
```

Then use it with the CSV streamer:

```cpp
Csv<MyDataType> csv(std::cin);
```

## Complete Example

Here's a complete working example putting everything together:

```cpp
#include <iostream>
#include <string>
#include "tzu.h"

using namespace tzu;

// Custom indicator: Exponential Hull Moving Average
class EHMA: public Indicator<EHMA, double, double> {
private:
    EMA ema1;
    EMA ema2;
    
public:
    EHMA(size_t period) : ema1(period), ema2(period / 2) {}
    
    double get() const noexcept {
        return ema1.get();
    }
    
    double update(double value) {
        double slow = ema1.update(value);
        double fast = ema2.update(value);
        return 2.0 * fast - slow;
    }
};

// Custom strategy using EHMA
class EHMAStrategy: public Strategy<EHMAStrategy, Ohlcv> {
private:
    EHMA ehma;
    Side last_side;
    double last_price;
    
public:
    EHMAStrategy(size_t period = 20) 
        : ehma(period), last_side(Side::NONE), last_price(0) {}
    
    Signal update(const Ohlcv& data) {
        double indicator = ehma.update(data.close);
        Signal signal = {data.timestamp, Side::NONE, data.close};
        
        if (std::isnan(indicator)) {
            last_price = data.close;
            return signal;
        }
        
        // Buy when price crosses above indicator
        if (last_price <= indicator && data.close > indicator 
            && last_side != Side::BUY) {
            signal.side = Side::BUY;
            last_side = Side::BUY;
        }
        // Sell when price crosses below indicator
        else if (last_price >= indicator && data.close < indicator 
                 && last_side != Side::SELL) {
            signal.side = Side::SELL;
            last_side = Side::SELL;
        }
        
        last_price = data.close;
        return signal;
    }
};

int main(int argc, char** argv) {
    bool verbose = (argc > 1 && std::string(argv[1]) == "-v");
    
    EHMAStrategy strategy(20);
    BasicPortfolio portfolio(100000.0, 0.001, 0.15, 0.30);
    Csv<Ohlcv> csv(std::cin);
    
    BasicRunner<BasicPortfolio, EHMAStrategy, Csv<Ohlcv>> runner(
        portfolio, strategy, csv
    );
    
    runner.run(verbose);
    return 0;
}
```

Build and run:

```bash
cd build
cmake .. && cmake --build .
cat ../tests/data/btcusd.csv | ./my_example
```

## Best Practices

### Performance

- Use circular buffers for indicators that need historical data
- Avoid dynamic memory allocation in hot loops
- Keep indicator state minimal
- Process data in a streaming fashion

### Correctness

- Always check for NaN values from indicators
- Never peek ahead at future data
- Test strategies on out-of-sample data
- Validate CSV data before backtesting

### Design

- Keep components small and focused
- Compose complex behaviors from simple pieces
- Make indicators and strategies reusable
- Use clear, descriptive names

## Troubleshooting

**Indicator returns NaN**

- Not enough data points to fill the window yet
- Check that you're providing valid numeric inputs

**No trades executed**

- Strategy might not be generating signals (check verbose mode)
- Portfolio might have no cash or positions to trade

**Unexpected results**

- Verify CSV data format matches expected structure
- Check for lookahead bias in strategy logic
- Validate that indicators are updating correctly

## What's Next

As an experimental project, tzutrader continues to evolve. Future directions may include:

- Additional data input formats
- More sophisticated portfolio management options
- Extended performance metrics
- Multi-asset portfolio support

The API may change as I discover better patterns and approaches. Check the repository for updates and feel free to contribute ideas or feedback.
