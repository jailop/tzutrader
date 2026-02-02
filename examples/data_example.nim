## Example: Fetching and displaying stock data

import ../src/tzutrader
import std/[times, tables, strformat]

echo "=== TzuTrader Data Module Example ==="
echo ""

# Example 1: Fetch historical data for a single symbol
echo "1. Fetching historical data for AAPL (last 7 days)..."
let ds = newDataStream("AAPL", Int1d)
let data = ds.fetch(days = 7)

echo "   Retrieved ", data.len, " bars"
if data.len > 0:
  echo "   Latest bar:"
  let latest = data[^1]
  echo "     Date: ", fromUnix(latest.timestamp).format("yyyy-MM-dd")
  echo "     Open: $", latest.open
  echo "     High: $", latest.high
  echo "     Low: $", latest.low
  echo "     Close: $", latest.close
  echo "     Volume: ", latest.volume
echo ""

# Example 2: Get current quote
echo "2. Getting current quote for MSFT..."
let quote = getQuote("MSFT")
echo "   ", quote
echo ""

# Example 3: Fetch multiple symbols
echo "3. Fetching data for multiple symbols..."
let symbols = @["AAPL", "MSFT", "GOOGL"]
let endTime = getTime().toUnix()
let startTime = endTime - (7 * 86400) # 7 days ago

let multiData = fetchMultiple(symbols, startTime, endTime, Int1d)
for symbol, bars in multiData:
  echo "   ", symbol, ": ", bars.len, " bars"
echo ""

# Example 4: Get quotes for multiple symbols
echo "4. Getting quotes for multiple symbols..."
let quotes = getQuotes(symbols)
for symbol, q in quotes:
  let changeStr = if q.regularMarketChange >= 0: "+" &
      $q.regularMarketChange else: $q.regularMarketChange
  let pctStr = if q.regularMarketChangePercent >= 0: "+" else: ""
  echo "   ", symbol, ": $", q.regularMarketPrice,
       " (", pctStr, $q.regularMarketChangePercent, "%)"
echo ""

# Example 5: Using the iterator interface
echo "5. Streaming data using iterator..."
let ds2 = newDataStream("AAPL", Int1d)
var count = 0
for bar in ds2.stream(startTime, endTime):
  if count < 3: # Show first 3 bars
    echo "   ", fromUnix(bar.timestamp).format("yyyy-MM-dd"),
         ": Close = $", bar.close
  count += 1
echo "   ... (", count, " total bars)"
echo ""

# Example 6: Cache demonstration
echo "6. Demonstrating cache usage..."
let ds3 = newDataStream("TSLA", Int1d)
echo "   First fetch (from API or mock)..."
let data1 = ds3.fetch(startTime, endTime)
echo "   Retrieved ", data1.len, " bars, cache size: ", ds3.cache.len

echo "   Second fetch (from cache)..."
let data2 = ds3.fetch(startTime, endTime)
echo "   Retrieved ", data2.len, " bars, cache size: ", ds3.cache.len
echo "   Data identical: ", data1.len == data2.len
echo ""

# Example 7: Different time intervals
echo "7. Fetching with different intervals..."
for interval in [Int1h, Int1d, Int1wk]:
  let ds = newDataStream("AAPL", interval)
  let data = ds.fetch(days = 7)
  echo "   ", interval, ": ", data.len, " bars"
echo ""

echo "=== Example Complete ==="
