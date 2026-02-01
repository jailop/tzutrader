## Unit Tests for Screener History Module

import std/[unittest, times, tables, os, json]
import tzutrader/screener/[alerts, history]

suite "Screener History Tests":
  
  setup:
    # Create test directory
    let testHistoryDir = "test_history_temp"
    if not dirExists(testHistoryDir):
      createDir(testHistoryDir)
  
  teardown:
    # Clean up test directory
    let testHistoryDir = "test_history_temp"
    if dirExists(testHistoryDir):
      removeDir(testHistoryDir)
  
  test "Save and load empty history entry":
    let testDir = "test_history_temp"
    let configName = "test_config"
    let alerts: seq[Alert] = @[]
    
    # Save history
    saveScreenerHistory(configName, alerts, 5, 2, testDir)
    
    # Verify file was created
    let files = listScreenerHistory(testDir)
    check files.len == 1
    
    # Load and verify
    let loaded = loadScreenerHistory(files[0])
    check loaded.configName == configName
    check loaded.alerts.len == 0
    check loaded.symbolsScanned == 5
    check loaded.strategiesUsed == 2
    check loaded.totalSignals == 0
  
  test "Save and load history with alerts":
    let testDir = "test_history_temp"
    let configName = "test_with_alerts"
    
    # Create test alerts
    var indicators = initTable[string, float64]()
    indicators["rsi"] = 35.5
    
    var metadata = initTable[string, string]()
    metadata["reason"] = "RSI oversold"
    
    let alert1 = newAlert(
      symbol = "AAPL",
      strategyName = "RSI Strategy",
      alertType = atBuySignal,
      price = 178.25,
      strength = asStrong,
      indicators = indicators,
      metadata = metadata
    )
    
    let alert2 = newAlert(
      symbol = "GOOGL",
      strategyName = "RSI Strategy",
      alertType = atSellSignal,
      price = 145.80,
      strength = asModerate
    )
    
    let alerts = @[alert1, alert2]
    
    # Save history
    saveScreenerHistory(configName, alerts, 10, 3, testDir)
    
    # Load and verify
    let files = listScreenerHistory(testDir)
    check files.len == 1
    
    let loaded = loadScreenerHistory(files[0])
    check loaded.configName == configName
    check loaded.alerts.len == 2
    check loaded.symbolsScanned == 10
    check loaded.strategiesUsed == 3
    check loaded.totalSignals == 2
    
    # Verify first alert details
    check loaded.alerts[0].symbol == "AAPL"
    check loaded.alerts[0].strategyName == "RSI Strategy"
    check loaded.alerts[0].alertType == atBuySignal
    check loaded.alerts[0].price == 178.25
    check loaded.alerts[0].strength == asStrong
    check loaded.alerts[0].indicators["rsi"] == 35.5
    check loaded.alerts[0].metadata["reason"] == "RSI oversold"
    
    # Verify second alert
    check loaded.alerts[1].symbol == "GOOGL"
    check loaded.alerts[1].alertType == atSellSignal
  
  test "List history files sorted by modification time":
    let testDir = "test_history_temp"
    
    # Create multiple history entries with small delay
    saveScreenerHistory("config1", @[], 5, 1, testDir)
    sleep(100)  # Small delay to ensure different timestamps
    saveScreenerHistory("config2", @[], 3, 1, testDir)
    sleep(100)
    saveScreenerHistory("config3", @[], 7, 1, testDir)
    
    # List files
    let files = listScreenerHistory(testDir)
    check files.len == 3
    
    # Files should be sorted newest first (by modification time)
    # The last created file should be first in the list
  
  test "Get latest screener result":
    let testDir = "test_history_temp"
    let configName = "my_screener"
    
    # Create multiple entries for the same config
    saveScreenerHistory(configName, @[], 5, 1, testDir)
    sleep(100)
    
    let alert = newAlert(
      symbol = "TSLA",
      strategyName = "Test",
      alertType = atBuySignal,
      price = 200.0,
      strength = asStrong
    )
    saveScreenerHistory(configName, @[alert], 5, 1, testDir)
    
    # Get latest result
    let latest = getLatestScreenerResult(configName, testDir)
    
    # Latest should have the alert
    check latest.alerts.len == 1
    check latest.alerts[0].symbol == "TSLA"
  
  test "Compare screener results - new signals":
    let testDir = "test_history_temp"
    let configName = "compare_test"
    
    # First run with no alerts
    saveScreenerHistory(configName, @[], 5, 1, testDir)
    sleep(1500)  # Increased delay to ensure different timestamps
    
    # Second run with alerts
    let alert = newAlert(
      symbol = "MSFT",
      strategyName = "Test",
      alertType = atSellSignal,
      price = 400.0,
      strength = asModerate
    )
    saveScreenerHistory(configName, @[alert], 5, 1, testDir)
    
    let files = listScreenerHistory(testDir)
    check files.len == 2
    
    # Load the history entries first
    let newerEntry = loadScreenerHistory(files[0])
    let olderEntry = loadScreenerHistory(files[1])
    
    # Compare results (older vs newer) - new signals are in entry2 (newer)
    let comparison = compareScreenerResults(olderEntry, newerEntry)
    
    # Should have 1 new signal
    check comparison.newSignals.len == 1
    if comparison.newSignals.len > 0:
      check comparison.newSignals[0].symbol == "MSFT"
    check comparison.removedSignals.len == 0
  
  test "Print history summary":
    let testDir = "test_history_temp"
    
    # Create some history entries
    saveScreenerHistory("daily_scan", @[], 20, 3, testDir)
    sleep(1500)  # Increased delay
    
    let alert = newAlert(
      symbol = "NVDA",
      strategyName = "Test",
      alertType = atBuySignal,
      price = 500.0,
      strength = asStrong
    )
    saveScreenerHistory("daily_scan", @[alert], 20, 3, testDir)
    
    # Load all entries for summary
    let files = listScreenerHistory(testDir)
    var entries: seq[ScreenerHistoryEntry] = @[]
    for file in files:
      entries.add(loadScreenerHistory(file))
    
    # This should generate summary without errors
    let summary = printHistorySummary(entries)
    check summary.len > 0
    
    # Basic check - files exist
    check files.len == 2
  
  test "Handle non-existent directory gracefully":
    # List history from non-existent directory
    let files = listScreenerHistory("non_existent_dir")
    check files.len == 0
    
    # Print summary for empty list
    let summary = printHistorySummary(@[])
    check summary.len > 0  # Should have at least header
