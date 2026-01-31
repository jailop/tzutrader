## Tests for Batch Parser
##
## Tests the parsing of batch test YAML configurations

import std/[unittest, options, tables]
import ../src/tzutrader/declarative/[schema, batch_parser]

suite "Batch Parser Tests":
  
  test "Parse minimal batch test":
    let yamlContent = """
version: "1.0"
type: batch_test

data:
  source: yahoo
  symbols:
    - AAPL
    - MSFT
  start_date: "2023-01-01"
  end_date: "2024-01-01"

strategies:
  - file: "strategies/test.yml"
    name: "Test Strategy"

portfolio:
  initial_cash: 100000.0
  commission: 0.001
"""
    
    let config = parseBatchTestYAML(yamlContent)
    
    check config.version == "1.0"
    check config.data.source == "yahoo"
    check config.data.symbols.len == 2
    check config.data.symbols[0] == "AAPL"
    check config.data.symbols[1] == "MSFT"
    check config.data.startDate == "2023-01-01"
    check config.data.endDate == "2024-01-01"
    check config.strategies.len == 1
    check config.strategies[0].file == "strategies/test.yml"
    check config.strategies[0].name == "Test Strategy"
    check config.portfolio.initialCash == 100000.0
    check config.portfolio.commission == 0.001
  
  test "Parse batch test with output config":
    let yamlContent = """
version: "1.0"
type: batch_test

data:
  source: yahoo
  symbols: [AAPL]
  start_date: "2023-01-01"
  end_date: "2024-01-01"

strategies:
  - file: "test.yml"
    name: "Test"

portfolio:
  initial_cash: 50000.0
  commission: 0.002

output:
  comparison_report: "results/report.html"
  individual_results: "results/individual/"
  format: "html"
"""
    
    let config = parseBatchTestYAML(yamlContent)
    
    check config.output.comparisonReport.isSome()
    check config.output.comparisonReport.get() == "results/report.html"
    check config.output.individualResults.isSome()
    check config.output.individualResults.get() == "results/individual/"
    check config.output.format.isSome()
    check config.output.format.get() == "html"
  
  test "Parse batch test with parameter overrides":
    let yamlContent = """
version: "1.0"
type: batch_test

data:
  source: csv
  symbols: [TEST]
  start_date: "2023-01-01"
  end_date: "2024-01-01"
  csv_path: "data.csv"

strategies:
  - file: "rsi.yml"
    name: "RSI Default"
  
  - file: "rsi.yml"
    name: "RSI Aggressive"
    overrides:
      rsi_14:
        period: 10
        oversold: 25
      sma_20:
        period: 30

portfolio:
  initial_cash: 100000.0
  commission: 0.001
"""
    
    let config = parseBatchTestYAML(yamlContent)
    
    check config.data.source == "csv"
    check config.data.csvPath.isSome()
    check config.data.csvPath.get() == "data.csv"
    check config.strategies.len == 2
    check config.strategies[0].name == "RSI Default"
    check config.strategies[0].overrides.len == 0
    check config.strategies[1].name == "RSI Aggressive"
    check config.strategies[1].overrides.len == 3  # 2 params for rsi_14, 1 for sma_20
    
    # Check override values
    var foundPeriod = false
    var foundOversold = false
    for override in config.strategies[1].overrides:
      if override.indicatorId == "rsi_14":
        if override.paramName == "period":
          check override.paramValue.kind == pkInt
          check override.paramValue.intVal == 10
          foundPeriod = true
        elif override.paramName == "oversold":
          check override.paramValue.kind == pkInt
          check override.paramValue.intVal == 25
          foundOversold = true
    
    check foundPeriod
    check foundOversold
  
  test "Parse coinbase data source":
    let yamlContent = """
version: "1.0"
type: batch_test

data:
  source: coinbase
  symbols:
    - BTC-USD
    - ETH-USD
  start_date: "2023-01-01"
  end_date: "2024-01-01"

strategies:
  - file: "crypto.yml"
    name: "Crypto Strategy"

portfolio:
  initial_cash: 10000.0
  commission: 0.005
"""
    
    let config = parseBatchTestYAML(yamlContent)
    
    check config.data.source == "coinbase"
    check config.data.symbols.len == 2
    check config.data.symbols[0] == "BTC-USD"
    check config.portfolio.commission == 0.005
  
  test "Fail on missing required sections":
    # Missing data section
    let yaml1 = """
version: "1.0"
type: batch_test

strategies:
  - file: "test.yml"
    name: "Test"

portfolio:
  initial_cash: 100000.0
  commission: 0.001
"""
    
    expect(BatchParseError):
      discard parseBatchTestYAML(yaml1)
    
    # Missing strategies section
    let yaml2 = """
version: "1.0"
type: batch_test

data:
  source: yahoo
  symbols: [AAPL]
  start_date: "2023-01-01"
  end_date: "2024-01-01"

portfolio:
  initial_cash: 100000.0
  commission: 0.001
"""
    
    expect(BatchParseError):
      discard parseBatchTestYAML(yaml2)
    
    # Missing portfolio section
    let yaml3 = """
version: "1.0"
type: batch_test

data:
  source: yahoo
  symbols: [AAPL]
  start_date: "2023-01-01"
  end_date: "2024-01-01"

strategies:
  - file: "test.yml"
    name: "Test"
"""
    
    expect(BatchParseError):
      discard parseBatchTestYAML(yaml3)
  
  test "Fail on invalid data source":
    let yamlContent = """
version: "1.0"
type: batch_test

data:
  source: invalid_source
  symbols: [AAPL]
  start_date: "2023-01-01"
  end_date: "2024-01-01"

strategies:
  - file: "test.yml"
    name: "Test"

portfolio:
  initial_cash: 100000.0
  commission: 0.001
"""
    
    expect(BatchParseError):
      discard parseBatchTestYAML(yamlContent)
  
  test "Fail on empty symbols list":
    let yamlContent = """
version: "1.0"
type: batch_test

data:
  source: yahoo
  symbols: []
  start_date: "2023-01-01"
  end_date: "2024-01-01"

strategies:
  - file: "test.yml"
    name: "Test"

portfolio:
  initial_cash: 100000.0
  commission: 0.001
"""
    
    expect(BatchParseError):
      discard parseBatchTestYAML(yamlContent)
  
  test "Fail on invalid output format":
    let yamlContent = """
version: "1.0"
type: batch_test

data:
  source: yahoo
  symbols: [AAPL]
  start_date: "2023-01-01"
  end_date: "2024-01-01"

strategies:
  - file: "test.yml"
    name: "Test"

portfolio:
  initial_cash: 100000.0
  commission: 0.001

output:
  format: "xml"
"""
    
    expect(BatchParseError):
      discard parseBatchTestYAML(yamlContent)
  
  test "Fail on wrong type field":
    let yamlContent = """
version: "1.0"
type: single_strategy

data:
  source: yahoo
  symbols: [AAPL]
  start_date: "2023-01-01"
  end_date: "2024-01-01"

strategies:
  - file: "test.yml"
    name: "Test"

portfolio:
  initial_cash: 100000.0
  commission: 0.001
"""
    
    expect(BatchParseError):
      discard parseBatchTestYAML(yamlContent)
  
  test "Parse with default values":
    let yamlContent = """
version: "1.0"
type: batch_test

data:
  source: yahoo
  symbols: [AAPL]
  start_date: "2023-01-01"
  end_date: "2024-01-01"

strategies:
  - file: "test.yml"
    name: "Test"

portfolio:
  initial_cash: 100000.0
  commission: 0.001
"""
    
    let config = parseBatchTestYAML(yamlContent)
    
    # Output config should have none values when not specified
    check config.output.comparisonReport.isNone()
    check config.output.individualResults.isNone()
    check config.output.format.isNone()
