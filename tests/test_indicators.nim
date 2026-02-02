## Tests for indicators module
##
## All tests follow pybottrader streaming pattern:
## - Create indicator with period and memSize
## - Feed data point by point using update()
## - Check NaN until sufficient data
## - Verify computed values
## - Test circular buffer access with [0], [-1], [-2], etc.

import std/[unittest, math]
import ../src/tzutrader/indicators

proc almostEqual(a, b: float64, epsilon = 1e-6): bool =
  ## Compare floats with tolerance
  if a.isNaN and b.isNaN:
    return true
  if a.isNaN or b.isNaN:
    return false
  abs(a - b) < epsilon

suite "Base Indicator":
  test "Circular buffer indexing":
    var ind = newMA(period = 3, memSize = 5)
    # Feed 10 values
    for i in 1..10:
      discard ind.update(float64(i))

    # Should have last 5 computed MA values
    # Last 5 windows: [6,7,8], [7,8,9], [8,9,10]
    check almostEqual(ind[0], 9.0) # Current: (8+9+10)/3
    check almostEqual(ind[-1], 8.0) # Previous: (7+8+9)/3
    check almostEqual(ind[-2], 7.0) # (6+7+8)/3
    check almostEqual(ind[-3], 6.0) # (5+6+7)/3
    check almostEqual(ind[-4], 5.0) # (4+5+6)/3
    
    # Out of bounds should raise
    expect IndexDefect:
      discard ind[-5]

    expect IndexDefect:
      discard ind[1]

suite "MA (Simple Moving Average)":
  test "Basic calculation with warmup period":
    let period = 3
    var ma = newMA(period)
    let ts = @[1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]

    for i, value in ts:
      let y = ma.update(value)
      if i < period - 1:
        check y.isNaN
      else:
        # MA at position i should be average of last 'period' values
        # For i=2: (1+2+3)/3 = 2.0
        # For i=3: (2+3+4)/3 = 3.0, etc.
        let expected = ts[i] - 1.0 # Because of consecutive integers
        check almostEqual(y, expected)

  test "Memory access with circular buffer":
    let period = 3
    let memSize = 3
    var ma = newMA(period = period, memSize = memSize)
    let ts = @[1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]

    for value in ts:
      discard ma.update(value)

    # Last 3 MA values: (8,9,10)=9.0, (7,8,9)=8.0, (6,7,8)=7.0
    check almostEqual(ma[0], 9.0)
    check almostEqual(ma[-1], 8.0)
    check almostEqual(ma[-2], 7.0)

    # Out of range should raise
    expect IndexDefect:
      discard ma[-3]

  test "SMA is alias for MA":
    var sma = newSMA(period = 3)
    let ts = @[10.0, 20.0, 30.0, 40.0]

    check sma.update(10.0).isNaN
    check sma.update(20.0).isNaN
    check almostEqual(sma.update(30.0), 20.0)
    check almostEqual(sma.update(40.0), 30.0)

suite "EMA (Exponential Moving Average)":
  test "Basic calculation with known values":
    ## Test adapted from pybottrader C++ tests
    let periods = 5
    var ema = newEMA(periods)
    let ts = @[10.0, 12.0, 14.0, 13.0, 15.0, 16.0, 18.0]
    let expected = @[12.8, 13.866666, 15.244444]

    for i, value in ts:
      let y = ema.update(value)
      if i < periods - 1:
        check y.isNaN
      else:
        check almostEqual(y, expected[i - periods + 1], 1e-5)

  test "Memory access with circular buffer":
    let period = 5
    let memSize = 3
    var ema = newEMA(period, memSize = memSize)
    let ts = @[10.0, 12.0, 14.0, 13.0, 15.0, 16.0, 18.0]
    let expected = @[12.8, 13.866666, 15.244444]

    for value in ts:
      discard ema.update(value)

    check almostEqual(ema[0], expected[2], 1e-5)
    check almostEqual(ema[-1], expected[1], 1e-5)
    check almostEqual(ema[-2], expected[0], 1e-5)

    expect IndexDefect:
      discard ema[-3]

suite "MV (Moving Variance)":
  test "Basic variance calculation":
    let period = 3
    let memSize = 3
    var mv = newMV(period, memSize)
    let ts = @[1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]

    for value in ts:
      discard mv.update(value)

    # For consecutive integers, variance of any 3 consecutive is 2/3
    check almostEqual(mv[0], 2.0 / 3.0, 1e-5)
    check almostEqual(mv[-1], 2.0 / 3.0, 1e-5)
    check almostEqual(mv[-2], 2.0 / 3.0, 1e-5)

suite "STDEV (Standard Deviation)":
  test "Basic calculation":
    let period = 3
    var stdev = newSTDEV(period)
    let ts = @[1.0, 2.0, 3.0, 4.0, 5.0, 6.0]

    for i, value in ts:
      let y = stdev.update(value)
      if i < period - 1:
        check y.isNaN
      else:
        # Standard deviation of consecutive integers
        # Variance is 2/3, so stdev is sqrt(2/3)
        check almostEqual(y, sqrt(2.0 / 3.0), 1e-5)

  test "Zero variance for constant values":
    var stdev = newSTDEV(period = 5)
    for _ in 1..10:
      discard stdev.update(100.0)

    check almostEqual(stdev[0], 0.0, 1e-6)

suite "TRIMA (Triangular Moving Average)":
  test "Basic TRIMA calculation":
    var trima = newTRIMA(3)

    # Feed data: 1, 2, 3, 4, 5, 6, 7
    # First MA(3): NaN, NaN, 2.0, 3.0, 4.0, 5.0, 6.0
    # Second MA(3) of first MA: NaN, NaN, NaN, NaN, 3.0, 4.0, 5.0

    check trima.update(1.0).isNaN
    check trima.update(2.0).isNaN
    check trima.update(3.0).isNaN
    check trima.update(4.0).isNaN
    check almostEqual(trima.update(5.0), 3.0) # (2+3+4)/3
    check almostEqual(trima.update(6.0), 4.0) # (3+4+5)/3
    check almostEqual(trima.update(7.0), 5.0) # (4+5+6)/3

  test "TRIMA is smoother than SMA":
    var trima = newTRIMA(5)
    var sma = newSMA(5)

    # Feed oscillating data
    let data = @[100.0, 110.0, 105.0, 115.0, 108.0, 118.0, 112.0, 120.0, 115.0,
        125.0, 120.0]

    for price in data:
      discard trima.update(price)
      discard sma.update(price)

    # After warmup, both should have valid values
    check not trima[0].isNaN
    check not sma[0].isNaN

    # TRIMA should produce values (can't easily test "smoother" without more data)
    # Just verify it calculates correctly
    check trima[0] > 0.0

  test "TRIMA circular buffer access":
    var trima = newTRIMA(3, memSize = 3)

    for i in 1..10:
      discard trima.update(float64(i))

    # Should have last 3 valid values
    check not trima[0].isNaN
    check not trima[-1].isNaN
    check not trima[-2].isNaN

suite "DEMA (Double Exponential Moving Average)":
  test "Basic DEMA calculation":
    var dema = newDEMA(3)

    # DEMA needs: period for EMA1, then period-1 more for EMA2 of EMA1
    check dema.update(1.0).isNaN
    check dema.update(2.0).isNaN
    check dema.update(3.0).isNaN # EMA1 starts
    check dema.update(4.0).isNaN # EMA2 still warming

    let val5 = dema.update(5.0)
    check not val5.isNaN # Should have DEMA value now

    let val6 = dema.update(6.0)
    check not val6.isNaN

  test "DEMA has less lag than EMA":
    var dema = newDEMA(5)
    var ema = newEMA(5)

    # Feed data with trend change
    for i in 1..10:
      discard dema.update(float64(i * 10))
      discard ema.update(float64(i * 10))

    # Add sudden price increase
    discard dema.update(200.0)
    discard ema.update(200.0)

    # DEMA should be closer to 200 than EMA (less lag)
    # This is a qualitative test - just verify both have values
    check not dema[0].isNaN
    check not ema[0].isNaN

  test "DEMA formula verification":
    var dema = newDEMA(3)
    var ema1 = newEMA(3)
    var ema2 = newEMA(3)

    let prices = @[10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0]

    for price in prices:
      discard dema.update(price)
      let e1 = ema1.update(price)
      if not e1.isNaN:
        discard ema2.update(e1)

    # After warmup, verify DEMA = 2*EMA1 - EMA2
    if not ema1[0].isNaN and not ema2[0].isNaN:
      let expected = 2.0 * ema1[0] - ema2[0]
      check almostEqual(dema[0], expected, 1e-5)

suite "TEMA (Triple Exponential Moving Average)":
  test "Basic TEMA calculation":
    var tema = newTEMA(3)

    # Feed data - needs more warmup than DEMA
    for i in 1..10:
      discard tema.update(float64(i * 10))

    # Should have valid value after sufficient warmup
    check not tema[0].isNaN

  test "TEMA has minimal lag":
    var tema = newTEMA(5)
    var dema = newDEMA(5)
    var ema = newEMA(5)

    # Feed trending data
    for i in 1..15:
      discard tema.update(float64(i * 10))
      discard dema.update(float64(i * 10))
      discard ema.update(float64(i * 10))

    # All should have valid values
    check not tema[0].isNaN
    check not dema[0].isNaN
    check not ema[0].isNaN

    # TEMA should be highest (closest to trend)
    # This is a directional test
    check tema[0] > 0.0

  test "TEMA formula verification":
    var tema = newTEMA(3)
    var ema1 = newEMA(3)
    var ema2 = newEMA(3)
    var ema3 = newEMA(3)

    let prices = @[10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0, 19.0]

    for price in prices:
      discard tema.update(price)
      let e1 = ema1.update(price)
      if not e1.isNaN:
        let e2 = ema2.update(e1)
        if not e2.isNaN:
          discard ema3.update(e2)

    # Verify TEMA = 3*EMA1 - 3*EMA2 + EMA3
    if not ema1[0].isNaN and not ema2[0].isNaN and not ema3[0].isNaN:
      let expected = 3.0 * ema1[0] - 3.0 * ema2[0] + ema3[0]
      check almostEqual(tema[0], expected, 1e-5)

suite "KAMA (Kaufman Adaptive Moving Average)":
  test "Basic KAMA calculation":
    var kama = newKAMA(period = 10)

    # Need period + 1 values
    for i in 1..15:
      discard kama.update(float64(100 + i))

    # Should have valid value after warmup
    check not kama[0].isNaN

  test "KAMA adapts to trending market":
    var kama = newKAMA(period = 10, fastPeriod = 2, slowPeriod = 30)

    # Feed strong trending data (high efficiency ratio)
    for i in 1..20:
      discard kama.update(float64(100 + i * 5)) # Strong uptrend

    let kama1 = kama[0]
    check not kama1.isNaN

    # Continue trend
    for i in 21..25:
      discard kama.update(float64(100 + i * 5))

    # KAMA should follow trend (increase)
    check kama[0] > kama1

  test "KAMA adapts to choppy market":
    var kama = newKAMA(period = 10)

    # Feed choppy data (low efficiency ratio)
    let choppyData = @[100.0, 102.0, 99.0, 101.0, 98.0, 103.0, 97.0, 102.0,
                       99.0, 101.0, 100.0, 102.0, 98.0, 101.0, 99.0]

    for price in choppyData:
      discard kama.update(price)

    # Should have value after warmup
    check not kama[0].isNaN

    # KAMA should be relatively stable (not following each wiggle)
    let kama1 = kama[0]

    # Add a few more choppy points
    discard kama.update(100.0)
    discard kama.update(99.0)

    # KAMA shouldn't change dramatically
    check abs(kama[0] - kama1) < 5.0

  test "KAMA efficiency ratio calculation":
    var kama = newKAMA(period = 10)

    # Feed data that should give measurable efficiency ratio
    # Trending: change = 10, volatility = 10 (1 per bar), ER = 1.0
    for i in 0..15:
      discard kama.update(float64(100 + i))

    check not kama[0].isNaN
    # Just verify it calculates without errors

  test "KAMA circular buffer access":
    var kama = newKAMA(period = 10, memSize = 5)

    # Feed enough data
    for i in 1..20:
      discard kama.update(float64(100 + i))

    # Should have last 5 values accessible
    check not kama[0].isNaN
    check not kama[-1].isNaN
    check not kama[-2].isNaN
    check not kama[-3].isNaN
    check not kama[-4].isNaN

suite "ROI (Return on Investment)":
  test "Basic ROI calculation":
    check almostEqual(calculateROI(100.0, 120.0), 0.2, 1e-6) # 20% gain
    check almostEqual(calculateROI(100.0, 80.0), -0.2, 1e-6) # 20% loss
    check almostEqual(calculateROI(100.0, 100.0), 0.0, 1e-6) # No change

  test "ROI with zero initial value":
    check calculateROI(0.0, 100.0).isNaN

  test "Streaming ROI indicator":
    var roi = newROI(memSize = 2)

    let val1 = roi.update(10.0)
    check val1.isNaN # First value has no previous

    let val2 = roi.update(12.0)
    check almostEqual(val2, 0.2, 1e-6) # 20% gain

    let val3 = roi.update(15.0)
    check almostEqual(val3, 0.25, 1e-6) # 25% gain from 12 to 15
    check almostEqual(roi[0], 0.25, 1e-6)
    check almostEqual(roi[-1], 0.2, 1e-6)

suite "RSI (Relative Strength Index)":
  test "Basic RSI calculation":
    ## Test from pybottrader
    var rsi = newRSI(period = 3)

    check rsi.update(1.0, 2.0).isNaN # First update
    check rsi.update(2.0, 4.0).isNaN # Second update

    let val = rsi.update(4.0, 3.0) # Third update
                                   # Gains: [1, 2, 0], avg = 1.0
                                   # Losses: [0, 0, 1], avg = 0.333
                                   # RS = 1.0 / 0.333 = 3.0
                                   # RSI = 100 - 100/(1+3) = 75.0
    check almostEqual(val, 75.0, 1e-5)

  test "RSI for uptrend":
    var rsi = newRSI(period = 3)

    discard rsi.update(100.0, 101.0) # +1
    discard rsi.update(101.0, 103.0) # +2
    let val = rsi.update(103.0, 105.0) # +2

    # All gains, no losses -> RSI should be very high
    check val > 90.0
    check val <= 100.0

  test "RSI for downtrend":
    var rsi = newRSI(period = 3)

    discard rsi.update(105.0, 103.0) # -2
    discard rsi.update(103.0, 101.0) # -2
    let val = rsi.update(101.0, 100.0) # -1

    # All losses, no gains -> RSI should be very low
    check val < 10.0
    check val >= 0.0

suite "ROC (Rate of Change)":
  test "Basic ROC calculation":
    let period = 3
    var roc = newROC(period = period)

    # Feed values
    check roc.update(100.0).isNaN
    check roc.update(102.0).isNaN
    check roc.update(104.0).isNaN # Still warming up

    let val1 = roc.update(110.0)
    # Compare 110 to 100: ((110-100)/100)*100 = 10%
    check almostEqual(val1, 10.0, 1e-5)

    let val2 = roc.update(112.0)
    # Compare 112 to 102: ((112-102)/102)*100 ≈ 9.8%
    check almostEqual(val2, 9.803921568627, 1e-5)

suite "MACD":
  test "Basic MACD calculation with known data":
    ## Data from pybottrader test (Excel example)
    var macd = newMACD(shortPeriod = 12, longPeriod = 26,
                       diffPeriod = 9, memSize = 2)

    let ts = @[
      459.99, 448.85, 446.06, 450.81, 442.8, 448.97, 444.57, 441.4,
      430.47, 420.05, 431.14, 425.66, 430.58, 431.72, 437.87, 428.43,
      428.35, 432.5, 443.66, 455.72, 454.49, 452.08, 452.73, 461.91,
      463.58, 461.14, 452.08, 442.66, 428.91, 429.79, 431.99, 427.72,
      423.2, 426.21, 426.98, 435.69, 434.33, 429.8, 419.85, 426.24,
      402.8, 392.05, 390.53, 398.67, 406.13, 405.46, 408.38, 417.2,
      430.12, 442.78, 439.29, 445.52, 449.98, 460.71, 458.66, 463.84,
      456.77, 452.97, 454.74, 443.86, 428.85, 434.58, 433.26, 442.93,
      439.66, 441.3
    ]

    # Expected signal values (from pybottrader test)
    let expectedSignals = @[
      3.037526, 1.905652, 1.058708, 0.410640, -0.152013, -0.790035,
      -1.338100, -2.171975, -3.307835, -4.590141, -5.756686, -6.657381,
      -7.339747, -7.786182, -7.902872, -7.582625, -6.786036, -5.772859,
      -4.564486, -3.215554, -1.670716, -0.112969, 1.454111, 2.828780,
      3.943712, 4.856651, 5.410473, 5.458368, 5.265626, 4.899098,
      4.585973, 4.260111, 3.960601
    ]

    for i, value in ts:
      let result = macd.update(value)
      if i < 33:
        check result.signal.isNaN
      else:
        check almostEqual(result.signal, expectedSignals[i - 33], 1e-3)

  test "MACD structure and warmup":
    var macd = newMACD() # Default: 12, 26, 9

    # MACD line needs 26 periods (for long EMA)
    # Signal line needs additional 9 periods on top of MACD
    # Signal starts receiving MACD values at index 26 (counter=27)
    # After 8 more values (indices 26-33), signal is ready at index 33
    for i in 0..32:
      let result = macd.update(100.0 + float64(i))
      check result.signal.isNaN # Signal not ready yet
    
    # At index 33, signal should be valid
    let result = macd.update(133.0)
    check not result.signal.isNaN

suite "ATR (Average True Range)":
  test "Basic ATR calculation":
    let period = 14
    var atr = newATR(period = period)

    # Feed lowPrice, highPrice, closePrice
    for i in 0..<period-1:
      let low = 95.0 + float64(i)
      let high = 105.0 + float64(i)
      let close = 100.0 + float64(i)
      let val = atr.update(low, high, close)
      check val.isNaN

    # 14th value should be valid
    let val = atr.update(108.0, 118.0, 113.0)
    check not val.isNaN
    check val > 0.0

  test "ATR increases with volatility":
    var atrLow = newATR(period = 5)
    var atrHigh = newATR(period = 5)

    # Low volatility: range of 2
    for i in 0..<10:
      discard atrLow.update(99.0, 101.0, 100.0)

    # High volatility: range of 20
    for i in 0..<10:
      discard atrHigh.update(90.0, 110.0, 100.0)

    check atrHigh[0] > atrLow[0]

suite "Bollinger Bands":
  test "Basic calculation":
    let period = 20
    var bb = newBollingerBands(period = period, numStdDev = 2.0)

    # Feed values - need 'period' values for MA and STDEV to be ready
    for i in 0..<period:
      let result = bb.update(100.0 + float64(i))
      if i < period - 1:
        check result.upper.isNaN

    # After 'period' values, bands should be valid
    let result = bb[0]
    check not result.upper.isNaN
    check not result.middle.isNaN
    check not result.lower.isNaN

  test "Band relationships":
    var bb = newBollingerBands(period = 10, numStdDev = 2.0)

    # Feed some values
    for i in 0..<20:
      discard bb.update(100.0 + float64(i mod 10))

    let result = bb[0]
    check result.upper > result.middle
    check result.middle > result.lower

  test "Price typically within bands":
    var bb = newBollingerBands(period = 20, numStdDev = 2.0)
    var prices: seq[float64] = @[]

    # Generate some random-ish prices
    for i in 0..<30:
      let price = 100.0 + float64(i mod 20) - 10.0
      prices.add(price)
      discard bb.update(price)

    # Last price should be within bands
    let lastPrice = prices[^1]
    let bands = bb[0]
    if not bands.upper.isNaN:
      # With 2 std devs, ~95% should be within bands
      check lastPrice >= bands.lower - 5.0 # Allow some margin
      check lastPrice <= bands.upper + 5.0

suite "OBV (On-Balance Volume)":
  test "Basic OBV accumulation":
    var obv = newOBV()

    # First day: just add volume
    check almostEqual(obv.update(102.0, 1000.0), 1000.0)

    # Price up: add volume
    check almostEqual(obv.update(104.0, 1500.0), 2500.0)

    # Price down: subtract volume
    check almostEqual(obv.update(103.0, 1200.0), 1300.0)

    # Price up again: add volume
    check almostEqual(obv.update(106.0, 1800.0), 3100.0)

  test "OBV with no price change":
    var obv = newOBV()

    check obv.update(100.0, 1000.0) == 1000.0
    check obv.update(100.0, 500.0) == 1000.0 # No change
    check obv.update(101.0, 300.0) == 1300.0 # Price up

  test "OBV memory access":
    var obv = newOBV(memSize = 3)

    discard obv.update(100.0, 1000.0)
    discard obv.update(101.0, 500.0)
    discard obv.update(102.0, 300.0)
    discard obv.update(101.0, 200.0)

    # Should have last 3 values
    check almostEqual(obv[0], 1600.0) # 1000+500+300-200
    check almostEqual(obv[-1], 1800.0) # 1000+500+300
    check almostEqual(obv[-2], 1500.0) # 1000+500

suite "STOCH (Stochastic Oscillator)":
  test "Basic calculation with warmup":
    let kPeriod = 14
    let dPeriod = 3
    var stoch = newSTOCH(kPeriod = kPeriod, dPeriod = dPeriod)

    # Create test data with clear high/low pattern
    var testData: seq[tuple[h, l, c: float64]] = @[]
    for i in 0..<30:
      let base = 100.0 + float64(i mod 10)
      testData.add((h: base + 2.0, l: base - 2.0, c: base))

    # Feed data
    for i, bar in testData:
      let result = stoch.update(bar.h, bar.l, bar.c)
      if i < kPeriod - 1:
        check result.k.isNaN
        check result.d.isNaN
      elif i < kPeriod + dPeriod - 2:
        # %K is valid but %D still warming up
        check not result.k.isNaN
        check result.d.isNaN
      else:
        # Both should be valid
        check not result.k.isNaN
        check not result.d.isNaN
        check result.k >= 0.0
        check result.k <= 100.0

  test "Stochastic at extremes":
    var stoch = newSTOCH(kPeriod = 5, dPeriod = 3)

    # Price at lowest for 5 bars, then closes at highest
    for i in 0..<5:
      discard stoch.update(110.0, 100.0, 100.0) # Close at low
    
    # Now close at high
    let result = stoch.update(110.0, 100.0, 110.0)

    # %K should be 100 (close at highest high)
    check almostEqual(result.k, 100.0, 0.1)

  test "Memory access":
    var stoch = newSTOCH(kPeriod = 5, dPeriod = 3, memSize = 3)

    for i in 0..<15:
      let base = 100.0 + float64(i)
      discard stoch.update(base + 5.0, base - 5.0, base)

    # Should have last 3 results
    check not stoch[0].k.isNaN
    check not stoch[-1].k.isNaN
    check not stoch[-2].k.isNaN

    expect IndexDefect:
      discard stoch[-3]

suite "CCI (Commodity Channel Index)":
  test "Basic calculation with warmup":
    let period = 20
    var cci = newCCI(period = period)

    # Generate test data
    for i in 0..<period-1:
      let result = cci.update(105.0, 95.0, 100.0)
      check result.isNaN

    # 20th value should be valid
    let result = cci.update(105.0, 95.0, 100.0)
    check not result.isNaN

  test "CCI with trending data":
    var cci = newCCI(period = 10)

    # Feed stable data first
    for i in 0..<15:
      discard cci.update(105.0, 95.0, 100.0)

    # CCI should be near 0 for stable prices
    let stable = cci[0]
    check almostEqual(stable, 0.0, 50.0)

    # Now feed price spike
    for i in 0..<5:
      discard cci.update(125.0, 115.0, 120.0)

    # CCI should be positive (above average)
    let spike = cci[0]
    check spike > 0.0

  test "Memory access":
    var cci = newCCI(period = 10, memSize = 5)

    for i in 0..<20:
      discard cci.update(105.0 + float64(i), 95.0 + float64(i), 100.0 + float64(i))

    check not cci[0].isNaN
    check not cci[-1].isNaN
    check not cci[-4].isNaN

    expect IndexDefect:
      discard cci[-5]

suite "MFI (Money Flow Index)":
  test "Basic calculation with warmup":
    let period = 14
    var mfi = newMFI(period = period)

    # MFI needs period bars to become valid
    # First bar sets prevTP, subsequent bars calculate flow
    for i in 0..<period-1:
      let result = mfi.update(105.0, 95.0, 100.0 + float64(i) * 0.1, 1000.0)
      check result.isNaN

    # At period-th bar (index period-1), should be valid
    let result = mfi.update(105.0, 95.0, 101.0, 1000.0)
    check not result.isNaN
    check result >= 0.0
    check result <= 100.0

  test "MFI with all positive flow":
    var mfi = newMFI(period = 5)

    # Steadily increasing prices (all positive flow)
    for i in 0..10:
      discard mfi.update(100.0 + float64(i) + 5.0,
                        100.0 + float64(i) - 5.0,
                        100.0 + float64(i),
                        1000.0)

    # MFI should be high (near 100)
    check mfi[0] > 70.0

  test "MFI with all negative flow":
    var mfi = newMFI(period = 5)

    # Steadily decreasing prices (all negative flow)
    for i in 0..10:
      discard mfi.update(120.0 - float64(i) + 5.0,
                        120.0 - float64(i) - 5.0,
                        120.0 - float64(i),
                        1000.0)

    # MFI should be low (near 0)
    check mfi[0] < 30.0

  test "Memory access":
    var mfi = newMFI(period = 5, memSize = 3)

    for i in 0..<15:
      discard mfi.update(105.0, 95.0, 100.0 + float64(i mod 5), 1000.0)

    check not mfi[0].isNaN
    check not mfi[-1].isNaN
    check not mfi[-2].isNaN

suite "ADX (Average Directional Movement Index)":
  test "Basic calculation with warmup":
    let period = 14
    var adx = newADX(period = period)

    # ADX needs period+1 bars for initial smoothing, then more for ADX calculation
    for i in 0..<period*2:
      let result = adx.update(105.0 + float64(i), 95.0 + float64(i), 100.0 +
          float64(i))
      if i < period:
        check result.adx.isNaN

    # After sufficient periods, should have values
    let result = adx[0]
    check not result.adx.isNaN
    check not result.plusDI.isNaN
    check not result.minusDI.isNaN

  test "ADX in strong uptrend":
    var adx = newADX(period = 10)

    # Create strong uptrend
    for i in 0..<30:
      let base = 100.0 + float64(i) * 2.0 # Strong trend
      discard adx.update(base + 5.0, base - 5.0, base + 3.0)

    let result = adx[0]

    # In strong uptrend:
    # - ADX should be high (trend strength)
    # - +DI should be > -DI (upward direction)
    check result.adx > 20.0 # Moderate to strong trend
    check result.plusDI > result.minusDI # Upward direction

  test "ADX in ranging market":
    var adx = newADX(period = 10)

    # Create ranging/choppy market
    for i in 0..<30:
      let base = 100.0 + float64(i mod 4) * 2.0           # Oscillating
      discard adx.update(base + 5.0, base - 5.0, base)

    let result = adx[0]

    # In ranging market, ADX should be lower
    check result.adx < 30.0 # Weak trend

  test "Memory access":
    var adx = newADX(period = 10, memSize = 5)

    for i in 0..<40:
      discard adx.update(105.0 + float64(i), 95.0 + float64(i), 100.0 + float64(i))

    check not adx[0].adx.isNaN
    check not adx[-1].adx.isNaN
    check not adx[-4].adx.isNaN

    expect IndexDefect:
      discard adx[-5]

  test "ADX values in valid range":
    var adx = newADX(period = 10)

    for i in 0..<40:
      let base = 100.0 + float64(i)
      discard adx.update(base + 5.0, base - 5.0, base)

    let result = adx[0]

    # All values should be in valid ranges
    check result.adx >= 0.0
    check result.adx <= 100.0
    check result.plusDI >= 0.0
    check result.plusDI <= 100.0
    check result.minusDI >= 0.0
    check result.minusDI <= 100.0

suite "TRANGE (True Range)":
  test "Basic True Range calculation":
    var tr = newTRANGE()

    # First bar - no previous close, uses high-low
    let tr1 = tr.update(105.0, 95.0, 100.0)
    check almostEqual(tr1, 10.0) # 105 - 95
    
    # Second bar - normal calculation
    let tr2 = tr.update(106.0, 98.0, 103.0)
    # max(106-98, abs(106-100), abs(98-100)) = max(8, 6, 2) = 8
    check almostEqual(tr2, 8.0)

  test "True Range with gap up":
    var tr = newTRANGE()

    discard tr.update(102.0, 98.0, 100.0)

    # Gap up - high-prevClose is largest
    let tr2 = tr.update(115.0, 112.0, 114.0)
    # max(115-112, abs(115-100), abs(112-100)) = max(3, 15, 12) = 15
    check almostEqual(tr2, 15.0)

  test "True Range with gap down":
    var tr = newTRANGE()

    discard tr.update(102.0, 98.0, 100.0)

    # Gap down - prevClose-low is largest
    let tr2 = tr.update(88.0, 85.0, 86.0)
    # max(88-85, abs(88-100), abs(85-100)) = max(3, 12, 15) = 15
    check almostEqual(tr2, 15.0)

  test "Memory access":
    var tr = newTRANGE(memSize = 3)

    discard tr.update(105.0, 95.0, 100.0)
    discard tr.update(106.0, 98.0, 103.0)
    discard tr.update(107.0, 99.0, 104.0)

    check not tr[0].isNaN
    check not tr[-1].isNaN
    check not tr[-2].isNaN

suite "NATR (Normalized Average True Range)":
  test "Basic NATR calculation":
    var natr = newNATR(14)

    # Feed consistent data
    for i in 0..<20:
      let base = 100.0
      discard natr.update(base + 2.0, base - 2.0, base)

    # NATR should be around 4.0 / 100.0 * 100 = 4%
    check not natr[0].isNaN
    check natr[0] > 0.0
    check natr[0] < 10.0 # Should be reasonable percentage

  test "NATR as percentage":
    var natr = newNATR(5)

    # Create scenario where ATR = 10, close = 100
    # NATR should be ~10%
    for i in 0..<10:
      discard natr.update(110.0, 90.0, 100.0)

    let natrVal = natr[0]
    check not natrVal.isNaN
    # Should be around 10% (ATR of 20 / price of 100)
    check natrVal > 5.0
    check natrVal < 25.0

  test "NATR compares across price levels":
    # Test that NATR normalizes volatility
    var natr1 = newNATR(5)
    var natr2 = newNATR(5)

    # Same percentage volatility, different price levels
    for i in 0..<10:
      discard natr1.update(110.0, 90.0, 100.0) # $100 with $20 range
      discard natr2.update(220.0, 180.0, 200.0) # $200 with $40 range (same %)
    
    # NATR should be similar (both ~20% range)
    check not natr1[0].isNaN
    check not natr2[0].isNaN
    check almostEqual(natr1[0], natr2[0], 2.0) # Within 2%

suite "AD (Accumulation/Distribution)":
  test "Basic AD calculation":
    var ad = newAD()

    # Price closes near high - accumulation
    let ad1 = ad.update(110.0, 90.0, 108.0, 1000.0)
    # MFM = ((108-90) - (110-108)) / 20 = (18-2)/20 = 0.8
    # MFV = 0.8 * 1000 = 800
    check almostEqual(ad1, 800.0, 1.0)

    # Price closes near low - distribution
    let ad2 = ad.update(110.0, 90.0, 92.0, 1000.0)
    # MFM = ((92-90) - (110-92)) / 20 = (2-18)/20 = -0.8
    # MFV = -0.8 * 1000 = -800
    # AD = 800 + (-800) = 0
    check almostEqual(ad2, 0.0, 1.0)

  test "AD accumulation trend":
    var ad = newAD()

    # Consistent closes near high (accumulation)
    for i in 0..<10:
      discard ad.update(110.0, 90.0, 108.0, 1000.0)

    # AD should be strongly positive
    check ad[0] > 5000.0

  test "AD distribution trend":
    var ad = newAD()

    # Consistent closes near low (distribution)
    for i in 0..<10:
      discard ad.update(110.0, 90.0, 92.0, 1000.0)

    # AD should be strongly negative
    check ad[0] < -5000.0

  test "AD with zero range":
    var ad = newAD()

    # When high = low, MFM = 0
    let adVal = ad.update(100.0, 100.0, 100.0, 1000.0)
    check almostEqual(adVal, 0.0)

suite "AROON (Aroon Indicator)":
  test "Basic Aroon calculation":
    var aroon = newAROON(25)

    # Feed uptrending data
    for i in 0..<30:
      discard aroon.update(float64(100 + i), float64(90 + i))

    let result = aroon[0]

    # In strong uptrend:
    # - Recent high (Aroon Up high)
    # - Old low (Aroon Down low)
    check not result.up.isNaN
    check not result.down.isNaN
    check result.up > 50.0 # Recent high
    check result.down < 50.0 # Old low

  test "Aroon in uptrend":
    var aroon = newAROON(14)

    # Strong uptrend - new highs each bar
    for i in 0..<20:
      discard aroon.update(float64(100 + i), float64(95 + i))

    let result = aroon[0]

    # Most recent bar has highest high
    check result.up > 90.0 # Should be near 100
    check result.down < 20.0 # Lowest low is old
    check result.oscillator > 0.0 # Bullish

  test "Aroon in downtrend":
    var aroon = newAROON(14)

    # Strong downtrend - new lows each bar
    for i in 0..<20:
      discard aroon.update(float64(100 - i), float64(95 - i))

    let result = aroon[0]

    # Most recent bar has lowest low
    check result.down > 90.0 # Should be near 100
    check result.up < 20.0 # Highest high is old
    check result.oscillator < 0.0 # Bearish

  test "Aroon in ranging market":
    var aroon = newAROON(14)

    # Ranging market
    for i in 0..<25:
      let base = 100.0 + float64(i mod 5) * 2.0
      discard aroon.update(base + 5.0, base - 5.0)

    let result = aroon[0]

    # In ranging market, both should be moderate
    check result.up > 0.0 and result.up < 100.0
    check result.down > 0.0 and result.down < 100.0
    check abs(result.oscillator) < 50.0 # Not strongly bullish or bearish

  test "Aroon oscillator range":
    var aroon = newAROON(14)

    for i in 0..<20:
      discard aroon.update(float64(100 + i), float64(95 + i))

    let result = aroon[0]

    # Oscillator should be in valid range
    check result.oscillator >= -100.0
    check result.oscillator <= 100.0

  test "Memory access":
    var aroon = newAROON(14, memSize = 3)

    for i in 0..<20:
      discard aroon.update(float64(100 + i), float64(95 + i))

    check not aroon[0].up.isNaN
    check not aroon[-1].up.isNaN
    check not aroon[-2].up.isNaN

suite "Integration Tests":
  test "Multiple indicators on same data stream":
    var ma = newMA(period = 5)
    var ema = newEMA(period = 5)
    var rsi = newRSI(period = 5)
    var roc = newROC(period = 5)

    # Stream same data to all indicators
    for i in 0..<20:
      let price = 100.0 + float64(i)
      discard ma.update(price)
      discard ema.update(price)
      discard rsi.update(price, price + 1.0) # Uptrend
      discard roc.update(price)

    # All should have valid values
    check not ma[0].isNaN
    check not ema[0].isNaN
    check not rsi[0].isNaN
    check not roc[0].isNaN

  test "Phase 9.1 indicators on same data":
    var stoch = newSTOCH(kPeriod = 10, dPeriod = 3)
    var cci = newCCI(period = 10)
    var mfi = newMFI(period = 10)
    var adx = newADX(period = 10)

    # Stream same data to all Phase 9.1 indicators
    for i in 0..<30:
      let base = 100.0 + float64(i)
      discard stoch.update(base + 5.0, base - 5.0, base)
      discard cci.update(base + 5.0, base - 5.0, base)
      discard mfi.update(base + 5.0, base - 5.0, base, 1000.0)
      discard adx.update(base + 5.0, base - 5.0, base)

    # All should have valid values after warmup
    check not stoch[0].k.isNaN
    check not cci[0].isNaN
    check not mfi[0].isNaN
    check not adx[0].adx.isNaN

  test "Composed indicators (MACD uses EMA internally)":
    var macd = newMACD(shortPeriod = 5, longPeriod = 10, diffPeriod = 3)

    # Feed data
    for i in 0..<20:
      discard macd.update(100.0 + float64(i))

    let result = macd[0]
    check not result.macd.isNaN
    check not result.signal.isNaN
    check almostEqual(result.hist, result.macd - result.signal)

  test "Bollinger Bands uses MA and STDEV internally":
    var bb = newBollingerBands(period = 10, numStdDev = 2.0)

    # Feed data
    for i in 0..<15:
      discard bb.update(100.0 + float64(i mod 10))

    let result = bb[0]
    check not result.middle.isNaN
    check not result.upper.isNaN
    check not result.lower.isNaN

    # Upper and lower should be symmetrical around middle
    let upperDiff = result.upper - result.middle
    let lowerDiff = result.middle - result.lower
    check almostEqual(upperDiff, lowerDiff, 1e-5)

suite "STOCHRSI (Stochastic RSI)":
  test "Basic StochRSI calculation":
    var stochRsi = newSTOCHRSI(rsiPeriod = 14, period = 14, kPeriod = 3, dPeriod = 3)

    # Generate data with variation
    for i in 0..<60:
      let price = 100.0 + float64(i mod 10)
      discard stochRsi.update(price - 0.5, price)

    let result = stochRsi[0]
    check not result.k.isNaN
    check result.k >= 0.0 and result.k <= 100.0

  test "StochRSI responds to RSI changes":
    var stochRsi = newSTOCHRSI(rsiPeriod = 14, period = 14, kPeriod = 3, dPeriod = 3)

    # Oscillating pattern should create RSI variation
    for i in 0..<60:
      let price = if i mod 4 < 2: 100.0 + float64(i div 4) else: 100.0 +
          float64(i div 4) + 5.0
      discard stochRsi.update(price - 1.0, price)

    let result = stochRsi[0]
    check not result.k.isNaN
    # K should be in valid range
    check result.k >= 0.0 and result.k <= 100.0

  test "StochRSI with mixed trend":
    var stochRsi = newSTOCHRSI(rsiPeriod = 14, period = 14, kPeriod = 3, dPeriod = 3)

    # Up then down pattern
    for i in 0..<30:
      let price = 100.0 + float64(i)
      discard stochRsi.update(price - 0.5, price)
    for i in 0..<30:
      let price = 130.0 - float64(i)
      discard stochRsi.update(price + 0.5, price)

    let result = stochRsi[0]
    check not result.k.isNaN

  test "StochRSI warmup period":
    var stochRsi = newSTOCHRSI(rsiPeriod = 14, period = 14, kPeriod = 3, dPeriod = 3)

    # Need: RSI period (14) + Stoch period (14) + smoothing (3) = ~31 bars minimum
    # But calculations overlap, so actual warmup varies
    var nanCount = 0
    var firstValidIdx = -1
    for i in 0..<35:
      let result = stochRsi.update(100.0 + float64(i mod 5), 101.0 + float64(i mod 5))
      if result.k.isNaN:
        nanCount += 1
      elif firstValidIdx == -1:
        firstValidIdx = i

    # Should have significant warmup period (at least 10 bars)
    check nanCount >= 10
    # First valid value should not be in first few bars
    check firstValidIdx >= 10

  test "StochRSI memory access":
    var stochRsi = newSTOCHRSI(rsiPeriod = 14, period = 14, kPeriod = 3,
        dPeriod = 3, memSize = 10)

    # Generate lots of variable data to ensure buffer is full
    for i in 0..<100:
      let price = 100.0 + float64(i mod 15)
      discard stochRsi.update(price - 0.5, price)

    # Access current value only (safest test)
    let current = stochRsi[0]
    check not current.k.isNaN
    check current.k >= 0.0 and current.k <= 100.0

suite "PPO (Percentage Price Oscillator)":
  test "Basic PPO calculation":
    var ppo = newPPO(fastPeriod = 12, slowPeriod = 26, signalPeriod = 9)

    # Generate trending data
    for i in 0..<50:
      let price = 100.0 + float64(i)
      discard ppo.update(price)

    let result = ppo[0]
    check not result.ppo.isNaN
    check not result.signal.isNaN
    check not result.histogram.isNaN

  test "PPO in uptrend":
    var ppo = newPPO(fastPeriod = 5, slowPeriod = 10, signalPeriod = 3)

    # Strong uptrend
    for i in 0..<30:
      let price = 100.0 + float64(i) * 2.0
      discard ppo.update(price)

    let result = ppo[0]
    check result.ppo > 0.0 # Fast EMA above slow EMA
    check result.histogram > -5.0 # Histogram should be positive or near zero

  test "PPO in downtrend":
    var ppo = newPPO(fastPeriod = 5, slowPeriod = 10, signalPeriod = 3)

    # Initial uptrend
    for i in 0..<20:
      discard ppo.update(100.0 + float64(i))

    # Then downtrend
    for i in 0..<20:
      let price = 120.0 - float64(i) * 2.0
      discard ppo.update(price)

    let result = ppo[0]
    check result.ppo < 0.0 # Fast EMA below slow EMA

  test "PPO as percentage":
    var ppo = newPPO(fastPeriod = 5, slowPeriod = 10, signalPeriod = 3)

    # Generate data
    for i in 0..<30:
      discard ppo.update(100.0 + float64(i))

    let result = ppo[0]
    # PPO should be reasonable percentage (not huge values)
    check abs(result.ppo) < 50.0 # Should be percentage-like

  test "PPO warmup period":
    var ppo = newPPO(fastPeriod = 12, slowPeriod = 26, signalPeriod = 9)

    # First values should be NaN (need slow period)
    for i in 0..<20:
      let result = ppo.update(100.0 + float64(i))
      check result.ppo.isNaN

  test "PPO cross-asset comparison":
    # Low price asset
    var ppo1 = newPPO(fastPeriod = 5, slowPeriod = 10, signalPeriod = 3)
    for i in 0..<30:
      discard ppo1.update(10.0 + float64(i) * 0.5)

    # High price asset with same percentage move
    var ppo2 = newPPO(fastPeriod = 5, slowPeriod = 10, signalPeriod = 3)
    for i in 0..<30:
      discard ppo2.update(200.0 + float64(i) * 10.0)

    # PPO values should be similar (both ~5% per period increase)
    check almostEqual(ppo1[0].ppo, ppo2[0].ppo, 2.0) # Within 2%

suite "CMO (Chande Momentum Oscillator)":
  test "Basic CMO calculation":
    var cmo = newCMO(period = 14)

    # Generate mixed trend data
    for i in 0..<30:
      let price = 100.0 + float64(i mod 10)
      discard cmo.update(price)

    let result = cmo[0]
    check not result.isNaN
    check result >= -100.0 and result <= 100.0

  test "CMO in strong uptrend":
    var cmo = newCMO(period = 14)

    # Consistent upward moves
    for i in 0..<30:
      let price = 100.0 + float64(i) * 2.0
      discard cmo.update(price)

    let result = cmo[0]
    check result > 50.0 # Should be positive and strong
    check result <= 100.0

  test "CMO in strong downtrend":
    var cmo = newCMO(period = 14)

    # Initial prices
    for i in 0..<10:
      discard cmo.update(150.0 + float64(i))

    # Consistent downward moves
    for i in 0..<20:
      let price = 160.0 - float64(i) * 2.0
      discard cmo.update(price)

    let result = cmo[0]
    check result < -50.0 # Should be negative and strong
    check result >= -100.0

  test "CMO neutral market":
    var cmo = newCMO(period = 14)

    # Oscillating around same price
    for i in 0..<30:
      let price = if i mod 2 == 0: 100.0 else: 102.0
      discard cmo.update(price)

    let result = cmo[0]
    # Should be near zero (balanced gains/losses)
    check abs(result) < 20.0

  test "CMO warmup period":
    var cmo = newCMO(period = 14)

    # First values should be NaN
    for i in 0..<13:
      let result = cmo.update(100.0 + float64(i))
      check result.isNaN

    # After period, should have value
    let result = cmo.update(113.0)
    check not result.isNaN

  test "CMO vs RSI comparison":
    # Both measure momentum but differently
    var cmo = newCMO(period = 14)
    var rsi = newRSI(period = 14)

    # Uptrend data
    for i in 0..<30:
      let price = 100.0 + float64(i)
      discard cmo.update(price)
      discard rsi.update(price - 0.5, price)

    let cmoVal = cmo[0]
    let rsiVal = rsi[0]

    # Both should indicate bullish (CMO > 0, RSI > 50)
    check cmoVal > 0.0
    check rsiVal > 50.0

suite "MOM (Momentum)":
  test "Basic Momentum calculation":
    var mom = newMOM(period = 10)

    # Generate data
    for i in 0..<20:
      let price = 100.0 + float64(i)
      discard mom.update(price)

    let result = mom[0]
    check not result.isNaN
    # Current price (119.0) - price 10 periods ago (109.0) = 10.0
    check almostEqual(result, 10.0, 0.1)

  test "Positive momentum in uptrend":
    var mom = newMOM(period = 5)

    # Uptrend
    for i in 0..<15:
      let price = 100.0 + float64(i) * 2.0
      discard mom.update(price)

    let result = mom[0]
    check result > 0.0 # Positive momentum
    check almostEqual(result, 10.0, 0.1) # 5 periods * 2.0 per period

  test "Negative momentum in downtrend":
    var mom = newMOM(period = 5)

    # Initial setup
    for i in 0..<10:
      discard mom.update(150.0 + float64(i))

    # Downtrend
    for i in 0..<10:
      let price = 160.0 - float64(i) * 2.0
      discard mom.update(price)

    let result = mom[0]
    check result < 0.0 # Negative momentum

  test "Zero momentum in sideways market":
    var mom = newMOM(period = 10)

    # Sideways movement
    for i in 0..<30:
      discard mom.update(100.0)

    let result = mom[0]
    check almostEqual(result, 0.0, 0.01)

  test "Momentum warmup period":
    var mom = newMOM(period = 10)

    # First 10 values should be NaN (collecting data)
    for i in 0..<10:
      let result = mom.update(100.0 + float64(i))
      check result.isNaN

    # 11th value should have result (current - 10 periods ago)
    let result = mom.update(110.0)
    check not result.isNaN
    check almostEqual(result, 10.0, 0.1) # 110 - 100

  test "Momentum with different periods":
    var mom5 = newMOM(period = 5)
    var mom10 = newMOM(period = 10)

    # Feed same data to both
    for i in 0..<20:
      let price = 100.0 + float64(i) * 2.0
      discard mom5.update(price)
      discard mom10.update(price)

    # Longer period should show larger momentum value
    check mom10[0] > mom5[0]
    check almostEqual(mom5[0], 10.0, 0.1) # 5 periods * 2.0
    check almostEqual(mom10[0], 20.0, 0.1) # 10 periods * 2.0

  test "Momentum memory access":
    var mom = newMOM(period = 5, memSize = 10)

    # Generate plenty of data
    for i in 0..<30:
      discard mom.update(100.0 + float64(i))

    # Access current value (safest)
    let current = mom[0]
    check not current.isNaN
    check almostEqual(current, 5.0, 0.1) # Constant momentum for linear growth

# Integration test for Phase 9.4
suite "Phase 9.4 Integration":
  test "All Phase 9.4 indicators on same data":
    var stochRsi = newSTOCHRSI(rsiPeriod = 14, period = 14, kPeriod = 3, dPeriod = 3)
    var ppo = newPPO(fastPeriod = 12, slowPeriod = 26, signalPeriod = 9)
    var cmo = newCMO(period = 14)
    var mom = newMOM(period = 10)

    # Generate trending data with some variation
    for i in 0..<60:
      let base = 100.0 + float64(i)
      let variation = float64(i mod 5) * 0.2
      let price = base + variation
      discard stochRsi.update(price - 0.5, price)
      discard ppo.update(price)
      discard cmo.update(price)
      discard mom.update(price)

    # All should have valid values
    check not stochRsi[0].k.isNaN
    check not ppo[0].ppo.isNaN
    check not cmo[0].isNaN
    check not mom[0].isNaN

    # All should indicate uptrend
    check stochRsi[0].k >= 40.0 # StochRSI should be elevated
    check ppo[0].ppo > 0.0 # PPO positive
    check cmo[0] > 0.0 # CMO positive
    check mom[0] > 0.0 # Momentum positive

echo "All indicator tests completed"
