# Reference Guide: Core Types

## Overview

This reference provides complete technical specifications for TzuTrader's core types and data structures. These types form the foundation of the library and are used throughout all modules.

**Module:** `tzutrader/core.nim`

## OHLCV Type

### Definition

```nim
type
  OHLCV* = object
    timestamp*: int64    ## Unix timestamp (seconds since epoch)
    open*: float64       ## Opening price
    high*: float64       ## Highest price
    low*: float64        ## Lowest price
    close*: float64      ## Closing price
    volume*: float64     ## Trading volume
```

### Description

OHLCV represents a single time period of market data. Each bar captures the complete price action and trading activity for its timeframe.

### Fields

| Field | Type | Description | Constraints |
|-------|------|-------------|-------------|
| `timestamp` | int64 | Unix timestamp in seconds | Must be > 0 |
| `open` | float64 | First traded price in period | Must be ≥ 0 |
| `high` | float64 | Highest traded price | Must be ≥ low, open, close |
| `low` | float64 | Lowest traded price | Must be ≤ high, open, close |
| `close` | float64 | Last traded price in period | Must be ≥ 0 |
| `volume` | float64 | Total trading volume | Must be ≥ 0 |

### Validation

An OHLCV bar is valid if and only if:

$$
\begin{align}
\text{open} &\geq 0 \\
\text{high} &\geq 0 \\
\text{low} &\geq 0 \\
\text{close} &\geq 0 \\
\text{high} &\geq \text{low} \\
\text{high} &\geq \text{open} \\
\text{high} &\geq \text{close} \\
\text{low} &\leq \text{open} \\
\text{low} &\leq \text{close}
\end{align}
$$

### Methods

#### `isValid() -> bool`

Validates OHLCV constraints.

```nim
proc isValid*(ohlcv: OHLCV): bool
```

**Returns:** `true` if all constraints are satisfied, `false` otherwise

**Example:**
```nim
let bar = OHLCV(timestamp: 1609459200, open: 100.0, high: 105.0, 
                low: 95.0, close: 102.0, volume: 1000000.0)
assert bar.isValid() == true
```

#### `typicalPrice() -> float64`

Calculates the typical price of the bar.

```nim
proc typicalPrice*(ohlcv: OHLCV): float64
```

**Formula:**

$$\text{Typical Price} = \frac{\text{high} + \text{low} + \text{close}}{3}$$

**Returns:** Average of high, low, and close prices

**Example:**
```nim
let bar = OHLCV(timestamp: 1609459200, open: 100.0, high: 105.0,
                low: 95.0, close: 102.0, volume: 1000000.0)
let typical = bar.typicalPrice()  # (105.0 + 95.0 + 102.0) / 3 = 100.67
```

#### `trueRange(prev: OHLCV) -> float64`

Calculates the true range for ATR calculation.

```nim
proc trueRange*(curr, prev: OHLCV): float64
```

**Formula:**

$$\text{True Range} = \max(\text{TR}_1, \text{TR}_2, \text{TR}_3)$$

where:

$$
\begin{align}
\text{TR}_1 &= \text{high}_{\text{curr}} - \text{low}_{\text{curr}} \\
\text{TR}_2 &= |\text{high}_{\text{curr}} - \text{close}_{\text{prev}}| \\
\text{TR}_3 &= |\text{low}_{\text{curr}} - \text{close}_{\text{prev}}|
\end{align}
$$

**Parameters:**
- `curr`: Current bar
- `prev`: Previous bar

**Returns:** Maximum of the three range calculations

**Example:**
```nim
let prev = OHLCV(timestamp: 1609459200, open: 100.0, high: 105.0,
                 low: 95.0, close: 102.0, volume: 1000000.0)
let curr = OHLCV(timestamp: 1609545600, open: 102.0, high: 108.0,
                 low: 100.0, close: 106.0, volume: 1200000.0)
let tr = trueRange(curr, prev)  # max(8.0, 6.0, 2.0) = 8.0
```

#### `change() -> float64`

Calculates absolute price change.

```nim
proc change*(ohlcv: OHLCV): float64
```

**Formula:**

$$\text{Change} = \text{close} - \text{open}$$

**Returns:** Absolute price change (positive = up, negative = down)

#### `changePercent() -> float64`

Calculates percentage price change.

```nim
proc changePercent*(ohlcv: OHLCV): float64
```

**Formula:**

$$\text{Change\%} = \frac{\text{close} - \text{open}}{\text{open}} \times 100$$

**Returns:** Percentage change (0.0 if open = 0)

### String Representation

```nim
proc `$`*(ohlcv: OHLCV): string
```

**Format:** `OHLCV(YYYY-MM-DD HH:MM:SS O:xxx H:xxx L:xxx C:xxx V:xxx)`

**Example:**
```nim
echo bar
# Output: OHLCV(2021-01-01 00:00:00 O:100.0 H:105.0 L:95.0 C:102.0 V:1000000.0)
```

## Position Enum

### Definition

```nim
type
  Position* = enum
    Stay  ## Hold current position
    Buy   ## Enter or increase long position
    Sell  ## Exit or decrease long position
```

### Values

| Value | Description | Usage |
|-------|-------------|-------|
| `Stay` | No action | Hold current position, wait |
| `Buy` | Open/increase long | Enter new position or add to existing |
| `Sell` | Close/decrease position | Exit position or reduce size |

### Notes

- TzuTrader currently supports long-only trading
- `Sell` exits positions, does not open short positions
- Strategies return `Position` values as trading signals

## Signal Type

### Definition

```nim
type
  Signal* = object
    position*: Position  ## Position action (Stay, Buy, Sell)
    symbol*: string      ## Symbol to trade
    timestamp*: int64    ## Signal generation time (Unix timestamp)
    price*: float64      ## Price at signal generation
    reason*: string      ## Human-readable reason for signal
```

### Description

A `Signal` represents a trading recommendation generated by a strategy. It specifies what action to take (Buy/Sell/Stay), on which symbol, at what price, and why.

### Fields

| Field | Type | Description | Required |
|-------|------|-------------|----------|
| `position` | Position | Trading action | Yes |
| `symbol` | string | Security identifier | Yes |
| `timestamp` | int64 | When signal was generated | Yes |
| `price` | float64 | Market price at signal time | Yes |
| `reason` | string | Explanation for signal | Optional |

### Constructor

```nim
proc newSignal*(position: Position, symbol: string, price: float64, 
                reason: string = ""): Signal
```

**Parameters:**
- `position`: Trading action (Buy, Sell, or Stay)
- `symbol`: Symbol identifier
- `price`: Current market price
- `reason`: Optional explanation (default: "")

**Returns:** New Signal with current timestamp

**Example:**
```nim
let signal = newSignal(Buy, "AAPL", 150.25, "RSI oversold: 28.5 < 30.0")
```

### String Representation

```nim
proc `$`*(signal: Signal): string
```

**Format:** `Signal(Position SYMBOL @PRICE at TIMESTAMP [reason: REASON])`

**Example:**
```nim
echo signal
# Output: Signal(Buy AAPL @150.25 at 2024-01-15 09:30:00 reason: RSI oversold: 28.5 < 30.0)
```

## Transaction Type

### Definition

```nim
type
  Transaction* = object
    timestamp*: int64    ## Transaction time (Unix timestamp)
    symbol*: string      ## Symbol traded
    action*: Position    ## Buy or Sell action
    quantity*: float64   ## Number of shares/units
    price*: float64      ## Execution price
    commission*: float64 ## Trading commission/fees
```

### Description

A `Transaction` records an executed trade. Portfolios maintain transaction history for audit trails and performance analysis.

### Fields

| Field | Type | Description | Constraints |
|-------|------|-------------|-------------|
| `timestamp` | int64 | Execution time | Must be > 0 |
| `symbol` | string | Security traded | Non-empty |
| `action` | Position | Buy or Sell | Not Stay |
| `quantity` | float64 | Shares traded | Must be > 0 |
| `price` | float64 | Execution price | Must be ≥ 0 |
| `commission` | float64 | Fees paid | Must be ≥ 0 |

### Constructor

```nim
proc newTransaction*(symbol: string, action: Position, 
                     quantity, price, commission: float64): Transaction
```

**Parameters:**
- `symbol`: Symbol identifier
- `action`: Buy or Sell
- `quantity`: Number of shares
- `price`: Execution price per share
- `commission`: Total commission paid

**Returns:** New Transaction with current timestamp

**Example:**
```nim
let tx = newTransaction("AAPL", Buy, 100.0, 150.25, 15.025)
```

### Cost Calculations

#### Buy Transaction Total Cost

$$\text{Total Cost} = (\text{quantity} \times \text{price}) + \text{commission}$$

#### Sell Transaction Net Proceeds

$$\text{Net Proceeds} = (\text{quantity} \times \text{price}) - \text{commission}$$

### String Representation

```nim
proc `$`*(tx: Transaction): string
```

**Format:** `Transaction(ACTION QUANTITY SYMBOL @PRICE fee:COMMISSION at TIMESTAMP)`

**Example:**
```nim
echo tx
# Output: Transaction(Buy 100.0 AAPL @150.25 fee:15.025 at 2024-01-15 09:30:00)
```

## StrategyConfig Type

### Definition

```nim
type
  StrategyConfig* = object
    name*: string                      ## Strategy name
    params*: Table[string, float64]    ## Parameter key-value pairs
```

### Description

`StrategyConfig` stores strategy configuration for serialization and reproduction of backtest conditions.

### Fields

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Strategy identifier |
| `params` | Table[string, float64] | Named parameters |

### Constructor

```nim
proc newStrategyConfig*(name: string, 
                        params: Table[string, float64] = initTable[string, float64]()): StrategyConfig
```

**Example:**
```nim
import std/tables

var params = initTable[string, float64]()
params["period"] = 14.0
params["oversold"] = 30.0
params["overbought"] = 70.0

let config = newStrategyConfig("RSI Strategy", params)
```

## Error Types

### TzuTraderError

Base exception type for all TzuTrader errors.

```nim
type
  TzuTraderError* = object of CatchableError
```

### DataError

Exception for data-related errors (file I/O, parsing, validation).

```nim
type
  DataError* = object of TzuTraderError
```

**Usage:**
```nim
raise newException(DataError, "Invalid CSV format at line 42")
```

### StrategyError

Exception for strategy execution errors.

```nim
type
  StrategyError* = object of TzuTraderError
```

**Usage:**
```nim
raise newException(StrategyError, "Insufficient data for indicator calculation")
```

### PortfolioError

Exception for portfolio operations errors.

```nim
type
  PortfolioError* = object of TzuTraderError
```

**Usage:**
```nim
raise newException(PortfolioError, "Insufficient cash for purchase")
```

## JSON Serialization

All core types support JSON serialization for data persistence and interoperability.

### OHLCV to JSON

```nim
proc toJson*(ohlcv: OHLCV): JsonNode
```

**Example:**
```nim
let bar = OHLCV(timestamp: 1609459200, open: 100.0, high: 105.0,
                low: 95.0, close: 102.0, volume: 1000000.0)
let json = bar.toJson()
# {"timestamp": 1609459200, "open": 100.0, "high": 105.0, 
#  "low": 95.0, "close": 102.0, "volume": 1000000.0}
```

### Signal to JSON

```nim
proc toJson*(signal: Signal): JsonNode
```

### Transaction to JSON

```nim
proc toJson*(tx: Transaction): JsonNode
```

### StrategyConfig to JSON

```nim
proc toJson*(config: StrategyConfig): JsonNode
```

### JSON Deserialization

```nim
proc fromJson*(node: JsonNode, T: typedesc[OHLCV]): OHLCV
proc fromJson*(node: JsonNode, T: typedesc[Signal]): Signal
```

**Example:**
```nim
let json = parseJson("""{"timestamp": 1609459200, "open": 100.0, ...}""")
let bar = fromJson(json, OHLCV)
```

## Time Representation

All timestamps use Unix time (seconds since January 1, 1970 00:00:00 UTC).

### Converting to Human-Readable Time

```nim
import std/times

let timestamp: int64 = 1609459200
let dt = fromUnix(timestamp)
echo dt.format("yyyy-MM-dd HH:mm:ss")
# Output: 2021-01-01 00:00:00
```

### Converting from Human-Readable Time

```nim
import std/times

let dt = parse("2021-01-01 00:00:00", "yyyy-MM-dd HH:mm:ss")
let timestamp = dt.toTime().toUnix()
# timestamp = 1609459200
```

### Time Zone Considerations

Unix timestamps are timezone-independent (always UTC). Convert to local time for display:

```nim
let dt = fromUnix(timestamp).local()
echo dt.format("yyyy-MM-dd HH:mm:ss ZZZ")
```

## Type Relationships

```
                    OHLCV
                      ↓
    Strategy → Signal → Transaction
                      ↓
                  Portfolio
```

**Flow:**
1. Strategies analyze `OHLCV` data
2. Strategies generate `Signal` objects
3. Portfolios execute signals, creating `Transaction` records
4. Transactions modify portfolio state

## Usage Examples

### Creating and Validating OHLCV

```nim
import tzutrader

let bar = OHLCV(
  timestamp: 1609459200,
  open: 100.0,
  high: 105.0,
  low: 95.0,
  close: 102.0,
  volume: 1000000.0
)

if bar.isValid():
  echo "Valid bar: ", bar
  echo "Typical price: ", bar.typicalPrice()
  echo "Change: ", bar.changePercent(), "%"
```

### Working with Signals

```nim
import tzutrader

let signal = newSignal(
  position = Buy,
  symbol = "AAPL",
  price = 150.25,
  reason = "Golden cross: 50-day MA crossed above 200-day MA"
)

case signal.position
of Buy:
  echo "BUY signal for ", signal.symbol, " at $", signal.price
of Sell:
  echo "SELL signal for ", signal.symbol, " at $", signal.price
of Stay:
  echo "No action"
```

### Recording Transactions

```nim
import tzutrader

let tx = newTransaction(
  symbol = "AAPL",
  action = Buy,
  quantity = 100.0,
  price = 150.25,
  commission = 15.025  # 0.1% commission
)

echo "Total cost: $", (tx.quantity * tx.price + tx.commission)
```

## See Also

- [Data Management Reference](02_data.md) - Data loading and streaming
- [Strategy Reference](04_strategies.md) - Strategy implementation
- [Portfolio Reference](05_portfolio.md) - Portfolio management
- [User Guide: Working with Data](../user_guide/02_data.md) - Conceptual overview
