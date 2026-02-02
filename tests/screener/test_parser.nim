## Test for Screener YAML Parser
##
## This test verifies that screener YAML configurations can be parsed correctly

import std/[unittest, strformat, options]
import ../../src/tzutrader/screener/[parser, schema, alerts]
import ../../src/tzutrader/data

suite "Screener YAML Parser Tests":

  test "Parse basic RSI screener":
    let config = parseScreenerYAMLFile("examples/screeners/basic_rsi_screener.yml")

    check config.metadata.name == "RSI Oversold Screener"
    check config.strategies.len == 1
    check config.strategies[0].kind == skBuiltIn
    check config.strategies[0].name == "rsi"

    check config.data.source == dsYahoo
    check config.data.symbols.len == 5
    check config.data.symbols[0] == "AAPL"
    check config.data.lookback.value == 90
    check config.data.lookback.unit == tuDays
    check config.data.interval == Int1d

    check config.output.format == ofTerminal
    check config.output.detailLevel == dlSummary

    check config.filters.signalTypes.len == 1
    check config.filters.signalTypes[0] == atBuySignal
    check config.filters.minStrength == asModerate
    check config.filters.topN.isSome()
    check config.filters.topN.get() == 10

  test "Parse multi-strategy screener":
    let config = parseScreenerYAMLFile("examples/screeners/multi_strategy_screener.yml")

    check config.strategies.len == 3
    check config.strategies[0].name == "rsi"
    check config.strategies[1].name == "macd"
    check config.strategies[2].name == "bollinger"

    check config.data.symbols.len == 8
    check config.data.lookback.value == 6
    check config.data.lookback.unit == tuMonths

    check config.output.format == ofCsv
    check config.output.detailLevel == dlDetailed
    check config.output.filepath.isSome()
    check config.output.filepath.get() == "screener_results.csv"

  test "Parse crypto screener":
    let config = parseScreenerYAMLFile("examples/screeners/crypto_screener.yml")

    check config.data.source == dsCoinbase
    check config.data.pairs.len == 4
    check config.data.pairs[0] == "BTC-USD"
    check config.data.lookbackCB.value == 7
    check config.data.lookbackCB.unit == tuDays
    check config.data.intervalCB == Int1h

  test "Parse intraday screener":
    let config = parseScreenerYAMLFile("examples/screeners/intraday_momentum.yml")

    check config.data.lookback.value == 3
    check config.data.lookback.unit == tuHours
    check config.data.interval == Int5m

    check config.filters.minStrength == asStrong
    check config.filters.topN.get() == 3

  test "Parse inline YAML":
    let yamlContent = """
metadata:
  name: "Test Screener"

strategies:
  - kind: built_in
    name: rsi

data:
  source: yahoo
  symbols:
    - AAPL
  lookback: 30d
  interval: 1d

output:
  format: terminal
  detail_level: summary

filters:
  signal_types:
    - buy_signal
  min_strength: weak
"""

    let config = parseScreenerYAML(yamlContent)
    check config.metadata.name == "Test Screener"
    check config.strategies[0].name == "rsi"
    check config.data.symbols[0] == "AAPL"
    check config.filters.minStrength == asWeak

  test "Error on missing data section":
    let yamlContent = """
metadata:
  name: "Invalid Screener"

strategies:
  - kind: built_in
    name: rsi
"""

    expect(ScreenerParseError):
      discard parseScreenerYAML(yamlContent)

  test "Error on missing strategies":
    let yamlContent = """
metadata:
  name: "Invalid Screener"

data:
  source: yahoo
  symbols:
    - AAPL
  lookback: 30d
  interval: 1d
"""

    expect(ScreenerParseError):
      discard parseScreenerYAML(yamlContent)

  test "Error on invalid data source":
    let yamlContent = """
metadata:
  name: "Invalid Screener"

strategies:
  - kind: built_in
    name: rsi

data:
  source: invalid_source
  symbols:
    - AAPL
  lookback: 30d
  interval: 1d
"""

    expect(ScreenerParseError):
      discard parseScreenerYAML(yamlContent)

when isMainModule:
  echo "Running screener parser tests..."
