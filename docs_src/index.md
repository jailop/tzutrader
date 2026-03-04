# tzutrader

A composable C++ backtesting library for testing trading strategies.

## What Is This?

tzutrader is an experimental library for backtesting algorithmic trading strategies. It's built around composability—mix and match indicators, strategies, and portfolio management components to test your trading ideas.

**Key features:**

- Streaming data processing to prevent lookahead bias
- Modular design with composable components
- Built-in indicators (SMA, EMA, RSI, MACD)
- Example strategies and portfolio management
- Simple, understandable C++ code

## Current Status

This is experimental software. It covers basic features to explore design patterns and validate architectural choices. The API may change as the project evolves.

**What works:**

- Basic indicators and strategies
- Simple portfolio management with risk controls
- CSV data input
- Performance metrics calculation

**What doesn't (yet):**

- Multi-asset portfolios
- Complex order types
- Real-time data feeds
- Extensive built-in strategy library

## Quick Example

```cpp
#include "tzu.h"
using namespace tzu;

int main() {
    // Create strategy and portfolio
    RSIStrat strategy(14, 30, 70);
    BasicPortfolio portfolio(100000.0, 0.001, 0.10, 0.20);
    
    // Stream data and run backtest
    Csv<Ohlcv> csv(std::cin);
    BasicRunner<BasicPortfolio, RSIStrat, Csv<Ohlcv>> runner(
        portfolio, strategy, csv
    );
    
    runner.run(false);
    return 0;
}
```

Run it:
```bash
cat data.csv | ./backtest
```

## Documentation

**Start here:**

- **[Getting Started](getting-started.md)**: Installation and first backtest
- **[Design Philosophy](philosophy.md)**: Why tzutrader exists and who it's for

**Learn the concepts:**

- **[Intro to Trading](intro-trading.md)**: Backtesting fundamentals and pitfalls

**Build with components:**

- **[Indicators](indicators.md)**: Using and creating indicators
- **[Strategies](strategies.md)**: Building trading strategies
- **[Portfolios](portfolios.md)**: Position and risk management

**Understand the design:**

- **[Architecture](architecture.md)**: Implementation details and patterns

**Development tools:**

- **[Utilities](utilities.md)**: Helper tools for program development

**Get involved:**

- **[Contributing](contributing.md)**: How to contribute
- **[FAQ](faq.md)**: Common questions

**API Reference:** <https://jailop.codeberg.page/tzutrader/docs/html>

## Philosophy

tzutrader follows the Unix philosophy: build small, composable tools that do one thing well. Rather than a monolithic framework, it provides building blocks you combine to create backtests.

**Core principles:**

- **Composability**: Mix and match indicators, strategies, portfolios
- **Streaming**: Process data point-by-point to prevent lookahead bias
- **Simplicity**: Minimal dependencies, focused scope, no magic
- **Transparency**: Code you can read, understand, and modify

Inspired by Unix tools (`grep`, `awk`, `sort`), components do one thing well and work together through standard interfaces.

## Who This Is For

**You'll get value from tzutrader if you:**

- Are comfortable with C++ and template programming
- Want to understand backtesting architecture, not just use it
- Prefer reading code over reading documentation
- Are willing to write your own indicators and strategies
- Value performance and learning systems programming

**This is probably not for you if:**

- You're new to C++ (Python backtesting libraries are easier)
- You want a GUI or plug-and-play solutions
- You need production-ready, stable software right now
- You prefer extensive documentation over code exploration

C++ is harder than Python. I chose it for performance, learning value, and because production trading systems use it. If you're learning algorithmic trading, start with Python. If you're learning systems programming or want skills that transfer to professional trading systems, tzutrader is relevant.

See [Design Philosophy](philosophy.md) for the detailed rationale.

## The Reality Check

Most trading strategies don't work. Even strategies that backtest well often fail in live trading. This library won't make you rich—it's a tool for systematically testing ideas before risking money.

Treat backtesting as education, not a guarantee. If you do trade live, start small and be prepared to lose money while learning.

## Getting Started

1. Clone the repository: `git clone https://codeberg.org/jailop/tzutrader`
2. Build: `mkdir build && cd build && cmake .. && cmake --build .`
3. Run examples: `cat ../tests/data/btcusd.csv | ./example01`
4. Read the [Getting Started](getting-started.md) guide

## Related Projects

- **[yfnim](https://codeberg.org/jailop/yfnim)**: A Yahoo Finance data puller for fetching historical price data. Useful for obtaining CSV data to use with tzutrader. [Documentation](https://jailop.codeberg.page/yfnim/docs/)

## Community

- **Source code**: <https://codeberg.org/jailop/tzutrader>
- **Issues**: <https://codeberg.org/jailop/tzutrader/issues>
- **License**: See LICENSE file in repository

Feedback and criticism are welcome. This is an experiment—help make it better.
