# Package

version       = "0.1.1"
author        = "tzutrader contributors"
description   = "A simplified trading bot library in Nim"
license       = "MIT"
srcDir        = "src"
bin           = @["tzu"]
installExt    = @["nim"]

# Dependencies

requires "nim >= 2.0.0"
requires "https://codeberg.org/jailop/yfnim.git"
requires "cligen >= 1.7.0"
requires "yaml >= 2.0.0"

task test, "Run the test suite":
  echo "Running Phase 1-7 tests..."
  exec "nim c -r tests/test_core.nim"
  exec "nim c -r tests/test_data.nim"
  exec "nim c -r tests/test_indicators.nim"
  exec "nim c -r tests/test_strategy.nim"
  exec "nim c -r tests/test_portfolio.nim"
  exec "nim c -r tests/test_trader.nim"
  exec "nim c -r tests/test_scanner.nim"
  exec "nim c -r tests/test_export.nim"
  echo "Running declarative strategy tests..."
  exec "nim c -r --path:src tests/declarative/test_schema.nim"
  exec "nim c -r --path:src tests/declarative/test_parser.nim"
  exec "nim c -r --path:src tests/declarative/test_validator.nim"
  exec "nim c -r --path:src tests/declarative/test_strategy_builder.nim"
  echo "========================="
  echo "All tests passed!"

task docs, "Build complete HTML documentation":
  echo "Building TzuTrader documentation..."
  exec "bash scripts/build_docs.sh"

task docserve, "Serve documentation locally":
  echo "Starting documentation server..."
  exec "bash scripts/serve_docs.sh"

task docclean, "Clean generated documentation":
  echo "Cleaning documentation build..."
  exec "rm -rf docs/*"
  exec "touch docs/.gitkeep"
  echo "Documentation cleaned"

task docapi, "Generate API documentation only":
  echo "Generating API documentation..."
  exec "mkdir -p docs/api"
  exec "nim doc --project --index:on --outdir:docs/api src/tzutrader.nim"
  echo "API documentation generated in docs/api/"

task benchmark, "Run performance benchmarks":
  exec "nim c -d:release --opt:speed -r benchmarks/indicator_perf.nim"

task cli, "Build the CLI tool (alias for 'nimble build')":
  echo "Building TzuTrader CLI..."
  exec "nimble build"
  echo ""
  echo "Usage (16 strategies available):"
  echo "  ./tzu --help                          # List all strategies"
  echo "  ./tzu rsi --help                      # RSI strategy options"
  echo "  ./tzu rsi -s AAPL --start=2023-01-01  # Yahoo Finance (default)"
  echo "  ./tzu rsi --csvFile=data/AAPL.csv     # CSV file"
  echo "  ./tzu macd --coinbase=BTC-USD --start=2024-01-01  # Coinbase"

task examples, "Compile all examples":
  echo "Compiling examples..."
  exec "nim c examples/data_example.nim"
  exec "nim c examples/indicators_example.nim"
  exec "nim c examples/csv_example.nim"
  exec "nim c examples/strategy_example.nim"
  exec "nim c examples/rsi_strategy_example.nim"
  exec "nim c examples/crossover_strategy_example.nim"
  exec "nim c examples/macd_strategy_example.nim"
  exec "nim c examples/bollinger_strategy_example.nim"
  # exec "nim c examples/momentum_indicators_example.nim"  # TODO: Rewrite for streaming
  exec "nim c examples/advanced_oscillators_example.nim"
  exec "nim c examples/moving_averages_example.nim"
  exec "nim c examples/volume_volatility_example.nim"
  exec "nim c examples/momentum_indicators_example.nim"
  exec "nim c examples/advanced_strategies_example.nim"
  exec "nim c examples/portfolio_example.nim"
  exec "nim c examples/backtest_example.nim"
  echo "Examples compiled successfully!"
  echo ""
  echo "Run examples with:"
  echo "  ./examples/data_example"
  echo "  ./examples/indicators_example"
  echo "  ./examples/csv_example"
  echo "  ./examples/strategy_example         # All strategies"
  echo "  ./examples/rsi_strategy_example     # RSI only"
  echo "  ./examples/crossover_strategy_example  # MA Crossover only"
  echo "  ./examples/macd_strategy_example    # MACD only"
  echo "  ./examples/bollinger_strategy_example  # Bollinger Bands only"
  echo "  ./examples/advanced_oscillators_example # STOCH, CCI, MFI, ADX"
  echo "  ./examples/moving_averages_example  # TRIMA, DEMA, TEMA, KAMA"
  echo "  ./examples/volume_volatility_example # TRANGE, NATR, AD, AROON"
  echo "  ./examples/momentum_indicators_example # STOCHRSI, PPO, CMO, MOM"
  echo "  ./examples/advanced_strategies_example # Multi-indicator strategies"
  echo "  ./examples/portfolio_example        # Portfolio management"
  echo "  ./examples/backtest_example         # Backtesting"

requires "mathexpr >= 1.3.2"
