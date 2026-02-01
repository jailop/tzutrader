# TzuTrader

An experimental algorithmic trading framework designed to develop, and test
systematic trading strategies. Whether you're validating a new trading
idea, optimizing strategy parameters, or screening markets for
opportunities, TzuTrader provides tools to do it efficiently.

Why?

- Fast Development Cycle: Test trading ideas in minutes using the CLI or
  declarative YAML configs—no coding required for basic strategies
- Better Performance: Built in Nim for speed and memory
  efficiency, with O(1) memory streaming indicators
- Flexible Workflow: Start with simple built-in strategies, evolve to
  YAML configs, or write custom strategies in Nim for maximum control
- Comprehensive Toolset: Backtesting, market screening, batch testing,
  parameter optimization, and basic portfolio simulation in one 
  library

[Read the docs...](https://jailop.codeberg.page/tzutrader/docs/)

How it looks?

CLI Tool:

```bash
# Backtest with built-in strategy
tzu --backtest=rsi --symbol=AAPL --start=2023-01-01

# With custom strategy parameters
tzu --backtest=macd -s AAPL --start=2023-01-01 --fast=10 --slow=20 --signal=5

# Backtest YAML strategy file
tzu --strategy=examples/rsi_strategy_example.yaml --symbol=AAPL --start=2023-01-01

# Screen multiple symbols and get alerts
tzu --screen=examples/screeners/basic_rsi_screener.yml
```

Library Example:

```nim
import tzutrader

# Load data and create strategy
let data = readCSV("data/AAPL.csv")
let strategy = newRSIStrategy(period = 14, oversold = 30, overbought = 70)

# Run backtest
let report = quickBacktest(
  symbol = "AAPL",
  strategy = strategy,
  data = data,
  initialCash = 100000.0,
  commission = 0.001
)

echo report.summary()
```

YAML files:

```
metadata:
  name: "Simple RSI Mean Reversion"
  description: "Classic RSI oversold/overbought strategy"
  author: "TzuTrader"
  created: "2026-01-31"
  tags:
    - rsi
    - mean-reversion
    - beginner-friendly

indicators:
  - id: rsi_14
    type: rsi
    params:
      period: 14

entry:
  conditions:
    left: rsi_14
    operator: "<"
    right: "30"

exit:
  conditions:
    left: rsi_14
    operator: ">"
    right: "70"

position_sizing:
  type: fixed
  size: 100
```

## Limitations

- At this moment only a few illustrative data sources are supported,
  like CSV files and Yahoo Finance.
- At this moment only OHLCV-based strategies are supported.
- The API is not stable yet. Don't use this library for production (no
  yet).

## ⚠️ Disclaimers

This software is provided for educational and research purposes
only.

- No Financial Advice: This software does not provide financial,
  investment, trading, or any other type of professional advice. Any
  strategies, indicators, or results shown are for informational
  purposes only.
- No Liability: The authors and contributors are not responsible for
  any financial losses, damages, or other consequences resulting from
  the use of this software.
- Trading Risks: Trading financial instruments involves substantial
  risk of loss. Past performance does not guarantee future results.
  Backtested results do not represent actual trading and may not reflect
  the impact of material market factors such as liquidity, slippage, and
  transaction costs.
- Use at Your Own Risk: Users are solely responsible for their
  trading decisions and should consult with qualified financial
  professionals before making any investment decisions.

By using TzuTrader, you acknowledge that you understand these risks and
accept full responsibility for your actions.
