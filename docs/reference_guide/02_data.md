# Reference Guide: Data Management

## Overview

Data management in TzuTrader handles loading, validating, and streaming historical market data. The system supports CSV files for backtesting and provides an extensible interface for live data sources.

Most backtesting workflows use CSV files containing historical OHLCV data. The data module handles parsing, validation, and providing bar-by-bar access to this data.

**Module:** `tzutrader/data.nim`

## CSV File Format

TzuTrader expects CSV files with six columns representing OHLCV (Open, High, Low, Close, Volume) data plus timestamps.

### Standard Format

```csv
timestamp,open,high,low,close,volume
1609459200,100.0,105.0,95.0,102.0,1000000.0
1609545600,102.0,108.0,100.0,106.0,1200000.0
1609632000,106.0,110.0,104.0,108.0,1100000.0
```

### Field Specifications

| Column | Type | Description | Constraints |
|--------|------|-------------|-------------|
| `timestamp` | int64 | Unix timestamp (seconds since epoch) | Must be > 0, ascending order |
| `open` | float64 | Opening price | Must be ≥ 0 |
| `high` | float64 | Highest price | Must be ≥ max(open, close, low) |
| `low` | float64 | Lowest price | Must be ≤ min(open, close, high) |
| `close` | float64 | Closing price | Must be ≥ 0 |
| `volume` | float64 | Trading volume | Must be ≥ 0 |

### Timestamp Formats

TzuTrader accepts Unix timestamps (seconds since January 1, 1970 UTC). Many data sources provide dates in other formats:

**Converting from date strings:**

```nim
import std/times

# Parse YYYY-MM-DD format
let dt = parse("2021-01-01", "yyyy-MM-dd")
let timestamp = dt.toTime().toUnix()
# timestamp = 1609459200
```

**Converting from datetime objects:**

Most programming languages can convert datetime objects to Unix timestamps. For example, in Python:

```python
from datetime import datetime
dt = datetime(2021, 1, 1)
timestamp = int(dt.timestamp())
```

### Header Row

CSV files should include a header row with column names. TzuTrader skips the first line by default when reading files.

**If your file has no header:** Use `readCSV(filename, hasHeader = false)`

### Data Ordering

Bars must be in chronological order (earliest to latest). The system does not automatically sort data because maintaining order is critical for accurate backtesting.

### Data Quality

Before backtesting, verify:
- No missing bars (gaps in timestamps)
- No invalid bars (high < low, negative prices)
- Volume data is present (even if zero)
- Timestamps are consistent with the intended interval

## Reading CSV Files

### Basic CSV Reading

```nim
proc readCSV*(filename: string, hasHeader: bool = true): seq[OHLCV]
```

**Parameters:**
- `filename`: Path to CSV file
- `hasHeader`: Whether first line contains column names (default: `true`)

**Returns:** Sequence of OHLCV bars in file order

**Errors:** Raises `DataError` if:
- File doesn't exist
- CSV format is invalid (wrong number of columns)
- Values cannot be parsed as numbers
- Data violates OHLCV constraints

**Example:**

```nim
import tzutrader

try:
  let data = readCSV("data/AAPL.csv")
  echo "Loaded ", data.len, " bars"
  echo "Period: ", data[0].timestamp.fromUnix.format("yyyy-MM-dd"), 
       " to ", data[^1].timestamp.fromUnix.format("yyyy-MM-dd")
except DataError as e:
  echo "Error loading data: ", e.msg
```

### Writing CSV Files

```nim
proc writeCSV*(data: seq[OHLCV], filename: string, includeHeader: bool = true)
```

**Parameters:**
- `data`: OHLCV sequence to write
- `filename`: Output file path
- `includeHeader`: Include column header row (default: `true`)

**Example:**

```nim
import tzutrader

let mockData = generateMockOHLCV("TEST", startTime, endTime, Int1d)
writeCSV(mockData, "test_data.csv")
```

## CSV Data Streaming

For memory-efficient processing or when you need to process data bar-by-bar, use `CSVDataStream`.

### Creating a Stream

```nim
proc newCSVDataStream*(filename: string, symbol: string = ""): CSVDataStream
```

**Parameters:**
- `filename`: Path to CSV file
- `symbol`: Optional symbol identifier (extracted from filename if omitted)

**Example:**

```nim
let stream = newCSVDataStream("data/AAPL.csv")
```

If symbol is not provided, it's extracted from the filename. `data/AAPL.csv` becomes symbol `AAPL`.

### Stream Operations

#### Iterating Through Bars

```nim
for bar in stream.items():
  # Process each bar
  echo bar.timestamp, ": $", bar.close
```

The iterator automatically resets the stream to the beginning before iterating.

#### Manual Navigation

```nim
proc reset*(stream: CSVDataStream)  # Reset to beginning
proc hasNext*(stream: CSVDataStream): bool  # Check if more data exists
proc next*(stream: CSVDataStream): OHLCV  # Get next bar and advance
proc peek*(stream: CSVDataStream): OHLCV  # Get current bar without advancing
```

**Example:**

```nim
let stream = newCSVDataStream("data/AAPL.csv")

while stream.hasNext():
  let bar = stream.next()
  if bar.close > 150.0:
    echo "Price above $150: ", bar.timestamp.fromUnix.format("yyyy-MM-dd")
```

#### Stream Information

```nim
proc len*(stream: CSVDataStream): int  # Total bars in stream
proc remaining*(stream: CSVDataStream): int  # Unprocessed bars remaining
```

**Example:**

```nim
let stream = newCSVDataStream("data/AAPL.csv")
echo "Total bars: ", stream.len()

for i in 1..10:
  discard stream.next()

echo "Remaining: ", stream.remaining()
```

### When to Use Streaming

**Use `readCSV()`** when:
- Dataset fits comfortably in memory
- You need random access to bars
- Running a single backtest

**Use `CSVDataStream`** when:
- Processing very large files (millions of bars)
- Memory is constrained
- Implementing custom bar-by-bar logic
- Building real-time simulation systems

For typical backtesting with daily data over years, `readCSV()` is simpler and sufficient.

## Mock Data Generation

For testing strategies before acquiring real data or for unit testing, generate synthetic data:

```nim
proc generateMockOHLCV*(symbol: string, startTime, endTime: int64, 
                       interval: Interval, startPrice: float64 = 100.0,
                       volatility: float64 = 0.02): seq[OHLCV]
```

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `symbol` | string | — | Symbol identifier |
| `startTime` | int64 | — | Start timestamp (Unix) |
| `endTime` | int64 | — | End timestamp (Unix) |
| `interval` | Interval | — | Time between bars |
| `startPrice` | float64 | 100.0 | Initial price ($) |
| `volatility` | float64 | 0.02 | Daily volatility (0.02 = 2%) |

**Returns:** Sequence of valid OHLCV bars with random price walks

**Algorithm:**

The generator creates a random walk with:
- Normally distributed returns based on volatility
- High/low values that respect open/close prices
- Random volume around a baseline
- Valid OHLCV constraints (high ≥ all prices ≥ low)

**Example:**

```nim
import tzutrader, std/times

# Generate 1 year of daily data
let start = parse("2020-01-01", "yyyy-MM-dd").toTime().toUnix()
let endTime = parse("2021-01-01", "yyyy-MM-dd").toTime().toUnix()

let data = generateMockOHLCV(
  symbol = "MOCK",
  startTime = start,
  endTime = endTime,
  interval = Int1d,
  startPrice = 100.0,
  volatility = 0.015  # 1.5% daily volatility
)

echo "Generated ", data.len, " bars"
writeCSV(data, "mock_data.csv")
```

**Uses for mock data:**

- **Strategy development:** Test logic before acquiring real data
- **Unit testing:** Verify strategy behavior with known inputs
- **Parameter exploration:** Understand strategy mechanics in controlled conditions
- **Documentation:** Create reproducible examples

**Limitations:**

Mock data lacks real market characteristics:
- No trends (pure random walk)
- No correlation between days
- No volume patterns
- No gaps, splits, or dividends

Use mock data for testing code, not for evaluating strategy performance.

## Time Intervals

The `Interval` enum defines standard timeframes:

```nim
type
  Interval* = enum
    Int1m = "1m"    ## 1 minute
    Int5m = "5m"    ## 5 minutes
    Int15m = "15m"  ## 15 minutes
    Int30m = "30m"  ## 30 minutes
    Int1h = "1h"    ## 1 hour
    Int1d = "1d"    ## 1 day
    Int1wk = "1wk"  ## 1 week
    Int1mo = "1mo"  ## 1 month
```

### Interval Utilities

```nim
proc toSeconds*(interval: Interval): int64
```

Converts interval to seconds for timestamp calculations:

```nim
let daySeconds = Int1d.toSeconds()  # 86400
let hourSeconds = Int1h.toSeconds()  # 3600
```

**Usage example:**

```nim
import tzutrader

# Calculate how many bars in a year for daily data
let secondsPerYear = 365 * 86400
let secondsPerBar = Int1d.toSeconds()
let barsPerYear = secondsPerYear div secondsPerBar
echo "Approximately ", barsPerYear, " daily bars per year"
```

### Interval Constraints

Different intervals have practical data availability limits. While TzuTrader can process any interval, data sources impose restrictions:

```nim
proc maxHistory*(interval: Interval): int64
```

Returns maximum lookback in seconds (0 = unlimited):

| Interval | Max History | Typical Use Case |
|----------|-------------|------------------|
| 1m | ~7 days | Intraday scalping |
| 5m, 15m, 30m | ~60 days | Day trading |
| 1h | ~2 years | Swing trading |
| 1d, 1wk, 1mo | Unlimited | Position trading, backtesting |

These limits reflect typical data provider constraints. Your specific data source may differ.

## Data Validation

All OHLCV bars are validated on creation using the `isValid()` method from the core module.

**Validation checks:**

$$
\begin{align}
\text{open} &\geq 0 \\
\text{high} &\geq 0 \\
\text{low} &\geq 0 \\
\text{close} &\geq 0 \\
\text{volume} &\geq 0 \\
\text{high} &\geq \text{low} \\
\text{high} &\geq \text{open} \\
\text{high} &\geq \text{close} \\
\text{low} &\leq \text{open} \\
\text{low} &\leq \text{close}
\end{align}
$$

**Handling invalid data:**

When `readCSV()` encounters invalid data, it raises a `DataError`. Fix the source data rather than trying to work around validation:

```nim
try:
  let data = readCSV("data/AAPL.csv")
except DataError as e:
  echo "Data validation failed: ", e.msg
  # Fix the CSV file before proceeding
```

Common invalid data patterns:
- High < Low (data entry error or bad source)
- Negative prices (incorrect parsing or corrupted data)
- Close > High or Close < Low (inconsistent data)

## Common Data Operations

### Extracting Price Series

```nim
import tzutrader

let data = readCSV("data/AAPL.csv")

# Extract close prices for indicator calculation
let closes = data.mapIt(it.close)

# Calculate RSI on closes
let rsiValues = rsi(closes, period = 14)
```

### Filtering by Date Range

```nim
import tzutrader, std/times

let data = readCSV("data/AAPL.csv")

# Filter to 2020 only
let start2020 = parse("2020-01-01", "yyyy-MM-dd").toTime().toUnix()
let end2020 = parse("2021-01-01", "yyyy-MM-dd").toTime().toUnix()

let data2020 = data.filterIt(it.timestamp >= start2020 and it.timestamp < end2020)

echo "2020 data: ", data2020.len, " bars"
```

### Calculating Basic Statistics

```nim
import tzutrader, std/math

let data = readCSV("data/AAPL.csv")

let closes = data.mapIt(it.close)
let volumes = data.mapIt(it.volume)

echo "Average close: $", closes.sum() / closes.len.float64
echo "Max close: $", closes.max()
echo "Min close: $", closes.min()
echo "Average volume: ", volumes.sum() / volumes.len.float64
```

### Detecting Data Gaps

```nim
import tzutrader

let data = readCSV("data/AAPL.csv")
let expectedInterval = Int1d.toSeconds()

for i in 1..<data.len:
  let gap = data[i].timestamp - data[i-1].timestamp
  if gap > expectedInterval * 1.2:  # Allow 20% tolerance
    echo "Gap detected: ", gap div expectedInterval, " intervals at ",
         data[i-1].timestamp.fromUnix.format("yyyy-MM-dd")
```

## Working with Multiple Symbols

### Loading Multiple Files

```nim
import tzutrader, std/tables

let symbols = ["AAPL", "MSFT", "GOOG"]
var datasets = initTable[string, seq[OHLCV]]()

for symbol in symbols:
  let filename = "data/" & symbol & ".csv"
  datasets[symbol] = readCSV(filename)
  echo symbol, ": ", datasets[symbol].len, " bars"
```

### Aligning Timestamps

When working with multiple symbols, ensure timestamps align:

```nim
import tzutrader, std/tables, std/sets

# Find common timestamps across all symbols
proc findCommonTimestamps(datasets: Table[string, seq[OHLCV]]): seq[int64] =
  # Get timestamps from first symbol
  var common = initHashSet[int64]()
  for bar in datasets.values.toSeq()[0]:
    common.incl(bar.timestamp)
  
  # Intersect with other symbols
  for symbol, data in datasets:
    var symbolTimes = initHashSet[int64]()
    for bar in data:
      symbolTimes.incl(bar.timestamp)
    common = common.intersection(symbolTimes)
  
  result = common.toSeq()
  result.sort()

let commonTimestamps = findCommonTimestamps(datasets)
echo "Common timestamps: ", commonTimestamps.len
```

This ensures backtests across symbols use the same time periods, preventing lookahead bias.

## Data Sources

TzuTrader's CSV format is intentionally simple to support data from any source. Common sources include:

**Free sources:**
- Yahoo Finance (via download or API)
- Alpha Vantage (API)
- Quandl/Nasdaq Data Link (API)
- Exchange websites (many provide historical data)

**Paid sources:**
- Interactive Brokers
- TD Ameritrade
- Polygon.io
- IEX Cloud

**Converting from other formats:**

Most data providers offer CSV exports. Ensure your conversion:
1. Uses Unix timestamps or converts dates to Unix time
2. Includes all six required columns
3. Maintains chronological order
4. Handles splits and dividends appropriately

## Error Handling

The data module raises `DataError` for data-related issues:

```nim
type
  DataError* = object of TzuTraderError
```

**Common error scenarios:**

- File not found: Check file paths
- Invalid CSV format: Verify column count and structure
- Parse errors: Ensure numeric values are valid numbers
- Constraint violations: Fix OHLCV relationships in source data

**Defensive programming:**

```nim
import tzutrader

proc loadDataSafely(filename: string): seq[OHLCV] =
  try:
    result = readCSV(filename)
    if result.len == 0:
      raise newException(DataError, "File is empty")
    echo "Loaded ", result.len, " bars successfully"
  except IOError as e:
    echo "File error: ", e.msg
    result = @[]
  except DataError as e:
    echo "Data error: ", e.msg
    result = @[]
```

## Performance Considerations

**Loading speed:** CSV parsing is fast. Files with millions of rows load in seconds on modern hardware.

**Memory usage:** Each OHLCV bar uses approximately 56 bytes (6 float64/int64 fields). One million bars requires ~56 MB.

**Optimization tips:**
- Use `CSVDataStream` for very large files to avoid loading everything into memory
- Filter data to the needed timeframe before processing
- Consider binary formats (like MessagePack or custom binary) for frequently-accessed large datasets

## See Also

- [Core Types Reference](01_core.md) - OHLCV structure and validation
- [Backtesting Reference](06_backtesting.md) - Using data in backtests
- [User Guide: Working with Data](../user_guide/02_data.md) - Conceptual introduction
