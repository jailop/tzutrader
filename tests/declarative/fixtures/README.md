# Test Fixtures for Declarative Strategies

This directory contains YAML test fixtures for the declarative strategy system.

## Valid Fixtures

- **valid_rsi.yml** - Simple RSI strategy (oversold/overbought)
- **valid_rsi_trend.yml** - RSI with trend filter using AND logic
- **valid_macd.yml** - MACD crossover strategy

## Invalid Fixtures

- **invalid_no_name.yml** - Missing required metadata.name field
- **invalid_duplicate_ids.yml** - Duplicate indicator IDs
- **invalid_undefined_ref.yml** - References undefined indicator

## Usage in Tests

```nim
import std/unittest
import tzutrader/declarative/parser

test "Parse valid RSI strategy":
  let strategy = parseStrategyYAMLFile("fixtures/valid_rsi.yml")
  check strategy.metadata.name == "Simple RSI Strategy"

test "Reject invalid strategy":
  expect ParseError:
    discard parseStrategyYAMLFile("fixtures/invalid_no_name.yml")
```
