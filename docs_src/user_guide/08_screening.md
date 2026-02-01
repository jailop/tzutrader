# Market Screener User Guide

## What is a Market Screener?

A market screener is a tool that automatically scans multiple financial
instruments (stocks, cryptocurrencies, etc.) across one or more trading
strategies to identify potential trading opportunities right now.

### Screener vs. Backtest

| Feature | Backtesting | Screening |
|---------|------------|-----------|
| Purpose | Test strategy performance over history | Find current trading opportunities |
| Output | Historical performance metrics | Latest signals and alerts |
| Timeframe | Past data (days/months/years) | Most recent data (latest bars) |
| Use Case | Strategy evaluation & optimization | Daily/weekly opportunity discovery |
| Symbols | Usually 1 symbol at a time | Many symbols simultaneously |

Example:
- Backtest: "How would RSI strategy have performed on AAPL in 2023?"
- Screen: "Which stocks are currently showing RSI oversold signals?"

---

## Quick Start

### 1. Create a Simple Screener Configuration

Create `my_first_screener.yml`:

```yaml
metadata:
  name: "My First Screener"
  description: "Find oversold stocks"
  author: "Your Name"

strategies:
  - kind: built_in
    name: rsi
    params:
      period: 14
      oversold: 30
      overbought: 70

data:
  source: yahoo
  symbols:
    - AAPL
    - MSFT
    - GOOGL
    - TSLA
    - NVDA
  lookback: 90d
  interval: 1d

output:
  format: terminal
  detail_level: detailed

filters:
  signal_types:
    - buy_signal
    - sell_signal
  min_strength: moderate
```

### 2. Run the Screener

```bash
tzu --screen=my_first_screener.yml
```

### 3. Understand the Output

```
Fetching market data...
Loaded data for 5 symbols
Scanning symbols...
  Scanning AAPL... (61 bars)
  Scanning MSFT... (61 bars)
  ...
Generated 3 raw alerts
After filtering: 2 alerts

SCREENING SUMMARY
══════════════════════════════════════════════════
Symbols Scanned:    5
Signals Generated:  2
Strategies Used:    1
══════════════════════════════════════════════════

DETAILED ALERTS
Symbol  Strategy        Type  Strength  Price    Indicators
──────────────────────────────────────────────────────────
AAPL    rsi            BUY   STRONG    $178.25  RSI: 28.5
TSLA    rsi            SELL  MODERATE  $245.80  RSI: 72.3
```

---

## How to Use the Screener CLI

### Basic Usage

```bash
# Run a screener configuration
tzu --screen=<config-file>

# With verbose output
tzu --screen=my_screener.yml --verbose
```

### Example Commands

```bash
# Daily stock scan
tzu --screen=examples/screeners/basic_rsi_screener.yml

# Crypto screening
tzu --screen=examples/screeners/crypto_screener.yml

# Multiple strategies
tzu --screen=examples/screeners/multi_strategy_screener.yml

# Intraday momentum
tzu --screen=examples/screeners/intraday_momentum.yml
```

---

## YAML Configuration Guide

### Complete Configuration Structure

```yaml
metadata:
  name: string          # Required: Screener name
  description: string   # Optional: What this screener does
  author: string        # Optional: Author name
  tags: [string]        # Optional: Tags for organization

strategies:
  - kind: built_in      # Strategy type
    name: string        # Strategy name (rsi, macd, etc.)
    params:             # Strategy parameters
      key: value

data:
  source: yahoo         # Data source: yahoo, coinbase, csv
  symbols: [string]     # List of symbols to screen
  lookback: string      # How far back to look (90d, 6mo, etc.)
  interval: string      # Bar interval (1d, 1h, 5m, etc.)

output:
  format: terminal      # Output format: terminal, csv, json, markdown
  detail_level: summary # Detail level: summary, detailed
  filepath: string      # Optional: Output file path

filters:
  signal_types: [enum]  # Filter by signal types
  min_strength: enum    # Minimum signal strength
  top_n: int            # Return only top N results
```

### Metadata Section

```yaml
metadata:
  name: "RSI Oversold Screener"
  description: "Find stocks showing RSI oversold conditions"
  author: "Your Name"
  tags:
    - mean-reversion
    - daily
    - stocks
```

- name: Display name for the screener
- description: What the screener does
- author: Who created it
- tags: Categories for organization

### Strategies Section

#### Built-in Strategies

```yaml
strategies:
  - kind: built_in
    name: rsi
    params:
      period: 14
      oversold: 30
      overbought: 70
```

Available built-in strategies:

- Mean Reversion: rsi, bollinger, stochastic, mfi, cci
- Trend Following: macd, crossover, kama, aroon, psar, triplem, adx
- Volatility: keltner
- Hybrid: volume, dualmomentum, filteredrsi

#### Multiple Strategies

```yaml
strategies:
  - kind: built_in
    name: rsi
    params:
      period: 14
  
  - kind: built_in
    name: macd
    params:
      fast: 12
      slow: 26
      signal: 9
```

#### YAML Strategy Files

```yaml
strategies:
  - kind: yaml_file
    filepath: "strategies/my_custom_rsi.yml"
```

### Data Section

#### Yahoo Finance

```yaml
data:
  source: yahoo
  symbols:
    - AAPL
    - MSFT
    - GOOGL
  lookback: 90d
  interval: 1d
```

#### Coinbase (Crypto)

```yaml
data:
  source: coinbase
  pairs:
    - BTC-USD
    - ETH-USD
    - SOL-USD
  lookback: 7d
  interval: 1h
```

#### CSV Files

```yaml
data:
  source: csv
  directory: "data/stocks"
  lookback: 90d  # Optional: filter by date
```

### Output Section

```yaml
output:
  format: terminal          # terminal, csv, json, markdown
  detail_level: detailed    # summary or detailed
  filepath: "results.csv"   # Optional: save to file
```

Format Options:

- terminal: Colored terminal output (default)
- csv: CSV file for Excel/analysis
- json: JSON for programmatic use
- markdown: Markdown tables for reports

Detail Levels:

- summary: Key info only (symbol, type, strength, price)
- detailed: All indicators and metadata

### Filters Section

```yaml
filters:
  signal_types:
    - buy_signal
    - sell_signal
  min_strength: moderate
  top_n: 10
```

Signal Types:
- `buy_signal` - Buy opportunities
- `sell_signal` - Sell opportunities
- `exit_long` - Exit long positions
- `exit_short` - Exit short positions

Signal Strength:
- `weak` - Low confidence signals
- `moderate` - Medium confidence signals
- `strong` - High confidence signals

Top N:
- Limit results to top N strongest signals
- Omit or set to 0 for all results

---

## Time Period Configuration

### Lookback Period

The `lookback` parameter specifies how much historical data to fetch:

Format: `<number><unit>`

Units:
- `m` - minutes (e.g., `30m` = 30 minutes)
- `h` - hours (e.g., `3h` = 3 hours)
- `d` - days (e.g., `90d` = 90 days)
- `mo` - months (e.g., `6mo` = 6 months)
- `y` - years (e.g., `1y` = 1 year)

Examples:
```yaml
lookback: 90d   # 90 days of data
lookback: 6mo   # 6 months of data
lookback: 3h    # 3 hours of data
```

### Bar Interval

The `interval` parameter specifies the timeframe for each data point:

Common Intervals:

- `1m` - 1-minute bars
- `5m` - 5-minute bars
- `15m` - 15-minute bars
- `30m` - 30-minute bars
- `1h` - 1-hour bars
- `1d` - Daily bars
- `1wk` - Weekly bars
- `1mo` - Monthly bars

### Minimum Data Requirements

Each strategy requires a minimum number of bars:

| Strategy | Minimum Bars | Notes |
|----------|--------------|-------|
| RSI | ~20-30 | Period + warmup |
| MACD | ~35 | slow(26) + signal(9) |
| Bollinger | ~20 | Period bars |
| Moving Average | Period | Exactly period bars |

Best Practice: Request 20-50% more data than the minimum to ensure accurate calculations.

Example Calculation:

```yaml
# MACD needs ~35 bars minimum
# Add 50% buffer: 35 × 1.5 = 52 bars
# On daily data: ~75 calendar days accounting for weekends
lookback: 90d  # Safe choice
interval: 1d
```

### Trading Days vs Calendar Days

When using daily intervals:

- Markets are closed weekends/holidays
- ~252 trading days per year (not 365)
- `90d` lookback ≈ 63 trading days
- TzuTrader handles this automatically

---

## Interpreting Screener Results

### Terminal Output

```
SCREENING SUMMARY
══════════════════════════════════════════════════
Symbols Scanned:    5
Signals Generated:  2
Strategies Used:    1
══════════════════════════════════════════════════

DETAILED ALERTS
Symbol  Strategy        Type  Strength  Price    Indicators
──────────────────────────────────────────────────────────
AAPL    rsi            BUY   STRONG    $178.25  RSI: 28.5
TSLA    rsi            SELL  MODERATE  $245.80  RSI: 72.3
```

Understanding the Output:

- Symbol: The ticker being signaled
- Strategy: Which strategy generated the signal
- Type: BUY, SELL, EXIT LONG, EXIT SHORT
- Strength: WEAK, MODERATE, STRONG
- Price: Current/latest price
- Indicators: Key indicator values

### CSV Output

```csv
Symbol,Strategy,Type,Strength,Price,Timestamp,Indicators
AAPL,rsi,BUY,STRONG,178.25,2024-02-01 16:00:00,"RSI: 28.5"
TSLA,rsi,SELL,MODERATE,245.80,2024-02-01 16:00:00,"RSI: 72.3"
```

Perfect for importing into Excel or Python for further analysis.

### JSON Output

```json
{
  "generated_at": 1706803200,
  "total_symbols": 5,
  "total_strategies": 1,
  "total_alerts": 2,
  "alerts": [
    {
      "symbol": "AAPL",
      "strategy": "rsi",
      "type": "BUY",
      "strength": "STRONG",
      "price": 178.25,
      "indicators": {"rsi": 28.5}
    }
  ]
}
```

Perfect for APIs, webhooks, or automated systems.

---

## Best Practices

### 1. Match Timeframe to Trading Style

- Day Trading: 5m-15m bars, 1-3 hour lookback
- Swing Trading: 1h-4h bars, 1-7 day lookback
- Position Trading: 1d bars, 3-12 month lookback

### 2. Use Multiple Strategies for Confirmation

```yaml
strategies:
  - kind: built_in
    name: rsi         # Mean reversion
  - kind: built_in
    name: macd        # Trend confirmation
```

Signals confirmed by multiple strategies tend to be more reliable.

### 3. Start with Small Symbol Lists

Begin with 5-10 symbols during development, then scale up:

```yaml
# Development
symbols: [AAPL, MSFT, GOOGL, TSLA, NVDA]

# Production
symbols: [AAPL, MSFT, GOOGL, ..., <100+ symbols>]
```

### 4. Adjust for Market Conditions

- Volatile markets: Increase min_strength threshold
- Quiet markets: Lower thresholds or expand symbol list
- Trending markets: Favor trend-following strategies
- Ranging markets: Favor mean-reversion strategies

### 5. Filter Results Appropriately

```yaml
filters:
  signal_types: [buy_signal]  # Focus on your trading direction
  min_strength: moderate      # Balance quality vs quantity
  top_n: 10                   # Limit to best opportunities
```

### 6. Consider Data Provider Limits

- Yahoo Finance: Good for daily, limited intraday
- Coinbase: Real-time crypto, hourly available
- Premium providers: Better for high-frequency screening

### 7. Automate Regular Screening

Schedule screeners to run automatically:

```bash
# Cron job for daily screening at market close
0 16 * * 1-5 tzu --screen=daily_screener.yml > results.txt
```

### 8. Track Results Over Time

Enable history tracking to compare signals:

```yaml
history:
  enabled: true
  directory: "screener_history"
  retention_days: 30
```

---

## Advanced Features

### History Tracking

Track screening results over time:

```yaml
output:
  saveHistory: true
  historyDir: "screener_history"
```

Benefits:
- Compare signals across multiple runs
- Track signal frequency by symbol
- Identify persistent opportunities
- Backtest signal reliability

### Multi-Strategy Screening

Combine complementary strategies:

```yaml
strategies:
  - kind: built_in
    name: rsi          # Oversold/overbought
    params:
      period: 14
  
  - kind: built_in
    name: macd         # Trend direction
    params:
      fast: 12
      slow: 26
  
  - kind: built_in
    name: bollinger    # Volatility bands
    params:
      period: 20
```

### Custom YAML Strategies

Use your own strategy definitions:

```yaml
strategies:
  - kind: yaml_file
    filepath: "strategies/my_custom_rsi.yml"
  
  - kind: yaml_file
    filepath: "strategies/my_macd_variant.yml"
```

### Sector-Specific Screening

Create screeners for specific sectors:

```yaml
# Tech sector screener
symbols: [AAPL, MSFT, GOOGL, META, NVDA, AMD, INTC]

# Healthcare screener
symbols: [JNJ, UNH, PFE, ABBV, TMO, DHR]

# Energy screener
symbols: [XOM, CVX, COP, SLB, EOG]
```

---

## Troubleshooting

### "Not enough data" Error

Cause: Lookback period too short for strategy requirements

Fix:
```yaml
# Before (insufficient)
lookback: 30d

# After (sufficient)
lookback: 90d
```

### No Signals Generated

Possible Causes:

1. Filters too restrictive
2. No current opportunities
3. Strategy configuration incorrect

Fixes:
```yaml
# Try lowering thresholds
filters:
  min_strength: weak    # Instead of strong
  # Remove top_n temporarily

# Check strategy params
strategies:
  - kind: built_in
    name: rsi
    params:
      oversold: 35      # Less strict (was 30)
      overbought: 65    # Less strict (was 70)
```

### Slow Performance

Causes:

- Too many symbols
- Very long lookback
- Complex strategies

Fixes:

```yaml
# Reduce symbol count
symbols: [AAPL, MSFT, GOOGL]  # Start small

# Shorter lookback
lookback: 30d  # Instead of 6mo

# Simpler strategies
strategies:
  - kind: built_in
    name: rsi  # Simple single-indicator strategy
```

### Intraday Data Not Available

Cause: Data provider doesn't support requested interval

Fix:

- Use daily data instead (`interval: 1d`)
- Switch to provider with intraday support
- Check provider API documentation

### "Invalid time period" Error

Cause: Malformed lookback or interval string

Fix:

```yaml
# Correct formats
lookback: 90d   # ✓ Correct
lookback: 6mo   # ✓ Correct
lookback: 3h    # ✓ Correct

# Incorrect formats
lookback: 90days  # ✗ Wrong
lookback: 6m      # ✗ Ambiguous (6 minutes or months?)
```

---

## Quick Reference Card

### Common Screening Patterns

Daily End-of-Day Scan:

```yaml
data:
  lookback: 6mo
  interval: 1d
filters:
  signal_types: [buy_signal]
  min_strength: moderate
  top_n: 10
```

Intraday Momentum:

```yaml
data:
  lookback: 3h
  interval: 5m
filters:
  signal_types: [buy_signal]
  min_strength: strong
  top_n: 3
```

Crypto Multi-Timeframe:

```yaml
data:
  source: coinbase
  lookback: 7d
  interval: 1h
filters:
  min_strength: moderate
```

### Time Period Cheat Sheet

| Use Case | Interval | Lookback | Bars |
|----------|----------|----------|------|
| Day trading | 5m-15m | 1-3h | ~12-36 |
| Swing trading | 1h-4h | 1-7d | ~24-168 |
| Position trading | 1d | 3-12mo | ~63-252 |
| Crypto (24/7) | 1h | 7-30d | ~168-720 |

### Signal Strength Guide

- WEAK: Low conviction, use for research only
- MODERATE: Reasonable confidence, good for watchlists
- STRONG: High conviction, actionable signals

### Recommended Filters

Conservative (High Quality):

```yaml
filters:
  min_strength: strong
  top_n: 5
```

Balanced (Good Mix):

```yaml
filters:
  min_strength: moderate
  top_n: 10
```

Aggressive (More Opportunities):

```yaml
filters:
  min_strength: weak
  top_n: 20
```

---

## See Also

- [CLI Reference](../reference_guide/09_cli.md) - Command-line options
