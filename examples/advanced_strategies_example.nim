## Advanced Trading Strategies Using Phase 9 Indicators
##
## This example demonstrates sophisticated trading strategies that leverage
## the advanced indicators from Phase 9.2, 9.3, and 9.4.
##
## Strategies covered:
## 1. Trend Strength Filter - Uses KAMA, StochRSI, and ADX
## 2. Momentum Rotation - Uses PPO and AROON for multi-asset comparison
## 3. Volatility-Adjusted Sizing - Uses NATR for position sizing
## 4. Momentum Divergence - Uses MOM and CMO for divergence detection

import ../src/tzutrader/indicators
import std/[math, tables, sequtils, strformat, strutils]

proc printSeparator(title: string) =
  echo "\n", "=".repeat(70)
  echo title
  echo "=".repeat(70)

proc printSubSection(title: string) =
  echo "\n", "-".repeat(70)
  echo title
  echo "-".repeat(70)

# Helper for formatting table rows
proc formatRow(values: varargs[string]): string =
  result = ""
  for i, val in values:
    if i > 0:
      result.add(" ")
    result.add(val)

proc pad(s: string, width: int, alignRight: bool = false): string =
  if s.len >= width:
    return s
  let padding = width - s.len
  if alignRight:
    result = spaces(padding) & s
  else:
    result = s & spaces(padding)

# ============================================================================
# Strategy 1: Trend Strength Filter with Adaptive Entry
# ============================================================================
# This strategy combines:
# - KAMA for adaptive trend following (responds to volatility)
# - StochRSI for precise entry timing (oversold/overbought in trend)
# - ADX for trend strength confirmation (only trade strong trends)
#
# Logic:
# - Only enter when ADX > 25 (strong trend)
# - Enter long when: price > KAMA and StochRSI %K < 20 (oversold in uptrend)
# - Exit when: StochRSI %K > 80 (overbought) or price < KAMA (trend breaks)

proc demonstrateTrendStrengthStrategy() =
  printSeparator("Strategy 1: Trend Strength Filter with Adaptive Entry")
  
  echo "\nConcept: Only trade during strong trends, use oversold/overbought for timing"
  echo "Indicators: KAMA (trend), StochRSI (timing), ADX (strength)"
  
  # Initialize indicators
  var kama = newKAMA(period = 10, fastPeriod = 2, slowPeriod = 30)
  var stochRsi = newSTOCHRSI(rsiPeriod = 14, period = 14, kPeriod = 3, dPeriod = 3)
  var adx = newADX(period = 14)
  
  # Simulate market data: strong uptrend with pullbacks
  var prices: seq[float64] = @[]
  var highs: seq[float64] = @[]
  var lows: seq[float64] = @[]
  var opens: seq[float64] = @[]
  
  # Phase 1: Accumulation (weak trend)
  for i in 0..<20:
    let price = 100.0 + float64(i) * 0.3 + float64(i mod 3) * 0.5
    prices.add(price)
    opens.add(price - 0.2)
    highs.add(price + 0.5)
    lows.add(price - 0.5)
  
  # Phase 2: Strong uptrend with pullbacks (should trigger entry)
  for i in 0..<30:
    let trend = 100.0 + float64(20 + i) * 0.8
    let pullback = if i mod 7 in [3, 4]: -2.0 else: 0.0  # Pullbacks every 7 bars
    let price = trend + pullback
    prices.add(price)
    opens.add(price - 0.3)
    highs.add(price + 1.0)
    lows.add(price - 1.0)
  
  # Phase 3: Top formation (weak momentum, should exit)
  for i in 0..<15:
    let price = 140.0 + float64(i) * 0.2 + float64(i mod 4) * 0.3
    prices.add(price)
    opens.add(price - 0.2)
    highs.add(price + 0.4)
    lows.add(price - 0.4)
  
  var inPosition = false
  var entryPrice = 0.0
  var entryBar = 0
  var trades: seq[tuple[entry: int, exit: int, profit: float64]] = @[]
  
  printSubSection("Processing Market Data")
  echo pad("Bar", 6) & pad("Price", 10, true) & pad("KAMA", 10, true) & pad("StochRSI", 10, true) & pad("ADX", 10, true) & pad("Signal", 14, true)
  echo "-".repeat(70)
  
  for i in 0..<prices.len:
    let kamaVal = kama.update(prices[i])
    let stochRsiVal = stochRsi.update(opens[i], prices[i])
    let adxVal = adx.update(highs[i], lows[i], prices[i])
    
    var signal = "HOLD"
    
    # Entry logic
    if not inPosition and i > 30:  # Allow warmup
      if not adxVal.adx.isNaN and adxVal.adx > 25.0:
        if prices[i] > kamaVal and not stochRsiVal.k.isNaN and stochRsiVal.k < 20.0:
          inPosition = true
          entryPrice = prices[i]
          entryBar = i
          signal = ">>> BUY <<<"
    
    # Exit logic
    elif inPosition:
      if not stochRsiVal.k.isNaN and stochRsiVal.k > 80.0:
        inPosition = false
        let profit = ((prices[i] - entryPrice) / entryPrice) * 100.0
        trades.add((entry: entryBar, exit: i, profit: profit))
        signal = "<<< SELL"
      elif prices[i] < kamaVal:
        inPosition = false
        let profit = ((prices[i] - entryPrice) / entryPrice) * 100.0
        trades.add((entry: entryBar, exit: i, profit: profit))
        signal = "<<< STOP"
    
    # Print important bars
    if signal != "HOLD" or i mod 10 == 0:
      let kamaStr = if kamaVal.isNaN: "warmup" else: formatFloat(kamaVal, ffDecimal, 2)
      let stochStr = if stochRsiVal.k.isNaN: "warmup" else: formatFloat(stochRsiVal.k, ffDecimal, 1)
      let adxStr = if adxVal.adx.isNaN: "warmup" else: formatFloat(adxVal.adx, ffDecimal, 1)
      let priceStr = formatFloat(prices[i], ffDecimal, 2)
      echo pad($i, 6) & pad(priceStr, 10, true) & pad(kamaStr, 10, true) & pad(stochStr, 10, true) & pad(adxStr, 10, true) & pad(signal, 14, true)
  
  printSubSection("Trade Summary")
  echo "Total Trades: " & $trades.len
  for i, trade in trades:
    let profitStr = formatFloat(trade.profit, ffDecimal, 2)
    let profitSign = if trade.profit >= 0: "+" else: ""
    echo "Trade " & $(i+1) & ": Entry bar " & $trade.entry & ", Exit bar " & $trade.exit & ", P&L: " & profitSign & profitStr & "%"
  
  if trades.len > 0:
    let totalProfit = trades.mapIt(it.profit).foldl(a + b, 0.0)
    let avgProfit = totalProfit / float64(trades.len)
    let winningTrades = trades.filterIt(it.profit > 0).len
    let winRate = float64(winningTrades) / float64(trades.len) * 100.0
    let totalProfitSign = if totalProfit >= 0: "+" else: ""
    let avgProfitSign = if avgProfit >= 0: "+" else: ""
    echo "\nTotal P&L: " & totalProfitSign & formatFloat(totalProfit, ffDecimal, 2) & "%"
    echo "Average P&L per trade: " & avgProfitSign & formatFloat(avgProfit, ffDecimal, 2) & "%"
    echo "Win Rate: " & formatFloat(winRate, ffDecimal, 1) & "% (" & $winningTrades & "/" & $trades.len & ")"
  
  echo "\nStrategy Insight:"
  echo "  - ADX filter prevents trading in choppy markets (Phase 1)"
  echo "  - StochRSI catches pullbacks in strong trends (Phase 2)"
  echo "  - Multiple exit conditions protect profits (Phase 3)"

# ============================================================================
# Strategy 2: Multi-Asset Momentum Rotation
# ============================================================================
# This strategy rotates capital into the strongest momentum asset
# Combines:
# - PPO for normalized momentum comparison across different price levels
# - AROON for trend confirmation (only trade assets in confirmed uptrends)
#
# Logic:
# - Calculate PPO for each asset (momentum as percentage)
# - Calculate AROON for each asset (trend confirmation)
# - Select asset with highest PPO where AROON-up > 70
# - Rotate when another asset shows stronger momentum

proc demonstrateMomentumRotation() =
  printSeparator("Strategy 2: Multi-Asset Momentum Rotation")
  
  echo "\nConcept: Rotate capital into the strongest momentum asset"
  echo "Indicators: PPO (normalized momentum), AROON (trend confirmation)"
  
  # Three assets with different characteristics
  let symbols = @["TECH", "ENERGY", "FINANCE"]
  var ppoIndicators = initTable[string, PPO]()
  var aroonIndicators = initTable[string, AROON]()
  
  for symbol in symbols:
    ppoIndicators[symbol] = newPPO(fastPeriod = 12, slowPeriod = 26, signalPeriod = 9)
    aroonIndicators[symbol] = newAROON(period = 25)
  
  # Generate market data for 3 assets with rotating leadership
  var prices = initTable[string, seq[float64]]()
  var highs = initTable[string, seq[float64]]()
  var lows = initTable[string, seq[float64]]()
  
  # Period 1 (0-20): TECH leads
  # Period 2 (21-40): ENERGY leads  
  # Period 3 (41-60): FINANCE leads
  
  for i in 0..<60:
    # TECH: Strong in period 1, weak later
    let techTrend = if i < 20: 1.0 else: 0.1
    let techPrice = 100.0 + float64(i) * techTrend
    prices.mgetOrPut("TECH", @[]).add(techPrice)
    highs.mgetOrPut("TECH", @[]).add(techPrice + 0.5)
    lows.mgetOrPut("TECH", @[]).add(techPrice - 0.5)
    
    # ENERGY: Weak in period 1, strong in period 2, weak in period 3
    let energyTrend = if i >= 20 and i < 40: 1.2 else: 0.1
    let energyBase = 100.0 + (if i < 20: float64(i) * 0.1 else: float64(i - 20) * 1.2 + 2.0)
    let energyPrice = if i < 40: energyBase else: energyBase + float64(i - 40) * 0.1
    prices.mgetOrPut("ENERGY", @[]).add(energyPrice)
    highs.mgetOrPut("ENERGY", @[]).add(energyPrice + 0.5)
    lows.mgetOrPut("ENERGY", @[]).add(energyPrice - 0.5)
    
    # FINANCE: Weak early, strong in period 3
    let financeTrend = if i >= 40: 1.3 else: 0.1
    let financeBase = 100.0 + (if i < 40: float64(i) * 0.1 else: float64(i - 40) * 1.3 + 4.0)
    prices.mgetOrPut("FINANCE", @[]).add(financeBase)
    highs.mgetOrPut("FINANCE", @[]).add(financeBase + 0.5)
    lows.mgetOrPut("FINANCE", @[]).add(financeBase - 0.5)
  
  var currentHolding = ""
  var rotations: seq[tuple[bar: int, fromSymbol: string, toSymbol: string]] = @[]
  
  printSubSection("Monitoring Multi-Asset Momentum")
  echo pad("Bar", 6) & pad("Asset", 10, true) & pad("Price", 10, true) & pad("PPO", 10, true) & pad("AROON", 10, true) & pad("Action", 14, true)
  echo "-".repeat(70)
  
  for i in 0..<60:
    var bestSymbol = ""
    var bestPPO = -Inf
    var ppoValues = initTable[string, float64]()
    
    # Update all indicators and find strongest
    for symbol in symbols:
      let ppoVal = ppoIndicators[symbol].update(prices[symbol][i])
      let aroonVal = aroonIndicators[symbol].update(highs[symbol][i], lows[symbol][i])
      
      ppoValues[symbol] = ppoVal.ppo
      
      # Only consider assets in confirmed uptrends
      if not aroonVal.up.isNaN and aroonVal.up > 70.0:
        if not ppoVal.ppo.isNaN and ppoVal.ppo > bestPPO:
          bestPPO = ppoVal.ppo
          bestSymbol = symbol
    
    # Rotation logic
    if i > 25 and bestSymbol != "" and bestSymbol != currentHolding:  # Allow warmup
      if currentHolding == "":
        rotations.add((bar: i, fromSymbol: "CASH", toSymbol: bestSymbol))
      else:
        rotations.add((bar: i, fromSymbol: currentHolding, toSymbol: bestSymbol))
      currentHolding = bestSymbol
    
    # Print rotation bars and periodic updates
    if rotations.len > 0 and rotations[^1].bar == i:
      let rotation = rotations[^1]
      echo "\n" & pad($i, 6) & " ROTATION: " & rotation.fromSymbol & " -> " & rotation.toSymbol
      echo "-".repeat(70)
    
    if i > 25 and (i mod 5 == 0 or (rotations.len > 0 and rotations[^1].bar == i)):
      for symbol in symbols:
        let ppoStr = if symbol in ppoValues and not ppoValues[symbol].isNaN: 
                      formatFloat(ppoValues[symbol], ffDecimal, 2) else: "warmup"
        let aroonVal = aroonIndicators[symbol][0]
        let aroonStr = if not aroonVal.up.isNaN: formatFloat(aroonVal.up, ffDecimal, 0) else: "warmup"
        let action = if symbol == currentHolding: ">>> HOLD" else: ""
        let priceStr = formatFloat(prices[symbol][i], ffDecimal, 2)
        echo pad($i, 6) & pad(symbol, 10, true) & pad(priceStr, 10, true) & pad(ppoStr, 10, true) & pad(aroonStr, 10, true) & pad(action, 14, true)
  
  printSubSection("Rotation Summary")
  echo "Total Rotations: " & $rotations.len
  for i, rotation in rotations:
    echo "Rotation " & $(i+1) & " at bar " & $rotation.bar & ": " & rotation.fromSymbol & " -> " & rotation.toSymbol
  
  echo "\nStrategy Insight:"
  echo "  - PPO normalizes momentum across different price levels"
  echo "  - AROON > 70 confirms uptrend before entering"
  echo "  - Rotations capture leadership changes between sectors"
  echo "  - Avoid trading assets in weak trends (AROON < 70)"

# ============================================================================
# Strategy 3: Volatility-Adjusted Position Sizing
# ============================================================================
# This strategy adjusts position size based on volatility
# Uses NATR (Normalized ATR) to scale positions inversely with volatility
#
# Logic:
# - NATR measures volatility as percentage of price
# - Higher volatility = smaller position (lower risk)
# - Lower volatility = larger position (higher risk)
# - Target constant risk per trade (e.g., 2% of account)

proc demonstrateVolatilityAdjusted() =
  printSeparator("Strategy 3: Volatility-Adjusted Position Sizing")
  
  echo "\nConcept: Scale position size inversely with volatility"
  echo "Indicator: NATR (Normalized Average True Range)"
  echo "Goal: Maintain consistent risk per trade regardless of market conditions"
  
  var natr = newNATR(period = 14)
  var rsi = newRSI(period = 14)
  
  # Simulate two market regimes: low volatility then high volatility
  var prices: seq[float64] = @[]
  var highs: seq[float64] = @[]
  var lows: seq[float64] = @[]
  var opens: seq[float64] = @[]
  
  # Period 1: Low volatility (bars 0-30)
  for i in 0..<30:
    let price = 100.0 + float64(i) * 0.3
    prices.add(price)
    opens.add(price - 0.1)
    highs.add(price + 0.2)  # Small range
    lows.add(price - 0.2)
  
  # Period 2: High volatility (bars 30-60)
  for i in 0..<30:
    let base = 109.0 + float64(i) * 0.5
    let volatility = float64(i mod 3) * 2.0  # Larger swings
    let price = base + volatility
    prices.add(price)
    opens.add(price - 0.5)
    highs.add(price + 1.5)  # Large range
    lows.add(price - 1.5)
  
  const accountSize = 100000.0
  const targetRiskPercent = 2.0  # Risk 2% per trade
  const baseShares = 1000  # Starting position size
  
  var trades: seq[tuple[bar: int, price: float64, natr: float64, shares: int, riskAmount: float64]] = @[]
  
  printSubSection("Position Sizing Based on Volatility")
  echo "Account Size: $" & formatFloat(accountSize, ffDecimal, 0)
  let targetRiskDollars = accountSize * targetRiskPercent / 100.0
  echo "Target Risk per Trade: " & formatFloat(targetRiskPercent, ffDecimal, 0) & "% ($" & formatFloat(targetRiskDollars, ffDecimal, 0) & ")"
  echo ""
  echo pad("Bar", 6) & pad("Price", 10, true) & pad("NATR %", 10, true) & pad("Shares", 10, true) & pad("Position", 12, true) & pad("Risk $", 12, true)
  echo "-".repeat(70)
  
  for i in 0..<prices.len:
    let natrVal = natr.update(highs[i], lows[i], prices[i])
    let rsiVal = rsi.update(opens[i], prices[i])
    
    # Generate trade signals (simple RSI strategy)
    if not rsiVal.isNaN and i > 14:
      if rsiVal < 30 or rsiVal > 70:  # Trade signal
        if not natrVal.isNaN and natrVal > 0:
          # Calculate position size: inverse relationship with volatility
          # shares = (accountSize * targetRiskPercent / 100) / (price * natrVal / 100)
          let targetRiskDollars = accountSize * targetRiskPercent / 100.0
          let priceRisk = prices[i] * (natrVal / 100.0)  # Expected price move
          let shares = int(targetRiskDollars / priceRisk)
          
          let positionValue = float64(shares) * prices[i]
          let actualRisk = float64(shares) * priceRisk
          
          trades.add((bar: i, price: prices[i], natr: natrVal, shares: shares, riskAmount: actualRisk))
          
          let priceStr = formatFloat(prices[i], ffDecimal, 2)
          let natrStr = formatFloat(natrVal, ffDecimal, 2)
          let posStr = formatFloat(positionValue, ffDecimal, 0)
          let riskStr = formatFloat(actualRisk, ffDecimal, 0)
          echo pad($i, 6) & pad(priceStr, 10, true) & pad(natrStr, 10, true) & pad($shares, 10, true) & pad("$" & posStr, 12, true) & pad("$" & riskStr, 12, true)
  
  printSubSection("Volatility Regime Analysis")
  
  # Analyze low volatility period
  let lowVolTrades = trades.filterIt(it.bar < 30)
  if lowVolTrades.len > 0:
    let avgShares = lowVolTrades.mapIt(float64(it.shares)).foldl(a + b, 0.0) / float64(lowVolTrades.len)
    let avgNatr = lowVolTrades.mapIt(it.natr).foldl(a + b, 0.0) / float64(lowVolTrades.len)
    echo "Low Volatility Period (bars 0-30):"
    echo "  Average NATR: " & formatFloat(avgNatr, ffDecimal, 2) & "%"
    echo "  Average Position Size: " & formatFloat(avgShares, ffDecimal, 0) & " shares"
  
  # Analyze high volatility period
  let highVolTrades = trades.filterIt(it.bar >= 30)
  if highVolTrades.len > 0:
    let avgShares = highVolTrades.mapIt(float64(it.shares)).foldl(a + b, 0.0) / float64(highVolTrades.len)
    let avgNatr = highVolTrades.mapIt(it.natr).foldl(a + b, 0.0) / float64(highVolTrades.len)
    echo "High Volatility Period (bars 30-60):"
    echo "  Average NATR: " & formatFloat(avgNatr, ffDecimal, 2) & "%"
    echo "  Average Position Size: " & formatFloat(avgShares, ffDecimal, 0) & " shares"
  
  echo "\nStrategy Insight:"
  echo "  - NATR normalizes volatility across different price levels"
  echo "  - Lower position size in high volatility protects capital"
  echo "  - Higher position size in low volatility maximizes opportunity"
  echo "  - Consistent risk per trade improves risk management"

# ============================================================================
# Strategy 4: Momentum Divergence Detection
# ============================================================================
# This strategy identifies divergences between price and momentum
# Combines:
# - MOM (Momentum) to track absolute momentum
# - CMO (Chande Momentum Oscillator) for confirmation
#
# Logic:
# - Bearish divergence: Price makes higher high, momentum makes lower high
# - Bullish divergence: Price makes lower low, momentum makes higher low
# - CMO confirms the divergence (must be on correct side of zero)

proc demonstrateDivergenceDetection() =
  printSeparator("Strategy 4: Momentum Divergence Detection")
  
  echo "\nConcept: Identify divergences between price and momentum"
  echo "Indicators: MOM (momentum), CMO (confirmation)"
  echo "Types: Bearish divergence (top), Bullish divergence (bottom)"
  
  var mom = newMOM(period = 10)
  var cmo = newCMO(period = 14)
  
  # Simulate market with divergences
  var prices: seq[float64] = @[]
  var momValues: seq[float64] = @[]
  var cmoValues: seq[float64] = @[]
  
  # Phase 1: Strong uptrend (bars 0-25)
  for i in 0..<25:
    prices.add(100.0 + float64(i) * 1.5)
  
  # Phase 2: Bearish divergence - price makes higher high, momentum weakens (bars 25-35)
  for i in 0..<10:
    let weakGain = 137.5 + float64(i) * 0.3  # Slower gains
    prices.add(weakGain)
  
  # Phase 3: Decline (bars 35-50)
  for i in 0..<15:
    prices.add(140.5 - float64(i) * 1.0)
  
  # Phase 4: Bullish divergence - price makes lower low, momentum improving (bars 50-60)
  for i in 0..<10:
    let lessDrop = 125.5 - float64(i) * 0.2  # Slower declines
    prices.add(lessDrop)
  
  # Phase 5: Recovery (bars 60-75)
  for i in 0..<15:
    prices.add(123.5 + float64(i) * 0.8)
  
  printSubSection("Analyzing Price and Momentum")
  echo pad("Bar", 6) & pad("Price", 10, true) & pad("MOM", 10, true) & pad("CMO", 10, true) & pad("Signal", 22, true)
  echo "-".repeat(70)
  
  var signals: seq[tuple[bar: int, signalType: string, price: float64]] = @[]
  
  for i in 0..<prices.len:
    let momVal = mom.update(prices[i])
    let cmoVal = cmo.update(prices[i])
    
    momValues.add(momVal)
    cmoValues.add(cmoVal)
    
    var signal = ""
    
    # Look for divergences after sufficient data
    if i >= 20:
      # Check last 10 bars for divergence patterns
      let recentBars = 10
      let lookbackBars = 10
      
      if i >= 20 + lookbackBars:
        # Recent highs/lows
        let recentPriceHigh = max(prices[i-recentBars+1..i])
        let recentMomHigh = max(momValues[i-recentBars+1..i])
        let recentPriceLow = min(prices[i-recentBars+1..i])
        let recentMomLow = min(momValues[i-recentBars+1..i])
        
        # Previous highs/lows
        let prevPriceHigh = max(prices[i-recentBars-lookbackBars+1..i-recentBars])
        let prevMomHigh = max(momValues[i-recentBars-lookbackBars+1..i-recentBars])
        let prevPriceLow = min(prices[i-recentBars-lookbackBars+1..i-recentBars])
        let prevMomLow = min(momValues[i-recentBars-lookbackBars+1..i-recentBars])
        
        # Bearish divergence: price higher high, momentum lower high
        if recentPriceHigh > prevPriceHigh and recentMomHigh < prevMomHigh:
          if not cmoVal.isNaN and cmoVal < 0:  # CMO confirms weakness
            signal = "BEARISH DIVERGENCE"
            if signals.len == 0 or signals[^1].bar < i - 5:  # Avoid duplicate signals
              signals.add((bar: i, signalType: "BEARISH", price: prices[i]))
        
        # Bullish divergence: price lower low, momentum higher low
        elif recentPriceLow < prevPriceLow and recentMomLow > prevMomLow:
          if not cmoVal.isNaN and cmoVal > 0:  # CMO confirms strength
            signal = "BULLISH DIVERGENCE"
            if signals.len == 0 or signals[^1].bar < i - 5:
              signals.add((bar: i, signalType: "BULLISH", price: prices[i]))
    
    # Print interesting bars
    if signal != "" or i mod 10 == 0:
      let momStr = if momVal.isNaN: "warmup" else: formatFloat(momVal, ffDecimal, 2)
      let cmoStr = if cmoVal.isNaN: "warmup" else: formatFloat(cmoVal, ffDecimal, 1)
      let priceStr = formatFloat(prices[i], ffDecimal, 2)
      echo pad($i, 6) & pad(priceStr, 10, true) & pad(momStr, 10, true) & pad(cmoStr, 10, true) & pad(signal, 22, true)
  
  printSubSection("Divergence Signals Summary")
  echo "Total Divergence Signals: " & $signals.len
  for i, sig in signals:
    let priceStr = formatFloat(sig.price, ffDecimal, 2)
    echo "Signal " & $(i+1) & " at bar " & $sig.bar & ": " & sig.signalType & " divergence at price " & priceStr
  
  # Analyze signal quality
  if signals.len > 0:
    echo "\nSignal Analysis:"
    for sig in signals:
      let futureMove = if sig.bar + 10 < prices.len:
        prices[sig.bar + 10] - sig.price
      else:
        0.0
      
      let expectedDirection = if sig.signalType == "BEARISH": "down" else: "up"
      let actualDirection = if futureMove < 0: "down" else: "up"
      let correct = expectedDirection == actualDirection
      let movementSign = if futureMove >= 0: "+" else: ""
      let movementStr = formatFloat(futureMove, ffDecimal, 2)
      let correctStr = if correct: "CORRECT" else: "WRONG"
      
      echo "  " & sig.signalType & " at bar " & $sig.bar & ": Price moved " & movementSign & movementStr & " (" & actualDirection & ") - " & correctStr
  
  echo "\nStrategy Insight:"
  echo "  - Bearish divergence warns of trend exhaustion at tops"
  echo "  - Bullish divergence signals potential reversal at bottoms"
  echo "  - CMO confirmation reduces false signals"
  echo "  - Early warning system for trend changes"

# ============================================================================
# Main Program
# ============================================================================

when isMainModule:
  echo """
╔══════════════════════════════════════════════════════════════════════╗
║                                                                      ║
║              TzuTrader Advanced Strategy Examples                   ║
║                                                                      ║
║           Leveraging Phase 9 Advanced Indicators                    ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝

This example demonstrates four sophisticated trading strategies that use
the advanced indicators implemented in Phase 9.2, 9.3, and 9.4:

  1. Trend Strength Filter - KAMA + StochRSI + ADX
  2. Momentum Rotation - PPO + AROON  
  3. Volatility-Adjusted Sizing - NATR
  4. Momentum Divergence - MOM + CMO

Each strategy showcases practical applications of these indicators in
realistic trading scenarios.
"""

  # Run all demonstrations
  demonstrateTrendStrengthStrategy()
  demonstrateMomentumRotation()
  demonstrateVolatilityAdjusted()
  demonstrateDivergenceDetection()
  
  printSeparator("Summary")
  echo """
Advanced indicators enable sophisticated multi-factor strategies:

  ✓ KAMA adapts to market volatility for better trend following
  ✓ StochRSI provides precise entry timing in trends
  ✓ ADX filters out weak, choppy markets
  ✓ PPO normalizes momentum for cross-asset comparison
  ✓ AROON confirms trend direction and strength
  ✓ NATR enables consistent risk management across volatility regimes
  ✓ MOM and CMO detect momentum divergences early

These strategies can be combined and customized for your specific trading
objectives, timeframes, and risk tolerance.

Next Steps:
  - Review the indicator documentation in docs/reference_guide/
  - Backtest these strategies with your historical data
  - Combine multiple signals for higher conviction trades
  - Adjust parameters based on your asset class and timeframe
"""
