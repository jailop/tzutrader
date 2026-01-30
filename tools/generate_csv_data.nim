## CSV Data Generator
## 
## Generates sample CSV files for testing and examples

import std/[times, random, os]

include ../src/tzutrader/core
include ../src/tzutrader/data

proc generateTrendingData(basePrice: float, bars: int, trend: float = 0.001): seq[OHLCV] =
  ## Generate trending price data
  ## trend > 0 = uptrend, trend < 0 = downtrend, trend = 0 = sideways
  result = newSeq[OHLCV](bars)
  randomize()
  
  var price = basePrice
  let startTime = parse("2023-01-01", "yyyy-MM-dd").toTime.toUnix
  
  for i in 0..<bars:
    # Add trend and some randomness
    let dailyChange = price * trend + rand(-1.0..1.0)
    price = price + dailyChange
    
    # Generate OHLC around the close price
    let volatility = price * 0.02  # 2% daily volatility
    let open = price + rand(-volatility..volatility)
    let high = max(open, price) + rand(0.0..volatility)
    let low = min(open, price) - rand(0.0..volatility)
    let volume = rand(1_000_000.0..10_000_000.0)
    
    result[i] = OHLCV(
      timestamp: startTime + (i * 86400),  # Daily bars
      open: open,
      high: high,
      low: low,
      close: price,
      volume: volume
    )

proc generateVolatileData(basePrice: float, bars: int, volatility: float = 0.05): seq[OHLCV] =
  ## Generate volatile sideways price data
  result = newSeq[OHLCV](bars)
  randomize()
  
  var price = basePrice
  let startTime = parse("2023-01-01", "yyyy-MM-dd").toTime.toUnix
  
  for i in 0..<bars:
    # Random walk with mean reversion
    let change = rand(-volatility..volatility) * price
    price = basePrice + change  # Mean revert to base price
    
    let dailyVol = price * volatility
    let open = price + rand(-dailyVol..dailyVol)
    let high = max(open, price) + rand(0.0..dailyVol)
    let low = min(open, price) - rand(0.0..dailyVol)
    let volume = rand(1_000_000.0..10_000_000.0)
    
    result[i] = OHLCV(
      timestamp: startTime + (i * 86400),
      open: open,
      high: high,
      low: low,
      close: price,
      volume: volume
    )

proc generateCyclicalData(basePrice: float, bars: int, cycleLength: int = 20): seq[OHLCV] =
  ## Generate cyclical/oscillating price data
  result = newSeq[OHLCV](bars)
  randomize()
  
  let startTime = parse("2023-01-01", "yyyy-MM-dd").toTime.toUnix
  let amplitude = basePrice * 0.2  # 20% swing
  
  for i in 0..<bars:
    # Sine wave pattern
    let phase = (i.float / cycleLength.float) * 2.0 * PI
    let cyclicalValue = sin(phase) * amplitude
    let price = basePrice + cyclicalValue + rand(-5.0..5.0)
    
    let volatility = price * 0.01
    let open = price + rand(-volatility..volatility)
    let high = max(open, price) + rand(0.0..volatility)
    let low = min(open, price) - rand(0.0..volatility)
    let volume = rand(1_000_000.0..10_000_000.0)
    
    result[i] = OHLCV(
      timestamp: startTime + (i * 86400),
      open: open,
      high: high,
      low: low,
      close: price,
      volume: volume
    )

# ============================================================================
# Main: Generate sample CSV files
# ============================================================================

echo "Generating sample CSV files..."

# Create data directory if it doesn't exist
let dataDir = "data"
if not dirExists(dataDir):
  createDir(dataDir)
  echo "Created directory: ", dataDir

# 1. Strong uptrend - good for trend-following strategies
echo "\n1. Generating AAPL.csv (strong uptrend, 250 bars)..."
let aaplData = generateTrendingData(150.0, 250, 0.002)  # +0.2% daily
writeCSV(aaplData, dataDir / "AAPL.csv")
echo "   Price: $150.00 -> $", aaplData[^1].close.formatFloat(ffDecimal, 2)
echo "   Gain: ", ((aaplData[^1].close - 150.0) / 150.0 * 100).formatFloat(ffDecimal, 2), "%"

# 2. Moderate uptrend - realistic stock behavior
echo "\n2. Generating MSFT.csv (moderate uptrend, 250 bars)..."
let msftData = generateTrendingData(300.0, 250, 0.0008)  # +0.08% daily
writeCSV(msftData, dataDir / "MSFT.csv")
echo "   Price: $300.00 -> $", msftData[^1].close.formatFloat(ffDecimal, 2)
echo "   Gain: ", ((msftData[^1].close - 300.0) / 300.0 * 100).formatFloat(ffDecimal, 2), "%"

# 3. Downtrend - test short strategies
echo "\n3. Generating BEAR.csv (downtrend, 250 bars)..."
let bearData = generateTrendingData(100.0, 250, -0.001)  # -0.1% daily
writeCSV(bearData, dataDir / "BEAR.csv")
echo "   Price: $100.00 -> $", bearData[^1].close.formatFloat(ffDecimal, 2)
echo "   Loss: ", ((bearData[^1].close - 100.0) / 100.0 * 100).formatFloat(ffDecimal, 2), "%"

# 4. Sideways/choppy - test mean reversion strategies
echo "\n4. Generating SIDEWAYS.csv (volatile sideways, 250 bars)..."
let sidewaysData = generateVolatileData(50.0, 250, 0.03)
writeCSV(sidewaysData, dataDir / "SIDEWAYS.csv")
echo "   Price: $50.00 -> $", sidewaysData[^1].close.formatFloat(ffDecimal, 2)
echo "   Change: ", ((sidewaysData[^1].close - 50.0) / 50.0 * 100).formatFloat(ffDecimal, 2), "%"

# 5. Cyclical - test oscillator strategies (RSI, Stochastic)
echo "\n5. Generating CYCLE.csv (cyclical, 250 bars)..."
let cycleData = generateCyclicalData(75.0, 250, 30)
writeCSV(cycleData, dataDir / "CYCLE.csv")
echo "   Price: $75.00 -> $", cycleData[^1].close.formatFloat(ffDecimal, 2)
echo "   Range: ~", (75.0 * 0.8).formatFloat(ffDecimal, 2), " - ", (75.0 * 1.2).formatFloat(ffDecimal, 2)

# 6. Short dataset for quick tests
echo "\n6. Generating TEST.csv (short dataset, 50 bars)..."
let testData = generateTrendingData(100.0, 50, 0.001)
writeCSV(testData, dataDir / "TEST.csv")
echo "   Price: $100.00 -> $", testData[^1].close.formatFloat(ffDecimal, 2)

# 7. Long dataset for comprehensive backtests
echo "\n7. Generating LONG.csv (5 years daily, 1260 bars)..."
let longData = generateTrendingData(200.0, 1260, 0.0005)  # ~5 years
writeCSV(longData, dataDir / "LONG.csv")
echo "   Price: $200.00 -> $", longData[^1].close.formatFloat(ffDecimal, 2)
echo "   Gain: ", ((longData[^1].close - 200.0) / 200.0 * 100).formatFloat(ffDecimal, 2), "%"
echo "   ~", (1260 / 252).formatFloat(ffDecimal, 1), " years of data"

echo "\n" & "=" .repeat(70)
echo "CSV files generated successfully in ", dataDir, "/ directory"
echo "=" .repeat(70)
echo "\nFiles:"
echo "  - AAPL.csv      : Strong uptrend (trend-following strategies)"
echo "  - MSFT.csv      : Moderate uptrend (realistic stock behavior)"
echo "  - BEAR.csv      : Downtrend (short strategies, risk management)"
echo "  - SIDEWAYS.csv  : Volatile sideways (mean reversion strategies)"
echo "  - CYCLE.csv     : Cyclical (oscillator strategies)"
echo "  - TEST.csv      : Short dataset (quick tests)"
echo "  - LONG.csv      : Long dataset (comprehensive backtests)"
echo "\nUsage in your code:"
echo "  let stream = newCSVDataStream(\"data/AAPL.csv\")"
echo "  for bar in stream.items():"
echo "    echo bar"
