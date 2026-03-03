# Strategies

Strategies generate trading signals based on market data and indicator values. They implement the logic that decides when to buy, sell, or do nothing.

## Strategy Interface

Strategies inherit from the `Strategy` template and implement an `update` method:

```cpp
template <class T, typename In>
class Strategy {
public:
    Signal update(const In& data);
};
```

The `update` method receives market data and returns a `Signal` object:

```cpp
struct Signal {
    int64_t timestamp;
    Side side;        // BUY, SELL, or NONE
    double price;
    double volume;
};
```

## Built-in Strategies

### SMACrossover Strategy

Generates buy signals when a short-period SMA crosses above a long-period SMA, and sell signals on the opposite crossover.

```cpp
SMACrossover strat(10, 30, 0.01);  // fast period, slow period, threshold

// threshold adds a percentage buffer to avoid false signals
// e.g., 0.01 = 1% buffer
```

**How it works:**

- Buy when fast_sma > slow_sma * (1 + threshold)
- Sell when fast_sma < slow_sma * (1 - threshold)

**Typical use case:** Trend following in markets with clear directional moves.

**Weaknesses:** Many false signals in choppy markets, lags at trend changes.

### RSIStrat Strategy

Buys when RSI falls below the oversold threshold and sells when it rises above the overbought threshold.

```cpp
RSIStrat strat(14, 30, 70);  // period, oversold, overbought
```

**How it works:**

- Buy when RSI < 30
- Sell when RSI > 70

**Typical use case:** Mean reversion in ranging markets.

**Weaknesses:** Can trigger too early in strong trends, thresholds aren't universal.

### MACDStrat Strategy

Generates signals based on MACD line and signal line crossovers.

```cpp
MACDStrat strat(12, 26, 9, 2.0, 0.0);
// short_period, long_period, signal_period, smoothing, threshold
```

**How it works:**

- Buy when MACD line crosses above signal line
- Sell when MACD line crosses below signal line

**Typical use case:** Momentum trading, capturing trending moves.

**Weaknesses:** Multiple parameters to optimize, whipsaws in consolidation.

## Creating Custom Strategies

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

## Multi-Indicator Strategy

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

This combines trend (moving averages) and momentum (RSI) to filter signals. It only buys when both conditions align.

## Strategy Design Guidelines

### Keep it Simple

Complex strategies aren't better. Simple logic is easier to understand, debug, and reason about. If you can't explain your strategy in a few sentences, it's probably too complex.

### Avoid Lookahead Bias

Only use data available up to the current timestamp. Never peek at future prices to make current decisions.

**Wrong:**
```cpp
// Using tomorrow's price today
if (data[i+1].close > data[i].close) {
    return buy_signal;
}
```

**Correct:**

```cpp
// Using only current and past data
if (data.close > yesterday_close) {
    return buy_signal;
}
```

### Test for NaN

Always check indicator values before using them:

```cpp
double sma_val = sma.update(data.close);
if (std::isnan(sma_val)) {
    return no_signal;  // Not enough data yet
}
```

### Track State Properly

Use `last_side` to prevent signal spam:

```cpp
if (buy_condition && last_side != Side::BUY) {
    last_side = Side::BUY;
    return buy_signal;
}
```

Without this, you'd generate 50 consecutive buy signals during an uptrend.

### Make Parameters Configurable

Use constructor arguments for thresholds and periods:

```cpp
class MyStrategy {
public:
    MyStrategy(size_t period = 20, double threshold = 0.02)
        : sma(period), threshold(threshold) {}
private:
    SMA sma;
    double threshold;
};
```

This makes testing different parameter values easier.

### Return Clear Signals

The portfolio needs clear BUY/SELL/NONE signals. Don't return ambiguous values or partial signals.

## Advanced Strategy Example

```cpp
class AdaptiveStrategy: public tzu::Strategy<AdaptiveStrategy, tzu::Ohlcv> {
private:
    tzu::RSI rsi;
    tzu::SMA sma_fast;
    tzu::SMA sma_slow;
    tzu::MVar volatility;
    tzu::Side last_side;
    double vol_threshold;
    
public:
    AdaptiveStrategy(double vol_threshold = 0.02)
        : rsi(14), sma_fast(10), sma_slow(30), 
          volatility(20, 1), last_side(tzu::Side::NONE),
          vol_threshold(vol_threshold) {}
    
    tzu::Signal update(const tzu::Ohlcv& data) {
        double rsi_val = rsi.update(data);
        double fast = sma_fast.update(data.close);
        double slow = sma_slow.update(data.close);
        double vol = volatility.update(data.close);
        
        tzu::Signal signal = {data.timestamp, tzu::Side::NONE, data.close};
        
        // Wait for all indicators
        if (std::isnan(rsi_val) || std::isnan(fast) || 
            std::isnan(slow) || std::isnan(vol)) {
            return signal;
        }
        
        // Adapt strategy based on volatility
        double vol_normalized = std::sqrt(vol) / data.close;
        
        if (vol_normalized < vol_threshold) {
            // Low volatility: use mean reversion (RSI)
            if (rsi_val < 30 && last_side != tzu::Side::BUY) {
                signal.side = tzu::Side::BUY;
                last_side = tzu::Side::BUY;
            } else if (rsi_val > 70 && last_side != tzu::Side::SELL) {
                signal.side = tzu::Side::SELL;
                last_side = tzu::Side::SELL;
            }
        } else {
            // High volatility: use trend following (MA crossover)
            if (fast > slow && last_side != tzu::Side::BUY) {
                signal.side = tzu::Side::BUY;
                last_side = tzu::Side::BUY;
            } else if (fast < slow && last_side != tzu::Side::SELL) {
                signal.side = tzu::Side::SELL;
                last_side = tzu::Side::SELL;
            }
        }
        
        return signal;
    }
};
```

This strategy adapts its approach based on market volatility. In low volatility, it uses mean reversion. In high volatility, it follows trends.

## Common Strategy Mistakes

### Over-optimization

Tweaking parameters until the backtest looks perfect, then failing on new data.

**Symptom:** Amazing results on test data, poor results on out-of-sample data.

**Solution:** Use train/test splits, walk-forward analysis, or cross-validation.

### Too Many Indicators

Adding more indicators doesn't automatically improve performance. Often it just creates more noise.

**Symptom:** 5+ indicators with complex logic, marginal improvement over simpler strategy.

**Solution:** Start simple, add complexity only if it clearly helps.

### Ignoring Market Context

Strategies that work in trending markets often fail in ranging markets, and vice versa.

**Symptom:** Great performance in some periods, terrible in others.

**Solution:** Accept that no strategy works all the time, or build adaptive strategies.

### Unrealistic Assumptions

Assuming perfect execution at signal price, no slippage, no transaction costs.

**Symptom:** Profitable in backtest, unprofitable in live trading.

**Solution:** Model costs realistically, add buffer to signal prices.

## Strategy Testing Workflow

1. **Implement the strategy** with reasonable parameters
2. **Run initial backtest** on historical data
3. **Analyze results** - look at metrics, drawdowns, trade frequency
4. **Test on different periods** - does it work in bull markets? Bear markets?
5. **Vary parameters** slightly - are results stable or sensitive?
6. **Test on different assets** - does it generalize?
7. **Calculate realistic costs** - is it still profitable?
8. **Out-of-sample test** - run on data not used for development

If it passes all these steps and still looks promising, then maybe—maybe—it's worth considering for live trading. Start with small position sizes.

## The Reality of Strategy Development

Most strategies you develop won't work. That's normal. Even professionals have low hit rates when developing new strategies. The goal isn't to find the holy grail—it's to systematically test ideas, learn what doesn't work, and occasionally find something that might work.

Be skeptical of your own results. If something looks too good to be true, it probably is. Double-check for bugs, lookahead bias, or overfitting. Stay humble.
