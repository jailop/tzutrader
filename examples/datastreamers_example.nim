## Example: Using the DataStreamers Module
##
## This example demonstrates how to use the new generic data streaming API

import ../src/tzutrader/datastreamers

echo "=== DataStreamers Example ==="
echo ""

# Example 1: Stream OHLCV data from CSV file
echo "1. Streaming from CSV file:"
echo "----------------------------"
let csvStream = streamCSV[OHLCV]("tests/data/uptrend.csv", "AAPL")
var count = 0
for bar in csvStream.items():
  if count < 3:  # Show first 3 bars
    echo "  Bar ", count + 1, ": timestamp=", bar.timestamp, 
         ", close=$", bar.close, ", volume=", bar.volume
  count.inc
echo "  Total bars: ", count
echo ""

# Example 2: Stream OHLCV data from Yahoo Finance (mock data)
echo "2. Streaming from Yahoo Finance (last 7 days, mock data):"
echo "-----------------------------------------------------------"
let yahooStream = streamYahoo[OHLCV]("MSFT", 7)
count = 0
for bar in yahooStream.items():
  if count < 3:  # Show first 3 bars
    echo "  Bar ", count + 1, ": timestamp=", bar.timestamp, 
         ", close=$", bar.close, ", volume=", bar.volume
  count.inc
echo "  Total bars: ", count
echo ""

# Example 3: Stream with date strings
echo "3. Streaming with date range:"
echo "-----------------------------"
let dateStream = streamYahoo[OHLCV]("AAPL", "2023-01-01", "2023-01-31")
echo "  Streaming AAPL data for January 2023"
echo "  Total bars: ", dateStream.len()
echo ""

# Example 4: Stream from Coinbase (mock data)
echo "4. Streaming cryptocurrency data from Coinbase (mock):"
echo "-------------------------------------------------------"
let coinbaseStream = streamCoinbase[OHLCV]("BTC-USD", 7)
count = 0
for bar in coinbaseStream.items():
  if count < 3:  # Show first 3 bars
    echo "  Candle ", count + 1, ": timestamp=", bar.timestamp, 
         ", close=$", bar.close, ", volume=", bar.volume
  count.inc
echo "  Total candles: ", count
echo ""

# Example 5: Query provider capabilities
echo "5. Query provider capabilities:"
echo "-------------------------------"
echo "  Providers supporting OHLCV: ", supportedProviders[OHLCV]()
echo "  Providers supporting Quote: ", supportedProviders[Quote]()
echo "  CSV supports OHLCV: ", supports(dpCSV, OHLCV)
echo "  CSV supports Quote: ", supports(dpCSV, Quote)
echo "  Yahoo supports Quote: ", supports(dpYahoo, Quote)
echo ""

# Example 6: Use toSeq for random access (not recommended for large datasets!)
echo "6. Convert stream to sequence (for small datasets only):"
echo "---------------------------------------------------------"
let smallStream = streamCSV[OHLCV]("tests/data/uptrend.csv")
let data = smallStream.toSeq()
echo "  First bar close: $", data[0].close
echo "  Last bar close: $", data[^1].close
echo "  Total: ", data.len, " bars"
echo ""

echo "=== Example Complete ==="
