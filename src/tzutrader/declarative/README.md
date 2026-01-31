# Declarative Strategy System

This directory contains the implementation of TzuTrader's YAML-based declarative strategy system.

## Status: Phase 1 - In Progress

**Current Implementation**: Day 1-5 Complete
- ✅ Module structure created
- ✅ Schema types defined
- ✅ YAML parser implemented
- ✅ Validator implemented
- ✅ Test fixtures created
- ✅ Unit tests written
- ⏳ Strategy builder (Day 8-9) - **Next**
- ⏳ CLI integration (Day 10)

## Module Structure

```
declarative/
├── schema.nim           # Type definitions for strategy AST
├── parser.nim           # YAML → Schema object conversion
├── validator.nim        # Semantic validation
├── strategy_builder.nim # Schema → Executable strategy (WIP)
└── README.md           # This file
```

## Architecture

```
YAML File → Parser → StrategyYAML → Validator → Strategy Builder → DeclarativeStrategy
                                         ↓
                                   ValidationResult
```

## Usage (After Phase 1 Complete)

```nim
import tzutrader/declarative/[parser, validator, strategy_builder]

# Load and validate strategy
let strategyDef = parseStrategyYAMLFile("my_strategy.yml")
let validation = validateStrategy(strategyDef)

if not validation.valid:
  for err in validation.errors:
    echo "ERROR: ", err
  quit(1)

# Build executable strategy
let strategy = buildStrategy(strategyDef)

# Run backtest
# ... (use existing backtest infrastructure)
```

## YAML Strategy Format

See test fixtures in `tests/declarative/fixtures/` for examples:

```yaml
metadata:
  name: "My Strategy"
  description: "Description here"
  tags: [tag1, tag2]

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
  type: fixed          # Fixed number of shares
  size: 100

# OR

position_sizing:
  type: percent        # Percentage of portfolio equity (Phase 2)
  percent: 20          # Use 20% of portfolio per trade
```

**Position Sizing Types:**
- **fixed**: Buy exactly N shares (e.g., `size: 100`)
- **percent**: Use P% of portfolio equity (e.g., `percent: 20` for 20%)
  - Scales with portfolio growth
  - Better risk management
  - Recommended: 10-25% per trade


## Boolean Logic Support (Phase 1)

### Simple AND (implicit)
```yaml
conditions:
  - left: rsi_14
    operator: "<"
    right: "30"
  - left: price
    operator: ">"
    right: sma_200
```

### Explicit AND
```yaml
conditions:
  all:
    - left: rsi_14
      operator: "<"
      right: "30"
    - left: macd
      operator: ">"
      right: "0"
```

### OR Logic
```yaml
conditions:
  any:
    - left: rsi_14
      operator: "<"
      right: "30"
    - left: rsi_14
      operator: ">"
      right: "70"
```

### Nested Logic
```yaml
conditions:
  all:
    - any:
        - left: rsi_14
          operator: "<"
          right: "30"
        - left: rsi_14
          operator: ">"
          right: "70"
    - left: volume
      operator: ">"
      right: "1000000"
```

## Testing

```bash
# Run all declarative tests
nim c -r tests/declarative/test_all.nim

# Run individual test suites
nim c -r tests/declarative/test_schema.nim
nim c -r tests/declarative/test_parser.nim
nim c -r tests/declarative/test_validator.nim
```

## Next Steps (Day 8-9)

1. **Research Nim macros/introspection**
   - Study how `cligen` introspects function signatures
   - Explore `macros` module for compile-time reflection
   - Investigate `typetraits` for type information

2. **Implement Strategy Builder**
   - Create indicator factory using introspection
   - Implement condition evaluator with short-circuit logic
   - Build `DeclarativeStrategy` that inherits from `Strategy`
   - Implement `onBar()` method for strategy execution

3. **Key Design Decision**: Full macro approach vs semi-automated?
   - **Option A**: Full introspection (like cligen) - zero maintenance
   - **Option B**: Semi-automated with templates - some manual work
   - **Recommendation**: Start with Option B, upgrade to Option A in Phase 2

## Phase 1 Limitations

- ❌ No NOT logic (Phase 3)
- ❌ No expression-based indicators (Phase 3)
- ❌ No dynamic position sizing (Phase 2)
- ❌ No batch testing (Phase 4)
- ❌ No optimization (Phase 5)
- ✅ Simple AND/OR conditions only
- ✅ Fixed position sizing only
- ✅ Single-indicator strategies

## References

- **Design Document**: `../../design.md`
- **Phase 1 Plan**: `../../phase1.md`
- **CLI Integration**: Will use `--run-yaml` option
- **Existing Strategies**: `../strategies/` for comparison
