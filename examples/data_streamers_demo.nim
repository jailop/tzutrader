## Demo of data streaming APIs
## 
## This example demonstrates the use of different data streamers:
## - CSVFileStreamer: Read data from CSV files
## - YFHistory: Fetch data from Yahoo Finance
## - CBHistory: Fetch data from Coinbase (crypto)

import ../src/tzutrader/[core, data]
import std/[times, strutils, options]

echo "=========================================="
echo "tzutrader Data Streamers Demo"
echo "=========================================="
echo ""

# ============================================================================
# 1. CSV File Streamer Demo
# ============================================================================

echo "1. CSV File Streamer Demo"
echo "--------------------------"

# Generate some mock data to a CSV file
let mockData = generateMockOHLCV(
  "DEMO", 
  parse("2024-01-01", "yyyy-MM-dd").toTime().toUnix(),
  parse("2024-01-10", "yyyy-MM-dd").toTime().toUnix(),
  Int1d
)

# Write to CSV
writeCSV(mockData, "/tmp/demo_data.csv")

# Create CSV streamer
let csvStream = newCSVFileStreamer("/tmp/demo_data.csv", "DEMO")
echo csvStream
echo ""

# Stream first 3 bars
var count = 0
for bar in csvStream.items():
  if count >= 3:
    break
  echo "  Bar ", count + 1, ": ", bar
  count.inc

echo "  ... (", csvStream.len - 3, " more bars)"
echo ""

# ============================================================================
# 2. Yahoo Finance History Demo
# ============================================================================

echo "2. Yahoo Finance History Demo"
echo "------------------------------"

# Create Yahoo Finance streamer
let yfStream = newYFHistory("AAPL", "2024-01-01", "2024-01-10", Int1d)
echo yfStream
echo ""

# Stream first 3 bars using next() method
yfStream.reset()
count = 0
while yfStream.hasNext() and count < 3:
  let barOpt = yfStream.next()
  if barOpt.isSome:
    echo "  Bar ", count + 1, ": ", barOpt.get
    count.inc

echo "  ... (", yfStream.len - 3, " more bars)"
echo ""

# ============================================================================
# 3. Coinbase History Demo
# ============================================================================

echo "3. Coinbase History Demo"
echo "-------------------------"
echo "  (Note: Using mock data - set COINBASE_API_KEY for real data)"
echo ""

# Create Coinbase streamer
let cbStream = newCBHistory("BTC-USD", "2024-01-01", "2024-01-10", Int1d)
echo cbStream
echo ""

# Stream first 3 bars
cbStream.reset()
count = 0
while cbStream.hasNext() and count < 3:
  let barOpt = cbStream.next()
  if barOpt.isSome:
    echo "  Bar ", count + 1, ": ", barOpt.get
    count.inc

echo "  ... (", cbStream.len - 3, " more bars)"
echo ""

# ============================================================================
# 4. Using result() method to peek without advancing
# ============================================================================

echo "4. Peek at current observation (result() method)"
echo "------------------------------------------------"

yfStream.reset()
echo "Current index: ", yfStream.index
let current = yfStream.result()
if current.isSome:
  echo "Current bar (peeking): ", current.get

echo "Current index (unchanged): ", yfStream.index
discard yfStream.next()  # Now advance
echo "After next(), index: ", yfStream.index
echo ""

# ============================================================================
# 5. Legacy API still works
# ============================================================================

echo "5. Legacy DataStream API (backward compatible)"
echo "-----------------------------------------------"

let legacyStream = newDataStream("AAPL", Int1d)
let historicalData = legacyStream.fetch(
  parse("2024-01-01", "yyyy-MM-dd").toTime().toUnix(),
  parse("2024-01-10", "yyyy-MM-dd").toTime().toUnix()
)
echo "Fetched ", historicalData.len, " bars using legacy API"
if historicalData.len > 0:
  echo "  First bar: ", historicalData[0]
  echo "  Last bar: ", historicalData[^1]

echo ""
echo "=========================================="
echo "Demo completed!"
echo "=========================================="
