# TzuTrader Market Screener Examples

This directory contains example screener configurations demonstrating various use cases and features of the TzuTrader market screening system.

## Quick Start

Run any screener with:
```bash
./src/tzu --screen=examples/screeners/basic_rsi_screener.yml
```

Or specify custom output format:
```bash
./src/tzu --screen=examples/screeners/multi_strategy_screener.yml --output=json
```

## Examples Overview

### 1. basic_rsi_screener.yml
**Purpose:** Simple RSI-based oversold stock finder  
**Strategy:** Single RSI mean reversion strategy  
**Time Period:** 90 days of daily bars (requires ~90 trading days of data)  
**Symbols:** 5 large-cap tech stocks (AAPL, MSFT, GOOGL, TSLA, AMZN)  
**Output:** Terminal summary  
**Best For:** Learning the basic screener structure and RSI signals

**Key Features:**
- Finds oversold stocks (RSI < 30)
- Filters for buy signals only
- Returns top 10 results with moderate or higher signal strength

**When to Use:**
- Daily end-of-day screening for mean reversion opportunities
- Learning how RSI oversold/overbought signals work
- Quick screening of a small watchlist

---

### 2. multi_strategy_screener.yml
**Purpose:** Comprehensive multi-strategy market scanner  
**Strategies:** RSI + MACD + Bollinger Bands  
**Time Period:** 6 months of daily bars (requires ~126 trading days of data)  
**Symbols:** 8 tech stocks  
**Output:** CSV file with detailed results  
**Best For:** Regular daily market screening with multiple confirmation signals

**Key Features:**
- Uses three complementary strategies for signal confirmation
- Exports to CSV for further analysis in Excel/Python
- Captures both buy and sell signals
- Returns top 20 results

**When to Use:**
- End-of-day comprehensive market screening
- Finding opportunities confirmed by multiple indicators
- Building a watchlist for further research

**Time Period Note:**  
The 6-month lookback ensures all three strategies have sufficient data:
- RSI: needs 14 periods minimum
- MACD: needs 26 periods (slow EMA) + 9 (signal line) = 35 periods
- Bollinger Bands: needs 20 periods minimum
- Extra buffer for warm-up periods and edge cases

---

### 3. crypto_screener.yml
**Purpose:** Cryptocurrency pair screener using hourly data  
**Strategy:** RSI + Bollinger Bands (adjusted thresholds for crypto volatility)  
**Time Period:** 7 days of hourly bars (168 hours total)  
**Symbols:** 4 crypto pairs (BTC-USD, ETH-USD, SOL-USD, AVAX-USD)  
**Output:** Terminal summary  
**Best For:** Short-term crypto trading opportunity identification

**Key Features:**
- Adjusted RSI thresholds (35/65 instead of 30/70) for crypto volatility
- Hourly timeframe for more frequent signal generation
- Both buy and sell signals captured
- Returns top 5 most promising opportunities

**When to Use:**
- Multiple times per day for crypto swing trading
- Identifying short-term volatility plays
- Monitoring crypto market conditions

**Time Period Note:**  
7 days of hourly data (168 hours) provides sufficient history while staying relevant for short-term crypto trading. More than 20 hours needed for Bollinger Bands calculation.

---

### 4. intraday_momentum.yml
**Purpose:** Short-term intraday momentum trading signals  
**Strategy:** MACD + RSI on 5-minute bars  
**Time Period:** 3 hours of 5-minute bars (36 bars total)  
**Symbols:** 5 high-volatility tech stocks  
**Output:** Terminal detailed view  
**Best For:** Active day trading with quick entries/exits

**Key Features:**
- Very short timeframe (5-minute bars)
- Strong signal strength requirement
- Limited lookback (3 hours) for current market conditions
- Buy signals only (for momentum longs)

**When to Use:**
- During market hours for active day trading
- Finding immediate momentum opportunities
- Quick screening before market open or during key trading hours

**Time Period Note:**  
3 hours (36 five-minute bars) is sufficient for 5-minute MACD calculation (needs ~26 bars minimum for slow EMA). The short lookback keeps signals relevant to current intraday conditions.

**⚠️ Warning:**  
Intraday data availability varies by data provider. Yahoo Finance may have limited intraday historical data. Consider using a premium data provider for reliable intraday screening.

---

### 5. custom_yaml_strategies.yml
**Purpose:** Demonstrate using custom YAML strategy files  
**Strategy:** Custom strategies loaded from external YAML files  
**Time Period:** 90 days of daily bars  
**Symbols:** 6 tech stocks  
**Output:** Terminal detailed view  
**Best For:** Using your own custom strategy definitions

**Key Features:**
- Loads strategies from separate YAML files
- Demonstrates the yaml_file strategy kind
- Supports any custom strategy logic defined in YAML format
- Full strategy reusability across screeners

**When to Use:**
- You have custom strategies defined in YAML format
- Want to separate strategy logic from screener configuration
- Need to reuse the same strategies across multiple screeners

**Required Files:**
- `examples/yaml_strategies/rsi_percent_sizing.yml`
- `examples/yaml_strategies/macd_crossover.yml`
- `examples/yaml_strategies/bollinger_mean_reversion.yml`

These strategy files should be standard TzuTrader YAML strategy definitions. See the `examples/yaml_strategies/` directory for examples.

---

### 6. performance_test.yml
**Purpose:** Performance testing with many symbols  
**Strategy:** Simple RSI strategy  
**Time Period:** 30 days of daily bars  
**Symbols:** 20+ stocks for performance testing  
**Output:** Terminal summary  
**Best For:** Testing screener performance and scalability

**Key Features:**
- Large symbol list for performance testing
- Shorter lookback period for faster execution
- Single simple strategy to isolate data fetching performance

**When to Use:**
- Testing screener performance with many symbols
- Benchmarking data provider speed
- Validating screener scalability

---

## Test Files

The following files are used for automated testing and integration tests:

- **test_integration.yml** - Integration test configuration
- **test_history.yml** - History persistence testing
- **test_history_signals.yml** - History with signals testing
- **test_lenient_rsi.yml** - Lenient mode testing for RSI strategy

These are not intended as user examples but can be referenced to understand advanced features.

---

## Understanding Time Periods

Time periods in screeners use two key parameters:

### 1. Lookback Period (`lookback`)
How much historical data to fetch. Format: `<number><unit>`

**Units:**
- `d` - days (e.g., `90d` = 90 days)
- `mo` - months (e.g., `6mo` = 6 months)
- `y` - years (e.g., `1y` = 1 year)
- `h` - hours (e.g., `3h` = 3 hours)
- `m` - minutes (e.g., `30m` = 30 minutes)

**Examples:**
- `lookback: 90d` - Fetch 90 days of data
- `lookback: 6mo` - Fetch 6 months of data
- `lookback: 3h` - Fetch 3 hours of data

### 2. Bar Interval (`interval`)
The timeframe for each data point. Format: `<number><unit>`

**Common Intervals:**
- **Daily:** `1d` - One bar per day
- **Hourly:** `1h` - One bar per hour
- **Intraday:** `5m`, `15m`, `30m`, `1h` - Minute/hour bars

### Minimum Data Requirements

Each strategy requires a minimum number of bars to calculate:

| Strategy | Minimum Bars | Calculation |
|----------|--------------|-------------|
| RSI | period + warmup | ~20-30 bars for period=14 |
| MACD | slow + signal | ~35 bars for 12/26/9 |
| Bollinger | period | ~20 bars for period=20 |
| SMA | period | Exactly period bars |
| EMA | ~3 × period | More bars = better accuracy |

**Best Practice:** Always request MORE data than the minimum:
- Add 20-50% buffer for warm-up periods
- Account for weekends/holidays (daily data)
- Consider indicator accuracy at the start of the dataset

**Example Calculation:**
```yaml
# MACD strategy needs 35 bars minimum (26 slow + 9 signal)
# Add 50% buffer = 35 × 1.5 = 52 bars
# On daily data: 52 trading days ≈ 75 calendar days
lookback: 90d  # Safe choice for MACD daily screening
interval: 1d
```

### Trading Days vs Calendar Days

**Important:** When using daily intervals:
- Markets are closed on weekends and holidays
- ~252 trading days per year (not 365)
- 1 month ≈ 21 trading days
- 90 calendar days ≈ 63 trading days

The screener handles this automatically, but be aware that `lookback: 90d` will fetch approximately 63 days of actual market data.

---

## Choosing the Right Time Period

### For Daily Screening (1d interval)
```yaml
lookback: 90d    # Short-term (2-3 months of data)
lookback: 6mo    # Medium-term (typical for most strategies)
lookback: 1y     # Long-term (for trend analysis)
```

### For Hourly Screening (1h interval)
```yaml
lookback: 7d     # 1 week of hourly bars (~168 hours)
lookback: 30d    # 1 month of hourly bars (~720 hours)
```

### For Intraday Screening (5m, 15m intervals)
```yaml
lookback: 3h     # Very short-term (current session)
lookback: 1d     # Full trading day
lookback: 5d     # Week of intraday data
```

---

## Output Formats

Configure output in the `output` section:

```yaml
output:
  format: terminal        # Options: terminal, csv, json, markdown
  detail_level: summary   # Options: summary, detailed
  filepath: "results.csv" # Required for csv/json/markdown
```

### Terminal (Default)
- Best for quick checks and development
- Color-coded signal types
- Easy to read summary or detailed view

### CSV
- Best for analysis in Excel or Python/R
- One row per alert
- Easy to filter, sort, and chart

### JSON
- Best for programmatic consumption
- Structured data for APIs and automation
- Includes full metadata

### Markdown
- Best for reports and documentation
- Human-readable tables
- Can be rendered in GitHub, Notion, etc.

---

## Filtering Results

Use the `filters` section to narrow down results:

```yaml
filters:
  signal_types:           # Which signal types to include
    - buy_signal          # Only buy opportunities
    - sell_signal         # Only sell opportunities
    - exit_long           # Exit long positions
    - exit_short          # Exit short positions
  
  min_strength: moderate  # Minimum signal strength
                         # Options: weak, moderate, strong
  
  top_n: 10              # Return only top N results
                         # Based on signal strength
```

**Signal Strength Levels:**
- **Weak:** Marginal signals, higher false positive rate
- **Moderate:** Reasonable confidence, good for initial screening
- **Strong:** High confidence, use for immediate action

---

## Common Patterns

### Pattern 1: Daily End-of-Day Screening
```yaml
data:
  lookback: 6mo
  interval: 1d
strategies:
  - kind: built_in
    name: rsi
  - kind: built_in
    name: macd
filters:
  signal_types: [buy_signal]
  min_strength: moderate
  top_n: 10
```

### Pattern 2: Intraday Momentum
```yaml
data:
  lookback: 3h
  interval: 5m
strategies:
  - kind: built_in
    name: macd
filters:
  signal_types: [buy_signal]
  min_strength: strong
  top_n: 3
```

### Pattern 3: Crypto Multi-Timeframe
```yaml
data:
  source: coinbase
  lookback: 7d
  interval: 1h
strategies:
  - kind: built_in
    name: rsi
    params:
      oversold: 35  # Adjusted for crypto volatility
  - kind: built_in
    name: bollinger
```

---

## Tips and Best Practices

### 1. Start Simple
Begin with `basic_rsi_screener.yml` and gradually add complexity.

### 2. Test with Small Symbol Lists
Use 5-10 symbols during development, then scale up.

### 3. Match Timeframe to Trading Style
- Day trading: 5m-15m bars, 1-3 hour lookback
- Swing trading: 1h-4h bars, 1-7 day lookback
- Position trading: 1d bars, 3-12 month lookback

### 4. Consider Data Provider Limits
- Yahoo Finance: Good for daily, limited intraday
- Coinbase: Real-time crypto, hourly available
- Premium providers: Better for high-frequency intraday

### 5. Use Multiple Strategies for Confirmation
Combine trend-following (MACD) with mean-reversion (RSI) for better signal quality.

### 6. Adjust for Market Conditions
- Volatile markets: Increase signal strength threshold
- Quiet markets: May need to lower thresholds or expand symbol list

### 7. Monitor Performance
Use `performance_test.yml` as a baseline to track screener speed.

---

## Troubleshooting

### "Not enough data" Error
- **Cause:** Lookback period too short for strategy requirements
- **Fix:** Increase `lookback` value (e.g., 90d → 6mo)

### No Signals Generated
- **Cause:** Filters too restrictive or no current opportunities
- **Fix:** 
  - Lower `min_strength` threshold
  - Include more signal types
  - Remove `top_n` limit temporarily
  - Check if strategies are configured correctly

### Slow Screening Performance
- **Cause:** Too many symbols or very long lookback
- **Fix:**
  - Reduce symbol count
  - Use shorter lookback period
  - Use simpler strategies
  - Consider caching data

### Intraday Data Not Available
- **Cause:** Data provider doesn't support requested interval
- **Fix:**
  - Use daily data instead
  - Switch to a provider with intraday support
  - Check provider API documentation

---

## Next Steps

1. **Start with examples:** Run each example to understand different screening approaches
2. **Modify examples:** Copy and adjust parameters for your needs
3. **Create custom screeners:** Build configurations for your specific trading strategy
4. **Automate:** Schedule screeners to run automatically (e.g., cron jobs)
5. **Integrate:** Use JSON output to feed results into other tools or dashboards

## Additional Resources

- **Full Documentation:** `docs/user_guide/08_screening/screener.md`
- **Technical Reference:** `SCREENER.md` (project root)
- **Workflow Examples:** `SCREENER_WORKFLOWS.md` (project root)
- **Strategy Examples:** `examples/yaml_strategies/`

---

**Happy Screening! 🎯**
