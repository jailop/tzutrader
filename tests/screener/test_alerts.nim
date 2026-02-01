## Unit Tests for Alert Data Structures and Operations

import std/[unittest, times, tables, json, strutils]
import tzutrader/core
import tzutrader/screener/alerts

suite "Alert Creation Tests":
  
  test "Create basic alert":
    let alert = newAlert(
      symbol = "AAPL",
      strategyName = "RSI Strategy",
      alertType = atBuySignal,
      price = 150.50,
      strength = asStrong
    )
    
    check alert.symbol == "AAPL"
    check alert.strategyName == "RSI Strategy"
    check alert.alertType == atBuySignal
    check alert.price == 150.50
    check alert.strength == asStrong
    check alert.indicators.len == 0
    check alert.metadata.len == 0
  
  test "Create alert with indicators":
    var indicators = initTable[string, float64]()
    indicators["rsi"] = 28.5
    indicators["ema_20"] = 148.75
    
    let alert = newAlert(
      symbol = "MSFT",
      strategyName = "RSI Mean Reversion",
      alertType = atBuySignal,
      price = 380.25,
      indicators = indicators
    )
    
    check alert.indicators.len == 2
    check alert.indicators["rsi"] == 28.5
    check alert.indicators["ema_20"] == 148.75
  
  test "Create alert with metadata":
    var metadata = initTable[string, string]()
    metadata["reason"] = "RSI oversold"
    metadata["confidence"] = "high"
    
    let alert = newAlert(
      symbol = "GOOGL",
      strategyName = "Technical Screener",
      alertType = atBuySignal,
      price = 140.00,
      metadata = metadata
    )
    
    check alert.metadata.len == 2
    check alert.metadata["reason"] == "RSI oversold"
    check alert.metadata["confidence"] == "high"
  
  test "Create alert from Signal":
    # Create a buy signal
    let buySignal = Signal(
      symbol: "TSLA",
      timestamp: getTime().toUnix(),
      position: Buy,
      price: 250.00,
      reason: "Bullish crossover"
    )
    
    var indicators = initTable[string, float64]()
    indicators["macd"] = 1.5
    
    let alert = newAlertFromSignal(buySignal, "MACD Strategy", asStrong, indicators)
    
    check alert.symbol == "TSLA"
    check alert.alertType == atBuySignal
    check alert.price == 250.00
    check alert.strength == asStrong
    check alert.strategyName == "MACD Strategy"
    check alert.metadata["reason"] == "Bullish crossover"
    check alert.indicators["macd"] == 1.5
  
  test "Create alert from Sell signal":
    let sellSignal = Signal(
      symbol: "NVDA",
      timestamp: getTime().toUnix(),
      position: Sell,
      price: 500.00,
      reason: "Bearish divergence"
    )
    
    let alert = newAlertFromSignal(sellSignal, "Divergence Detector", asModerate)
    
    check alert.alertType == atSellSignal
    check alert.strength == asModerate
  
  test "Create alert from Stay signal":
    let staySignal = Signal(
      symbol: "AMD",
      timestamp: getTime().toUnix(),
      position: Stay,
      price: 150.00,
      reason: ""
    )
    
    let alert = newAlertFromSignal(staySignal, "Trend Follower")
    
    check alert.alertType == atNeutral
  
  test "Create AlertCollection":
    let alert1 = newAlert("AAPL", "Strategy1", atBuySignal, 150.0)
    let alert2 = newAlert("MSFT", "Strategy2", atSellSignal, 380.0)
    
    let collection = newAlertCollection(@[alert1, alert2], 10, 3)
    
    check collection.alerts.len == 2
    check collection.totalSymbols == 10
    check collection.totalStrategies == 3

suite "Alert Filtering Tests":
  
  setup:
    # Create test alerts
    let alert1 = newAlert("AAPL", "RSI", atBuySignal, 150.0, asStrong)
    let alert2 = newAlert("MSFT", "MACD", atSellSignal, 380.0, asModerate)
    let alert3 = newAlert("GOOGL", "RSI", atBuySignal, 140.0, asWeak)
    let alert4 = newAlert("TSLA", "Bollinger", atSellSignal, 250.0, asStrong)
    let alert5 = newAlert("NVDA", "RSI", atNeutral, 500.0, asModerate)
    let alerts = @[alert1, alert2, alert3, alert4, alert5]
  
  test "Filter by alert type - buy signals":
    let buyAlerts = filterByType(alerts, @[atBuySignal])
    
    check buyAlerts.len == 2
    check buyAlerts[0].symbol == "AAPL"
    check buyAlerts[1].symbol == "GOOGL"
  
  test "Filter by alert type - sell signals":
    let sellAlerts = filterByType(alerts, @[atSellSignal])
    
    check sellAlerts.len == 2
    check sellAlerts[0].symbol == "MSFT"
    check sellAlerts[1].symbol == "TSLA"
  
  test "Filter by alert type - multiple types":
    let filtered = filterByType(alerts, @[atBuySignal, atSellSignal])
    
    check filtered.len == 4  # Excludes neutral
  
  test "Filter by strength - strong only":
    let strongAlerts = filterByStrength(alerts, asStrong)
    
    check strongAlerts.len == 2
    check strongAlerts[0].symbol == "AAPL"
    check strongAlerts[1].symbol == "TSLA"
  
  test "Filter by strength - moderate and above":
    let filtered = filterByStrength(alerts, asModerate)
    
    check filtered.len == 4  # Excludes weak
  
  test "Filter by strength - weak and above":
    let filtered = filterByStrength(alerts, asWeak)
    
    check filtered.len == 5  # All alerts
  
  test "Filter by symbol - single":
    let filtered = filterBySymbol(alerts, @["AAPL"])
    
    check filtered.len == 1
    check filtered[0].symbol == "AAPL"
  
  test "Filter by symbol - multiple":
    let filtered = filterBySymbol(alerts, @["AAPL", "MSFT", "TSLA"])
    
    check filtered.len == 3
  
  test "Filter by strategy":
    let rsiAlerts = filterByStrategy(alerts, @["RSI"])
    
    check rsiAlerts.len == 3
    check rsiAlerts[0].strategyName == "RSI"
    check rsiAlerts[1].strategyName == "RSI"
    check rsiAlerts[2].strategyName == "RSI"

suite "Alert Sorting Tests":
  
  setup:
    var alert1 = newAlert("AAPL", "RSI", atBuySignal, 150.0, asWeak)
    var alert2 = newAlert("MSFT", "MACD", atSellSignal, 380.0, asStrong)
    var alert3 = newAlert("GOOGL", "RSI", atBuySignal, 140.0, asModerate)
    var alert4 = newAlert("TSLA", "Bollinger", atSellSignal, 250.0, asStrong)
    
    # Set different timestamps
    alert1.timestamp = fromUnix(1000)
    alert2.timestamp = fromUnix(2000)
    alert3.timestamp = fromUnix(3000)
    alert4.timestamp = fromUnix(4000)
  
  test "Sort by strength - descending":
    var testAlerts = @[alert1, alert2, alert3, alert4]
    sortByStrength(testAlerts)  # Default: descending
    
    check testAlerts[0].strength == asStrong
    check testAlerts[1].strength == asStrong
    check testAlerts[2].strength == asModerate
    check testAlerts[3].strength == asWeak
  
  test "Sort by strength - ascending":
    var testAlerts = @[alert1, alert2, alert3, alert4]
    sortByStrength(testAlerts, ascending = true)
    
    check testAlerts[0].strength == asWeak
    check testAlerts[3].strength == asStrong
  
  test "Sort by symbol":
    var testAlerts = @[alert1, alert2, alert3, alert4]
    sortBySymbol(testAlerts)
    
    check testAlerts[0].symbol == "AAPL"
    check testAlerts[1].symbol == "GOOGL"
    check testAlerts[2].symbol == "MSFT"
    check testAlerts[3].symbol == "TSLA"
  
  test "Sort by price - ascending":
    var testAlerts = @[alert1, alert2, alert3, alert4]
    sortByPrice(testAlerts, ascending = true)
    
    check testAlerts[0].price == 140.0
    check testAlerts[1].price == 150.0
    check testAlerts[2].price == 250.0
    check testAlerts[3].price == 380.0
  
  test "Sort by price - descending":
    var testAlerts = @[alert1, alert2, alert3, alert4]
    sortByPrice(testAlerts, ascending = false)
    
    check testAlerts[0].price == 380.0
    check testAlerts[3].price == 140.0
  
  test "Sort by timestamp - most recent first":
    var testAlerts = @[alert1, alert2, alert3, alert4]
    sortByTimestamp(testAlerts)  # Default: descending
    
    check testAlerts[0].timestamp == fromUnix(4000)
    check testAlerts[3].timestamp == fromUnix(1000)
  
  test "Sort by timestamp - oldest first":
    var testAlerts = @[alert1, alert2, alert3, alert4]
    sortByTimestamp(testAlerts, ascending = true)
    
    check testAlerts[0].timestamp == fromUnix(1000)
    check testAlerts[3].timestamp == fromUnix(4000)

suite "Alert Utility Tests":
  
  setup:
    let alert1 = newAlert("AAPL", "RSI", atBuySignal, 150.0, asStrong)
    let alert2 = newAlert("MSFT", "MACD", atSellSignal, 380.0, asModerate)
    let alert3 = newAlert("GOOGL", "RSI", atBuySignal, 140.0, asWeak)
    let alert4 = newAlert("TSLA", "Bollinger", atSellSignal, 250.0, asStrong)
    let alert5 = newAlert("NVDA", "RSI", atNeutral, 500.0, asModerate)
    let alerts = @[alert1, alert2, alert3, alert4, alert5]
  
  test "Get top N alerts":
    let top3 = topN(alerts, 3)
    
    check top3.len == 3
    check top3[0].symbol == "AAPL"
    check top3[1].symbol == "MSFT"
    check top3[2].symbol == "GOOGL"
  
  test "Get top N when N > total":
    let top10 = topN(alerts, 10)
    
    check top10.len == 5  # Only 5 alerts total
  
  test "Get top N when N = 0":
    let top0 = topN(alerts, 0)
    
    check top0.len == 0
  
  test "Count by type":
    let counts = countByType(alerts)
    
    check counts[atBuySignal] == 2
    check counts[atSellSignal] == 2
    check counts[atNeutral] == 1
  
  test "Count by strength":
    let counts = countByStrength(alerts)
    
    check counts[asStrong] == 2
    check counts[asModerate] == 2
    check counts[asWeak] == 1

suite "Alert String Representation Tests":
  
  test "AlertType to string":
    check $atBuySignal == "BUY"
    check $atSellSignal == "SELL"
    check $atExitLong == "EXIT LONG"
    check $atExitShort == "EXIT SHORT"
    check $atNeutral == "NEUTRAL"
  
  test "AlertStrength to string":
    check $asWeak == "WEAK"
    check $asModerate == "MODERATE"
    check $asStrong == "STRONG"
  
  test "Alert to string":
    let alert = newAlert("AAPL", "RSI Strategy", atBuySignal, 150.50, asStrong)
    let str = $alert
    
    check "AAPL" in str
    check "RSI Strategy" in str
    check "BUY" in str
    check "STRONG" in str

suite "Alert JSON Serialization Tests":
  
  test "Alert to JSON":
    var indicators = initTable[string, float64]()
    indicators["rsi"] = 28.5
    
    var metadata = initTable[string, string]()
    metadata["reason"] = "oversold"
    
    let alert = newAlert(
      "AAPL", 
      "RSI Strategy", 
      atBuySignal, 
      150.50, 
      asStrong,
      indicators,
      metadata
    )
    
    let json = alert.toJson()
    
    check json["symbol"].getStr() == "AAPL"
    check json["strategy"].getStr() == "RSI Strategy"
    check json["type"].getStr() == "BUY"
    check json["strength"].getStr() == "STRONG"
    check json["price"].getFloat() == 150.50
    check json["indicators"]["rsi"].getFloat() == 28.5
    check json["metadata"]["reason"].getStr() == "oversold"
  
  test "AlertCollection to JSON":
    let alert1 = newAlert("AAPL", "RSI", atBuySignal, 150.0, asStrong)
    let alert2 = newAlert("MSFT", "MACD", atSellSignal, 380.0, asModerate)
    
    let collection = newAlertCollection(@[alert1, alert2], 10, 3)
    let json = collection.toJson()
    
    check json["total_symbols"].getInt() == 10
    check json["total_strategies"].getInt() == 3
    check json["total_alerts"].getInt() == 2
    check json["alerts"].len == 2

suite "Combined Filter and Sort Tests":
  
  test "Filter then sort":
    let alert1 = newAlert("AAPL", "RSI", atBuySignal, 150.0, asStrong)
    let alert2 = newAlert("MSFT", "MACD", atSellSignal, 380.0, asModerate)
    let alert3 = newAlert("GOOGL", "RSI", atBuySignal, 140.0, asWeak)
    let alert4 = newAlert("TSLA", "Bollinger", atBuySignal, 250.0, asStrong)
    let alerts = @[alert1, alert2, alert3, alert4]
    
    # Filter for buy signals only
    var buySignals = filterByType(alerts, @[atBuySignal])
    check buySignals.len == 3
    
    # Then sort by strength
    sortByStrength(buySignals)
    
    # Should have strong alerts first
    check buySignals[0].strength == asStrong
    check buySignals[1].strength == asStrong
    check buySignals[2].strength == asWeak
  
  test "Multiple filters then top N":
    let alert1 = newAlert("AAPL", "RSI", atBuySignal, 150.0, asStrong)
    let alert2 = newAlert("MSFT", "MACD", atSellSignal, 380.0, asModerate)
    let alert3 = newAlert("GOOGL", "RSI", atBuySignal, 140.0, asWeak)
    let alert4 = newAlert("TSLA", "Bollinger", atBuySignal, 250.0, asStrong)
    let alert5 = newAlert("NVDA", "RSI", atBuySignal, 500.0, asModerate)
    let alerts = @[alert1, alert2, alert3, alert4, alert5]
    
    # Filter by type
    var filtered = filterByType(alerts, @[atBuySignal])
    check filtered.len == 4
    
    # Filter by strength
    filtered = filterByStrength(filtered, asModerate)
    check filtered.len == 3  # Excludes weak
    
    # Sort by price descending
    sortByPrice(filtered, ascending = false)
    
    # Get top 2
    let top2 = topN(filtered, 2)
    check top2.len == 2
    check top2[0].price == 500.0  # NVDA
    check top2[1].price == 250.0  # TSLA
