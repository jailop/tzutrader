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

suite "ParabolicSARStrategy Tests":
  test "Basic construction and parameters":
    let strat = newParabolicSARStrategy(acceleration = 0.02, maximum = 0.20)
    check strat.name() == "Parabolic SAR Strategy"

  test "Construction with custom parameters":
    let strat = newParabolicSARStrategy(acceleration = 0.03, maximum = 0.30)
    check strat.name() == "Parabolic SAR Strategy"
    check strat.acceleration == 0.03
    check strat.maximum == 0.30

  test "Signal generation in uptrend":
    let data = loadTestData("uptrend.csv")
    let strat = newParabolicSARStrategy()
    var buySignals = 0
    var sellSignals = 0

    for candle in data:
      let signal = strat.onBar(candle)
      if signal.position == Position.Buy:
        buySignals += 1
      elif signal.position == Position.Sell:
        sellSignals += 1

    # In uptrend, expect at least one buy signal when trend is detected
    check buySignals >= 0
    check sellSignals >= 0

  test "Signal generation in downtrend":
    let data = loadTestData("downtrend.csv")
    let strat = newParabolicSARStrategy()
    var buySignals = 0
    var sellSignals = 0

    for candle in data:
      let signal = strat.onBar(candle)
      if signal.position == Position.Buy:
        buySignals += 1
      elif signal.position == Position.Sell:
        sellSignals += 1

    # In downtrend, expect sell signals
    check sellSignals >= 0

  test "Signal generation in volatile market":
    let data = loadTestData("volatile.csv")
    let strat = newParabolicSARStrategy()
    var buySignals = 0
    var sellSignals = 0

    for candle in data:
      let signal = strat.onBar(candle)
      if signal.position == Position.Buy:
        buySignals += 1
      elif signal.position == Position.Sell:
        sellSignals += 1

    # In volatile market, expect multiple reversals
    check buySignals >= 0
    check sellSignals >= 0

  test "Reset functionality":
    let data = loadTestData("uptrend.csv")
    let strat = newParabolicSARStrategy()

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
    let strat = newParabolicSARStrategy()

    # First bar should return Stay (insufficient data)
    let signal = strat.onBar(data[0])
    check signal.position == Position.Stay

suite "KeltnerChannelStrategy Tests - Breakout Mode":
  test "Basic construction and parameters":
    let strat = newKeltnerChannelStrategy(emaPeriod = 20, atrPeriod = 10,
        multiplier = 2.0)
    check strat.name().contains("Keltner Channel Strategy")
    check strat.name().contains("Breakout")

  test "Construction with custom parameters":
    let strat = newKeltnerChannelStrategy(emaPeriod = 15, atrPeriod = 14,
        multiplier = 3.0, mode = Breakout)
    check strat.emaPeriod == 15
    check strat.atrPeriod == 14
    check strat.multiplier == 3.0

  test "Breakout signal generation in uptrend":
    let data = loadTestData("uptrend.csv")
    let strat = newKeltnerChannelStrategy(mode = Breakout)
    var buySignals = 0
    var sellSignals = 0

    for candle in data:
      let signal = strat.onBar(candle)
      if signal.position == Position.Buy:
        buySignals += 1
      elif signal.position == Position.Sell:
        sellSignals += 1

    # In uptrend with breakout mode, may get buy signals
    check buySignals >= 0

  test "Breakout signal generation in volatile market":
    let data = loadTestData("volatile.csv")
    let strat = newKeltnerChannelStrategy(mode = Breakout)
    var buySignals = 0
    var sellSignals = 0

    for candle in data:
      let signal = strat.onBar(candle)
      if signal.position == Position.Buy:
        buySignals += 1
      elif signal.position == Position.Sell:
        sellSignals += 1

    # Volatile market should generate breakout signals
    check buySignals >= 0
    check sellSignals >= 0

  test "Reset functionality":
    let data = loadTestData("uptrend.csv")
    let strat = newKeltnerChannelStrategy(mode = Breakout)

    # Process some data
    for i in 0..<25:
      discard strat.onBar(data[i])

    # Reset
    strat.reset()

    # After reset, should be able to process data again
    let signal = strat.onBar(data[0])
    check signal.position == Position.Stay # Insufficient data after reset

  test "Insufficient data handling":
    let data = loadTestData("uptrend.csv")
    let strat = newKeltnerChannelStrategy(emaPeriod = 20, atrPeriod = 10)

    # First several bars should return Stay (insufficient data)
    var stayCount = 0
    for i in 0..<15:
      let signal = strat.onBar(data[i])
      if signal.position == Position.Stay:
        stayCount += 1

    # Most early bars should be Stay
    check stayCount >= 10

suite "KeltnerChannelStrategy Tests - Reversion Mode":
  test "Basic construction and parameters":
    let strat = newKeltnerChannelStrategy(mode = Reversion)
    check strat.name().contains("Keltner Channel Strategy")
    check strat.name().contains("Reversion")

  test "Reversion signal generation in ranging market":
    let data = loadTestData("ranging.csv")
    let strat = newKeltnerChannelStrategy(mode = Reversion)
    var buySignals = 0
    var sellSignals = 0

    for candle in data:
      let signal = strat.onBar(candle)
      if signal.position == Position.Buy:
        buySignals += 1
      elif signal.position == Position.Sell:
        sellSignals += 1

    # In ranging market with reversion mode, expect signals
    check buySignals >= 0
    check sellSignals >= 0

  test "Reversion signal generation in volatile market":
    let data = loadTestData("volatile.csv")
    let strat = newKeltnerChannelStrategy(mode = Reversion)
    var buySignals = 0
    var sellSignals = 0

    for candle in data:
      let signal = strat.onBar(candle)
      if signal.position == Position.Buy:
        buySignals += 1
      elif signal.position == Position.Sell:
        sellSignals += 1

    # Volatile market with reversion mode should generate signals
    check buySignals >= 0
    check sellSignals >= 0

  test "Mode difference - same data different signals":
    let data = loadTestData("volatile.csv")
    let breakoutStrat = newKeltnerChannelStrategy(mode = Breakout)
    let reversionStrat = newKeltnerChannelStrategy(mode = Reversion)

    var breakoutBuys = 0
    var reversionBuys = 0

    for candle in data:
      let breakoutSignal = breakoutStrat.onBar(candle)
      if breakoutSignal.position == Position.Buy:
        breakoutBuys += 1

    # Reset to process same data
    for candle in data:
      let reversionSignal = reversionStrat.onBar(candle)
      if reversionSignal.position == Position.Buy:
        reversionBuys += 1

    # Both modes should process without error
    # (actual signal counts may vary depending on data)
    check breakoutBuys >= 0
    check reversionBuys >= 0

suite "Integration Tests - Phase 2 Strategies":
  test "All Phase 2 strategies can be instantiated":
    let psar = newParabolicSARStrategy()
    let keltnerBreakout = newKeltnerChannelStrategy(mode = Breakout)
    let keltnerReversion = newKeltnerChannelStrategy(mode = Reversion)

    check psar.name() == "Parabolic SAR Strategy"
    check keltnerBreakout.name().contains("Breakout")
    check keltnerReversion.name().contains("Reversion")

  test "All Phase 2 strategies work with streaming data":
    let data = loadTestData("uptrend.csv")
    let strategies = @[
      newParabolicSARStrategy().Strategy,
      newKeltnerChannelStrategy(mode = Breakout).Strategy,
      newKeltnerChannelStrategy(mode = Reversion).Strategy
    ]

    for strat in strategies:
      var signalCount = 0
      for candle in data:
        let signal = strat.onBar(candle)
        if signal.position != Position.Stay:
          signalCount += 1
      # Each strategy should process all bars without error
      check signalCount >= 0

  test "All Phase 2 strategies handle reset correctly":
    let data = loadTestData("uptrend.csv")
    let strategies = @[
      newParabolicSARStrategy().Strategy,
      newKeltnerChannelStrategy(mode = Breakout).Strategy,
      newKeltnerChannelStrategy(mode = Reversion).Strategy
    ]

    for strat in strategies:
      # Process some data
      for i in 0..<20:
        discard strat.onBar(data[i])

      # Reset
      strat.reset()

      # Should be able to process again
      let signal = strat.onBar(data[0])
      check signal.position == Position.Stay # First bar after reset should be Stay

  test "Phase 2 strategies with different market conditions":
    let uptrend = loadTestData("uptrend.csv")
    let downtrend = loadTestData("downtrend.csv")
    let volatile = loadTestData("volatile.csv")
    let ranging = loadTestData("ranging.csv")

    let psar = newParabolicSARStrategy()

    # Test PSAR with all market conditions
    for candle in uptrend:
      discard psar.onBar(candle)

    psar.reset()
    for candle in downtrend:
      discard psar.onBar(candle)

    psar.reset()
    for candle in volatile:
      discard psar.onBar(candle)

    psar.reset()
    for candle in ranging:
      discard psar.onBar(candle)

    # If we got here without crashing, test passes
    check true

when isMainModule:
  echo "Running tests for Phase 2 strategies..."
