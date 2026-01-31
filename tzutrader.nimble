version       = "0.1.0"
author        = "Jaime Lopez"
description   = "A trading bot library in Nim"
license       = "MIT"
srcDir        = "src"
installExt    = @["nim"]
bin           = @["tzu", "tzu2", "test"]

requires "nim >= 2.0.0"
requires "https://codeberg.org/jailop/yfnim.git"
requires "cligen >= 1.7.0"
requires "yaml >= 2.0.0"

task docs, "Build documentation":
  exec "bash scripts/build_docs.sh"

task docserve, "Serve documentation locally":
  exec "bash scripts/serve_docs.sh"

task docclean, "Clean generated documentation":
  exec "rm -rf docs/*"
  exec "touch docs/.gitkeep"

# task docapi, "Generate API documentation only":
#   exec "mkdir -p docs/api"
#   exec "nim doc --project --index:on --outdir:docs/api src/tzutrader.nim"
# 
# task benchmark, "Run performance benchmarks":
#   exec "nim c -d:release --opt:speed -r benchmarks/indicator_perf.nim"

task examples, "Compile all examples":
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
