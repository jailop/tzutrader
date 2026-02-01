## Quick test to see the actual output

import std/[tables, times, options]
import ../../src/tzutrader/screener/[reports, schema]
import ../../src/tzutrader/screener/alerts as alertsMod
import ../../src/tzutrader/core

let alert1 = newAlert(
  symbol = "AAPL",
  strategyName = "RSI Mean Reversion",
  alertType = atBuySignal,
  price = 178.25,
  strength = asStrong,
  indicators = {"RSI": 28.3, "Price": 178.25}.toTable,
  metadata = {"reason": "RSI oversold"}.toTable
)

let alert2 = newAlert(
  symbol = "TSLA",
  strategyName = "MACD Crossover",
  alertType = atBuySignal,
  price = 235.67,
  strength = asModerate,
  indicators = {"MACD": 0.45, "Signal": 0.30}.toTable
)

let alert3 = newAlert(
  symbol = "GOOGL",
  strategyName = "Bollinger Breakout",
  alertType = atSellSignal,
  price = 142.80,
  strength = asWeak,
  indicators = {"Upper": 145.0, "Lower": 140.0}.toTable
)

let alerts = @[alert1, alert2, alert3]

echo "=== Detailed Table ==="
let table = formatTerminalTable(alerts, dlDetailed)
echo table

echo "\n=== Detailed Alerts ==="
let detailed = printDetailedAlerts(alerts)
echo detailed
