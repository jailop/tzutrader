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

The CLI supports four modes of operation:

### 1. Built-in Strategy Mode

```bash
# Simple syntax (Yahoo Finance default)
tzu --run-strat=<STRATEGY> --symbol=<SYMBOL> --start=<YYYY-MM-DD> [options]
tzu -r <STRATEGY> -s <SYMBOL> --start=<YYYY-MM-DD> [options]

# Explicit data source
tzu --run-strat=<STRATEGY> --csvFile=<file> [options]
tzu --run-strat=<STRATEGY> --yahoo=<SYMBOL> --start=<YYYY-MM-DD> [options]
tzu --run-strat=<STRATEGY> --coinbase=<PAIR> --start=<YYYY-MM-DD> [options]
```

### 2. YAML Strategy Mode

```bash
# Test a declarative YAML strategy
tzu --yaml-strategy=<FILE> --symbol=<SYMBOL> --start=<YYYY-MM-DD> [options]
```

### 3. Batch Testing Mode

```bash
# Run multiple strategies/variants on multiple symbols
tzu --batch=<BATCH_CONFIG.yml>
```

### 4. Parameter Sweep Mode

```bash
# Automated parameter optimization (grid search)
tzu --sweep=<SWEEP_CONFIG.yml>
```

**Key Parameters:**
- `--run-strat=<STRATEGY>` or `-r`: Built-in strategy to backtest
- `--yaml-strategy=<FILE>`: Path to YAML strategy file
- `--batch=<FILE>`: Path to batch testing configuration
- `--sweep=<FILE>`: Path to parameter sweep configuration
- `--symbol=<SYMBOL>` or `-s`: Use Yahoo Finance (default data source)
- `--start=<YYYY-MM-DD>`: Start date (required for online sources, no short option)
- `--endDate=<YYYY-MM-DD>` or `-e`: End date (optional)

**Note**: Only ONE mode can be used at a time (--run-strat, --yaml-strategy, --batch, or --sweep).

This design ensures:
- Clear separation between different testing modes
- All strategies share the same parameter namespace
- Yahoo Finance as default data source when using `--symbol` or `-s`
- No conflicts: `--start` has no short option to avoid `-s` conflict

## Discovering Available Options

Get help on all available modes and parameters:

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
  YAML: Use --yaml-strategy for declarative strategies
  Batch: Use --batch to run multiple strategies at once
  Sweep: Use --sweep for automated parameter optimization

Options:
  -r=, --runStrat=STRATEGY       Built-in strategy to backtest
  --yamlStrategy=FILE            Path to YAML strategy file
  --batch=FILE                   Path to batch testing configuration
  --sweep=FILE                   Path to parameter sweep configuration
  -s=, --symbol=SYMBOL           Symbol for Yahoo Finance
  --start=YYYY-MM-DD             Start date (required for online sources)
  -e=, --endDate=YYYY-MM-DD      End date (optional)
  -v, --verbose                  Show detailed output
  ...
```

If no mode is specified, the CLI shows usage examples:

```bash
tzu
```

**Output:**
```
Error: Must specify one of: --run-strat, --yaml-strategy, --batch, or --sweep

Usage: tzu [--run-strat=<STRATEGY> | --yaml-strategy=<FILE> | --batch=<FILE> | --sweep=<FILE>] [options]

Examples:
  tzu --run-strat=rsi --symbol=AAPL --start=2023-01-01
  tzu --yaml-strategy=strategies/my_rsi.yml --symbol=AAPL --start=2023-01-01
  tzu --batch=examples/batch/basic_batch.yml
  tzu --sweep=examples/sweep/rsi_optimization.yml
  tzu --run-strat=macd --csvFile=data.csv --fast=10 --slow=20
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

### Example 8: YAML Strategy

```bash
tzu --yaml-strategy=strategies/my_rsi.yml --symbol=AAPL --start=2023-01-01
```

Tests a declarative YAML strategy. See [User Guide: Writing Custom Strategies with YAML](../user_guide/04b_custom_strategies_yaml.md).

### Example 9: YAML Strategy with CSV Data

```bash
tzu --yaml-strategy=strategies/macd_crossover.yml --csvFile=data/MSFT.csv
```

Tests a YAML strategy on local CSV data.

### Example 10: Batch Testing

```bash
tzu --batch=examples/batch/basic_batch.yml
```

Runs multiple strategy variants on multiple symbols. The batch configuration file specifies:
- Data source and symbols
- Multiple strategies with parameter overrides
- Portfolio settings
- Output format

See [Reference: Declarative System - Batch Testing](10_declarative.md#batch-testing).

### Example 11: Batch Testing with Verbose Output

```bash
tzu --batch=examples/batch/basic_batch.yml --verbose
```

Shows detailed progress during batch testing.

### Example 12: Parameter Sweep (Optimization)

```bash
tzu --sweep=examples/sweep/rsi_optimization.yml
```

Automatically tests all combinations of parameter values to find optimal settings. The sweep configuration specifies:
- Base strategy file
- Parameters to optimize
- Value ranges (list or linear)
- Output files

See [Reference: Declarative System - Parameter Sweep](10_declarative.md#parameter-sweep-grid-search).

### Example 13: Parameter Sweep with Verbose Output

```bash
tzu --sweep=examples/sweep/macd_simple.yml --verbose
```

Shows progress during parameter sweep (useful for long-running optimizations).

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

## YAML Strategy Mode

Test a declarative YAML strategy without writing code.

### Command Syntax

```bash
tzu --yaml-strategy=<FILE> [data-source] [portfolio-options]
```

### Example

```bash
tzu --yaml-strategy=strategies/my_rsi.yml --symbol=AAPL --start=2023-01-01 --endDate=2023-12-31
```

### What It Does

1. Loads and parses the YAML strategy file
2. Validates the strategy configuration
3. Builds an executable strategy from the YAML definition
4. Runs a backtest using the specified data source
5. Displays the backtest report

### YAML Strategy Format

```yaml
metadata:
  name: "My RSI Strategy"
  description: "Buy oversold, sell overbought"

indicators:
  - id: rsi_14
    type: rsi
    params:
      period: 14

entry:
  conditions:
    left: rsi_14
    operator: "<"
    right: "30"

exit:
  conditions:
    left: rsi_14
    operator: ">"
    right: "70"

position_sizing:
  type: fixed
  size: 100
```

See [User Guide: Writing Custom Strategies with YAML](../user_guide/04b_custom_strategies_yaml.md) for complete documentation.

### Validation

The CLI validates the strategy before running:

```bash
$ tzu --yaml-strategy=invalid_strategy.yml --symbol=AAPL --start=2023-01-01

Loading YAML strategy from: invalid_strategy.yml
Validating strategy...
Strategy validation failed:
  - Missing required field: metadata.name
  - Unknown indicator type: 'rsi2' (did you mean 'rsi'?)
  - Invalid operator: '>=' (valid operators: <, >, <=, >=, ==, !=, crosses_above, crosses_below)
```

### Example Output

```
Loading YAML strategy from: strategies/my_rsi.yml
Validating strategy...
Strategy 'My RSI Strategy' loaded successfully
Data: YahooFinance, AAPL, 252 bars

Backtest Report: AAPL
============================================================
Period: 2023-01-01 to 2023-12-31 (252 days)

Capital
  Initial: $      100000.00
  Final:   $      115300.00

Returns
  Total Return:           15.30%
  Annualized Return:      15.30%
  Sharpe Ratio:            1.45

Risk
  Max Drawdown:            8.20%
  DD Duration:             45 days

Trades
  Total Trades:              24
  Winning Trades:            15
  Losing Trades:              9
  Win Rate:                62.5%

Trade Statistics
  Profit Factor:            2.14
  Avg Win:          $   1240.50
  Avg Loss:         $    580.30
  Best Trade:       $   2100.00
  Worst Trade:      $ -  980.00
  Avg Trade Return: $    637.50
```

## Batch Testing Mode

Run multiple strategy variants on multiple symbols in a single command.

### Command Syntax

```bash
tzu --batch=<BATCH_CONFIG.yml> [--verbose]
```

### Example

```bash
tzu --batch=examples/batch/basic_batch.yml
```

### What It Does

1. Loads the batch configuration file
2. For each symbol:
   - For each strategy variant:
     - Fetches data (or loads from CSV)
     - Applies parameter overrides
     - Runs backtest
     - Records results
3. Exports comparison report to CSV
4. Displays top performers

### Batch Configuration Format

```yaml
version: "1.0"

metadata:
  name: "Compare RSI Strategies"
  description: "Test different RSI thresholds"

data:
  source: yahoo
  symbols:
    - AAPL
    - MSFT
    - GOOGL
  start_date: "2023-01-01"
  end_date: "2024-01-01"

portfolio:
  initial_cash: 100000.0
  commission: 0.001
  min_commission: 1.0

strategies:
  - file: "rsi_simple.yml"
    name: "RSI_Conservative"
    # Use default parameters
  
  - file: "rsi_simple.yml"
    name: "RSI_Aggressive"
    overrides:
      conditions:
        entry:
          left: rsi_14
          operator: "<"
          right: "25"
        exit:
          left: rsi_14
          operator: ">"
          right: "75"

output:
  formats:
    - csv
  comparison_report: "results/comparison.csv"
  individual_results: "results/individual/"
```

See [Reference: Declarative System - Batch Testing](10_declarative.md#batch-testing) for complete documentation.

### Example Output

```
Running batch test from: examples/batch/basic_batch.yml

Loading strategy: RSI_Conservative from rsi_simple.yml
Loading strategy: RSI_Aggressive from rsi_simple.yml

Testing RSI_Conservative on AAPL... Done (2.1s)
Testing RSI_Aggressive on AAPL... Done (1.9s)
Testing RSI_Conservative on MSFT... Done (2.0s)
Testing RSI_Aggressive on MSFT... Done (2.2s)
Testing RSI_Conservative on GOOGL... Done (2.1s)
Testing RSI_Aggressive on GOOGL... Done (2.0s)

Batch Test Summary
============================================================
Total Combinations: 6 (2 strategies × 3 symbols)
Completed: 6
Failed: 0

Exporting results to: results/comparison.csv

Top 10 by Total Return:
   1. RSI_Aggressive          on MSFT  :    28.56% (Sharpe:  1.85)
   2. RSI_Aggressive          on GOOGL :    24.32% (Sharpe:  1.72)
   3. RSI_Conservative        on MSFT  :    22.14% (Sharpe:  1.62)
   4. RSI_Aggressive          on AAPL  :    20.89% (Sharpe:  1.52)
   5. RSI_Conservative        on GOOGL :    18.75% (Sharpe:  1.48)
   6. RSI_Conservative        on AAPL  :    15.30% (Sharpe:  1.45)
```

### CSV Output

The batch test generates a CSV file with all results:

```csv
Strategy,Symbol,Start Date,End Date,Total Return %,Sharpe Ratio,Max Drawdown %,Win Rate %,Num Trades
RSI_Conservative,AAPL,2023-01-01,2024-01-01,15.30,1.45,-8.20,62.5,24
RSI_Aggressive,AAPL,2023-01-01,2024-01-01,20.89,1.52,-12.50,58.3,36
RSI_Conservative,MSFT,2023-01-01,2024-01-01,22.14,1.62,-7.50,65.0,28
...
```

## Parameter Sweep Mode

Automatically find optimal parameter values through grid search.

### Command Syntax

```bash
tzu --sweep=<SWEEP_CONFIG.yml> [--verbose]
```

### Example

```bash
tzu --sweep=examples/sweep/rsi_optimization.yml
```

### What It Does

1. Loads the parameter sweep configuration
2. Generates all parameter combinations (Cartesian product)
3. For each combination:
   - Creates a strategy variant with those parameters
   - Runs backtest
   - Records results
4. Exports full results and best results to CSV
5. Displays top N parameter combinations

### Sweep Configuration Format

```yaml
version: "1.0"

metadata:
  name: "Optimize RSI Parameters"
  description: "Find optimal RSI period and thresholds"

base_strategy: "rsi_simple.yml"

data:
  source: yahoo
  symbols:
    - AAPL
  start_date: "2023-01-01"
  end_date: "2024-01-01"

portfolio:
  initial_cash: 100000.0
  commission: 0.001

parameters:
  - path: "indicators.rsi_14.period"
    range:
      type: list
      values: [10, 14, 20, 30]
  
  - path: "conditions.entry.right"
    range:
      type: linear
      min: 20
      max: 40
      step: 5
  
  - path: "conditions.exit.right"
    range:
      type: linear
      min: 60
      max: 80
      step: 5

output:
  best_results: "results/best_params.csv"
  full_results: "results/all_params.csv"
```

**This configuration tests**: 4 × 5 × 5 = **100 combinations**

See [Reference: Declarative System - Parameter Sweep](10_declarative.md#parameter-sweep-grid-search) for complete documentation.

### Example Output

```
Running parameter sweep from: examples/sweep/rsi_optimization.yml

Base Strategy: rsi_simple.yml
Parameters to sweep:
  - indicators.rsi_14.period: [10, 14, 20, 30]
  - conditions.entry.right: [20, 25, 30, 35, 40]
  - conditions.exit.right: [60, 65, 70, 75, 80]

Total combinations: 100

Running sweep on AAPL...
Progress: [####################] 100/100 (100%)

Parameter Sweep Summary
============================================================
Total Combinations: 100
Completed: 100
Failed: 0

Exporting full results to: results/all_params.csv
Exporting best results to: results/best_params.csv

============================================================
Top 10 Parameter Combinations by Total Return
============================================================

1. Sweep_42 on AAPL
   Return: 28.50%, Sharpe: 2.15, Drawdown: -8.20%
   Parameters:
     indicators.rsi_14.period: 20
     conditions.entry.right: 30
     conditions.exit.right: 70

2. Sweep_17 on AAPL
   Return: 25.30%, Sharpe: 1.98, Drawdown: -9.50%
   Parameters:
     indicators.rsi_14.period: 14
     conditions.entry.right: 25
     conditions.exit.right: 75

3. Sweep_68 on AAPL
   Return: 24.80%, Sharpe: 1.92, Drawdown: -10.20%
   Parameters:
     indicators.rsi_14.period: 30
     conditions.entry.right: 30
     conditions.exit.right: 65

...
```

### CSV Output

**Full Results** (`results/all_params.csv`):
```csv
Strategy,Symbol,Total Return %,Sharpe Ratio,Max Drawdown %,Trades,indicators.rsi_14.period,conditions.entry.right,conditions.exit.right
Sweep_1,AAPL,12.50,1.20,-10.50,18,10,20,60
Sweep_2,AAPL,14.20,1.35,-9.80,20,10,20,65
...
```

**Best Results** (`results/best_params.csv`):
Top 50 combinations ranked by total return.

### Optimization Strategy

For efficient parameter optimization:

1. **Start with coarse sweep**: Wide ranges, big steps
2. **Identify promising regions**: Look at top 10 results
3. **Run fine-grained sweep**: Narrow ranges around winners
4. **Validate on different data**: Test winners on out-of-sample period

Example workflow:
```bash
# Stage 1: Coarse sweep
tzu --sweep=sweep_coarse.yml  # 27 combinations (3×3×3)

# Review results, identify best region (e.g., period=20, entry=30)

# Stage 2: Fine sweep
tzu --sweep=sweep_fine.yml    # 25 combinations (5×5 around best)

# Stage 3: Validate winners on different period
# Edit sweep_fine.yml to use 2024 data instead of 2023
tzu --sweep=sweep_validate.yml
```

## Mode Selection

Only ONE mode can be active at a time:

```bash
# ✅ Valid: Single mode
tzu --run-strat=rsi --symbol=AAPL --start=2023-01-01

# ✅ Valid: Single mode
tzu --yaml-strategy=my_strategy.yml --symbol=AAPL --start=2023-01-01

# ✅ Valid: Single mode
tzu --batch=batch_config.yml

# ✅ Valid: Single mode
tzu --sweep=sweep_config.yml

# ❌ Invalid: Multiple modes
tzu --run-strat=rsi --yaml-strategy=my_strategy.yml --symbol=AAPL
# Error: Can only use ONE of: --run-strat, --yaml-strategy, --batch, or --sweep
```

## Automatic Parameter Generation

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

## Built-in Strategy Parameters

TzuTrader includes 16 pre-built strategies. All their parameters are available as command-line options. Use the **self-documenting help system** to see all available options:

```bash
tzu --help
```

**Important**: The built-in strategies are **reference implementations** to demonstrate trading concepts. They are not optimized for production use. You should:
- Understand how each strategy works before using it
- Test thoroughly on historical data
- Create custom strategies tailored to your needs
- Consider using YAML strategies for easier customization

See [User Guide: Writing Custom Strategies with YAML](../user_guide/04b_custom_strategies_yaml.md) for creating your own strategies.

The help output shows all parameters for all built-in strategies in one unified interface, including:

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

### Built-in Strategy Mode

The `--run-strat` mode uses pre-built strategies with limited customization (parameter values only). For custom strategies:

- **Use YAML strategies** (`--yaml-strategy`): No programming required, full flexibility with 30+ indicators
- **Write Nim code**: Maximum flexibility and performance (see [Strategy Reference](04_strategies.md))

### When to Use Each Approach

| Need | Use CLI Mode | Or Write Nim Code |
|------|--------------|-------------------|
| Quick test of built-in strategy | `--run-strat` | ❌ |
| Custom strategy without programming | `--yaml-strategy` | ❌ |
| Test multiple parameter variations | `--batch` or `--sweep` | ❌ |
| Complex custom logic | ❌ | ✅ |
| State management across timeframes | ❌ | ✅ |
| Maximum performance | ❌ | ✅ |
| Multi-symbol scanning | Script multiple CLI calls | ✅ |
| Production trading bot | ❌ | ✅ |

The CLI is a powerful tool for backtesting and optimization. For most retail traders, YAML strategies with batch testing and parameter sweeps provide everything needed without programming.

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

- [User Guide: Writing Custom Strategies with YAML](../user_guide/04b_custom_strategies_yaml.md) - Create strategies without programming
- [Reference: Declarative System](10_declarative.md) - Complete YAML strategy reference
- [User Guide: Workflows](../user_guide/08_workflows.md) - Practical CLI usage examples  
- [Backtesting Reference](06_backtesting.md) - Understanding metrics
- [Strategy Reference](04_strategies.md) - Built-in strategies and their logic
- [cligen documentation](https://github.com/c-blake/cligen) - CLI framework details
