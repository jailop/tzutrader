## Unit tests for tzutrader/data module

import std/[unittest, times, tables, sequtils, strutils, os]

include ../src/tzutrader/core
include ../src/tzutrader/data

suite "Interval Tests":
  
  test "Interval string representation":
    check $Int1m == "1m"
    check $Int1d == "1d"
    check $Int1wk == "1wk"
  
  test "Interval to seconds conversion":
    check Int1m.toSeconds() == 60
    check Int5m.toSeconds() == 300
    check Int15m.toSeconds() == 900
    check Int30m.toSeconds() == 1800
    check Int1h.toSeconds() == 3600
    check Int1d.toSeconds() == 86400
    check Int1wk.toSeconds() == 604800
    check Int1mo.toSeconds() == 2592000
  
  test "Interval max history":
    check Int1m.maxHistory() == 7 * 86400
    check Int5m.maxHistory() == 60 * 86400
    check Int1h.maxHistory() == 730 * 86400
    check Int1d.maxHistory() == 0  # Unlimited
    check Int1wk.maxHistory() == 0  # Unlimited

suite "DataStream Tests":
  
  test "DataStream creation":
    let ds = newDataStream("AAPL", Int1d)
    
    check ds.symbol == "AAPL"
    check ds.interval == Int1d
    check ds.cache.len == 0
    check ds.useCache == true
  
  test "DataStream creation without cache":
    let ds = newDataStream("MSFT", Int1h, useCache = false)
    
    check ds.symbol == "MSFT"
    check ds.interval == Int1h
    check ds.useCache == false
  
  test "DataStream string representation":
    let ds = newDataStream("GOOGL", Int1d)
    let str = $ds
    
    check "DataStream" in str
    check "GOOGL" in str
    check "1d" in str
  
  test "Clear cache":
    var ds = newDataStream("AAPL", Int1d)
    ds.cache.add(OHLCV(
      timestamp: getTime().toUnix(),
      open: 100.0, high: 110.0, low: 95.0, close: 105.0, volume: 1000000.0
    ))
    
    check ds.cache.len == 1
    ds.clearCache()
    check ds.cache.len == 0
    check ds.cacheStart == 0
    check ds.cacheEnd == 0

suite "Cache Management Tests":
  
  test "Cache detection - empty cache":
    let ds = newDataStream("AAPL", Int1d)
    let now = getTime().toUnix()
    
    check ds.isCached(now - 86400, now) == false
  
  test "Add to cache and check":
    var ds = newDataStream("AAPL", Int1d)
    let now = getTime().toUnix()
    
    let data = @[
      OHLCV(timestamp: now - 86400, open: 100.0, high: 105.0, low: 99.0, close: 103.0, volume: 1000000.0),
      OHLCV(timestamp: now, open: 103.0, high: 108.0, low: 102.0, close: 106.0, volume: 1100000.0)
    ]
    
    ds.addToCache(data)
    
    check ds.cache.len == 2
    check ds.cacheStart == now - 86400
    check ds.cacheEnd == now
  
  test "Get cached data in range":
    var ds = newDataStream("AAPL", Int1d)
    let now = getTime().toUnix()
    
    let data = @[
      OHLCV(timestamp: now - 2 * 86400, open: 98.0, high: 102.0, low: 97.0, close: 100.0, volume: 900000.0),
      OHLCV(timestamp: now - 86400, open: 100.0, high: 105.0, low: 99.0, close: 103.0, volume: 1000000.0),
      OHLCV(timestamp: now, open: 103.0, high: 108.0, low: 102.0, close: 106.0, volume: 1100000.0)
    ]
    
    ds.addToCache(data)
    
    let cached = ds.getCached(now - 86400, now)
    check cached.len == 2
    check cached[0].timestamp == now - 86400
    check cached[1].timestamp == now
  
  test "Cache with useCache=false":
    var ds = newDataStream("AAPL", Int1d, useCache = false)
    let now = getTime().toUnix()
    
    let data = @[
      OHLCV(timestamp: now, open: 100.0, high: 105.0, low: 99.0, close: 103.0, volume: 1000000.0)
    ]
    
    ds.addToCache(data)
    check ds.cache.len == 0  # Should not cache when useCache=false

suite "Mock Data Generation Tests":
  
  test "Generate mock OHLCV data":
    let startTime = getTime().toUnix() - 86400 * 7  # 7 days ago
    let endTime = getTime().toUnix()
    
    let data = generateMockOHLCV("AAPL", startTime, endTime, Int1d, 
                                 startPrice = 150.0, volatility = 0.02)
    
    check data.len > 0
    check data[0].timestamp >= startTime
    check data[^1].timestamp <= endTime
    
    # Check all bars are valid
    for bar in data:
      check bar.isValid()
      check bar.high >= bar.low
      check bar.high >= bar.open
      check bar.high >= bar.close
      check bar.low <= bar.open
      check bar.low <= bar.close
  
  test "Generate mock OHLCV with different intervals":
    let startTime = getTime().toUnix() - 3600  # 1 hour ago
    let endTime = getTime().toUnix()
    
    let data1m = generateMockOHLCV("AAPL", startTime, endTime, Int1m)
    let data5m = generateMockOHLCV("AAPL", startTime, endTime, Int5m)
    
    check data1m.len > data5m.len  # 1m should have more bars than 5m
  
  test "Generate mock quote":
    let quote = generateMockQuote("AAPL", price = 150.0)
    
    check quote.symbol == "AAPL"
    check quote.regularMarketPrice > 0
    check quote.regularMarketVolume > 0
    check quote.regularMarketDayHigh >= quote.regularMarketDayLow
    check quote.timestamp > 0
  
  test "Mock quote has reasonable values":
    let quote = generateMockQuote("MSFT", price = 300.0)
    
    # Price should be within reasonable range of 300
    check quote.regularMarketPrice > 280.0
    check quote.regularMarketPrice < 320.0
    
    # High/Low should bracket the price
    check quote.regularMarketDayHigh >= quote.regularMarketPrice or
          quote.regularMarketDayLow <= quote.regularMarketPrice

suite "Data Fetching Tests":
  
  test "Fetch historical data":
    let ds = newDataStream("AAPL", Int1d)
    let endTime = getTime().toUnix()
    let startTime = endTime - 86400 * 7  # Last 7 days
    
    let data = ds.fetch(startTime, endTime)
    
    check data.len > 0
    check data[0].timestamp >= startTime
    check data[^1].timestamp <= endTime
  
  test "Fetch with days parameter":
    let ds = newDataStream("AAPL", Int1d)
    let data = ds.fetch(days = 7)
    
    check data.len > 0
  
  test "Fetch uses cache on second call":
    var ds = newDataStream("AAPL", Int1d)
    let endTime = getTime().toUnix()
    let startTime = endTime - 86400 * 7
    
    # First fetch - should populate cache
    let data1 = ds.fetch(startTime, endTime)
    check ds.cache.len > 0
    
    # Second fetch - should use cache
    let data2 = ds.fetch(startTime, endTime)
    check data1.len == data2.len
  
  test "Latest bar":
    let ds = newDataStream("AAPL", Int1d)
    let latest = ds.latest()
    
    check latest.timestamp > 0
    check latest.close > 0
  
  test "Get quote for symbol":
    let quote = getQuote("AAPL")
    
    check quote.symbol == "AAPL"
    check quote.regularMarketPrice > 0
    check quote.timestamp > 0

suite "Batch Operations Tests":
  
  test "Fetch multiple symbols":
    let symbols = @["AAPL", "MSFT", "GOOGL"]
    let endTime = getTime().toUnix()
    let startTime = endTime - 86400 * 7
    
    let data = fetchMultiple(symbols, startTime, endTime, Int1d)
    
    check data.len == 3
    check "AAPL" in data
    check "MSFT" in data
    check "GOOGL" in data
    check data["AAPL"].len > 0
  
  test "Get quotes for multiple symbols":
    let symbols = @["AAPL", "MSFT"]
    let quotes = getQuotes(symbols)
    
    check quotes.len == 2
    check "AAPL" in quotes
    check "MSFT" in quotes
    check quotes["AAPL"].regularMarketPrice > 0
    check quotes["MSFT"].regularMarketPrice > 0

suite "Iterator Tests":
  
  test "Stream iterator":
    let ds = newDataStream("AAPL", Int1d)
    let endTime = getTime().toUnix()
    let startTime = endTime - 86400 * 7
    
    var count = 0
    for bar in ds.stream(startTime, endTime):
      check bar.isValid()
      count += 1
    
    check count > 0
  
  test "Stream maintains order":
    let ds = newDataStream("AAPL", Int1d)
    let endTime = getTime().toUnix()
    let startTime = endTime - 86400 * 7
    
    var prevTimestamp: int64 = 0
    for bar in ds.stream(startTime, endTime):
      if prevTimestamp > 0:
        check bar.timestamp >= prevTimestamp
      prevTimestamp = bar.timestamp

suite "Quote String Representation Tests":
  
  test "Quote to string positive change":
    let quote = Quote(
      symbol: "AAPL",
      timestamp: getTime().toUnix(),
      regularMarketPrice: 150.0,
      regularMarketChange: 5.0,
      regularMarketChangePercent: 3.45,
      regularMarketVolume: 1000000.0,
      regularMarketOpen: 145.0,
      regularMarketDayHigh: 151.0,
      regularMarketDayLow: 144.0,
      regularMarketPreviousClose: 145.0
    )
    
    let str = $quote
    check "Quote" in str
    check "AAPL" in str
    check "$150" in str
    check "+5" in str
    check "+3.45%" in str
  
  test "Quote to string negative change":
    let quote = Quote(
      symbol: "MSFT",
      timestamp: getTime().toUnix(),
      regularMarketPrice: 295.0,
      regularMarketChange: -5.0,
      regularMarketChangePercent: -1.67,
      regularMarketVolume: 2000000.0,
      regularMarketOpen: 300.0,
      regularMarketDayHigh: 302.0,
      regularMarketDayLow: 294.0,
      regularMarketPreviousClose: 300.0
    )
    
    let str = $quote
    check "MSFT" in str
    check "$295" in str
    check "-5" in str
    check "-1.67%" in str

suite "CSV File I/O Tests":
  
  test "Write and read CSV file":
    let testData = @[
      OHLCV(timestamp: 1000, open: 100.0, high: 105.0, low: 95.0, close: 102.0, volume: 1000000.0),
      OHLCV(timestamp: 2000, open: 102.0, high: 107.0, low: 100.0, close: 104.0, volume: 1500000.0),
      OHLCV(timestamp: 3000, open: 104.0, high: 109.0, low: 102.0, close: 106.0, volume: 2000000.0)
    ]
    
    let filename = "test_temp.csv"
    writeCSV(testData, filename)
    let readData = readCSV(filename)
    
    check readData.len == 3
    check readData[0].timestamp == 1000
    check readData[0].close == 102.0
    check readData[2].volume == 2000000.0
    
    # Cleanup
    removeFile(filename)
  
  test "CSV with no header":
    let testData = @[
      OHLCV(timestamp: 1000, open: 100.0, high: 105.0, low: 95.0, close: 102.0, volume: 1000000.0)
    ]
    
    let filename = "test_noheader.csv"
    writeCSV(testData, filename, includeHeader = false)
    let readData = readCSV(filename, hasHeader = false)
    
    check readData.len == 1
    check readData[0].close == 102.0
    
    removeFile(filename)
  
  test "CSV error handling - invalid format":
    let filename = "test_invalid.csv"
    var file = open(filename, fmWrite)
    file.writeLine("timestamp,open,high,low,close,volume")
    file.writeLine("invalid,data,here")
    file.close()
    
    expect(DataError):
      discard readCSV(filename)
    
    removeFile(filename)

suite "CSV DataStream Tests":
  
  test "Create CSV data stream":
    # Use one of the generated CSV files
    let csvStream = newCSVDataStream("data/TEST.csv")
    
    check csvStream.len() > 0
    check csvStream.symbol == "TEST"
    check csvStream.hasNext()
  
  test "CSV stream iteration":
    let csvStream = newCSVDataStream("data/TEST.csv")
    let originalLen = csvStream.len()
    
    var count = 0
    csvStream.reset()
    while csvStream.hasNext():
      discard csvStream.next()
      count.inc
    
    check count == originalLen
    check not csvStream.hasNext()
  
  test "CSV stream reset":
    let csvStream = newCSVDataStream("data/TEST.csv")
    
    # Advance a few bars
    discard csvStream.next()
    discard csvStream.next()
    check csvStream.index == 2
    
    # Reset
    csvStream.reset()
    check csvStream.index == 0
    check csvStream.hasNext()
  
  test "CSV stream peek":
    let csvStream = newCSVDataStream("data/TEST.csv")
    csvStream.reset()
    
    let first = csvStream.peek()
    let second = csvStream.next()
    
    check first.timestamp == second.timestamp
    check first.close == second.close
  
  test "CSV stream remaining":
    let csvStream = newCSVDataStream("data/TEST.csv")
    let total = csvStream.len()
    
    csvStream.reset()
    check csvStream.remaining() == total
    
    discard csvStream.next()
    check csvStream.remaining() == total - 1
  
  test "CSV stream iterator":
    let csvStream = newCSVDataStream("data/TEST.csv")
    var count = 0
    
    for bar in csvStream.items():
      count.inc
      check bar.timestamp > 0
    
    check count == csvStream.len()
  
  test "CSV stream string representation":
    let csvStream = newCSVDataStream("data/TEST.csv")
    let str = $csvStream
    
    check "TEST" in str
    check "bars" in str

when isMainModule:
  echo "Running data module tests..."
