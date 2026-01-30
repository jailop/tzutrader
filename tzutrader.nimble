# Package

version       = "0.1.0"
author        = "tzutrader contributors"
description   = "A simplified trading bot library in Nim"
license       = "MIT"
srcDir        = "src"

# Dependencies

requires "nim >= 2.0.0"

# Tasks

task test, "Run the test suite":
  exec "nim c -r tests/test_core.nim"
  exec "nim c -r tests/test_data.nim"
  exec "nim c -r tests/test_indicators.nim"
  exec "nim c -r tests/test_strategy.nim"
  exec "nim c -r tests/test_portfolio.nim"
  exec "nim c -r tests/test_trader.nim"

task docs, "Generate documentation":
  exec "nim doc --project --index:on --outdir:docs src/tzutrader.nim"
  exec "nim doc --project --index:on --outdir:docs src/tzutrader/core.nim"
  exec "nim doc --project --index:on --outdir:docs src/tzutrader/data.nim"
  exec "nim doc --project --index:on --outdir:docs src/tzutrader/indicators.nim"
  exec "nim doc --project --index:on --outdir:docs src/tzutrader/strategy.nim"
  exec "nim doc --project --index:on --outdir:docs src/tzutrader/portfolio.nim"
  exec "nim doc --project --index:on --outdir:docs src/tzutrader/trader.nim"

task benchmark, "Run performance benchmarks":
  exec "nim c -d:release --opt:speed -r benchmarks/indicator_perf.nim"
