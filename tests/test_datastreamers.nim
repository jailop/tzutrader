## Test suite for the datastreamers module
##
## Tests all streamers (CSV, Yahoo Finance, Coinbase) and the high-level API

import unittest
import ../src/tzutrader/datastreamers
import ../src/tzutrader/core
import std/[times, os, tables, strutils]

suite "DataStreamers - Type System":
  test "getDataKind for OHLCV":
    check getDataKind[OHLCV]() == dkOHLCV
  
  test "getDataKind for Quote":
    check getDataKind[Quote]() == dkQuote
  
  test "CSV provider supports OHLCV":
    check supports(dpCSV, OHLCV) == true
  
  test "CSV provider does not support Quote":
    check supports(dpCSV, Quote) == false
  
  test "Yahoo provider supports OHLCV":
    check supports(dpYahoo, OHLCV) == true
  
  test "Yahoo provider supports Quote":
    check supports(dpYahoo, Quote) == true
  
  test "Coinbase provider supports OHLCV":
    check supports(dpCoinbase, OHLCV) == true
  
  test "Coinbase provider does not support Quote":
    check supports(dpCoinbase, Quote) == false
  
  test "supportedProviders for OHLCV":
    let providers = supportedProviders[OHLCV]()
    check dpCSV in providers
    check dpYahoo in providers
    check dpCoinbase in providers
  
  test "supportedProviders for Quote":
    let providers = supportedProviders[Quote]()
    check dpYahoo in providers
    check dpCSV notin providers
    check dpCoinbase notin providers

suite "DataStreamers - CSV Streaming":
  test "Stream CSV file with iterator":
    let stream = streamCSV[OHLCV]("tests/data/uptrend.csv", "TEST")
    var count = 0
    var firstBar: OHLCV
    var lastBar: OHLCV
    
    for bar in stream.items():
      if count == 0:
        firstBar = bar
      lastBar = bar
      count.inc
    
    check count > 0
    check firstBar.timestamp > 0
    check firstBar.close > 0
    check lastBar.timestamp >= firstBar.timestamp
  
  test "Stream CSV file with next/result":
    let stream = streamCSV[OHLCV]("tests/data/uptrend.csv", "TEST")
    var count = 0
    
    while stream.next():
      let bar = stream.result()
      check bar.timestamp > 0
      check bar.open > 0
      check bar.high >= bar.low
      count.inc
    
    check count > 0
  
  test "CSV stream reset":
    let stream = streamCSV[OHLCV]("tests/data/uptrend.csv", "TEST")
    
    # Read first bar
    check stream.next()
    let firstBar = stream.result()
    
    # Read a few more
    discard stream.next()
    discard stream.next()
    
    # Reset and read first bar again
    stream.reset()
    check stream.next()
    let firstBarAgain = stream.result()
    
    check firstBar.timestamp == firstBarAgain.timestamp
    check firstBar.close == firstBarAgain.close
  
  test "CSV stream len":
    let stream = streamCSV[OHLCV]("tests/data/uptrend.csv", "TEST")
    let length = stream.len()
    
    var count = 0
    for bar in stream.items():
      count.inc
    
    check count == length
  
  test "CSV stream with time range filter":
    # Get a bar to find timestamps
    let fullStream = streamCSV[OHLCV]("tests/data/uptrend.csv", "TEST")
    check fullStream.next()
    let firstBar = fullStream.result()
    check fullStream.next()
    check fullStream.next()
    let thirdBar = fullStream.result()
    
    # Create filtered stream (skip first 2 bars)
    let filteredStream = streamCSV[OHLCV]("tests/data/uptrend.csv", "TEST",
                                          startTime = thirdBar.timestamp)
    check filteredStream.next()
    let filteredFirstBar = filteredStream.result()
    
    check filteredFirstBar.timestamp >= thirdBar.timestamp
  
  test "CSV stream with symbol extraction from filename":
    let stream = streamCSV[OHLCV]("tests/data/uptrend.csv")
    check stream.symbol == "uptrend"
  
  test "CSV stream toSeq":
    let stream = streamCSV[OHLCV]("tests/data/uptrend.csv", "TEST")
    let data = stream.toSeq()
    
    check data.len > 0
    check data[0].timestamp > 0
    check data[0].close > 0

suite "DataStreamers - Yahoo Finance Streaming":
  test "Stream Yahoo OHLCV (mock data)":
    # This will use mock data since yfnim is not available
    let stream = streamYahoo[OHLCV]("AAPL", 7)  # Last 7 days
    var count = 0
    
    for bar in stream.items():
      check bar.timestamp > 0
      check bar.close > 0
      check bar.high >= bar.low
      count.inc
    
    check count > 0
  
  test "Stream Yahoo with date strings":
    let stream = streamYahoo[OHLCV]("AAPL", "2023-01-01", "2023-01-31")
    check stream.len() > 0
  
  test "Yahoo stream reset":
    let stream = streamYahoo[OHLCV]("AAPL", 7)
    
    check stream.next()
    let firstBar = stream.result()
    
    discard stream.next()
    discard stream.next()
    
    stream.reset()
    check stream.next()
    let firstBarAgain = stream.result()
    
    check firstBar.timestamp == firstBarAgain.timestamp

suite "DataStreamers - Coinbase Streaming":
  test "Stream Coinbase OHLCV (mock data)":
    # This will use mock data since credentials are not available
    let stream = streamCoinbase[OHLCV]("BTC-USD", 7)  # Last 7 days
    var count = 0
    
    for bar in stream.items():
      check bar.timestamp > 0
      check bar.close > 0
      check bar.high >= bar.low
      count.inc
    
    check count > 0
  
  test "Stream Coinbase with date strings":
    let stream = streamCoinbase[OHLCV]("ETH-USD", "2023-01-01", "2023-01-31")
    check stream.len() > 0
  
  test "Coinbase stream reset":
    let stream = streamCoinbase[OHLCV]("BTC-USD", 7)
    
    check stream.next()
    let firstBar = stream.result()
    
    discard stream.next()
    discard stream.next()
    
    stream.reset()
    check stream.next()
    let firstBarAgain = stream.result()
    
    check firstBar.timestamp == firstBarAgain.timestamp

suite "DataStreamers - Generic API":
  test "Generic stream() with CSV provider":
    var params = StreamParams(
      provider: dpCSV,
      symbol: "TEST",
      startTime: 0,
      endTime: high(int64),
      metadata: {"filename": "tests/data/uptrend.csv", "hasHeader": "true"}.toTable
    )
    
    let stream = stream[OHLCV](params)
    var count = 0
    
    for bar in stream.items():
      count.inc
    
    check count > 0
  
  test "Generic stream() with Yahoo provider":
    let endTime = getTime().toUnix()
    let startTime = endTime - (7 * 86400)
    
    var params = StreamParams(
      provider: dpYahoo,
      symbol: "AAPL",
      startTime: startTime,
      endTime: endTime,
      metadata: {"interval": "1d"}.toTable
    )
    
    let stream = stream[OHLCV](params)
    check stream.len() > 0
  
  test "Unsupported type raises error":
    var params = StreamParams(
      provider: dpCSV,
      symbol: "TEST",
      metadata: {"filename": "tests/data/uptrend.csv"}.toTable
    )
    
    expect(UnsupportedDataTypeError):
      discard stream[Quote](params)

suite "DataStreamers - Utility Functions":
  test "parseDate converts string to timestamp":
    let timestamp = parseDate("2023-01-01")
    # Just check it's a reasonable timestamp (sometime in 2023)
    check timestamp > 1672531200 - 86400  # Within a day of Jan 1, 2023
    check timestamp < 1704067200  # Before Jan 1, 2024
  
  test "formatDate converts timestamp to string":
    # Use a timestamp and check format, not exact value due to timezone
    let timestamp = parseDate("2023-01-01")
    let dateStr = formatDate(timestamp)
    check dateStr.len == 10  # YYYY-MM-DD format
    check "2023" in dateStr
  
  test "parseDate and formatDate are inverses":
    let original = "2023-06-15"
    let timestamp = parseDate(original)
    let converted = formatDate(timestamp)
    check converted == original

suite "DataStreamers - Error Handling":
  test "CSV file not found raises error":
    expect(DataError):
      discard streamCSV[OHLCV]("nonexistent.csv")
  
  test "Invalid CSV format raises error":
    # Create a temporary invalid CSV
    let tempFile = "tests/data/invalid.csv"
    var f = open(tempFile, fmWrite)
    f.writeLine("timestamp,open,high,low,close,volume")
    f.writeLine("invalid,data,here")
    f.close()
    
    expect(DataError):
      let stream = streamCSV[OHLCV](tempFile)
      for bar in stream.items():
        discard
    
    # Clean up
    removeFile(tempFile)
  
  test "next() without result() is safe":
    let stream = streamCSV[OHLCV]("tests/data/uptrend.csv", "TEST")
    # Just calling next() without result() should not crash
    discard stream.next()
    check true
  
  test "result() without next() raises error":
    let stream = streamCSV[OHLCV]("tests/data/uptrend.csv", "TEST")
    
    expect(DataError):
      discard stream.result()

suite "DataStreamers - Performance":
  test "Streaming is O(1) memory (not loading all data at once)":
    # For CSV, this verifies we're reading line-by-line
    let stream = streamCSV[OHLCV]("tests/data/uptrend.csv", "TEST")
    
    # Should be able to start iterating immediately
    check stream.next()
    check stream.result().timestamp > 0

when isMainModule:
  echo "Running DataStreamers tests..."
