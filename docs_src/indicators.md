# Indicators

Indicators are mathematical calculations based on price, volume, or other market data. They help identify patterns and generate trading signals.

## How Indicators Work in tzutrader

All indicators follow a consistent streaming interface:

- `get()`: Returns the current indicator value
- `update(value)`: Processes a new data point and returns the updated value

Indicators maintain internal state (usually circular buffers) to compute values efficiently as new data arrives. This streaming approach mimics how indicators work in live trading.

## Available Indicators

### SMA (Simple Moving Average)

Computes the arithmetic mean over a fixed window.

```cpp
#include "tzu.h"
using namespace tzu;

SMA sma(20);  // 20-period moving average

// Update with new values
double result = sma.update(100.5);
// Returns NaN until 20 values are provided

// After 20 updates, returns valid averages
for (int i = 0; i < 20; i++) {
    sma.update(prices[i]);
}
double avg = sma.get();  // Now contains valid average
```

**Usage:** Trend identification, support/resistance levels, crossover strategies.

**Limitations:** Lags price action, equal weight to all values in window.

### EMA (Exponential Moving Average)

Gives more weight to recent values using exponential smoothing.

```cpp
EMA ema(20);         // 20-period EMA with default smoothing
EMA ema(20, 2.0);    // Explicit smoothing factor
```

The smoothing factor determines how much weight recent values receive. Default is 2.0.

**Usage:** Faster response to price changes than SMA, popular in momentum strategies.

**Limitations:** Still lags price, sensitive to smoothing parameter choice.

### RSI (Relative Strength Index)

Measures momentum by comparing average gains to average losses. Returns a value between 0 and 100.

```cpp
RSI rsi(14);  // 14-period RSI

// Takes Ohlcv data as input
double rsi_value = rsi.update(ohlcv_data);

// Typical interpretation:
// RSI < 30: oversold (potential buy)
// RSI > 70: overbought (potential sell)
```

**Usage:** Identify overbought/oversold conditions, divergence trading.

**Limitations:** Can stay overbought/oversold for extended periods in strong trends. Thresholds (30/70) aren't magic numbers.

### MACD (Moving Average Convergence Divergence)

Tracks the relationship between two moving averages.

```cpp
MACD macd(12, 26, 9);  // Standard parameters

MACDResult result = macd.update(price);
// result.macd_line: Difference between fast and slow EMAs
// result.signal_line: EMA of the MACD line
// result.histogram: Difference between MACD and signal lines
```

**Usage:** Trend following, momentum, crossover signals.

**Limitations:** Multiple parameters to tune, lags in choppy markets.

### MVar (Moving Variance)

Computes variance over a rolling window.

```cpp
MVar mvar(20, 1);  // 20-period variance, sample variance (dof=1)
MVar mvar(20, 0);  // Population variance (dof=0)
```

**Usage:** Volatility measurement, basis for other indicators like Bollinger Bands.

**Limitations:** Sensitive to outliers, requires choosing appropriate degrees of freedom.

## Creating Custom Indicators

Inherit from the `Indicator` base class template:

```cpp
#include "tzu.h"

class CustomIndicator: public tzu::Indicator<CustomIndicator, double, double> {
private:
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

**Key principles:**

- Use circular buffers or running sums to avoid storing all historical data
- Return `std::nan("")` when there isn't enough data to compute a valid value
- Keep state minimal and update incrementally
- Make the `get()` method `const` and `noexcept`

### Example: Rolling Window Indicator

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
            sum -= buffer[pos];  // Remove oldest value
        }
        
        sum += value;
        buffer[pos] = value;
        pos = (pos + 1) % window;
        
        return get();
    }
};
```

## Combining Indicators

Build complex indicators by composing simpler ones:

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

## Indicator Best Practices

**Handle NaN values:** Always check if indicators are ready before using their values in strategies.

```cpp
double value = sma.update(price);
if (std::isnan(value)) {
    return;  // Not enough data yet
}
```

**Choose appropriate periods:** Shorter periods are more responsive but noisier. Longer periods are smoother but lag more. There's no universal "best" period.

**Avoid over-optimization:** Don't tweak parameters endlessly to fit historical data. Test on out-of-sample data.

**Understand what you're measuring:** Indicators are tools, not magic. Know why an indicator might be useful for your strategy, not just that it has been.

**Memory efficiency:** Custom indicators should use O(window_size) memory, not O(all_historical_data).

## Common Mistakes

**Using indicators without context:** RSI < 30 doesn't always mean "buy." Markets can stay oversold for long periods.

**Mixing timeframes incorrectly:** Using a daily indicator on minute data without proper adjustment.

**Ignoring indicator lag:** All moving average-based indicators lag price. They tell you what already happened, not what will happen.

**Signal chasing:** Adding more indicators doesn't necessarily improve results. Often it just adds complexity and overfitting risk.

## When Indicators Don't Work

Indicators are derived from price. They can't predict the future—they can only summarize the past. They work better in trending markets than choppy, sideways markets. In reality, no indicator works reliably all the time. That's why risk management (stop-loss, position sizing) is crucial.
