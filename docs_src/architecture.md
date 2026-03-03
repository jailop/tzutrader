# Architecture Guide

**Note:** This is an experimental project exploring different architectural patterns for backtesting libraries. The design choices described here may evolve as we learn what works well in practice.

## Design Philosophy

tzutrader is built around three core principles:

1. **Composability**: Components can be mixed and matched to create different backtesting configurations
2. **Streaming**: Data is processed incrementally without loading everything into memory
3. **Simplicity**: Focus on core functionality with minimal dependencies

These principles are inspired by the Unix philosophy of building small, focused tools that do one thing well.

## Component Architecture

### Layer Overview

```
┌─────────────────────────────────────────┐
│            Application Layer            │
│     (User code combining components)    │
└─────────────────────────────────────────┘
                    │
┌─────────────────────────────────────────┐
│           Orchestration Layer           │
│              (Runners)                  │
└─────────────────────────────────────────┘
                    │
        ┌───────────┴───────────┐
        │                       │
┌───────▼────────┐    ┌────────▼───────┐
│   Strategy     │    │   Portfolio    │
│    Layer       │    │     Layer      │
└───────┬────────┘    └────────────────┘
        │
┌───────▼────────┐
│   Indicator    │
│     Layer      │
└───────┬────────┘
        │
┌───────▼────────┐
│  Data Layer    │
│  (Streamers)   │
└────────────────┘
```

### Data Flow

Data flows upward through the layers:

1. **Data Layer** reads and parses raw data
2. **Indicator Layer** computes technical values
3. **Strategy Layer** generates trading signals
4. **Portfolio Layer** executes trades and tracks state
5. **Orchestration Layer** coordinates the process

Each layer is independent and replaceable.

## Data Layer

### Design Goals

- Support multiple data formats (CSV, JSON, etc.)
- Stream data point-by-point
- Parse efficiently without excessive allocation
- Handle malformed data gracefully

### Implementation Pattern

The data layer uses a template-based design with specialized parsers:

```cpp
template<typename T>
class Csv {
    // Generic CSV reader
};

template<typename T>
struct CsvParseTraits {
    // Specialized parser for type T
    static bool parse(const char* line, T& out);
};
```

This separates the streaming mechanism from format-specific parsing logic.

### Iterator Interface

The `Csv` class provides an STL-compatible iterator:

```cpp
for (const auto& data_point : csv_reader) {
    // Process data_point
}
```

This makes data sources compatible with standard algorithms and easy to integrate.

### Buffer Management

Fixed-size buffers (2048 bytes) are used for line parsing to avoid dynamic allocation in hot loops. This is a trade-off between flexibility and performance. For most financial data, 2KB per line is sufficient.

### Extension Points

To add support for new formats:

1. Create a new reader class (e.g., `JsonReader`)
2. Implement an iterator that yields data points
3. Optionally specialize parse traits for custom data types

## Indicator Layer

### State Management

Indicators maintain minimal state to compute values incrementally:

```cpp
class SMA {
    std::vector<double> prev;  // Circular buffer
    size_t pos;                // Current position
    size_t len;                // Number of values seen
    double sum;                // Running sum
};
```

This approach:

- Uses O(window_size) memory, not O(all_data)
- Updates in O(1) time after initialization
- Naturally handles streaming data

### Circular Buffers

Most indicators use circular buffers to maintain rolling windows:

```cpp
double update(double value) {
    if (len < window_size) {
        len++;
    } else {
        sum -= prev[pos];  // Remove oldest value
    }
    sum += value;
    prev[pos] = value;
    pos = (pos + 1) % window_size;
    return sum / window_size;
}
```

This pattern efficiently implements sliding windows without shifting array elements.

### NaN Handling

Indicators return `std::nan("")` when they don't have enough data:

```cpp
return len < window_size ? std::nan("") : computed_value;
```

This signals to strategies that the indicator isn't ready yet, avoiding premature trading.

### CRTP Pattern

Indicators use the Curiously Recurring Template Pattern (CRTP) for static polymorphism:

```cpp
template <class T, typename In, typename Out>
class Indicator {
public:
    Out update(In value) {
        return static_cast<T*>(this)->update(value);
    }
};

class SMA: public Indicator<SMA, double, double> {
    // Implementation
};
```

This provides a uniform interface without virtual function overhead.

### Composition

Complex indicators are built by composing simpler ones:

```cpp
class RSI {
    SMA gains;   // Reuse SMA for average gains
    SMA losses;  // Reuse SMA for average losses
};
```

This encourages code reuse and keeps individual components simple.

## Strategy Layer

### Responsibilities

A strategy:

- Receives market data
- Updates indicators
- Generates trading signals (BUY/SELL/NONE)
- Maintains state between updates

### Signal Generation

Strategies output `Signal` objects:

```cpp
struct Signal {
    int64_t timestamp;
    Side side;        // BUY, SELL, or NONE
    double price;
    double volume;
};
```

This standardized interface allows any portfolio to consume signals from any strategy.

### State Tracking

Strategies track the last signal to avoid spam:

```cpp
class MyStrategy {
    Side last_side;
    
    Signal update(const Data& data) {
        if (should_buy && last_side != Side::BUY) {
            last_side = Side::BUY;
            return buy_signal;
        }
        // ...
    }
};
```

This prevents generating 100 consecutive BUY signals in a strong uptrend.

### Multi-Indicator Coordination

Strategies coordinate multiple indicators to implement complex logic:

```cpp
Signal update(const Ohlcv& data) {
    double rsi_val = rsi.update(data);
    double ma_fast = fast_ma.update(data.close);
    double ma_slow = slow_ma.update(data.close);
    
    // Wait for all indicators
    if (std::isnan(rsi_val) || std::isnan(ma_fast) || std::isnan(ma_slow)) {
        return no_signal;
    }
    
    // Combine indicators
    if (rsi_val < 30 && ma_fast > ma_slow) {
        return buy_signal;
    }
    // ...
}
```

### Extension Points

Custom strategies inherit from `Strategy<T, In>` and implement:

```cpp
Signal update(const In& data);
```

The template parameters specify:

- `T`: The derived strategy type (for CRTP)
- `In`: The input data type (Ohlcv, Tick, SingleValue, etc.)

## Portfolio Layer

### Responsibilities

A portfolio:

- Manages cash and positions
- Executes trades based on signals
- Applies transaction costs
- Implements risk management (stop-loss, take-profit)
- Tracks performance metrics

### Position Management

The `BasicPortfolio` uses an all-in approach:

```cpp
void update(const Signal& signal) {
    if (signal.side == Side::BUY) {
        // Use all available cash
        double quantity = cash / signal.price;
        open_position(quantity, signal.price);
    } else if (signal.side == Side::SELL) {
        // Close all positions
        close_all_positions(signal.price);
    }
}
```

This simplifies the implementation but isn't realistic for production trading.

### Risk Management

Stop-loss and take-profit are checked on every update:

```cpp
void check_stop_loss_take_profit(double price, int64_t timestamp) {
    for (auto& position : positions) {
        double return_pct = (price - position.price) / position.price;
        
        if (return_pct <= -stop_loss_pct) {
            liquidate_position(position, price, timestamp, true, false);
        } else if (return_pct >= take_profit_pct) {
            liquidate_position(position, price, timestamp, false, true);
        }
    }
}
```

This protects against large losses and locks in profits.

### Performance Metrics

The portfolio delegates metric calculation to `PortfolioStats`:

```cpp
class PortfolioStats {
    void record_trade_close(...);
    void add_costs(double cost);
    double compute_sharpe_ratio();
    double compute_max_drawdown();
    // ...
};
```

This separation keeps portfolio logic focused on trade execution.

### Extension Points

Custom portfolios can implement:

- Position sizing based on risk (e.g., Kelly criterion)
- Multiple simultaneous positions
- Partial exits and scaling in/out
- Different order types (limit, stop)
- Slippage modeling
- Multi-asset support

## Orchestration Layer

### Runner Design

The `BasicRunner` connects all components:

```cpp
template <typename Portfolio, typename Strategy, typename Streamer>
class BasicRunner {
    Portfolio portfolio;
    Strategy strategy;
    Streamer streamer;
    
    void run(bool verbose) {
        for (const auto& data : streamer) {
            Signal signal = strategy.update(data);
            portfolio.update(signal);
            if (verbose) print(portfolio);
        }
        print(portfolio);
    }
};
```

The runner:

- Pulls data from the streamer
- Feeds data to the strategy
- Passes signals to the portfolio
- Optionally prints state after each step

### Template-Based Composition

Using templates allows compile-time composition without runtime overhead:

```cpp
BasicRunner<BasicPortfolio, RSIStrat, Csv<Ohlcv>> runner(portfolio, strat, csv);
```

Each combination of components generates specialized code optimized for that exact configuration.

### Alternative Runner Designs

Future runners might:

- Support multiple strategies simultaneously
- Enable strategy comparison
- Add warmup periods
- Implement walk-forward analysis
- Support parameter optimization

## Design Patterns

### CRTP (Curiously Recurring Template Pattern)

Used for indicators and strategies to provide static polymorphism:

```cpp
template <class Derived, typename In, typename Out>
class Indicator {
    Out update(In value) {
        return static_cast<Derived*>(this)->update(value);
    }
};
```

Benefits:

- No virtual function overhead
- Type-safe interface
- Enables compile-time optimization

### Traits-Based Specialization

Used for parsing different data types:

```cpp
template<typename T>
struct CsvParseTraits {
    static bool parse(const char* line, T& out);
};
```

Benefits:

- Separates format from parsing logic
- Easy to extend with new types
- No runtime dispatch overhead

### Composition Over Inheritance

Indicators and strategies are composed:

```cpp
class RSI {
    SMA gains;  // Has-a relationship
    SMA losses;
};
```

Rather than inherited:

```cpp
// Not done this way
class RSI: public SMA {
};
```

Benefits:

- More flexible
- Clearer dependencies
- Easier to test components in isolation

## Memory and Performance

### Memory Characteristics

- **Data Layer**: Fixed 2KB buffer per reader
- **Indicators**: O(window_size) per indicator
- **Strategies**: O(1) for most strategies
- **Portfolios**: O(number_of_positions)

Total memory usage is bounded and predictable.

### Performance Characteristics

- **Data Reading**: O(1) per data point
- **Indicator Updates**: O(1) after warmup
- **Strategy Updates**: O(number_of_indicators)
- **Portfolio Updates**: O(number_of_positions)

The library processes millions of data points efficiently.

### Optimization Opportunities

Current focus is on correctness and simplicity. Future optimizations might include:

- SIMD for indicator calculations
- Parallel processing of multiple strategies
- Memory-mapped file I/O
- Zero-copy data structures

These will be considered if profiling reveals bottlenecks.

## Threading and Concurrency

The current design is single-threaded. All components maintain mutable state and are not thread-safe.

For concurrent backtesting:

- Run separate backtest instances in different threads
- Each instance has its own data streamer, strategy, and portfolio
- No shared state between instances

This "shared-nothing" approach is simple and scales well.

## Extensibility

### Adding New Indicators

1. Inherit from `Indicator<YourIndicator, InputType, OutputType>`
2. Implement `get()` and `update()`
3. Use existing indicators as building blocks
4. Return NaN when not enough data

### Adding New Strategies

1. Inherit from `Strategy<YourStrategy, DataType>`
2. Implement `update(const DataType&) -> Signal`
3. Use indicators to compute values
4. Track state to avoid signal spam

### Adding New Data Sources

1. Create a class with begin()/end() methods
2. Implement an iterator that returns data points
3. Optionally specialize CsvParseTraits for custom types
4. Ensure iterator is STL-compatible

### Adding New Portfolio Types

1. Inherit from `Portfolio<YourPortfolio>`
2. Implement `update(const Signal&)`
3. Track positions and cash
4. Implement operator<< for output

## Testing Strategy

The library includes tests for:

- Individual indicators (correctness of calculations)
- Parsing logic (handling valid and invalid input)
- End-to-end backtests (comparing expected vs actual results)

Testing approach:

- Unit tests for indicators with known outputs
- Property-based tests for invariants
- Integration tests with sample data

## Known Limitations

As an experimental project, there are known limitations:

- **Single asset**: Only one tradable asset at a time
- **Simple portfolio**: All-in/all-out position management
- **Limited orders**: Market orders only
- **No slippage**: Assumes perfect execution at signal price
- **CSV only**: Limited data format support currently
- **Minimal error handling**: Expects well-formed input

These limitations are intentional to keep the core design simple while exploring the architecture.

## Evolution and Future Directions

The architecture may evolve as we explore:

- Multi-asset portfolio management
- More realistic order execution
- Additional data formats and sources
- Alternative runner designs
- Plugin system for custom components

Changes will prioritize:
- Maintaining simplicity
- Preserving composability
- Avoiding breaking changes when possible

Feedback and experimentation will guide future architectural decisions.

## Learning Resources

To understand the design better:

1. Read the header files in `include/tzu/` - they're well-commented
2. Study the example implementations in `examples/`
3. Look at the test cases in `tests/`
4. Experiment with custom indicators and strategies

The best way to understand the architecture is to use it and try extending it.
