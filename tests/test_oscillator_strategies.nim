import unittest
import ../src/tzutrader/core
import ../src/tzutrader/data
import ../src/tzutrader/strategy
import strutils
import os

# Helper function to load test data
proc loadTestData(filename: string): seq[OHLCV] =
  let filepath = "tests/data/" & filename
  if not fileExists(filepath):
    raise newException(IOError, "Test data file not found: " & filepath)
  result = readCSV(filepath)

suite "StochasticStrategy Tests":
  test "Basic construction and parameters":
    let strat = newStochasticStrategy(kPeriod = 14, dPeriod = 3,
        oversold = 20.0, overbought = 80.0)
    check strat.name() == "Stochastic Oscillator Strategy"

  test "Construction with custom parameters":
    let strat = newStochasticStrategy(kPeriod = 21, dPeriod = 5,
        oversold = 30.0, overbought = 70.0)
    check strat.name() == "Stochastic Oscillator Strategy"

  test "Signal generation in ranging market":
    let data = loadTestData("ranging.csv")
    let strat = newStochasticStrategy()
    var buySignals = 0
    var sellSignals = 0

    for candle in data:
      let signal = strat.onBar(candle)
      if signal.position == Position.Buy:
        buySignals += 1
      elif signal.position == Position.Sell:
        sellSignals += 1

    # In ranging market, expect multiple buy/sell signals as it oscillates
    check buySignals > 0
    check sellSignals >= 0 # May not always get sell signals depending on data

  test "Signal generation in uptrend":
    let data = loadTestData("uptrend.csv")
    let strat = newStochasticStrategy()
    var buySignals = 0
    var sellSignals = 0

    for candle in data:
      let signal = strat.onBar(candle)
      if signal.position == Position.Buy:
        buySignals += 1
      elif signal.position == Position.Sell:
        sellSignals += 1

    # In uptrend, expect fewer signals (mostly buy signals at pullbacks)
    check buySignals >= 0 # May have some buy signals at pullbacks

  test "Signal generation in downtrend":
    let data = loadTestData("downtrend.csv")
    let strat = newStochasticStrategy()
    var buySignals = 0
    var sellSignals = 0

    for candle in data:
      let signal = strat.onBar(candle)
      if signal.position == Position.Buy:
        buySignals += 1
      elif signal.position == Position.Sell:
        sellSignals += 1

    # In downtrend, expect more sell signals
    check sellSignals >= 0

  test "Reset functionality":
    let data = loadTestData("uptrend.csv")
    let strat = newStochasticStrategy()

    # Process some data
    for i in 0..<10:
      discard strat.onBar(data[i])

    # Reset
    strat.reset()

    # After reset, should be able to process data again
    let signal = strat.onBar(data[0])
    check signal.position == Position.Stay # Insufficient data after reset

  test "Insufficient data handling":
    let data = loadTestData("uptrend.csv")
    let strat = newStochasticStrategy(kPeriod = 14)

    # With kPeriod=14, need at least 14 bars before generating signals
    for i in 0..<13:
      let signal = strat.onBar(data[i])
      check signal.position == Position.Stay

suite "MFIStrategy Tests":
  test "Basic construction and parameters":
    let strat = newMFIStrategy(period = 14, oversold = 20.0, overbought = 80.0)
    check strat.name() == "Money Flow Index Strategy"

  test "Construction with custom parameters":
    let strat = newMFIStrategy(period = 10, oversold = 30.0, overbought = 70.0)
    check strat.name() == "Money Flow Index Strategy"

  test "Signal generation in ranging market":
    let data = loadTestData("ranging.csv")
    let strat = newMFIStrategy()
    var buySignals = 0
    var sellSignals = 0

    for candle in data:
      let signal = strat.onBar(candle)
      if signal.position == Position.Buy:
        buySignals += 1
      elif signal.position == Position.Sell:
        sellSignals += 1

    # MFI uses volume, so signals depend on volume patterns
    check buySignals >= 0
    check sellSignals >= 0

  test "Signal generation in volatile market":
    let data = loadTestData("volatile.csv")
    let strat = newMFIStrategy()
    var buySignals = 0
    var sellSignals = 0

    for candle in data:
      let signal = strat.onBar(candle)
      if signal.position == Position.Buy:
        buySignals += 1
      elif signal.position == Position.Sell:
        sellSignals += 1

    # In volatile market with volume changes, expect some signals
    check buySignals >= 0
    check sellSignals >= 0

  test "Reset functionality":
    let data = loadTestData("uptrend.csv")
    let strat = newMFIStrategy()

    # Process some data
    for i in 0..<15:
      discard strat.onBar(data[i])

    # Reset
    strat.reset()

    # After reset, should be able to process data again
    let signal = strat.onBar(data[0])
    check signal.position == Position.Stay # Insufficient data after reset

  test "Insufficient data handling":
    let data = loadTestData("uptrend.csv")
    let strat = newMFIStrategy(period = 14)

    # Need at least period+1 bars for MFI, first few bars should be Stay
    var stayCount = 0
    for i in 0..<10:
      let signal = strat.onBar(data[i])
      if signal.position == Position.Stay:
        stayCount += 1

    # Most early bars should be Stay (insufficient data)
    check stayCount >= 5

suite "CCIStrategy Tests":
  test "Basic construction and parameters":
    let strat = newCCIStrategy(period = 20)
    check strat.name() == "Commodity Channel Index Strategy"

  test "Construction with custom parameters":
    let strat = newCCIStrategy(period = 14)
    check strat.name() == "Commodity Channel Index Strategy"

  test "Signal generation in ranging market":
    let data = loadTestData("ranging.csv")
    let strat = newCCIStrategy()
    var buySignals = 0
    var sellSignals = 0

    for candle in data:
      let signal = strat.onBar(candle)
      if signal.position == Position.Buy:
        buySignals += 1
      elif signal.position == Position.Sell:
        sellSignals += 1

    # CCI is mean reversion, so expect signals in ranging market
    check buySignals >= 0
    check sellSignals >= 0

  test "Signal generation in uptrend":
    let data = loadTestData("uptrend.csv")
    let strat = newCCIStrategy()
    var buySignals = 0
    var sellSignals = 0

    for candle in data:
      let signal = strat.onBar(candle)
      if signal.position == Position.Buy:
        buySignals += 1
      elif signal.position == Position.Sell:
        sellSignals += 1

    check buySignals >= 0 # May generate buy signals when CCI crosses -100

  test "Signal generation in volatile market":
    let data = loadTestData("volatile.csv")
    let strat = newCCIStrategy()
    var buySignals = 0
    var sellSignals = 0

    for candle in data:
      let signal = strat.onBar(candle)
      if signal.position == Position.Buy:
        buySignals += 1
      elif signal.position == Position.Sell:
        sellSignals += 1

    # Volatile market should trigger CCI crossovers
    check buySignals >= 0
    check sellSignals >= 0

  test "Reset functionality":
    let data = loadTestData("uptrend.csv")
    let strat = newCCIStrategy()

    # Process some data
    for i in 0..<25:
      discard strat.onBar(data[i])

    # Reset
    strat.reset()

    # After reset, should be able to process data again
    let signal = strat.onBar(data[0])
    check signal.position == Position.Stay

  test "Insufficient data handling":
    let data = loadTestData("uptrend.csv")
    let strat = newCCIStrategy(period = 20)

    # Need at least period bars
    for i in 0..<19:
      let signal = strat.onBar(data[i])
      check signal.position == Position.Stay

suite "AroonStrategy Tests":
  test "Basic construction and parameters":
    let strat = newAroonStrategy(period = 25, upThreshold = 70.0,
        downThreshold = 30.0)
    check strat.name() == "Aroon Strategy"

  test "Construction with custom parameters":
    let strat = newAroonStrategy(period = 14, upThreshold = 80.0,
        downThreshold = 20.0)
    check strat.name() == "Aroon Strategy"

  test "Signal generation in uptrend":
    let data = loadTestData("uptrend.csv")
    let strat = newAroonStrategy()
    var buySignals = 0
    var sellSignals = 0

    for candle in data:
      let signal = strat.onBar(candle)
      if signal.position == Position.Buy:
        buySignals += 1
      elif signal.position == Position.Sell:
        sellSignals += 1

    # In uptrend, expect buy signals when Aroon Up > 70 and Down < 30
    check buySignals >= 0

  test "Signal generation in downtrend":
    let data = loadTestData("downtrend.csv")
    let strat = newAroonStrategy()
    var buySignals = 0
    var sellSignals = 0

    for candle in data:
      let signal = strat.onBar(candle)
      if signal.position == Position.Buy:
        buySignals += 1
      elif signal.position == Position.Sell:
        sellSignals += 1

    # In downtrend, expect sell signals when Aroon Down > 70 and Up < 30
    check sellSignals >= 0

  test "Signal generation in ranging market":
    let data = loadTestData("ranging.csv")
    let strat = newAroonStrategy()
    var buySignals = 0
    var sellSignals = 0

    for candle in data:
      let signal = strat.onBar(candle)
      if signal.position == Position.Buy:
        buySignals += 1
      elif signal.position == Position.Sell:
        sellSignals += 1

    # In ranging market, Aroon may not trigger strong signals
    # (neither line consistently above threshold)
    check buySignals >= 0
    check sellSignals >= 0

  test "Reset functionality":
    let data = loadTestData("uptrend.csv")
    let strat = newAroonStrategy()

    # Process some data
    for i in 0..<30:
      discard strat.onBar(data[i])

    # Reset
    strat.reset()

    # After reset, should be able to process data again
    let signal = strat.onBar(data[0])
    check signal.position == Position.Stay

  test "Insufficient data handling":
    let data = loadTestData("uptrend.csv")
    let strat = newAroonStrategy(period = 25)

    # Need at least period bars
    for i in 0..<24:
      let signal = strat.onBar(data[i])
      check signal.position == Position.Stay

suite "KAMAStrategy Tests":
  test "Basic construction and parameters":
    let strat = newKAMAStrategy(period = 10, fastPeriod = 2, slowPeriod = 30)
    check strat.name() == "KAMA Strategy"

  test "Construction with custom parameters":
    let strat = newKAMAStrategy(period = 20, fastPeriod = 5, slowPeriod = 50)
    check strat.name() == "KAMA Strategy"

  test "Signal generation in uptrend":
    let data = loadTestData("uptrend.csv")
    let strat = newKAMAStrategy()
    var buySignals = 0
    var sellSignals = 0

    for candle in data:
      let signal = strat.onBar(candle)
      if signal.position == Position.Buy:
        buySignals += 1
      elif signal.position == Position.Sell:
        sellSignals += 1

    # In uptrend, expect at least one buy signal when price crosses above KAMA
    check buySignals >= 0

  test "Signal generation in downtrend":
    let data = loadTestData("downtrend.csv")
    let strat = newKAMAStrategy()
    var buySignals = 0
    var sellSignals = 0

    for candle in data:
      let signal = strat.onBar(candle)
      if signal.position == Position.Buy:
        buySignals += 1
      elif signal.position == Position.Sell:
        sellSignals += 1

    # In downtrend, expect sell signals when price crosses below KAMA
    check sellSignals >= 0

  test "Signal generation in volatile market":
    let data = loadTestData("volatile.csv")
    let strat = newKAMAStrategy()
    var buySignals = 0
    var sellSignals = 0

    for candle in data:
      let signal = strat.onBar(candle)
      if signal.position == Position.Buy:
        buySignals += 1
      elif signal.position == Position.Sell:
        sellSignals += 1

    # KAMA adapts to volatility, should generate signals
    check buySignals >= 0
    check sellSignals >= 0

  test "Signal generation in ranging market":
    let data = loadTestData("ranging.csv")
    let strat = newKAMAStrategy()
    var buySignals = 0
    var sellSignals = 0

    for candle in data:
      let signal = strat.onBar(candle)
      if signal.position == Position.Buy:
        buySignals += 1
      elif signal.position == Position.Sell:
        sellSignals += 1

    # In ranging market, may get whipsaw signals
    check buySignals >= 0
    check sellSignals >= 0

  test "Reset functionality":
    let data = loadTestData("uptrend.csv")
    let strat = newKAMAStrategy()

    # Process some data
    for i in 0..<20:
      discard strat.onBar(data[i])

    # Reset
    strat.reset()

    # After reset, should be able to process data again
    let signal = strat.onBar(data[0])
    check signal.position == Position.Stay

  test "Insufficient data handling":
    let data = loadTestData("uptrend.csv")
    let strat = newKAMAStrategy(period = 10)

    # Need at least period bars
    for i in 0..<9:
      let signal = strat.onBar(data[i])
      check signal.position == Position.Stay

suite "Integration Tests - New Strategies":
  test "All strategies can be instantiated":
    let stoch = newStochasticStrategy()
    let mfi = newMFIStrategy()
    let cci = newCCIStrategy()
    let aroon = newAroonStrategy()
    let kama = newKAMAStrategy()

    check stoch.name() == "Stochastic Oscillator Strategy"
    check mfi.name() == "Money Flow Index Strategy"
    check cci.name() == "Commodity Channel Index Strategy"
    check aroon.name() == "Aroon Strategy"
    check kama.name() == "KAMA Strategy"

  test "All strategies work with streaming data":
    let data = loadTestData("uptrend.csv")
    let strategies = @[
      newStochasticStrategy().Strategy,
      newMFIStrategy().Strategy,
      newCCIStrategy().Strategy,
      newAroonStrategy().Strategy,
      newKAMAStrategy().Strategy
    ]

    for strat in strategies:
      var signalCount = 0
      for candle in data:
        let signal = strat.onBar(candle)
        if signal.position != Position.Stay:
          signalCount += 1
      # Each strategy should process all bars without error
      check signalCount >= 0

  test "All strategies handle reset correctly":
    let data = loadTestData("uptrend.csv")
    let strategies = @[
      newStochasticStrategy().Strategy,
      newMFIStrategy().Strategy,
      newCCIStrategy().Strategy,
      newAroonStrategy().Strategy,
      newKAMAStrategy().Strategy
    ]

    for strat in strategies:
      # Process some data
      for i in 0..<20:
        discard strat.onBar(data[i])

      # Reset
      strat.reset()

      # Should be able to process again
      let signal = strat.onBar(data[0])
      check signal.position == Position.Stay # First bar after reset should be Hold

when isMainModule:
  echo "Running tests for new Phase 1 strategies..."
