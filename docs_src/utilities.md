# Utilities

Development utilities to support building backtesting programs with tzutrader.

## Overview

The `utils/` directory contains helper tools that simplify common development tasks. These utilities follow the same Unix philosophy as the main library—small, focused tools that do one thing well.

Currently available utilities focus on program configuration and setup. As the project evolves, more utilities may be added to support testing, data preparation, and other development needs.

## genopts - Command-Line Option Parser Generator

### What It Does

`genopts` is an AWK script that generates C++ command-line parsing code from a simple specification file. Instead of manually writing argument parsing logic, you describe your options in a text file and generate a complete parser.

This is useful when writing backtesting programs that need configurable parameters (strategy periods, portfolio settings, data files, etc.).

### Why It Exists

Command-line parsing in C++ is tedious. Libraries like `getopt` are C-style and verbose. Modern C++ options exist but add dependencies. `genopts` generates simple, readable C++ code with no runtime dependencies—you own the generated code.

**Philosophy:**

- Generate code, don't depend on a library
- Simple specification format anyone can understand
- Generated code is readable C++ you can modify if needed
- No magic, no hidden behavior

### How It Works

**1. Write a specification file (`opts.txt`):**

```txt
bool verbose false "Enable verbose output"
int period 20 "Indicator period"
double threshold 0.02 "Signal threshold"
std::string datafile POSITIONAL "CSV data file"
```

**2. Generate the header:**

```bash
cd utils/genopts
./genopts.awk opts.txt > generated_config.h
```

**3. Use in your C++ program:**

```cpp
#include "generated_config.h"

int main(int argc, char* argv[]) {
    Config config;
    parse_args(config, argc, argv);
    
    // Use parsed options
    if (config.verbose) {
        std::cout << "Period: " << config.period << std::endl;
    }
    
    // config.datafile contains the positional argument
    return 0;
}
```

**4. Compile and run:**

```bash
g++ -std=c++17 my_backtest.cpp -o my_backtest
./my_backtest --verbose --period 50 data.csv
./my_backtest --help  # Auto-generated help
```

### Specification Format

Each line describes one option:

```
TYPE NAME DEFAULT "Description"
```

**Fields:**
- `TYPE`: C++ type (`bool`, `int`, `size_t`, `double`, `std::string`)
- `NAME`: Option name (becomes `--NAME` flag and struct member)
- `DEFAULT`: Default value (or `POSITIONAL` for required argument)
- `Description`: Help text in quotes

**Example:**

```txt
bool verbose false "Enable verbose logging"
int threads 4 "Number of worker threads"
size_t limit 1024 "Size limit in bytes"
std::string output output.txt "Output filename"
std::string input POSITIONAL "Input file"
```

### Generated Code

The script generates:

**1. Config struct:**
```cpp
struct Config {
    bool verbose = false;
    int threads = 4;
    size_t limit = 1024;
    std::string output = "output.txt";
    std::string input;  // positional
};
```

**2. parse_args() function:**

Parses command-line arguments and fills the Config struct. Handles:

- Long flags: `--verbose`, `--threads 8`
- Short flags: `-v`, `-t 8` (auto-assigned)
- Help flag: `-h`, `--help`
- Positional arguments
- Type conversions (string to int, double, etc.)

**3. print_help() function:**

Auto-generated help message showing all options and defaults.

### Usage Examples

**Basic backtest with options:**

```txt
# backtest_opts.txt
bool verbose false "Print portfolio after each update"
int fast_period 10 "Fast SMA period"
int slow_period 30 "Slow SMA period"
double threshold 0.01 "Crossover threshold percentage"
std::string datafile POSITIONAL "CSV data file"
```

Generate and use:

```bash
./genopts.awk backtest_opts.txt > generated_config.h
```

```cpp
#include "tzu.h"
#include "generated_config.h"

int main(int argc, char* argv[]) {
    Config cfg;
    parse_args(cfg, argc, argv);
    
    tzu::SMACrossover strategy(cfg.fast_period, cfg.slow_period, cfg.threshold);
    tzu::BasicPortfolio portfolio(100000, 0.001, 0.1, 0.2);
    
    std::ifstream file(cfg.datafile);
    tzu::Csv<tzu::Ohlcv> csv(file);
    
    tzu::BasicRunner<tzu::BasicPortfolio, tzu::SMACrossover, tzu::Csv<tzu::Ohlcv>>
        runner(portfolio, strategy, csv);
    
    runner.run(cfg.verbose);
    return 0;
}
```

Run with different parameters:

```bash
# Default parameters
./backtest data.csv

# Custom parameters
./backtest --fast-period 5 --slow-period 20 --verbose data.csv

# Show help
./backtest --help
```

### Supported Types

**Boolean (`bool`):**

- Flags that set to `true` when present
- Example: `--verbose` sets `config.verbose = true`

**Integers (`int`, `size_t`):**

- Converted using `std::stoi` or `std::stoul`
- Example: `--period 50` sets `config.period = 50`

**Floating-point (`double`):**

- Converted using `std::stod`
- Example: `--threshold 0.05` sets `config.threshold = 0.05`

**Strings (`std::string`):**

- Assigned directly
- Example: `--output result.txt` sets `config.output = "result.txt"`

**Positional arguments:**

- Use `POSITIONAL` as default value
- Must appear after all flags
- Example: `input_file` in `./program [options] input_file`

### Short Flags

Short flags are auto-assigned using the first available letter of the option name:

- `verbose` → `-v`
- `threads` → `-t`
- `output` → `-o`

If the first letter is taken, the next available letter is used. The `-h` flag is reserved for `--help`.

### Limitations

**Simple by design:**

- No combined short flags (`-vt` for `-v -t`)
- No advanced getopt-style features
- No option validation (you handle that in your program)
- No complex default values (must be C++ literals)

These limitations keep the generator simple and the generated code readable.

### When to Use

**Use genopts when:**

- Building backtesting programs with configurable parameters
- You want simple command-line parsing without dependencies
- You prefer generated code over library dependencies
- Your option parsing needs are straightforward

**Don't use genopts when:**

- You need complex option parsing (subcommands, validation, etc.)
- You're already using a parsing library you like
- Your program has no command-line options

### Files

```
utils/genopts/
├── genopts.awk        # The generator script
├── README.md          # Detailed documentation
├── specs.txt          # Example specification
├── main.cc            # Example usage
└── generated_config.h # Example generated output
```

**Try it:**

```bash
cd utils/genopts
./genopts.awk specs.txt > test_config.h
g++ -std=c++17 main.cc -o test
./test --help
./test --verbose --threads 8 input.txt
```

## Future Utilities

The `utils/` directory may expand with additional development tools:

**Potential additions:**

- Data format converters (JSON to CSV, etc.)
- Test data generators (synthetic OHLCV)
- Parameter grid search helpers
- Performance profiling wrappers
- Result visualization scripts
- Build configuration helpers

If you create utilities that would be useful to others, consider contributing them. See [Contributing](contributing.md) for details.

## Philosophy

Utilities follow the same principles as the main library:

**1. Small and focused:** Each utility does one thing well.

**2. No dependencies:** Generate code or use standard tools (AWK, shell scripts).

**3. Composable:** Work with Unix pipes and shell scripting.

**4. Optional:** Use them if helpful, ignore them if not.

**5. Readable:** Simple enough to understand and modify.

The goal is providing helpful tools without imposing a workflow. If a utility doesn't fit your needs, don't use it or modify it for your situation.

## Contributing Utilities

If you've created a useful development tool for tzutrader:

1. Ensure it's small and focused
2. Document clearly what it does and why
3. Provide examples of usage
4. Keep dependencies minimal
5. Submit a pull request with the utility in `utils/your_tool/`

See [Contributing](contributing.md) for the full process.

## Getting Help

For utility-specific questions:

- Check the README.md in each utility's directory
- Look at example files provided
- File an issue on [Codeberg](https://codeberg.org/jailop/tzutrader/issues)

For general questions about tzutrader, see the [FAQ](faq.md).
