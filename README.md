tzutrader
=========

An experiment on building a composable and performant C++ trading
backtesting framework.

At this moment, the implementation covers only very basic features, in
order to explore and validate design and architecture choices.

Criticism is very welcome!

Example
-------

```c++

#include <iostream>
#include <string>
#include <utility>
#include "tzu.h"

using namespace tzu;

int main(int argc, char** argv) {
    bool verbose = (argc > 1 && std::string(argv[1]) == "-v");
    RSIStrat<> strat;
    BasicPortfolio portfolio(
        100000.0,   // initial capital
        0.001,      // trading fee 0.1%,
        0.10,       // stop-loss 10%
        0.20        // take-profit 20%
     );
    Csv<Ohlcv> csv(std::cin);
    BasicRunner<BasicPortfolio, RSIStrat<>, Csv<Ohlcv>> runner(
            std::move(portfolio),
            std::move(strat),
            std::move(csv));
    runner.run(verbose);
    return 0;
}
```

Build the backtesting example:

    g++ -I./include examples/example01.cc -o example01

The example reads CSV OHLCV data from stdin. That file includes data
from 2015 to 2026.

    cat tests/data/btcusd.csv | ./example01

The output:

```
init_time:1419984 curr_time:1767052 init_cash:100000.0000 curr_cash:197422.2894 
num_trades:116 num_stop_loss:18 num_take_profit:7 quantity:0.0000 
holdings:0.0000 valuation:197422.2894 total_costs:14952.7706 profit:97422.2894
total_return:97.4223%
```

How does it work?
-----------------

- The `Csv` class reads OHLCV data from a CSV file and streams it as
  `Ohlcv` objects.
- The `RSIStrat` class implements a simple RSI-based trading strategy.
  It generates buy/sell signals based on RSI thresholds.
- The `BasicPortfolio` class manages the trading portfolio, tracking
  cash, holdings, and performance metrics.
- The `BasicRunner` class orchestrates the backtesting process, feeding data
  to the strategy and updating the portfolio accordingly.

Here is the `RSIStrat`'s `update` method:

```c++
    Signal update(const Ohlcv& data) {
        double rsi_value = rsi.update(data);
        Signal signal = {data.timestamp, Side::NONE, data.getFieldValue(field)};
        if (std::isnan(rsi_value))
            return signal;
        if ((rsi_value < oversold) && (last_side != Side::BUY))
            last_side = signal.side = Side::BUY;
        else if ((rsi_value > overbought) && (last_side != Side::SELL))
            last_side = signal.side = Side::SELL;
        return signal;
    }
```

Initial Features
----------------

- Indicators: SMA, EMA, Moving Variance, RSI, and MACD.
- Data types: OHLCV, trades, and simple time series.
- Input data formats: csv
- Built-in Strategies: Crossover, RSI, and MACD.
- Basic portfolio management
- Initial testing suite for the core components

Critically, it still pending proper documentation, with a conceptual
overview of the framework's design and architecture, as well as detailed
usage instructions and examples about the built-in components, and a
guide on implementing custom indicators, strategies,
and portfolio management approaches.
 
Design Philosophy
-----------------

- Designed to be as simple and lightweight as possible, with zero
  external dependencies and a focus on core functionality.
- Built to be easily composable, with a modular design
  that allows to easily swap out different components, as well as 
  to implement their own custom indicators, strategies, and portfolio
  management approaches.
- Optimized for performance, using efficient data structures and
  algorithms. Comptime optimizations and careful memory management are
  employed to minimize overhead and maximize speed.
- The framework processes data in a streaming fashion, allowing it to
  handle large datasets without needing to load everything into memory
  at once. This also allows for more realistic backtesting, as it
  simulates the way that real trading systems operate, processing data
  as it arrives, and protecting against look-ahead bias.
- Correctness is a top priority, not only in terms of proper
  implementation, but also in terms of ensuring
  that the framework's behavior is consistent and predictable.

Roadmap
-------

- Produce documentation and add more examples to demonstrate the
  framework's
- Improve the design and architecture to make it more composable and
  performant.
- Add support for the most common input data formats, e.g. JSON.
- Implement a minimal but useful set of built-in trading strategies and
  indicators.
- Introduce strategies that can take multiple input data streams
- Add support for a more realistic portfolio, risk and order management
  features, e.g. multiple assets, position sizing, slippage, etc.
- Enforce a rigorous testing strategy, with a comprehensive set of unit
  tests to validate the correctness of the core components, and to
  ensure that future changes do not introduce regressions. In addition,
  performance benchmarks will be added to track the framework's
  performance.

Not considered:

- Include an extensive set of built-in strategies and indicators. The
  framework is designed to be small, and users are encouraged to
  implement their own custom strategies and indicators using the
  provided interfaces.
- Support for data retrieval APIs. The framework is designed to be
  agnostic to data sources, and users can easily implement their own
  data retrieval logic using the provided interfaces.
