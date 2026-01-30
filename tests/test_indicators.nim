import std/[unittest, math, sequtils]

include ../src/tzutrader/core
include ../src/tzutrader/indicators

suite "Indicators Module Tests":
  
  # Helper to compare floats with tolerance
  proc almostEqual(a, b: float, epsilon = 1e-6): bool =
    if a.isNaN and b.isNaN:
      return true
    abs(a - b) < epsilon
  
  # Helper to create sample OHLCV data
  proc createSampleData(count: int): seq[OHLCV] =
    result = newSeq[OHLCV](count)
    for i in 0..<count:
      result[i] = OHLCV(
        timestamp: 1000 + i,
        open: 100.0 + float(i),
        high: 105.0 + float(i),
        low: 95.0 + float(i),
        close: 100.0 + float(i),
        volume: 1000.0
      )
  
  # Helper to create trending data
  proc createTrendingData(): seq[OHLCV] =
    let closes = @[100.0, 102.0, 104.0, 103.0, 105.0, 107.0, 106.0, 108.0, 110.0, 109.0]
    result = newSeq[OHLCV](closes.len)
    for i, close in closes:
      result[i] = OHLCV(
        timestamp: 1000 + i,
        open: close - 1.0,
        high: close + 1.0,
        low: close - 2.0,
        close: close,
        volume: 1000.0
      )

  suite "SMA (Simple Moving Average)":
    test "Batch mode with valid data":
      let data = createTrendingData()
      let closes = data.mapIt(it.close)
      let sma5 = sma(closes, 5)
      
      check sma5.len == 10
      # First 4 should be NaN (insufficient data)
      check sma5[0].isNaN
      check sma5[3].isNaN
      # 5th element: avg of first 5 closes
      check almostEqual(sma5[4], (100.0 + 102.0 + 104.0 + 103.0 + 105.0) / 5.0)
      # 6th element
      check almostEqual(sma5[5], (102.0 + 104.0 + 103.0 + 105.0 + 107.0) / 5.0)
    
    test "Batch mode with period larger than data":
      let closes = @[100.0, 101.0, 102.0]
      let sma5 = sma(closes, 5)
      check sma5.allIt(it.isNaN)
    
    test "Batch mode with empty data":
      let closes: seq[float] = @[]
      let sma5 = sma(closes, 5)
      check sma5.len == 0
    
    test "Streaming mode":
      var smaCalc = newSMA(3)
      check smaCalc.update(10.0).isNaN
      check smaCalc.update(20.0).isNaN
      check almostEqual(smaCalc.update(30.0), 20.0)  # (10+20+30)/3
      check almostEqual(smaCalc.update(40.0), 30.0)  # (20+30+40)/3

  suite "EMA (Exponential Moving Average)":
    test "Batch mode with valid data":
      let closes = @[22.0, 24.0, 23.0, 25.0, 26.0, 24.0, 25.0, 27.0, 28.0, 26.0]
      let ema5 = ema(closes, 5)
      
      check ema5.len == 10
      # First 4 should be NaN
      check ema5[0].isNaN
      check ema5[3].isNaN
      # 5th element should be SMA of first 5
      check almostEqual(ema5[4], 24.0)
    
    test "EMA follows trend faster than SMA":
      let closes = @[100.0, 100.0, 100.0, 100.0, 100.0, 110.0, 110.0, 110.0]
      let sma5 = sma(closes, 5)
      let ema5 = ema(closes, 5)
      # After spike, EMA should adjust faster
      check ema5[7] > sma5[7]  # EMA closer to new level
    
    test "Streaming mode":
      var emaCalc = newEMA(3)
      check emaCalc.update(10.0).isNaN
      check emaCalc.update(20.0).isNaN
      let first = emaCalc.update(30.0)  # Should be SMA: 20.0
      check almostEqual(first, 20.0)
      let second = emaCalc.update(40.0)
      check second > first  # Should increase
      check second < 40.0   # But not reach full value

  suite "WMA (Weighted Moving Average)":
    test "Batch mode with valid data":
      let closes = @[10.0, 20.0, 30.0, 40.0, 50.0]
      let wma3 = wma(closes, 3)
      
      check wma3[0].isNaN
      check wma3[1].isNaN
      # wma3[2] = (10*1 + 20*2 + 30*3) / (1+2+3) = 140/6 = 23.33
      check almostEqual(wma3[2], 23.333333, 1e-5)
      # wma3[3] = (20*1 + 30*2 + 40*3) / 6 = 200/6 = 33.33
      check almostEqual(wma3[3], 33.333333, 1e-5)
    
    test "WMA gives more weight to recent prices":
      let closes = @[100.0, 100.0, 100.0, 100.0, 100.0, 110.0]
      let sma3 = sma(closes, 3)
      let wma3 = wma(closes, 3)
      # Last value: WMA should be higher due to recent spike
      check wma3[5] > sma3[5]

  suite "RSI (Relative Strength Index)":
    test "Batch mode with trending up data":
      # Consistent upward trend should give high RSI
      let closes = @[100.0, 101.0, 102.0, 103.0, 104.0, 105.0, 106.0, 107.0, 
                     108.0, 109.0, 110.0, 111.0, 112.0, 113.0, 114.0]
      let rsi14 = rsi(closes, 14)
      
      # First 14 values should be NaN
      check rsi14[0].isNaN
      check rsi14[13].isNaN
      # Strong uptrend should have RSI > 70
      check rsi14[14] > 70.0
      check rsi14[14] <= 100.0
    
    test "Batch mode with trending down data":
      # Consistent downward trend should give low RSI
      let closes = @[114.0, 113.0, 112.0, 111.0, 110.0, 109.0, 108.0, 107.0,
                     106.0, 105.0, 104.0, 103.0, 102.0, 101.0, 100.0]
      let rsi14 = rsi(closes, 14)
      
      # Strong downtrend should have RSI < 30
      check rsi14[14] < 30.0
      check rsi14[14] >= 0.0
    
    test "RSI with flat prices":
      let closes = @[100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0,
                     100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0]
      let rsi14 = rsi(closes, 14)
      # No change means no gains or losses, implementation may return NaN or 50
      # We'll just check it doesn't crash and is valid
      check rsi14.len == 15
    
    test "Streaming mode":
      var rsiCalc = newRSI(14)
      # Feed 15 increasing values
      for i in 0..13:
        check rsiCalc.update(100.0 + float(i)).isNaN
      let rsi_val = rsiCalc.update(114.0)
      check rsi_val > 70.0

  suite "MACD (Moving Average Convergence Divergence)":
    test "Batch mode with valid data":
      let closes = createTrendingData().mapIt(it.close)
      let extended = closes & @[111.0, 113.0, 115.0, 114.0, 116.0, 118.0, 
                                117.0, 119.0, 121.0, 120.0, 122.0, 124.0,
                                123.0, 125.0, 127.0, 126.0, 128.0, 130.0]
      let macd_result = macd(extended)
      
      check macd_result.macd.len == extended.len
      check macd_result.signal.len == extended.len
      check macd_result.histogram.len == extended.len
      
      # First values should be NaN (need at least 12 for fast EMA)
      check macd_result.macd[0].isNaN
      check macd_result.macd[11].isNaN
    
    test "MACD histogram shows momentum":
      let uptrend = @[100.0, 101.0, 102.0, 103.0, 104.0, 105.0, 106.0, 107.0,
                      108.0, 109.0, 110.0, 111.0, 112.0, 113.0, 114.0, 115.0,
                      116.0, 117.0, 118.0, 119.0, 120.0, 121.0, 122.0, 123.0,
                      124.0, 125.0, 126.0, 127.0, 128.0, 129.0, 130.0, 131.0,
                      132.0, 133.0, 134.0]
      let macd_result = macd(uptrend)
      # In strong uptrend, histogram should be positive near end
      check macd_result.histogram[^1] > 0.0
    
    test "Streaming mode":
      var macdCalc = newMACD()
      var lastHistogram = NaN
      for i in 0..40:
        let result = macdCalc.update(100.0 + float(i))
        if i >= 33:  # After warmup period
          if not result.histogram.isNaN:
            lastHistogram = result.histogram
      # In uptrend, histogram should eventually be positive or close to zero
      check not lastHistogram.isNaN

  suite "ATR (Average True Range)":
    test "Batch mode with valid data":
      let data = createSampleData(20)
      let highs = data.mapIt(it.high)
      let lows = data.mapIt(it.low)
      let closes = data.mapIt(it.close)
      let atr14 = atr(highs, lows, closes, 14)
      
      check atr14.len == 20
      check atr14[0].isNaN
      # ATR needs at least 14 periods, so first valid is at index 13
      check not atr14[13].isNaN
      check atr14[14] > 0.0  # ATR should be positive
    
    test "ATR increases with volatility":
      var lowVol = newSeq[OHLCV](20)
      var highVol = newSeq[OHLCV](20)
      
      for i in 0..19:
        lowVol[i] = OHLCV(
          timestamp: 1000 + i,
          open: 100.0, high: 101.0, low: 99.0, close: 100.0, volume: 1000.0
        )
        highVol[i] = OHLCV(
          timestamp: 1000 + i,
          open: 100.0, high: 110.0, low: 90.0, close: 100.0, volume: 1000.0
        )
      
      let atr_low = atr(lowVol.mapIt(it.high), lowVol.mapIt(it.low), lowVol.mapIt(it.close), 14)
      let atr_high = atr(highVol.mapIt(it.high), highVol.mapIt(it.low), highVol.mapIt(it.close), 14)
      
      check atr_high[19] > atr_low[19]
    
    test "Streaming mode":
      var atrCalc = newATR(14)
      var lastValue = NaN
      for i in 0..20:
        let high = 105.0 + float(i)
        let low = 95.0 + float(i)
        let close = 100.0 + float(i)
        lastValue = atrCalc.update(high, low, close)
      check not lastValue.isNaN
      check lastValue > 0.0

  suite "Bollinger Bands":
    test "Batch mode with valid data":
      let closes = createTrendingData().mapIt(it.close)
      let extended = closes & @[111.0, 113.0, 115.0, 114.0, 116.0, 118.0, 
                                117.0, 119.0, 121.0, 120.0]
      let bb = bollinger(extended, 20, 2.0)
      
      check bb.upper.len == extended.len
      check bb.middle.len == extended.len
      check bb.lower.len == extended.len
    
    test "Upper band above middle, middle above lower":
      let closes = @[100.0, 101.0, 102.0, 103.0, 104.0, 105.0, 106.0, 107.0,
                     108.0, 109.0, 110.0, 111.0, 112.0, 113.0, 114.0, 115.0,
                     116.0, 117.0, 118.0, 119.0, 120.0]
      let bb = bollinger(closes, 20, 2.0)
      
      # Check last valid value
      check bb.upper[^1] > bb.middle[^1]
      check bb.middle[^1] > bb.lower[^1]
    
    test "Price usually within bands":
      let closes = @[100.0, 101.0, 99.0, 102.0, 98.0, 103.0, 97.0, 104.0,
                     96.0, 105.0, 95.0, 106.0, 94.0, 107.0, 93.0, 108.0,
                     92.0, 109.0, 91.0, 110.0, 100.0]
      let bb = bollinger(closes, 20, 2.0)
      
      # Last price should be within bands
      let last = closes[^1]
      check last >= bb.lower[^1]
      check last <= bb.upper[^1]

  suite "ROC (Rate of Change)":
    test "Batch mode with valid data":
      let closes = @[100.0, 102.0, 104.0, 103.0, 105.0, 107.0, 106.0, 108.0, 110.0, 109.0]
      let roc5 = roc(closes, 5)
      
      check roc5[0].isNaN
      check roc5[4].isNaN
      # roc5[5] should be positive (price increased from 102 to 107)
      check roc5[5] > 0.0
    
    test "ROC positive for uptrend":
      let closes = @[100.0, 101.0, 102.0, 103.0, 104.0, 105.0]
      let roc5 = roc(closes, 5)
      check roc5[5] > 0.0

  suite "OBV (On-Balance Volume)":
    test "Batch mode with valid data":
      let data = @[
        OHLCV(timestamp: 1, open: 100.0, high: 105.0, low: 95.0, close: 102.0, volume: 1000.0),
        OHLCV(timestamp: 2, open: 102.0, high: 107.0, low: 100.0, close: 104.0, volume: 1500.0),
        OHLCV(timestamp: 3, open: 104.0, high: 109.0, low: 102.0, close: 103.0, volume: 1200.0),
        OHLCV(timestamp: 4, open: 103.0, high: 108.0, low: 101.0, close: 106.0, volume: 1800.0),
      ]
      let closes = data.mapIt(it.close)
      let volumes = data.mapIt(it.volume)
      let obv_result = obv(closes, volumes)
      
      check obv_result[0] == 1000.0  # First day
      check obv_result[1] == 2500.0  # Up day: 1000 + 1500
      check obv_result[2] == 1300.0  # Down day: 2500 - 1200
      check obv_result[3] == 3100.0  # Up day: 1300 + 1800
    
    test "Streaming mode":
      var obvCalc = newOBV()
      
      check obvCalc.update(102.0, 1000.0) == 1000.0
      check obvCalc.update(104.0, 1500.0) == 2500.0
      check obvCalc.update(103.0, 1200.0) == 1300.0

  suite "Standard Deviation":
    test "Batch mode with valid data":
      let values = @[2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0]
      let stdev = stddev(values, 8)
      # Known std dev ≈ 2.0
      check almostEqual(stdev[7], 2.0, 0.1)
    
    test "Standard deviation of constant values":
      let values = @[5.0, 5.0, 5.0, 5.0, 5.0]
      let stdev = stddev(values, 5)
      check almostEqual(stdev[4], 0.0, 1e-6)

  suite "ROI (Return on Investment)":
    test "ROI calculation":
      check almostEqual(roi(100.0, 150.0), 50.0)  # 50% gain
      check almostEqual(roi(100.0, 75.0), -25.0)   # 25% loss
      check almostEqual(roi(100.0, 100.0), 0.0)    # No change
      check almostEqual(roi(50.0, 100.0), 100.0)   # 100% gain
    
    test "ROI with zero initial value":
      check roi(0.0, 100.0).isNaN  # Should be NaN

  suite "Integration Tests":
    test "Multiple indicators on same data":
      let data = createTrendingData()
      let closes = data.mapIt(it.close)
      let highs = data.mapIt(it.high)
      let lows = data.mapIt(it.low)
      
      let sma5 = sma(closes, 5)
      let ema5 = ema(closes, 5)
      let rsi14 = rsi(closes, 14)
      let atr14 = atr(highs, lows, closes, 14)
      
      # All should have same length as input
      check sma5.len == data.len
      check ema5.len == data.len
      check rsi14.len == data.len
      check atr14.len == data.len
    
    test "Streaming indicators with same data":
      var smaCalc = newSMA(3)
      var emaCalc = newEMA(3)
      
      for i in 0..10:
        let price = 100.0 + float(i)
        discard smaCalc.update(price)
        discard emaCalc.update(price)
      
      # Both should have valid values after warmup
      check not smaCalc.update(111.0).isNaN
      check not emaCalc.update(111.0).isNaN

echo "Indicators module: All tests defined"
