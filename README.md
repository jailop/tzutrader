tzutrader
=========

A C++ trading backtesting framework.

Example
-------

```c++
#include <iostream>
#include <string>
#include "tzu.h"

using namespace tzu;

int main(int argc, char** argv) {
    bool verbose = false;
    if (argc > 1 && std::string(argv[1]) == "-v") verbose = true;
    SimpleRunner<RSIStrat<>, SimplePortfolio, Csv<Ohlcv>> runner(std::cin);
    runner.run(verbose);
    return 0;
}
```

Build the backtesting example:

    g++ -I./include examples/backtesting.cc -o examples/backtesting

The example reads CSV OHLCV data from stdin. Use a pipe, for example:

    cat tests/data/btcusd.csv | ./examples/backtesting

The output:

    timestamp: 1760572 init_cash: 100000 curr_cash: 370.72 \
    quantity: 2 invested: 212936 valuation: 213306 \
    profit: 113306 return: 1.13306

How does it work?
-----------------

- The `Csv` class reads OHLCV data from a CSV file and streams it as
  `Ohlcv` objects.
- The `RSIStrat` class implements a simple RSI-based trading strategy.
  It generates buy/sell signals based on RSI thresholds.
- The `SimplePortfolio` class manages the portfolio state, executing
  trades based on the strategy's signals and tracking cash and holdings.
- The `SimpleRunner` class orchestrates the backtesting process, feeding
  data from the `Csv` stream into the `RSIStrat` strategy and updating
  the portfolio accordingly.

Here is the `update` method of the `RSIStrat`:

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
  
Design Philosophy
-----------------

- Designed to be as simple and lightweight as possible, with minimal
  dependencies and a focus on core functionality.
- Optimized for performance, using efficient data structures and
  algorithms. Comptime optimizations and careful memory management are
  employed to minimize overhead and maximize speed.
- The framework processes data in a streaming fashion, allowing it to
  handle large datasets without needing to load everything into memory
  at once. This also allows for more realistic backtesting, as it
  simulates the real-time flow of data and trading decisions.
- Built to be easily composable, allowing users to mix and match
  different strategies, data sources, and portfolio management
  approaches without needing to modify the core backtesting logic.
- Designed to be easily extensible, allowing users to implement their
  own strategies, indicators, data sources, and automated runners
  without needing to modify the core framework.

Initial Features
----------------

- Indicators: SMA, EMA, Moving Variance, RSI, and MACD.
- Data types: OHLCV, trades, and simple time series.
- Input data formats: csv
- Built-in Strategies: Crossover, RSI, and MACD.

Roadmap
-------

- Improve documentation and add more examples to demonstrate the
  framework's and how users can adapt or extend it for their own needs.
- Add support for additional input data formats, e.g. JSON.
- Implement additional trading strategies and indicators.
- Add support for more realistic portfolio management, including
  transaction costs and slippage.
- Implement risk management features, such as stop-loss orders and
  position sizing.
