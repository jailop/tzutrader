# Working with Market Data

## Understanding OHLCV Data

Trading strategies analyze price movements to make decisions. The standard format for representing price data is OHLCV, which stands for:

- **Open**: The first traded price during a time period
- **High**: The highest traded price during the period
- **Low**: The lowest traded price during the period
- **Close**: The last traded price during the period
- **Volume**: The total number of shares or contracts traded

Each OHLCV bar represents one time period, which could be one minute, one hour, one day, or any other interval. Day traders might use 5-minute bars, while long-term investors typically use daily bars.

The OHLCV format captures essential information about price movement and trading activity. The relationship between open, high, low, and close reveals market sentiment. For example, a bar where close is much higher than open suggests buyers were in control during that period.

## CSV File Format

TzuTrader reads historical data from CSV (Comma-Separated Values) files. This is a simple text format that most data providers support.

### Required Format

The CSV file must have six columns in this order:

```csv
timestamp,open,high,low,close,volume
1609459200,100.0,105.0,95.0,102.0,1000000.0
1609545600,102.0,107.0,100.0,106.0,1200000.0
1609632000,106.0,108.0,104.0,105.0,900000.0
```

**Column descriptions:**

- `timestamp`: Unix timestamp (seconds since January 1, 1970 UTC)
- `open`, `high`, `low`, `close`: Prices as decimal numbers
- `volume`: Trading volume as a decimal number

### Important Requirements

1. **Header row**: The first line must be the column names
2. **Order matters**: Columns must appear in the exact order shown above
3. **No missing values**: Every field must have a value
4. **Chronological order**: Bars should be ordered by time (earliest first)
5. **Valid prices**: High must be >= low, and both must be >= 0
6. **Consistent intervals**: Gaps in time should represent actual market closures

## Loading Data from CSV

The simplest way to load data is with the `readCSV` function:

```nim
import tzutrader

# Load entire file into memory
let data = readCSV("data/AAPL.csv")
echo "Loaded ", data.len, " bars"

# Access individual bars
echo "First bar: ", data[0]
echo "Last bar: ", data[^1]

# Iterate through data
for bar in data:
  if bar.close > 150.0:
    echo "Price above $150 on ", fromUnix(bar.timestamp)
```

This loads all data into memory at once, which works well for most backtests. The function validates the CSV format and will raise an error if the file doesn't match the expected structure.

## Streaming Large Files

For very large data files, you can use `CSVDataStream` to process data without loading everything into memory:

```nim
import tzutrader

# Create a stream (doesn't load all data yet)
let stream = newCSVDataStream("data/AAPL.csv")
echo "File contains ", stream.len, " bars"

# Process bars one at a time
stream.reset()
while stream.hasNext():
  let bar = stream.next()
  # Process bar...

# Or use iterator syntax
for bar in stream.items():
  # Process bar...
```

The stream reads the file once during creation to count bars and validate format, then allows you to iterate through bars efficiently.

## Generating Test Data

When developing strategies, you often need data for testing. TzuTrader can generate realistic mock data:

```nim
import tzutrader
import std/times

# Generate 1 year of daily data
let startTime = parse("2023-01-01", "yyyy-MM-dd").toTime().toUnix()
let endTime = parse("2023-12-31", "yyyy-MM-dd").toTime().toUnix()

let mockData = generateMockOHLCV(
  symbol = "TEST",
  startTime = startTime,
  endTime = endTime,
  interval = Int1d,        # Daily bars
  startPrice = 100.0,      # Starting at $100
  volatility = 0.02        # 2% daily volatility
)

# Save to CSV for later use
writeCSV(mockData, "data/TEST.csv")
```

The mock data follows realistic price patterns with random walk behavior. The `volatility` parameter controls how much prices fluctuate - typical values range from 0.01 (1%, low volatility) to 0.03 (3%, high volatility).

Mock data is useful for:
- Testing strategy logic during development
- Creating examples and tutorials
- Validating your code works before obtaining real data

## Obtaining Real Historical Data

For actual backtesting, you need real historical price data. Several sources provide this:

### Free Sources

1. **Yahoo Finance**: Download CSV files manually for most stocks
   - Go to finance.yahoo.com
   - Search for a symbol
   - Click "Historical Data" tab
   - Select date range and frequency
   - Click "Download"

2. **Alpha Vantage**: Free API with rate limits (5 calls/minute, 500 calls/day)

3. **Polygon.io**: Free tier with delayed data

### Paid Sources

1. **Interactive Brokers**: Historical data included with account
2. **Alpaca**: Free historical data for account holders
3. **Tiingo**: Affordable plans for retail traders

### Data Considerations

When obtaining data, consider:

- **Survivorship bias**: Historical databases often exclude delisted stocks, making backtests overly optimistic
- **Splits and dividends**: Ensure price data is adjusted for corporate actions
- **Data quality**: Check for gaps, errors, and unusual values
- **Time zones**: Verify timestamps match your expectations
- **Costs**: Understand fees before committing to a data provider

## Common Data Issues

### Invalid OHLCV Relationships

Sometimes data files contain errors where high < low or prices are negative. TzuTrader validates this automatically:

```nim
import tzutrader

let data = readCSV("data/suspicious.csv")

# Check each bar
for bar in data:
  if not bar.isValid():
    echo "Invalid bar at ", fromUnix(bar.timestamp)
```

The `isValid()` function checks:
- All prices are non-negative
- High >= low
- High >= open and close
- Low <= open and close

### Missing Data

Gaps in timestamps can indicate:
1. Market closures (weekends, holidays) - expected
2. Data provider issues - problematic
3. Low liquidity periods - context-dependent

```nim
import tzutrader

let data = readCSV("data/AAPL.csv")

# Check for unexpected gaps (> 3 days for daily data)
for i in 1..<data.len:
  let gap = data[i].timestamp - data[i-1].timestamp
  let days = gap div 86400
  if days > 3:
    echo "Gap of ", days, " days between ",
         fromUnix(data[i-1].timestamp), " and ",
         fromUnix(data[i].timestamp)
```

### Timezone Issues

Unix timestamps are always in UTC. If your data source uses a different timezone, you'll need to convert:

```nim
import std/times

# If your data is in EST/EDT (Eastern)
let estTime = parse("2023-01-03 16:00:00", "yyyy-MM-dd HH:mm:ss")
let utcTime = estTime.utc()  # Convert to UTC
let timestamp = utcTime.toUnix()
```

## Data Validation Checklist

Before running backtests, validate your data:

- [ ] File has header row with correct column names
- [ ] All rows have exactly 6 values
- [ ] Timestamps are in ascending order
- [ ] No duplicate timestamps
- [ ] High >= Low for every bar
- [ ] No negative prices
- [ ] Volume values are reasonable (> 0 for liquid securities)
- [ ] No suspicious price spikes (compare to known sources)
- [ ] Date range matches expectations
- [ ] Time interval is consistent (daily, hourly, etc.)

## Saving Results

After processing data, you can save it back to CSV:

```nim
import tzutrader

# Load and process data
var data = readCSV("data/raw.csv")

# Remove invalid bars
data = data.filterIt(it.isValid())

# Save cleaned data
writeCSV(data, "data/cleaned.csv", includeHeader = true)
```

This is useful for creating cleaned datasets or converting data between formats.

## Next Steps

Now that you understand data management, the next chapter covers technical indicators - the tools strategies use to analyze price data and make trading decisions.

## Key Takeaways

- OHLCV data captures essential price and volume information for each time period
- TzuTrader expects CSV files with a specific format: timestamp, open, high, low, close, volume
- Use `readCSV()` for simple loading or `CSVDataStream` for large files
- Generate mock data with `generateMockOHLCV()` for testing
- Always validate data before backtesting - check for invalid prices, gaps, and errors
- Real historical data requires careful selection of providers and quality checks
