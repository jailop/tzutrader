# YAML Strategy Examples

This directory contains example YAML declarative strategies for TzuTrader.

## Available Examples

### Beginner-Friendly

1. **rsi_simple.yml** - Classic RSI oversold/overbought strategy
   - Entry: RSI < 30
   - Exit: RSI > 70
   - Position sizing: Fixed 100 shares

### Intermediate

2. **rsi_trend_filter.yml** - RSI with trend confirmation
   - Entry: RSI < 30 AND price > SMA(200)
   - Exit: RSI > 70
   - Only trades in uptrends
   - Position sizing: Fixed 100 shares

3. **macd_crossover.yml** - MACD signal line crossover
   - Entry: MACD crosses above signal
   - Exit: MACD crosses below signal
   - Position sizing: Fixed 100 shares

4. **bollinger_mean_reversion.yml** - Bollinger Bands extremes
   - Entry: Price <= lower band
   - Exit: Price >= upper band
   - Position sizing: Fixed 100 shares

### Advanced

5. **multi_indicator.yml** - Three-indicator confirmation
   - Entry: RSI < 30 AND MACD > 0 AND volume > SMA(20)
   - Exit: RSI > 70 OR MACD < 0
   - Position sizing: Fixed 100 shares

### Percent-Based Position Sizing (Phase 2)

6. **rsi_percent_sizing.yml** - RSI with 20% position sizing
   - Entry: RSI < 30
   - Exit: RSI > 70
   - **Position sizing: 20% of portfolio equity**

7. **macd_conservative.yml** - Conservative MACD with 10% sizing
   - Entry: MACD crosses above signal
   - Exit: MACD crosses below signal
   - **Position sizing: 10% of portfolio equity (conservative)**

### New Indicators (Phase 2)

8. **kama_trend_following.yml** - Adaptive trend following
   - Uses KAMA (Kaufman Adaptive Moving Average) crossover
   - Fast KAMA crosses above slow KAMA
   - Position sizing: 15% of portfolio

9. **dema_crossover.yml** - Fast trend detection
   - Uses DEMA (Double EMA) crossover with ATR filter
   - Requires minimum volatility (ATR > 2.0)
   - Position sizing: 20% of portfolio

10. **mean_reversion_volatility.yml** - Low volatility mean reversion
    - RSI oversold + low standard deviation filter
    - Only enters in low volatility environments
    - Position sizing: 10% of portfolio

11. **cmo_momentum.yml** - Chande Momentum Oscillator
    - Trades strong momentum (CMO > 50)
    - EMA trend filter for confirmation
    - Position sizing: 15% of portfolio

12. **volume_accumulation.yml** - Volume-based strategy
    - Accumulation/Distribution line crossover
    - Price MA confirmation
    - Position sizing: 12% of portfolio

### Source and Output Selection (Phase 2)

13. **volume_ma_breakout.yml** - Volume breakout with source parameter
    - Uses MA applied to volume (source: volume)
    - Enters on above-average volume + uptrend
    - Demonstrates custom source parameter
    - Position sizing: 15% of portfolio

14. **bb_explicit_bands.yml** - Bollinger Bands with output selection
    - Uses explicit upper/lower band outputs
    - Mean reversion between bands
    - Demonstrates output parameter
    - Position sizing: 10% of portfolio

## Position Sizing Options

### Fixed Size (Phase 1)
```yaml
position_sizing:
  type: fixed
  size: 100  # Buy exactly 100 shares
```

### Percent-Based (Phase 2)
```yaml
position_sizing:
  type: percent
  percent: 20  # Use 20% of portfolio equity
```

**Percent sizing benefits:**
- Scales with portfolio growth
- Better risk management
- Consistent exposure across trades
- Recommended: 10-25% per trade

## Advanced Features (Phase 2)

### Source Parameter

By default, indicators are applied to the closing price. You can change this using the `source` parameter:

```yaml
indicators:
  - id: volume_ma
    type: ma
    params:
      period: 20
    source: volume  # Apply MA to volume instead of close
```

**Valid sources:**
- `open` - Opening price
- `high` - Highest price
- `low` - Lowest price
- `close` - Closing price (default)
- `volume` - Trading volume

**Example use cases:**
- Volume moving average for volume breakouts
- High/low moving averages for range detection
- Open price indicators for gap strategies

**Example:** See `volume_ma_breakout.yml`

### Output Selection

Multi-output indicators can have their default output changed using the `output` parameter:

```yaml
indicators:
  - id: bb_upper
    type: bollinger
    params:
      period: 20
      numStdDev: 2.0
    output: upper  # Use upper band as the indicator value
```

**Multi-output indicators and their outputs:**

| Indicator | Outputs | Default |
|-----------|---------|---------|
| **bollinger** | `upper`, `middle`, `lower` | `middle` |
| **macd** | `macd`, `signal`, `histogram` | `macd` |
| **stoch** | `k`, `d` | `k` |
| **adx** | `adx`, `plus`, `minus` | `adx` |
| **aroon** | `up`, `down`, `oscillator` | `oscillator` |
| **stochrsi** | `k`, `d` | `k` |
| **ppo** | `ppo`, `signal`, `histogram` | `ppo` |

**Note:** You can still use dot notation to access specific outputs in conditions:
```yaml
entry:
  conditions:
    left: bb_20.upper  # Access upper band explicitly
    operator: "<"
    right: price
```

**Example:** See `bb_explicit_bands.yml`

## Usage

Run any strategy with:

```bash
# Yahoo Finance data
./tzu --strategy=examples/yaml_strategies/rsi_simple.yml \
      --symbol=AAPL --start=2023-01-01

# CSV data
./tzu --strategy=examples/yaml_strategies/macd_crossover.yml \
      --csvFile=data/AAPL.csv

# With portfolio options
./tzu --strategy=examples/yaml_strategies/multi_indicator.yml \
      --symbol=TSLA --start=2023-01-01 \
      --initialCash=50000 --commission=0.001
```

## Creating Your Own

1. Copy an example strategy
2. Modify the metadata, indicators, and conditions
3. Validate: The CLI will validate your strategy on load
4. Test: Run a backtest with historical data

## YAML Strategy Structure

```yaml
metadata:
  name: "Your Strategy Name"
  description: "What it does"
  tags: [tag1, tag2]

indicators:
  - id: unique_id
    type: indicator_type
    params:
      param1: value1

entry:
  conditions:
    # Simple: left operator right
    # AND: all: [cond1, cond2]
    # OR: any: [cond1, cond2]

exit:
  conditions:
    # Same structure as entry

position_sizing:
  type: fixed
  size: 100
```

## Supported Indicators

### Moving Averages
- **ma / sma**: Simple Moving Average
- **ema**: Exponential Moving Average
- **trima**: Triangular Moving Average (double-smoothed)
- **dema**: Double Exponential Moving Average (faster response)
- **tema**: Triple Exponential Moving Average (minimal lag)
- **kama**: Kaufman Adaptive Moving Average (adapts to volatility)

### Momentum Indicators
- **rsi**: Relative Strength Index
- **mom**: Simple Momentum
- **cmo**: Chande Momentum Oscillator
- **stochrsi**: Stochastic RSI (more sensitive)
- **ppo**: Percentage Price Oscillator

### Trend Indicators
- **macd**: Moving Average Convergence Divergence
- **adx**: Average Directional Index

### Volatility Indicators
- **bollinger**: Bollinger Bands
- **atr**: Average True Range
- **natr**: Normalized ATR (percentage)
- **trange**: True Range

### Statistical Indicators
- **mv**: Moving Variance
- **stdev**: Standard Deviation

### Volume Indicators
- **obv**: On Balance Volume
- **ad**: Accumulation/Distribution Line
- **mfi**: Money Flow Index

### Oscillators
- **stoch**: Stochastic Oscillator
- **cci**: Commodity Channel Index
- **aroon**: Aroon Indicator
- **psar**: Parabolic SAR

## Supported Operators

- Comparison: `<`, `>`, `<=`, `>=`, `==`, `!=`
- Crossovers: `crosses_above`, `crosses_below`

## Special References

- `price` / `close`: Current closing price
- `open`: Opening price
- `high`: Highest price
- `low`: Lowest price
- `volume`: Trading volume

## Tips

1. Start with simple strategies and test them
2. Use trend filters to reduce false signals
3. Combine multiple indicators for confirmation
4. Test different parameter values
5. Monitor drawdown and risk metrics

## Learn More

See the full design document in `design.md` for advanced features and future enhancements.
