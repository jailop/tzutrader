# Reference Guide: Command-Line Interface

## ⚠️ Disclaimer

**Educational Use Only**: The TzuTrader CLI is for backtesting and research purposes only. It does not provide financial advice. Trading involves substantial risk, and past performance does not guarantee future results. Users are solely responsible for their trading decisions.

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

## Command Structure

```bash
# Simple syntax (Yahoo Finance default)
tzu --run-strat=<STRATEGY> --symbol=<SYMBOL> --start=<YYYY-MM-DD> [options]
tzu -r <STRATEGY> -s <SYMBOL> --start=<YYYY-MM-DD> [options]

# Explicit data source
tzu --run-strat=<STRATEGY> --csvFile=<file> [options]
tzu --run-strat=<STRATEGY> --yahoo=<SYMBOL> --start=<YYYY-MM-DD> [options]
tzu --run-strat=<STRATEGY> --coinbase=<PAIR> --start=<YYYY-MM-DD> [options]
```

**Key Parameters:**
- `--run-strat=<STRATEGY>` or `-r` (required): Strategy to backtest
- `--symbol=<SYMBOL>` or `-s`: Use Yahoo Finance (default data source)
- `--start=<YYYY-MM-DD>` (required for online sources): Start date (no short option)
- `--endDate=<YYYY-MM-DD>` or `-e`: End date (optional)

This design ensures:
- Clear separation between command options and strategy selection
- All strategies share the same parameter namespace
- Yahoo Finance as default data source when using `--symbol` or `-s`
- No conflicts: `--start` has no short option to avoid `-s` conflict

## Discovering Available Strategies

List all 16 available strategies:

```bash
tzu --help
```

**Output shows:**
```
Usage:
  tzu [optional-params]

TzuTrader CLI - Backtest trading strategies

Available strategies:
  Mean Reversion: rsi, bollinger, stochastic, mfi, cci
  Trend Following: crossover, macd, kama, aroon, psar, triplem, adx
  Volatility: keltner
  Hybrid: volume, dualmomentum, filteredrsi

Options:
  -r=, --runStrat=STRATEGY    Strategy to backtest (required)
  -s=, --symbol=SYMBOL        Symbol for Yahoo Finance
  --start=YYYY-MM-DD          Start date (required for online sources)
  ...
```

## Discovering Strategy Parameters

Get detailed help for all parameters:

```bash
tzu --help
```

The help output shows all available parameters for all strategies, including:
- Strategy selection (`--run-strat`)
- Data source options (`--symbol`, `--csvFile`, etc.)
- All strategy-specific parameters (period, oversold, fast, slow, etc.)
- Portfolio configuration options
- Short flags (e.g., `-r`, `-s`, `-e`, `-p`, `-v`)
- Long flags (e.g., `--runStrat`, `--symbol`, `--period`, `--verbose`)

**All parameters are shown in a single help screen** since all strategies now share the same parameter namespace.

**Example:**

```bash
tzu --help
```

**Output shows all available options:**
```
Options:
  -r=, --runStrat=          string    Strategy to backtest
  -s=, --symbol=            string    Symbol for Yahoo Finance
  --start=                  string    Start date (YYYY-MM-DD)
  -e=, --endDate=           string    End date (YYYY-MM-DD)
  -c=, --csvFile=           string    CSV file path
  -p=, --period=            int       Period for indicators (default: 14)
  -o=, --oversold=          float     Oversold threshold (default: 30.0)
  --overbought=             float     Overbought threshold (default: 70.0)
  --fast=                   int       Fast period for MACD (default: 12)
  --slow=                   int       Slow period for MACD (default: 26)
  ... (and many more)
```

**The help is automatically generated from the function signature**, so it's always accurate and up-to-date.

## Common Parameters (All Strategies)

Every strategy accepts these common parameters:

### Data Source Parameters

**Option 1: Simple Yahoo Finance (Default)**

| Parameter | Short | Type | Description |
|-----------|-------|------|-------------|
| `--symbol` | `-s` | string | Symbol to backtest (uses Yahoo Finance automatically) |
| `--start` | *none* | string | Start date (YYYY-MM-DD format) - **no short option** |
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

### Example 1: Simple Yahoo Finance (Default Syntax)

```bash
tzu --run-strat=rsi --symbol=AAPL --start=2023-01-01 --endDate=2023-12-31
# Or using short flags:
tzu -r rsi -s AAPL --start=2023-01-01 -e 2023-12-31
```

Simplest syntax - uses Yahoo Finance automatically when `--symbol` is provided.

### Example 2: Yahoo Finance with Custom Parameters

```bash
tzu --run-strat=rsi -s TSLA --start=2024-01-01 --period=10 --oversold=25 -v
# Or fully abbreviated:
tzu -r rsi -s TSLA --start=2024-01-01 -p 10 -o 25 -v
```

Tesla data with custom RSI parameters and verbose output.

### Example 3: Yahoo Finance with Portfolio Configuration

```bash
tzu --run-strat=macd --symbol=MSFT --start=2023-01-01 --commission=0.001 --minCommission=1.0 --initialCash=50000
```

Tests with 0.1% commission, $1 minimum per trade, and $50K starting capital.

### Example 4: Simple Backtest with CSV

```bash
tzu --run-strat=rsi --csvFile=data/AAPL.csv
```

Uses RSI strategy with default parameters on local CSV file.

### Example 5: Explicit Yahoo Finance (Backward Compatible)

```bash
tzu --run-strat=rsi --yahoo=AAPL --start=2023-01-01 --endDate=2023-12-31
```

Explicit `--yahoo` flag still works for backward compatibility.

### Example 6: Bitcoin from Yahoo Finance

```bash
tzu --run-strat=macd -s BTC-USD --start=2024-01-01
```

Tests MACD on Bitcoin, endDate defaults to today.

### Example 7: Coinbase Cryptocurrency Data

```bash
export COINBASE_API_KEY="your_key_here"
export COINBASE_SECRET_KEY="your_secret_here"
tzu --run-strat=psar --coinbase=ETH-USD --start=2024-01-01
```

Fetches Ethereum data from Coinbase (requires API credentials).

## Data Sources

The CLI supports three data sources. 

### Default: Yahoo Finance via Symbol Parameter (Recommended)

The simplest way to use the CLI is with the `--symbol` (or `-s`) parameter and `--run-strat` to specify the strategy:

```bash
tzu --run-strat=rsi --symbol=AAPL --start=2023-01-01
tzu -r rsi -s AAPL --start=2023-01-01  # Short form
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
tzu --run-strat=rsi --csvFile=data/AAPL.csv
```

**Requirements:**
- CSV file must exist locally
- Must contain columns: timestamp, open, high, low, close, volume
- See [Data Management Reference](02_data.md) for format details

### Explicit Yahoo Finance (Backward Compatible)

You can still use the explicit `--yahoo` flag:

```bash
tzu --run-strat=rsi --yahoo=AAPL --start=2023-01-01 --endDate=2023-12-31
```

This is functionally identical to using `--symbol` but more explicit.

### Coinbase

Fetch cryptocurrency data from Coinbase Advanced Trade API.

```bash
export COINBASE_API_KEY="your_api_key"
export COINBASE_SECRET_KEY="your_secret_key"
tzu --run-strat=rsi --coinbase=BTC-USD --start=2024-01-01
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

The CLI uses **automatic parameter generation** from the main function signature:

1. The `tzu` procedure accepts all strategy parameters as optional arguments
2. cligen introspects the function signature at compile time
3. Parameters become CLI options automatically:
   - `runStrat: string` → required `--run-strat=` or `-r` option
   - `symbol: string` → optional `--symbol=` or `-s` option
   - `period = 14` → optional `--period=` with default 14
   - `verbose = false` → flag `-v` or `--verbose`
4. Doc comments become help text automatically

**Benefits:**
- Parameters stay in sync with code (no manual documentation drift)
- Type safety: cligen validates int/float/string/bool at parse time
- Zero boilerplate: adding a parameter requires zero CLI wiring code
- All strategies share the same parameter namespace

**Example from source code:**
```nim
proc tzu(
  runStrat = "",          # Required: strategy name
  symbol = "",            # Optional: Yahoo Finance symbol (default)
  csvFile = "",           # Optional: CSV file path
  yahoo = "",             # Optional: Explicit Yahoo Finance
  coinbase = "",          # Optional: Coinbase pair
  start = "",             # Required for symbol/yahoo/coinbase
  endDate = "",           # Optional: defaults to today
  period = 14,            # Optional int, default 14
  oversold = 30.0,        # Optional float, default 30.0
  overbought = 70.0,      # Optional float, default 70.0
  fast = 12,              # MACD fast period
  slow = 26,              # MACD slow period
  signal = 9,             # MACD signal period
  initialCash = 100000.0, # Optional: starting capital
  commission = 0.0,       # Optional: commission rate
  minCommission = 0.0,    # Optional: minimum commission per trade
  riskFreeRate = 0.02,    # Optional: risk-free rate for Sharpe
  verbose = false         # Optional flag, default false
): int =
  ## TzuTrader CLI - Backtest trading strategies  # ← This becomes help text
```

This single function signature automatically generates:
- `-r=` or `--runStrat=` (required)
- `--symbol=` or `-s` (optional, uses Yahoo Finance as default)
- `--csvFile=` or `-c` (optional)
- `--yahoo=` or `-y` (optional, explicit Yahoo Finance)
- `--coinbase=` (optional)
- `--start=` (required for online data sources, **no short option**)
- `--endDate=` or `-e` (optional, default: today)
- `--period=` or `-p` (default: 14)
- `--oversold=` or `-o` (default: 30.0)
- `--overbought=` (default: 70.0)
- `--fast=` (default: 12)
- `--slow=` (default: 26)
- `--signal=` (default: 9)
- `--initialCash=` or `-i` (default: 100000.0)
- `--commission=` (default: 0.0)
- `--minCommission=` (default: 0.0)
- `--riskFreeRate=` (default: 0.02)
- `-v` or `--verbose` (flag)
- Complete help text with descriptions

**Note:** `--start` has no short option to avoid conflicts with `-s` (symbol).

## Strategy-Specific Parameters

All strategy parameters are available as command-line options. Use the **self-documenting help system** to see all available options:

```bash
tzu --help
```

This shows all parameters for all strategies in one unified interface, including:

**RSI Strategy:**
- `--period` (default: 14)
- `--oversold` (default: 30.0)
- `--overbought` (default: 70.0)

**MACD Strategy:**
- `--fast` (default: 12)
- `--slow` (default: 26)
- `--signal` (default: 9)

**Stochastic Strategy:**
- `--kPeriod` (default: 14)
- `--dPeriod` (default: 3)
- `--oversold` (default: 20.0)
- `--overbought` (default: 80.0)

**Bollinger Bands:**
- `--period` (default: 20)
- `--stdDev` (default: 2.0)

**Crossover:**
- `--fastPeriod` (default: 50)
- `--slowPeriod` (default: 200)

**And many more...**

Use `tzu --help` to see the complete list with all available short options.

**This approach ensures documentation never goes out of date.**

## Removed Features (vs v0.7.0)

The cligen-based CLI (v0.8.0) simplified the interface by removing:

- **`scan` command:** Multi-symbol scanning removed. Use shell scripts for batch processing.
- **`--export` option:** Removed. Pipe output to files instead: `tzu --run-strat=rsi --csvFile=data.csv > results.txt`
- **Subcommand structure:** Strategies are now selected via `--run-strat` argument instead of subcommands.

**Migration from v0.7.0:**

Old syntax:
```bash
tzutrader backtest data/AAPL.csv --strategy=rsi --rsi-period=10
```

New syntax:
```bash
tzu --run-strat=rsi --csvFile=data/AAPL.csv --period=10
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

## Installation

### Standard Installation

```bash
git clone https://codeberg.org/jailop/tzutrader.git
cd tzutrader
nimble install -y    # Installs library + tzu command
```

After installation, the `tzu` command is available globally:

```bash
tzu --help           # Verify installation
tzu --run-strat=rsi -s AAPL --start=2023-01-01  # Run backtest
```

### Development Workflow

```bash
nimble build         # Build ./tzu in current directory (for testing)
nimble install       # Install library and CLI globally
```

Both commands follow standard Nim conventions:
- `nimble build` - Builds binaries in the current directory
- `nimble install` - Installs the library to `~/.nimble/pkgs/` and binaries to `~/.nimble/bin/`

## See Also

- [User Guide: Workflows](../user_guide/08_workflows.md) - Practical CLI usage examples  
- [Backtesting Reference](06_backtesting.md) - Understanding metrics
- [Strategy Reference](04_strategies.md) - Available strategies and their logic
- [cligen documentation](https://github.com/c-blake/cligen) - CLI framework details
