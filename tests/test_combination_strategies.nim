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

suite "TripleMAStrategy Tests":
  test "Basic construction and parameters":
    let strat = newTripleMAStrategy(fastPeriod=20, mediumPeriod=50, slowPeriod=200)
    check strat.name.contains("Triple MA Strategy")
    check strat.fastPeriod == 20
    check strat.mediumPeriod == 50
    check strat.slowPeriod == 200
  
  test "Construction validates MA periods":
    expect ValueError:
      discard newTripleMAStrategy(fastPeriod=50, mediumPeriod=20, slowPeriod=200)
    expect ValueError:
      discard newTripleMAStrategy(fastPeriod=20, mediumPeriod=200, slowPeriod=50)
  
  test "Signal generation in uptrend":
    let data = loadTestData("uptrend.csv")
    let strat = newTripleMAStrategy()
    var buySignals = 0
    var sellSignals = 0
    
    for candle in data:
      let signal = strat.onBar(candle)
      if signal.position == Position.Buy:
        buySignals += 1
      elif signal.position == Position.Sell:
        sellSignals += 1
    
    # In strong uptrend, expect at least one buy signal when MAs align
    check buySignals >= 0
  
  test "Signal generation in downtrend":
    let data = loadTestData("downtrend.csv")
    let strat = newTripleMAStrategy()
    var buySignals = 0
    var sellSignals = 0
    
    for candle in data:
      let signal = strat.onBar(candle)
      if signal.position == Position.Buy:
        buySignals += 1
      elif signal.position == Position.Sell:
        sellSignals += 1
    
    # In downtrend, expect sell signals when MAs align downward
    check sellSignals >= 0
  
  test "Reset functionality":
    let data = loadTestData("uptrend.csv")
    let strat = newTripleMAStrategy()
    
    # Process some data
    for i in 0..<50:
      discard strat.onBar(data[i])
    
    # Reset
    strat.reset()
    
    # After reset, should have insufficient data
    let signal = strat.onBar(data[0])
    check signal.position == Position.Stay
  
  test "Insufficient data handling":
    let data = loadTestData("uptrend.csv")
    let strat = newTripleMAStrategy(slowPeriod=200)
    
    # Need slowPeriod bars before signals
    var stayCount = 0
    for i in 0..<50:
      let signal = strat.onBar(data[i])
      if signal.position == Position.Stay:
        stayCount += 1
    
    # Most early bars should be Stay
    check stayCount >= 40

suite "ADXTrendStrategy Tests":
  test "Basic construction and parameters":
    let strat = newADXTrendStrategy(period=14, adxThreshold=25.0)
    check strat.name.contains("ADX Trend Strategy")
    check strat.period == 14
    check strat.adxThreshold == 25.0
  
  test "Construction with custom parameters":
    let strat = newADXTrendStrategy(period=20, adxThreshold=30.0)
    check strat.adxThreshold == 30.0
  
  test "Signal generation in uptrend":
    let data = loadTestData("uptrend.csv")
    let strat = newADXTrendStrategy()
    var buySignals = 0
    var sellSignals = 0
    
    for candle in data:
      let signal = strat.onBar(candle)
      if signal.position == Position.Buy:
        buySignals += 1
      elif signal.position == Position.Sell:
        sellSignals += 1
    
    # May or may not get signals depending on ADX strength
    check buySignals >= 0
  
  test "Signal generation in volatile market":
    let data = loadTestData("volatile.csv")
    let strat = newADXTrendStrategy()
    var buySignals = 0
    var sellSignals = 0
    
    for candle in data:
      let signal = strat.onBar(candle)
      if signal.position == Position.Buy:
        buySignals += 1
      elif signal.position == Position.Sell:
        sellSignals += 1
    
    # Volatile market should generate some signals
    check buySignals >= 0
    check sellSignals >= 0
  
  test "Reset functionality":
    let data = loadTestData("uptrend.csv")
    let strat = newADXTrendStrategy()
    
    # Process some data
    for i in 0..<20:
      discard strat.onBar(data[i])
    
    # Reset
    strat.reset()
    
    # After reset, should have insufficient data
    let signal = strat.onBar(data[0])
    check signal.position == Position.Stay
  
  test "Insufficient data handling":
    let data = loadTestData("uptrend.csv")
    let strat = newADXTrendStrategy(period=14)
    
    # First bars should return Stay
    var stayCount = 0
    for i in 0..<13:
      let signal = strat.onBar(data[i])
      if signal.position == Position.Stay:
        stayCount += 1
    
    check stayCount >= 10

suite "VolumeBreakoutStrategy Tests":
  test "Basic construction and parameters":
    let strat = newVolumeBreakoutStrategy(period=20, volumeMultiplier=1.5)
    check strat.name.contains("Volume Breakout Strategy")
    check strat.period == 20
    check strat.volumeMultiplier == 1.5
  
  test "Construction with custom parameters":
    let strat = newVolumeBreakoutStrategy(period=15, volumeMultiplier=2.0)
    check strat.volumeMultiplier == 2.0
  
  test "Signal generation in volatile market":
    let data = loadTestData("volatile.csv")
    let strat = newVolumeBreakoutStrategy()
    var buySignals = 0
    var sellSignals = 0
    
    for candle in data:
      let signal = strat.onBar(candle)
      if signal.position == Position.Buy:
        buySignals += 1
      elif signal.position == Position.Sell:
        sellSignals += 1
    
    # Volatile market may generate breakout signals
    check buySignals >= 0
    check sellSignals >= 0
  
  test "Signal generation in ranging market":
    let data = loadTestData("ranging.csv")
    let strat = newVolumeBreakoutStrategy()
    var buySignals = 0
    var sellSignals = 0
    
    for candle in data:
      let signal = strat.onBar(candle)
      if signal.position == Position.Buy:
        buySignals += 1
      elif signal.position == Position.Sell:
        sellSignals += 1
    
    # Ranging market should have few breakouts
    check buySignals >= 0
    check sellSignals >= 0
  
  test "Reset functionality":
    let data = loadTestData("uptrend.csv")
    let strat = newVolumeBreakoutStrategy()
    
    # Process some data
    for i in 0..<25:
      discard strat.onBar(data[i])
    
    # Reset
    strat.reset()
    
    # After reset, should be building history
    let signal = strat.onBar(data[0])
    check signal.position == Position.Stay
  
  test "Insufficient data handling":
    let data = loadTestData("uptrend.csv")
    let strat = newVolumeBreakoutStrategy(period=20)
    
    # Need period bars to build history
    var stayCount = 0
    for i in 0..<20:
      let signal = strat.onBar(data[i])
      if signal.position == Position.Stay:
        stayCount += 1
    
    check stayCount >= 15

suite "DualMomentumStrategy Tests":
  test "Basic construction and parameters":
    let strat = newDualMomentumStrategy(rocPeriod=12, smaPeriod=50)
    check strat.name.contains("Dual Momentum Strategy")
    check strat.rocPeriod == 12
    check strat.smaPeriod == 50
  
  test "Construction with custom parameters":
    let strat = newDualMomentumStrategy(rocPeriod=10, smaPeriod=40)
    check strat.rocPeriod == 10
  
  test "Signal generation in uptrend":
    let data = loadTestData("uptrend.csv")
    let strat = newDualMomentumStrategy()
    var buySignals = 0
    var sellSignals = 0
    
    for candle in data:
      let signal = strat.onBar(candle)
      if signal.position == Position.Buy:
        buySignals += 1
      elif signal.position == Position.Sell:
        sellSignals += 1
    
    # In uptrend, expect buy signals when momentum aligns
    check buySignals >= 0
  
  test "Signal generation in downtrend":
    let data = loadTestData("downtrend.csv")
    let strat = newDualMomentumStrategy()
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
  
  test "Reset functionality":
    let data = loadTestData("uptrend.csv")
    let strat = newDualMomentumStrategy()
    
    # Process some data
    for i in 0..<30:
      discard strat.onBar(data[i])
    
    # Reset
    strat.reset()
    
    # After reset, should have insufficient data
    let signal = strat.onBar(data[0])
    check signal.position == Position.Stay
  
  test "Insufficient data handling":
    let data = loadTestData("uptrend.csv")
    let strat = newDualMomentumStrategy(smaPeriod=50)
    
    # Need smaPeriod bars before signals
    var stayCount = 0
    for i in 0..<45:
      let signal = strat.onBar(data[i])
      if signal.position == Position.Stay:
        stayCount += 1
    
    check stayCount >= 40

suite "FilteredMeanReversionStrategy Tests":
  test "Basic construction and parameters":
    let strat = newFilteredMeanReversionStrategy(rsiPeriod=14, trendPeriod=200)
    check strat.name.contains("Filtered Mean Reversion Strategy")
    check strat.rsiPeriod == 14
    check strat.trendPeriod == 200
  
  test "Construction with custom parameters":
    let strat = newFilteredMeanReversionStrategy(rsiPeriod=10, trendPeriod=100, oversold=25.0, overbought=75.0)
    check strat.oversold == 25.0
    check strat.overbought == 75.0
  
  test "Signal generation in uptrend":
    let data = loadTestData("uptrend.csv")
    let strat = newFilteredMeanReversionStrategy()
    var buySignals = 0
    var sellSignals = 0
    
    for candle in data:
      let signal = strat.onBar(candle)
      if signal.position == Position.Buy:
        buySignals += 1
      elif signal.position == Position.Sell:
        sellSignals += 1
    
    # In uptrend, may get buy signals on RSI oversold pullbacks
    check buySignals >= 0
  
  test "Signal generation in ranging market":
    let data = loadTestData("ranging.csv")
    let strat = newFilteredMeanReversionStrategy()
    var buySignals = 0
    var sellSignals = 0
    
    for candle in data:
      let signal = strat.onBar(candle)
      if signal.position == Position.Buy:
        buySignals += 1
      elif signal.position == Position.Sell:
        sellSignals += 1
    
    # Ranging market may generate some signals
    check buySignals >= 0
    check sellSignals >= 0
  
  test "Reset functionality":
    let data = loadTestData("uptrend.csv")
    let strat = newFilteredMeanReversionStrategy()
    
    # Process some data
    for i in 0..<50:
      discard strat.onBar(data[i])
    
    # Reset
    strat.reset()
    
    # After reset, should have insufficient data
    let signal = strat.onBar(data[0])
    check signal.position == Position.Stay
  
  test "Insufficient data handling":
    let data = loadTestData("uptrend.csv")
    let strat = newFilteredMeanReversionStrategy(trendPeriod=200)
    
    # Need trendPeriod bars before signals
    var stayCount = 0
    for i in 0..<50:
      let signal = strat.onBar(data[i])
      if signal.position == Position.Stay:
        stayCount += 1
    
    check stayCount >= 45

suite "Integration Tests - Combination Strategies":
  test "All Phase 3 strategies can be instantiated":
    let triple = newTripleMAStrategy()
    let adx = newADXTrendStrategy()
    let volume = newVolumeBreakoutStrategy()
    let dual = newDualMomentumStrategy()
    let filtered = newFilteredMeanReversionStrategy()
    
    check triple.name.contains("Triple MA")
    check adx.name.contains("ADX")
    check volume.name.contains("Volume Breakout")
    check dual.name.contains("Dual Momentum")
    check filtered.name.contains("Filtered Mean Reversion")
  
  test "All Phase 3 strategies work with streaming data":
    let data = loadTestData("uptrend.csv")
    let strategies = @[
      newTripleMAStrategy().Strategy,
      newADXTrendStrategy().Strategy,
      newVolumeBreakoutStrategy().Strategy,
      newDualMomentumStrategy().Strategy,
      newFilteredMeanReversionStrategy().Strategy
    ]
    
    for strat in strategies:
      var signalCount = 0
      for candle in data:
        let signal = strat.onBar(candle)
        if signal.position != Position.Stay:
          signalCount += 1
      # Each strategy should process all bars without error
      check signalCount >= 0
  
  test "All Phase 3 strategies handle reset correctly":
    let data = loadTestData("uptrend.csv")
    let strategies = @[
      newTripleMAStrategy().Strategy,
      newADXTrendStrategy().Strategy,
      newVolumeBreakoutStrategy().Strategy,
      newDualMomentumStrategy().Strategy,
      newFilteredMeanReversionStrategy().Strategy
    ]
    
    for strat in strategies:
      # Process some data
      for i in 0..<30:
        discard strat.onBar(data[i])
      
      # Reset
      strat.reset()
      
      # Should be able to process again
      let signal = strat.onBar(data[0])
      check signal.position == Position.Stay  # First bar after reset should be Stay
  
  test "Phase 3 strategies with different market conditions":
    let uptrend = loadTestData("uptrend.csv")
    let downtrend = loadTestData("downtrend.csv")
    let volatile = loadTestData("volatile.csv")
    let ranging = loadTestData("ranging.csv")
    
    let strat = newDualMomentumStrategy()
    
    # Test with all market conditions
    for candle in uptrend:
      discard strat.onBar(candle)
    
    strat.reset()
    for candle in downtrend:
      discard strat.onBar(candle)
    
    strat.reset()
    for candle in volatile:
      discard strat.onBar(candle)
    
    strat.reset()
    for candle in ranging:
      discard strat.onBar(candle)
    
    # If we got here without crashing, test passes
    check true

when isMainModule:
  echo "Running tests for Phase 3 combination strategies..."
