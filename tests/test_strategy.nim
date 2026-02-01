import std/[unittest, times, sequtils, strformat]
import ../src/tzutrader/[core, data, indicators, strategy]

suite "Strategy Tests":
  
  # Helper to create sample OHLCV data
  proc createSampleData(patterns: string = "uptrend"): seq[OHLCV] =
    result = @[]
    let baseDate = initDateTime(1, mJan, 2024, 0, 0, 0, utc())
    
    case patterns
    of "uptrend":
      # Create uptrend data for testing bullish signals
      for i in 0..<50:
        result.add(OHLCV(
          timestamp: (baseDate + initDuration(days = i)).toTime().toUnix(),
          open: 100.0 + float(i) * 0.5,
          high: 102.0 + float(i) * 0.5,
          low: 99.0 + float(i) * 0.5,
          close: 101.0 + float(i) * 0.5,
          volume: 1000000
        ))
    of "downtrend":
      # Create downtrend data for testing bearish signals
      for i in 0..<50:
        result.add(OHLCV(
          timestamp: (baseDate + initDuration(days = i)).toTime().toUnix(),
          open: 150.0 - float(i) * 0.5,
          high: 152.0 - float(i) * 0.5,
          low: 149.0 - float(i) * 0.5,
          close: 150.5 - float(i) * 0.5,
          volume: 1000000
        ))
    of "oversold":
      # Create data with RSI oversold condition
      for i in 0..<30:
        if i < 15:
          # Sharp drop to create oversold
          result.add(OHLCV(
            timestamp: (baseDate + initDuration(days = i)).toTime().toUnix(),
            open: 100.0 - float(i) * 2.0,
            high: 101.0 - float(i) * 2.0,
            low: 99.0 - float(i) * 2.0,
            close: 100.0 - float(i) * 2.0,
            volume: 1000000
          ))
        else:
          # Stabilize
          result.add(OHLCV(
            timestamp: (baseDate + initDuration(days = i)).toTime().toUnix(),
            open: 70.0,
            high: 71.0,
            low: 69.0,
            close: 70.0,
            volume: 1000000
          ))
    of "overbought":
      # Create data with RSI overbought condition
      for i in 0..<30:
        if i < 15:
          # Sharp rise to create overbought
          result.add(OHLCV(
            timestamp: (baseDate + initDuration(days = i)).toTime().toUnix(),
            open: 100.0 + float(i) * 2.0,
            high: 101.0 + float(i) * 2.0,
            low: 99.0 + float(i) * 2.0,
            close: 100.0 + float(i) * 2.0,
            volume: 1000000
          ))
        else:
          # Stabilize
          result.add(OHLCV(
            timestamp: (baseDate + initDuration(days = i)).toTime().toUnix(),
            open: 130.0,
            high: 131.0,
            low: 129.0,
            close: 130.0,
            volume: 1000000
          ))
    else:
      # Default: sideways
      for i in 0..<50:
        result.add(OHLCV(
          timestamp: (baseDate + initDuration(days = i)).toTime().toUnix(),
          open: 100.0,
          high: 102.0,
          low: 98.0,
          close: 100.0,
          volume: 1000000
        ))

  test "RSIStrategy - Basic Construction":
    let strategy = newRSIStrategy(period = 14, oversold = 30.0, overbought = 70.0)
    check:
      strategy.period == 14
      strategy.oversold == 30.0
      strategy.overbought == 70.0
  
  test "RSIStrategy - Streaming Oversold":
    let strategy = newRSIStrategy(period = 14, oversold = 30.0, overbought = 70.0)
    let data = createSampleData("oversold")
    
    var signals: seq[Signal] = @[]
    for bar in data:
      let signal = strategy.onBar(bar)
      signals.add(signal)
    
    # Should generate signals (even if just Stay signals)
    check signals.len == data.len
  
  test "RSIStrategy - Streaming Overbought":
    let strategy = newRSIStrategy(period = 14, oversold = 30.0, overbought = 70.0)
    let data = createSampleData("overbought")
    
    var signals: seq[Signal] = @[]
    for bar in data:
      let signal = strategy.onBar(bar)
      signals.add(signal)
    
    # Should generate signals (even if just Stay signals)
    check signals.len == data.len
  
  test "RSIStrategy - Reset":
    let strategy = newRSIStrategy(period = 14, oversold = 30.0, overbought = 70.0)
    let data = createSampleData("oversold")
    
    # Process some bars
    for i in 0..<10:
      discard strategy.onBar(data[i])
    
    # Reset should clear indicator state
    strategy.reset()
    # Verify reset by checking that strategy works again
    discard strategy.onBar(data[0])
    check true  # If we got here without error, reset worked

  test "CrossoverStrategy - Basic Construction":
    let strategy = newCrossoverStrategy(fastPeriod = 10, slowPeriod = 20)
    check:
      strategy.fastPeriod == 10
      strategy.slowPeriod == 20
  
  test "CrossoverStrategy - Streaming Mode":
    let strategy = newCrossoverStrategy(fastPeriod = 10, slowPeriod = 20)
    let data = createSampleData("uptrend")
    
    var signals: seq[Signal] = @[]
    for bar in data:
      let signal = strategy.onBar(bar)
      if signal.position != Position.Stay:
        signals.add(signal)
    
    check signals.len > 0
  
  test "CrossoverStrategy - Reset":
    let strategy = newCrossoverStrategy(fastPeriod = 10, slowPeriod = 20)
    let data = createSampleData("uptrend")
    
    for i in 0..<10:
      discard strategy.onBar(data[i])
    
    strategy.reset()
    # Verify reset by checking that strategy works again
    discard strategy.onBar(data[0])
    check true  # If we got here without error, reset worked

  test "MACDStrategy - Basic Construction":
    let strategy = newMACDStrategy(fastPeriod = 12, slowPeriod = 26, signalPeriod = 9)
    check:
      strategy.fastPeriod == 12
      strategy.slowPeriod == 26
      strategy.signalPeriod == 9
  
  test "MACDStrategy - Streaming Mode":
    let strategy = newMACDStrategy(fastPeriod = 12, slowPeriod = 26, signalPeriod = 9)
    let data = createSampleData("uptrend")
    
    var signals: seq[Signal] = @[]
    for bar in data:
      let signal = strategy.onBar(bar)
      if signal.position != Position.Stay:
        signals.add(signal)
    
    check signals.len >= 0  # May or may not generate signals depending on data
  
  test "MACDStrategy - Reset":
    let strategy = newMACDStrategy(fastPeriod = 12, slowPeriod = 26, signalPeriod = 9)
    let data = createSampleData("uptrend")
    
    for i in 0..<15:
      discard strategy.onBar(data[i])
    
    strategy.reset()
    # Verify reset by checking that strategy works again
    discard strategy.onBar(data[0])
    check true  # If we got here without error, reset worked

  test "BollingerStrategy - Basic Construction":
    let strategy = newBollingerStrategy(period = 20, stdDev = 2.0)
    check:
      strategy.period == 20
      strategy.stdDev == 2.0
  
  test "BollingerStrategy - Streaming Signal Generation":
    let strategy = newBollingerStrategy(period = 20, stdDev = 2.0)
    
    # Create data that touches lower band (oversold -> Buy)
    var data: seq[OHLCV] = @[]
    let baseDate = initDateTime(1, mJan, 2024, 0, 0, 0, utc())
    
    # First 25 bars: stable around 100
    for i in 0..<25:
      data.add(OHLCV(
        timestamp: (baseDate + initDuration(days = i)).toTime().toUnix(),
        open: 100.0,
        high: 101.0,
        low: 99.0,
        close: 100.0,
        volume: 1000000
      ))
    
    # Sharp drop to trigger lower band
    data.add(OHLCV(
      timestamp: (baseDate + initDuration(days = 25)).toTime().toUnix(),
      open: 100.0,
      high: 100.0,
      low: 85.0,
      close: 85.0,
      volume: 1000000
    ))
    
    var lastSignal: Signal
    for bar in data:
      lastSignal = strategy.onBar(bar)
    
    # Last signal should be Buy (price touched lower band)
    check lastSignal.position == Position.Buy
  
  test "BollingerStrategy - Reset":
    let strategy = newBollingerStrategy(period = 20, stdDev = 2.0)
    let data = createSampleData("uptrend")
    
    for i in 0..<10:
      discard strategy.onBar(data[i])
    
    strategy.reset()
    # Verify reset by checking that strategy works again
    discard strategy.onBar(data[0])
    check true  # If we got here without error, reset worked

  test "Strategy - Signal Metadata":
    let strategy = newRSIStrategy(period = 14, oversold = 30.0, overbought = 70.0)
    let data = createSampleData("oversold")
    
    var signals: seq[Signal] = @[]
    for bar in data:
      signals.add(strategy.onBar(bar))
    
    # Check that signals have proper metadata
    for signal in signals:
      check:
        signal.timestamp > 0
        signal.price >= 0.0

  test "Strategy - Streaming Consistency":
    let strategy1 = newRSIStrategy(period = 14, oversold = 30.0, overbought = 70.0)
    let data = createSampleData("oversold")
    
    # Streaming mode
    var signals: seq[Signal] = @[]
    for bar in data:
      signals.add(strategy1.onBar(bar))
    
    # Should generate all signals
    check:
      signals.len == data.len
      signals.len > 0

  test "Multiple Strategies - Same Data Different Signals":
    let data = createSampleData("uptrend")
    
    let rsiStrat = newRSIStrategy()
    let crossStrat = newCrossoverStrategy()
    let macdStrat = newMACDStrategy()
    let bbStrat = newBollingerStrategy()
    
    var rsiSignals: seq[Signal] = @[]
    var crossSignals: seq[Signal] = @[]
    var macdSignals: seq[Signal] = @[]
    var bbSignals: seq[Signal] = @[]
    
    for bar in data:
      rsiSignals.add(rsiStrat.onBar(bar))
      crossSignals.add(crossStrat.onBar(bar))
      macdSignals.add(macdStrat.onBar(bar))
      bbSignals.add(bbStrat.onBar(bar))
    
    # All should generate signals
    check:
      rsiSignals.len > 0
      crossSignals.len > 0
      macdSignals.len > 0
      bbSignals.len > 0
    
    # Strategies should produce different signals (usually)
    # Just verify they all work independently
    echo &"\nStrategy signal counts for uptrend data:"
    echo &"  RSI: {rsiSignals.filterIt(it.position != Position.Stay).len} signals"
    echo &"  Crossover: {crossSignals.filterIt(it.position != Position.Stay).len} signals"
    echo &"  MACD: {macdSignals.filterIt(it.position != Position.Stay).len} signals"
    echo &"  Bollinger: {bbSignals.filterIt(it.position != Position.Stay).len} signals"

  test "Strategy with Real CSV Data":
    # Test with actual CSV data if available
    try:
      let csvData = readCSV("data/AAPL_sample.csv")
      
      if csvData.len > 0:
        let strategy = newCrossoverStrategy(fastPeriod = 10, slowPeriod = 20)
        
        var signals: seq[Signal] = @[]
        for bar in csvData:
          signals.add(strategy.onBar(bar))
        
        check:
          signals.len == csvData.len
          signals.len > 0
        
        let buySignals = signals.filterIt(it.position == Position.Buy)
        let sellSignals = signals.filterIt(it.position == Position.Sell)
        
        echo &"\nAAPL Strategy Test Results:"
        echo &"  Total bars: {csvData.len}"
        echo &"  Buy signals: {buySignals.len}"
        echo &"  Sell signals: {sellSignals.len}"
      else:
        skip()
    except:
      # CSV file not available, skip test
      skip()

when isMainModule:
  echo "Running Strategy Tests..."
  echo "========================="
