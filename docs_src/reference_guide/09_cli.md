# Reference Guide: Command-Line Interface

## Overview

The TzuTrader CLI provides a command-line interface for running backtests without writing code. It's particularly useful for quick parameter testing, batch processing historical data, and automating repetitive analysis tasks.

**Binary:** `tzu`  
**Version:** 0.8.0  
**Powered by:** [cligen](https://github.com/c-blake/cligen) - automatic CLI generation

## When to Use the CLI

The CLI tool serves specific use cases where writing Nim code would be overhead:

- **Quick backtests:** Testing a strategy against a single symbol's historical data
- **Parameter exploration:** Trying different parameter values to see their effect
- **Batch processing:** Automating backtests in scripts or pipelines

For more complex needs—custom strategies, multi-symbol scanning, advanced portfolio logic, or integration with other systems—writing Nim code using the library directly provides greater flexibility.

## Command Structure (Subcommand-Based)

```bash
# Simple syntax (Yahoo Finance default)
tzu <strategy> --symbol=<SYMBOL> --start=<YYYY-MM-DD> [options]
tzu <strategy> -s <SYMBOL> --start=<YYYY-MM-DD> [options]

# Explicit data source
tzu <strategy> --csvFile=<file> [options]
tzu <strategy> --yahoo=<SYMBOL> --start=<YYYY-MM-DD> [options]
tzu <strategy> --coinbase=<PAIR> --start=<YYYY-MM-DD> [options]
```

Each strategy is a separate subcommand with its own parameters. This design ensures:
- Type-safe parameter parsing
- Strategy-specific help text
- No parameter conflicts between strategies
- Yahoo Finance as default data source when using `--symbol` or `-s`

## Discovering Available Strategies

List all 16 available strategies:

```bash
tzu --help
```

**Output shows:**
```
Usage:
  tzu {SUBCMD}  [sub-command options & parameters]
where {SUBCMD} is one of:
  rsi           Backtest RSI mean reversion strategy
  bollinger     Backtest Bollinger Bands mean reversion strategy
  stochastic    Backtest Stochastic Oscillator mean reversion strategy
  mfi           Backtest Money Flow Index mean reversion strategy
  cci           Backtest Commodity Channel Index mean reversion strategy
  crossover     Backtest Moving Average Crossover trend following strategy
  macd          Backtest MACD trend following strategy
  kama          Backtest Kaufman Adaptive Moving Average strategy
  aroon         Backtest Aroon trend identification strategy
  psar          Backtest Parabolic SAR trend following strategy
  triplem       Backtest Triple Moving Average strategy
  adx           Backtest ADX Trend Strength strategy
  keltner       Backtest Keltner Channel volatility strategy
  volume        Backtest Volume Breakout hybrid strategy
  dualmomentum  Backtest Dual Momentum hybrid strategy
  filteredrsi   Backtest Filtered RSI hybrid strategy
```

## Discovering Strategy Parameters

Get detailed help for any strategy:

```bash
tzu <strategy> --help
```

**Example:**

```bash
tzu rsi --help
```

**Output shows:**
- Strategy description and trading logic
- All available parameters with types and defaults
- Short flags (e.g., `-c`, `-p`, `-v`)
- Long flags (e.g., `--csvFile`, `--period`, `--verbose`)

**The help is automatically generated from the strategy's function signature**, so it's always accurate and up-to-date.

## Common Parameters (All Strategies)

Every strategy accepts these common parameters:

### Data Source Parameters

**Option 1: Simple Yahoo Finance (Default)**

| Parameter | Short | Type | Description |
|-----------|-------|------|-------------|
| `--symbol` | `-s` | string | Symbol to backtest (uses Yahoo Finance automatically) |
| `--start` | | string | Start date (YYYY-MM-DD format) |
| `--endDate` | `-e` | string | End date (YYYY-MM-DD format, default: today) |

**Option 2: Explicit Data Source (Mutually Exclusive)**

| Parameter | Short | Type | Description |
|-----------|-------|------|-------------|
| `--csvFile` | `-c` | string | Path to CSV file with OHLCV data |
| `--yahoo` | `-y` | string | Yahoo Finance symbol (requires `--start`) |
| `--coinbase` | | string | Coinbase trading pair (requires `--start` and env vars) |

**Portfolio Configuration Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `--initialCash` | float | 100000.0 | Starting capital in dollars |
| `--commission` | float | 0.0 | Commission rate as decimal (0.001 = 0.1%) |
| `--minCommission` | float | 0.0 | Minimum commission per trade (e.g., 1.0 = $1 minimum) |
| `--riskFreeRate` | float | 0.02 | Risk-free rate for Sharpe ratio calculation (0.02 = 2%) |

**Output Parameters:**

| Parameter | Short | Type | Default | Description |
|-----------|-------|------|---------|-------------|
| `--verbose` | `-v` | flag | false | Show detailed trade-by-trade output |

## Usage Examples

### Example 1: Simple Yahoo Finance (New Default Syntax)

```bash
tzu rsi --symbol=AAPL --start=2023-01-01 --endDate=2023-12-31
# Or using short flag:
tzu rsi -s AAPL --start=2023-01-01 --endDate=2023-12-31
```

Simplest syntax - uses Yahoo Finance automatically when `--symbol` is provided.

### Example 2: Yahoo Finance with Custom Parameters

```bash
tzu rsi -s TSLA --start=2024-01-01 --period=10 --oversold=25 -v
```

Tesla data with custom RSI parameters and verbose output.

### Example 3: Yahoo Finance with Portfolio Configuration

```bash
tzu macd --symbol=MSFT --start=2023-01-01 --commission=0.001 --minCommission=1.0 --initialCash=50000
```

Tests with 0.1% commission, $1 minimum per trade, and $50K starting capital.

### Example 4: Simple Backtest with CSV

```bash
tzu rsi --csvFile=data/AAPL.csv
```

Uses RSI strategy with default parameters on local CSV file.

### Example 5: Explicit Yahoo Finance (Backward Compatible)

```bash
tzu rsi --yahoo=AAPL --start=2023-01-01 --endDate=2023-12-31
```

Explicit `--yahoo` flag still works for backward compatibility.

### Example 6: Bitcoin from Yahoo Finance

```bash
tzu macd -s BTC-USD --start=2024-01-01
```

Tests MACD on Bitcoin, endDate defaults to today.

### Example 7: Coinbase Cryptocurrency Data

```bash
export COINBASE_API_KEY="your_key_here"
export COINBASE_SECRET_KEY="your_secret_here"
tzu psar --coinbase=ETH-USD --start=2024-01-01
```

Fetches Ethereum data from Coinbase (requires API credentials).

## Data Sources

The CLI supports three data sources. 

### Default: Yahoo Finance via Symbol Parameter (Recommended)

The simplest way to use the CLI is with the `--symbol` (or `-s`) parameter, which automatically uses Yahoo Finance:

```bash
tzu rsi --symbol=AAPL --start=2023-01-01
tzu rsi -s AAPL --start=2023-01-01  # Short form
```

**Supported symbols:**
- Stocks: AAPL, MSFT, TSLA, etc.
- ETFs: SPY, QQQ, VTI, etc.
- Crypto: BTC-USD, ETH-USD, etc.
- Indices: ^GSPC (S&P 500), ^DJI (Dow Jones), etc.

**Advantages:**
- Simplest syntax (no explicit data source flag needed)
- No API key required
- Always up-to-date data
- Wide symbol coverage (stocks, crypto, indices, forex)

**Limitations:**
- Rate limits apply (avoid hammering the API)
- Historical data availability varies by symbol

### CSV Files

Load historical data from local CSV files.

```bash
tzu rsi --csvFile=data/AAPL.csv
```

**Requirements:**
- CSV file must exist locally
- Must contain columns: timestamp, open, high, low, close, volume
- See [Data Management Reference](02_data.md) for format details

### Explicit Yahoo Finance (Backward Compatible)

You can still use the explicit `--yahoo` flag:

```bash
tzu rsi --yahoo=AAPL --start=2023-01-01 --endDate=2023-12-31
```

This is functionally identical to using `--symbol` but more explicit.

### Coinbase

Fetch cryptocurrency data from Coinbase Advanced Trade API.

```bash
export COINBASE_API_KEY="your_api_key"
export COINBASE_SECRET_KEY="your_secret_key"
tzu rsi --coinbase=BTC-USD --start=2024-01-01
```

**Supported pairs:**
- BTC-USD, ETH-USD, SOL-USD, etc.
- See [Coinbase documentation](https://docs.cloud.coinbase.com/) for full list

**Requirements:**
- Coinbase account with API credentials
- Set environment variables: `COINBASE_API_KEY` and `COINBASE_SECRET_KEY`

**Parameters:**
- `--coinbase=PAIR` (required)
- `--start=YYYY-MM-DD` (required)
- `--endDate=YYYY-MM-DD` (optional)

**Advantages:**
- Official Coinbase data
- High-resolution crypto data

**Limitations:**
- Requires API key
- Only cryptocurrency trading pairs

**Note:** Alpha Vantage is NOT currently implemented as a data source.

The CLI uses **automatic parameter generation** from function signatures:

1. Each strategy is a Nim procedure with typed parameters and default values
2. cligen introspects the function signature at compile time
3. Parameters become CLI options automatically:
   - `csvFile: string` → required `--csvFile=` option
   - `period = 14` → optional `--period=` with default 14
   - `verbose = false` → flag `-v` or `--verbose`
4. Doc comments become help text automatically

**Benefits:**
- Parameters stay in sync with code (no manual documentation drift)
- Type safety: cligen validates int/float/string/bool at parse time
- Zero boilerplate: adding a parameter requires zero CLI wiring code

**Example from source code:**
```nim
proc rsi(
  symbol = "",            # Optional: Yahoo Finance symbol (default)
  csvFile = "",           # Optional: CSV file path
  yahoo = "",             # Optional: Explicit Yahoo Finance
  coinbase = "",          # Optional: Coinbase pair
  start = "",             # Required for symbol/yahoo/coinbase
  endDate = "",           # Optional: defaults to today
  period = 14,            # Optional int, default 14
  oversold = 30.0,        # Optional float, default 30.0
  overbought = 70.0,      # Optional float, default 70.0
  initialCash = 100000.0, # Optional: starting capital
  commission = 0.0,       # Optional: commission rate
  minCommission = 0.0,    # Optional: minimum commission per trade
  riskFreeRate = 0.02,    # Optional: risk-free rate for Sharpe
  verbose = false         # Optional flag, default false
): int =
  ## Backtest RSI mean reversion strategy  # ← This becomes help text
```

This single function signature automatically generates:
- `--symbol=` or `-s` (optional, uses Yahoo Finance as default)
- `--csvFile=` (optional)
- `--yahoo=` (optional, explicit Yahoo Finance)
- `--coinbase=` (optional)
- `--start=` (required for online data sources)
- `--endDate=` (optional, default: today)
- `--period=` (default: 14)
- `--oversold=` (default: 30.0)
- `--overbought=` (default: 70.0)
- `--initialCash=` (default: 100000.0)
- `--commission=` (default: 0.0)
- `--minCommission=` (default: 0.0)
- `--riskFreeRate=` (default: 0.02)
- `-v` or `--verbose` (flag)
- Complete help text with descriptions

## Strategy-Specific Parameters (Discovery Method)

Instead of documenting all 16 strategies × parameters here, use the **self-documenting help system**:

```bash
# Discover what each strategy needs:
tzu rsi --help          # RSI: period, oversold, overbought
tzu macd --help         # MACD: fast, slow, signal
tzu stochastic --help   # Stochastic: kPeriod, dPeriod, oversold, overbought
tzu bollinger --help    # Bollinger: period, stdDev
tzu keltner --help      # Keltner: emaPeriod, atrPeriod, multiplier, mode
tzu psar --help         # Parabolic SAR: acceleration, maximum
tzu aroon --help        # Aroon: period, upThreshold, downThreshold
tzu triplem --help      # Triple MA: fastPeriod, mediumPeriod, slowPeriod
tzu adx --help          # ADX: period, threshold
tzu volume --help       # Volume Breakout: period, volumeMultiplier
tzu dualmomentum --help # Dual Momentum: rocPeriod, smaPeriod
tzu filteredrsi --help  # Filtered RSI: rsiPeriod, trendPeriod, oversold, overbought
# ... etc for all 16 strategies
```

**This approach ensures documentation never goes out of date.**

## Removed Features (vs v0.7.0)

The cligen-based CLI (v0.8.0) simplified the interface by removing:

- **`scan` command:** Multi-symbol scanning removed. Use shell scripts for batch processing.
- **`--export` option:** Removed. Pipe output to files instead: `tzutrader rsi -c data.csv > results.txt`
- **`--strategy` selector:** Each strategy is now a separate subcommand.

**Migration from v0.7.0:**

Old syntax:
```bash
tzutrader backtest data/AAPL.csv --strategy=rsi --rsi-period=10
```

New syntax:
```bash
tzu rsi --csvFile=data/AAPL.csv --period=10
```

## CSV File Requirements

The CLI expects CSV files in a specific format. See the [Data Management Reference](02_data.md) for complete specifications.

**Required columns:**
- `timestamp` or `date`
- `open`
- `high`
- `low`
- `close`
- `volume`

**Example format:**

```csv
timestamp,open,high,low,close,volume
1609459200,100.0,105.0,98.0,103.0,1000000
1609545600,103.0,107.0,101.0,106.0,1200000
```

Timestamps should be Unix timestamps (seconds since epoch) or dates in common formats (YYYY-MM-DD).

## Output Format

The CLI displays a `BacktestReport` with:

- **Period:** Date range and number of days
- **Capital:** Initial and final values
- **Returns:** Total return, annualized return, Sharpe ratio
- **Risk:** Max drawdown and duration
- **Trades:** Total, winning, losing, win rate
- **Trade Statistics:** Profit factor, avg win/loss, best/worst trade

See [Backtesting Reference](06_backtesting.md) for detailed metric definitions.

**Example output:**

```
Backtest Report: AAPL
============================================================
Period: 2023-01-01 to 2023-09-07 (249. days)

Capital
  Initial: $      100000.00
  Final:   $      109138.11

Returns
  Total Return:            9.14%
  Annualized Return:      13.69%
  Sharpe Ratio:           11.34

Risk
  Max Drawdown:           95.00%
  DD Duration:              94. days

Trades
  Total Trades:               3
  Winning Trades:             3
  Losing Trades:              0
  Win Rate:               100.0%

Trade Statistics
  Profit Factor:            inf
  Avg Win:          $   3046.04
  Avg Loss:         $      0.00
  Best Trade:       $   3165.61
  Worst Trade:      $   2882.11
  Avg Trade Return: $   3046.04
```

## Error Handling

The CLI exits with non-zero status codes on errors:

**Common errors:**
- **File not found:** Check CSV file path
- **Invalid CSV format:** Verify column names match requirements
- **Insufficient data:** Ensure CSV has enough bars for indicator calculation (e.g., RSI needs >14 bars for period=14)

Error messages describe the issue clearly.

## Limitations

The CLI uses pre-built strategies and cannot execute custom strategy logic. For custom strategies, write Nim code using the library directly (see [Strategy Reference](04_strategies.md)).

The CLI is a convenience tool for common use cases, not a replacement for programming when you need flexibility.

## Building from Source

```bash
git clone <repo-url>
cd tzutrader
nimble install -y cligen    # Install dependency
nimble cli                   # Build CLI (creates ./tzu)
./tzu --help                 # Verify installation
```

**Note:** Use `nimble cli` (not `nimble build`) to create the CLI binary. The `nimble build` command is for libraries and will show a helpful message directing you to use `nimble cli` instead.

## See Also

- [User Guide: Workflows](../user_guide/08_workflows.md) - Practical CLI usage examples  
- [Backtesting Reference](06_backtesting.md) - Understanding metrics
- [Strategy Reference](04_strategies.md) - Available strategies and their logic
- [cligen documentation](https://github.com/c-blake/cligen) - CLI framework details
