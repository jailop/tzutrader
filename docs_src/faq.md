# FAQ

## General Questions

### What is tzutrader?

A C++ library for backtesting trading strategies. It's experimental, focused on composability and streaming data processing. Think of it as a toolkit for testing trading ideas before risking real money.

### Who is this for?

- Developers learning about algorithmic trading
- Traders who want to test strategies systematically
- Anyone interested in backtesting architecture
- People who prefer C++ for performance-critical tasks

It's not for complete beginners to programming or trading. Some C++ knowledge and basic trading understanding is expected.

### Is this production-ready?

No. It's experimental software exploring different design patterns. The API can change, features may be added or removed, and bugs likely exist. Use it for learning and experimentation, not for live trading.

### Can I make money with this?

tzutrader is a tool for testing ideas. Whether those ideas make money is up to you. Most strategies don't work. Even good backtests don't guarantee live trading success. Treat this as education, not a money-making machine.

## Installation & Setup

### What do I need to install?

- C++17 or later compiler (GCC, Clang, MSVC)
- CMake 3.10 or later
- Git (to clone the repository)

### How do I build it?

```bash
git clone https://codeberg.org/jailop/tzutrader
cd tzutrader
mkdir build && cd build
cmake ..
cmake --build .
```

### Can I use this on Windows?

Yes, with a C++17 compiler. Visual Studio 2017 or later should work. You may need to adjust CMake settings for your environment.

### Do I need Python/R/other languages?

No. tzutrader is pure C++. You can use other languages for data preparation or analysis, but the library itself doesn't require them.

## Usage Questions

### How do I load my data?

tzutrader expects CSV format piped through stdin:

```bash
cat your_data.csv | ./your_backtest
```

CSV format for OHLCV:
```csv
timestamp,open,high,low,close,volume
1419984000,320.0,325.0,315.0,322.0,1000.0
```

### Why is my indicator returning NaN?

Indicators need data to warm up. A 20-period SMA returns NaN until it has 20 data points. This is intentional—it prevents using incomplete indicator values in strategies.

### How do I create a custom indicator?

Inherit from `Indicator<YourIndicator, InputType, OutputType>` and implement `get()` and `update()`:

```cpp
class MyIndicator: public tzu::Indicator<MyIndicator, double, double> {
public:
    double get() const noexcept { /* return value */ }
    double update(double value) { /* update and return */ }
};
```

See the [Indicators](indicators.md) page for detailed examples.

### How do I create a custom strategy?

Inherit from `Strategy<YourStrategy, InputType>` and implement `update()`:

```cpp
class MyStrategy: public tzu::Strategy<MyStrategy, tzu::Ohlcv> {
public:
    tzu::Signal update(const tzu::Ohlcv& data) {
        // Your logic here
    }
};
```

See the [Strategies](strategies.md) page for examples.

### Why aren't any trades being executed?

Common reasons:

- Strategy isn't generating signals (check verbose mode)
- Indicators haven't warmed up yet (early data points)
- CSV format is incorrect (check timestamps and values)
- Portfolio has no cash left (check transaction costs)

Enable verbose mode to see what's happening:
```cpp
runner.run(true);  // Verbose mode
```

### How do I test different parameters?

Recompile with different parameter values or make them command-line arguments:

```cpp
int main(int argc, char** argv) {
    int period = (argc > 1) ? std::atoi(argv[1]) : 20;
    SMA sma(period);
    // ...
}
```

Then run:
```bash
cat data.csv | ./backtest 20
cat data.csv | ./backtest 50
```

For systematic parameter optimization, you'll need to write your own loop or use external tools.

### Can I backtest multiple assets simultaneously?

Not with the current `BasicPortfolio`. It's designed for single-asset backtesting. You'd need to implement a custom portfolio that handles multiple positions. See the [Portfolios](portfolios.md) page for ideas.

### How do I add transaction costs?

Pass them to the portfolio constructor:

```cpp
BasicPortfolio portfolio(
    100000.0,  // initial capital
    0.001,     // 0.1% transaction cost
    0.10,      // stop-loss
    0.20       // take-profit
);
```

Costs are applied on every buy and sell.

### Can I model slippage?

Not directly. `BasicPortfolio` assumes execution at signal price. For slippage, you'd need a custom portfolio that adjusts execution prices:

```cpp
void update(const Signal& signal) {
    double adjusted_price = signal.price * (1 + slippage_pct);
    // Execute at adjusted_price
}
```

### How do I save backtest results?

Redirect output to a file:

```bash
cat data.csv | ./backtest > results.txt
```

Or modify your code to write to files directly:

```cpp
std::ofstream out("results.csv");
// Write trades, metrics, etc.
```

## Performance Questions

### How fast is it?

Fast enough for typical backtests. Processing millions of data points takes seconds on modern hardware. Exact speed depends on strategy complexity and indicator calculations.

If performance is critical, profile first. Most bottlenecks are in I/O or inefficient strategy logic, not the library itself.

### Can I parallelize backtests?

The library is single-threaded. For parallel backtests (e.g., testing multiple parameter sets):

```bash
# Run separate instances in parallel
cat data.csv | ./backtest1 > results1.txt &
cat data.csv | ./backtest2 > results2.txt &
wait
```

Each instance is independent, so this scales well.

### Why use C++ instead of Python?

- Performance: C++ is much faster for computation-heavy tasks
- Learning: Understanding memory management and efficiency
- Production: Closer to what real trading systems use

Python is easier for prototyping. C++ is better for production or learning systems programming. Choose based on your goals.

## Technical Questions

### What's the CRTP pattern?

Curiously Recurring Template Pattern. It's used for static polymorphism:

```cpp
template <class Derived, typename In, typename Out>
class Indicator {
    Out update(In value) {
        return static_cast<Derived*>(this)->update(value);
    }
};

class SMA: public Indicator<SMA, double, double> {
    double update(double value) { /* implementation */ }
};
```

This gives you polymorphic-like behavior without virtual function overhead.

### Why streaming instead of vectorized?

Streaming prevents lookahead bias and mimics real trading. You can't peek at future data. It also uses less memory—you don't need to load the entire dataset.

Vectorized approaches (like pandas) are faster for analysis but make it easy to accidentally introduce lookahead bias.

### Can I use this with live data feeds?

tzutrader is designed for backtesting, not live trading. You'd need to:

- Wrap your data feed as a streamer
- Handle real-time execution
- Deal with order management
- Implement error handling

It's possible but not the intended use case. Production trading systems need much more infrastructure.

### Why no built-in parameter optimization?

Adding optimization would make decisions about search methods, stopping criteria, and validation approaches. That's opinionated. Instead, tzutrader is a tool you use within your own optimization framework.

Write a script that runs backtests with different parameters and collects results. Use the tool of your choice (grid search, random search, Bayesian optimization, etc.).

### How do I handle corporate actions (splits, dividends)?

Adjust your input data before feeding it to tzutrader. Most data providers offer adjusted prices. If you have unadjusted data:

- **Splits**: Divide prices before the split date by the split ratio
- **Dividends**: Adjust prices to account for value paid out

This preprocessing step is outside tzutrader's scope.

## Troubleshooting

### Compilation fails with C++17 errors

Ensure your compiler supports C++17:

```bash
g++ --version  # GCC 7+ required
clang++ --version  # Clang 5+ required
```

Set the standard explicitly:
```bash
g++ -std=c++17 your_file.cpp
```

### Segmentation fault when running

Common causes:
- Accessing uninitialized indicators
- Buffer overflow in custom indicators
- Invalid CSV data

Enable debugging symbols and use a debugger:
```bash
g++ -g -std=c++17 your_file.cpp
gdb ./your_program
```

### Results look too good to be true

Check for:

- Lookahead bias (using future data)
- Incorrect transaction costs (too low or missing)
- Overfitting (parameters tuned too specifically)
- Data quality issues (survivorship bias, bad prices)

Be skeptical of amazing results. Markets aren't easy.

### My strategy was profitable in backtest but loses money live

This is common. Reasons include:

- **Overfitting**: Optimized for historical quirks that don't repeat
- **Market regime change**: Markets evolve, strategies stop working
- **Execution differences**: Slippage, costs, fills differ from simulation
- **Psychological factors**: Hard to follow rules during drawdowns

Backtesting is imperfect. It's a filter to eliminate bad ideas, not a guarantee of success.

## Design Questions

### Why templates instead of inheritance?

Templates provide compile-time polymorphism with no runtime overhead. For performance-critical backtesting code, avoiding virtual function calls matters.

It also enables better compiler optimization since the full call graph is known at compile time.

### Why such a minimal feature set?

Intentional. The goal is exploring core architecture patterns, not building a feature-complete platform. Small scope means:

- Easier to understand and modify
- Fewer dependencies
- Clearer design tradeoffs
- Room to experiment

You can extend it for your needs.

### Will feature X be added?

Maybe. The roadmap is flexible. File an issue to discuss. Features aligned with the design philosophy (composability, simplicity, streaming) are more likely.

Features that add complexity, break composability, or introduce heavy dependencies are less likely.

### Can I use this in my project?

Yes, subject to the license. Check the LICENSE file in the repository. If you build something interesting with it, let us know.

### How can I contribute?

See the [Contributing](contributing.md) page. Bug reports, documentation improvements, and code contributions are welcome.

## Philosophy Questions

### Why Unix philosophy for a trading library?

The Unix philosophy ("do one thing well, work together") fits backtesting naturally:

- **Small tools**: Indicators, strategies, portfolios are separate
- **Text streams**: CSV in, metrics out—simple and scriptable
- **Composability**: Combine components like Unix pipelines
- **Mechanism not policy**: Library provides tools, you make decisions

This approach trades convenience for flexibility and understanding. You write more code, but you understand exactly what it does.

**Example:**
```bash
# Unix composability
cat data | grep pattern | sort | uniq

# tzutrader composability
Indicator + Strategy + Portfolio = Backtest
```

Each component is simple. Power comes from composition.

### Why be honest about limitations?

Because overselling backtesting tools is common and harmful. People lose money believing backtests guarantee profits. They don't.

Being upfront about limitations helps users understand what they're actually testing and where the blind spots are.

### Why not include tons of indicators and strategies?

Quality over quantity. A few well-tested components you understand are better than dozens you don't. Plus, writing your own indicators and strategies is educational—you learn how they actually work.

The library provides building blocks. You compose them into solutions.

### What's the long-term vision?

There isn't one, really. This is an experiment in architecture and design. It might evolve into something more substantial, or it might remain a small educational tool.

The goal is learning and exploration, not building a commercial product.

## Still Have Questions?

- Check the [User Guide](user-guide.md) for detailed documentation
- Review [Architecture](architecture.md) for design details
- Look at example code in the `examples/` directory
- File an issue on [Codeberg](https://codeberg.org/jailop/tzutrader/issues)

If your question isn't answered, it's probably a good one to add to this FAQ. Let us know.
