## Unit tests for tzutrader/core module

import std/[unittest, tables, times, json, strutils]

include ../src/tzutrader/core

suite "Core Types Tests":

  test "Position enum values":
    check Stay == Stay
    check Buy == Buy
    check Sell == Sell
    check Stay != Buy
    check Buy != Sell

  test "OHLCV creation and access":
    let ohlcv = OHLCV(
      timestamp: 1609459200, # 2021-01-01 00:00:00
      open: 100.0,
      high: 110.0,
      low: 95.0,
      close: 105.0,
      volume: 1000000.0
    )

    check ohlcv.timestamp == 1609459200
    check ohlcv.open == 100.0
    check ohlcv.high == 110.0
    check ohlcv.low == 95.0
    check ohlcv.close == 105.0
    check ohlcv.volume == 1000000.0

  test "OHLCV validation - valid data":
    let validOhlcv = OHLCV(
      timestamp: getTime().toUnix(),
      open: 100.0,
      high: 110.0,
      low: 95.0,
      close: 105.0,
      volume: 1000000.0
    )

    check validOhlcv.isValid() == true

  test "OHLCV validation - high < low":
    let invalidOhlcv = OHLCV(
      timestamp: getTime().toUnix(),
      open: 100.0,
      high: 90.0, # High less than low - invalid
      low: 95.0,
      close: 105.0,
      volume: 1000000.0
    )

    check invalidOhlcv.isValid() == false

  test "OHLCV validation - negative prices":
    let invalidOhlcv = OHLCV(
      timestamp: getTime().toUnix(),
      open: -100.0, # Negative price - invalid
      high: 110.0,
      low: 95.0,
      close: 105.0,
      volume: 1000000.0
    )

    check invalidOhlcv.isValid() == false

  test "OHLCV typical price calculation":
    let ohlcv = OHLCV(
      timestamp: getTime().toUnix(),
      open: 100.0,
      high: 120.0,
      low: 90.0,
      close: 110.0,
      volume: 1000000.0
    )

    let typical = ohlcv.typicalPrice()
    check typical == (120.0 + 90.0 + 110.0) / 3.0

  test "OHLCV change calculation":
    let ohlcv = OHLCV(
      timestamp: getTime().toUnix(),
      open: 100.0,
      high: 110.0,
      low: 95.0,
      close: 105.0,
      volume: 1000000.0
    )

    check ohlcv.change() == 5.0
    check ohlcv.changePercent() == 5.0

  test "OHLCV true range calculation":
    let prev = OHLCV(
      timestamp: getTime().toUnix() - 86400,
      open: 100.0,
      high: 110.0,
      low: 95.0,
      close: 105.0,
      volume: 1000000.0
    )

    let curr = OHLCV(
      timestamp: getTime().toUnix(),
      open: 106.0,
      high: 115.0,
      low: 100.0,
      close: 110.0,
      volume: 1000000.0
    )

    let tr = trueRange(curr, prev)
    # TR = max(H-L, |H-PC|, |L-PC|)
    # TR = max(115-100, |115-105|, |100-105|) = max(15, 10, 5) = 15
    check tr == 15.0

  test "Signal creation with newSignal":
    let signal = newSignal(Buy, "AAPL", 150.0, "RSI oversold")

    check signal.position == Buy
    check signal.symbol == "AAPL"
    check signal.price == 150.0
    check signal.reason == "RSI oversold"
    check signal.timestamp > 0

  test "Signal creation without reason":
    let signal = newSignal(Sell, "MSFT", 300.0)

    check signal.position == Sell
    check signal.symbol == "MSFT"
    check signal.price == 300.0
    check signal.reason == ""

  test "StrategyConfig creation":
    var params = initTable[string, float64]()
    params["period"] = 14.0
    params["oversold"] = 30.0
    params["overbought"] = 70.0

    let config = newStrategyConfig("RSI Strategy", params)

    check config.name == "RSI Strategy"
    check config.params["period"] == 14.0
    check config.params["oversold"] == 30.0
    check config.params["overbought"] == 70.0

  test "StrategyConfig creation without params":
    let config = newStrategyConfig("Simple Strategy")

    check config.name == "Simple Strategy"
    check config.params.len == 0

  test "Transaction creation":
    let tx = newTransaction("AAPL", Buy, 100.0, 150.0, 1.0)

    check tx.symbol == "AAPL"
    check tx.action == Buy
    check tx.quantity == 100.0
    check tx.price == 150.0
    check tx.commission == 1.0
    check tx.timestamp > 0

  test "OHLCV string representation":
    let ohlcv = OHLCV(
      timestamp: 1609459200, # 2021-01-01 00:00:00 UTC
      open: 100.0,
      high: 110.0,
      low: 95.0,
      close: 105.0,
      volume: 1000000.0
    )

    let str = $ohlcv
    check "OHLCV" in str
    check "100.0" in str
    check "110.0" in str

  test "Signal string representation":
    let signal = Signal(
      position: Buy,
      symbol: "AAPL",
      timestamp: getTime().toUnix(),
      price: 150.0,
      reason: "Test signal"
    )

    let str = $signal
    check "Signal" in str
    check "Buy" in str
    check "AAPL" in str
    check "150.0" in str
    check "Test signal" in str

  test "Transaction string representation":
    let tx = Transaction(
      timestamp: getTime().toUnix(),
      symbol: "MSFT",
      action: Sell,
      quantity: 50.0,
      price: 300.0,
      commission: 2.0
    )

    let str = $tx
    check "Transaction" in str
    check "Sell" in str
    check "MSFT" in str
    check "50.0" in str
    check "300.0" in str

suite "JSON Serialization Tests":

  test "OHLCV to JSON":
    let ohlcv = OHLCV(
      timestamp: 1609459200,
      open: 100.0,
      high: 110.0,
      low: 95.0,
      close: 105.0,
      volume: 1000000.0
    )

    let json = ohlcv.toJson()
    check json["timestamp"].getInt() == 1609459200
    check json["open"].getFloat() == 100.0
    check json["high"].getFloat() == 110.0
    check json["low"].getFloat() == 95.0
    check json["close"].getFloat() == 105.0
    check json["volume"].getFloat() == 1000000.0

  test "OHLCV from JSON":
    let jsonStr = """
    {
      "timestamp": 1609459200,
      "open": 100.0,
      "high": 110.0,
      "low": 95.0,
      "close": 105.0,
      "volume": 1000000.0
    }
    """

    let json = parseJson(jsonStr)
    let ohlcv = fromJson(json, OHLCV)

    check ohlcv.timestamp == 1609459200
    check ohlcv.open == 100.0
    check ohlcv.high == 110.0
    check ohlcv.low == 95.0
    check ohlcv.close == 105.0
    check ohlcv.volume == 1000000.0

  test "Signal to JSON":
    let signal = Signal(
      position: Buy,
      symbol: "AAPL",
      timestamp: 1609459200,
      price: 150.0,
      reason: "Test"
    )

    let json = signal.toJson()
    check json["position"].getStr() == "Buy"
    check json["symbol"].getStr() == "AAPL"
    check json["timestamp"].getInt() == 1609459200
    check json["price"].getFloat() == 150.0
    check json["reason"].getStr() == "Test"

  test "Signal from JSON":
    let jsonStr = """
    {
      "position": "Sell",
      "symbol": "MSFT",
      "timestamp": 1609459200,
      "price": 300.0,
      "reason": "Overbought"
    }
    """

    let json = parseJson(jsonStr)
    let signal = fromJson(json, Signal)

    check signal.position == Sell
    check signal.symbol == "MSFT"
    check signal.timestamp == 1609459200
    check signal.price == 300.0
    check signal.reason == "Overbought"

  test "Transaction to JSON":
    let tx = Transaction(
      timestamp: 1609459200,
      symbol: "GOOGL",
      action: Buy,
      quantity: 10.0,
      price: 2000.0,
      commission: 5.0
    )

    let json = tx.toJson()
    check json["timestamp"].getInt() == 1609459200
    check json["symbol"].getStr() == "GOOGL"
    check json["action"].getStr() == "Buy"
    check json["quantity"].getFloat() == 10.0
    check json["price"].getFloat() == 2000.0
    check json["commission"].getFloat() == 5.0

  test "StrategyConfig to JSON":
    var params = initTable[string, float64]()
    params["period"] = 14.0
    params["threshold"] = 0.5

    let config = StrategyConfig(name: "Test Strategy", params: params)
    let json = config.toJson()

    check json["name"].getStr() == "Test Strategy"
    check json["params"]["period"].getFloat() == 14.0
    check json["params"]["threshold"].getFloat() == 0.5

when isMainModule:
  echo "Running core types tests..."
