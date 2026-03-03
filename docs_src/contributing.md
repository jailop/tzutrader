# Contributing

tzutrader is an experimental project exploring composable backtesting architecture. Contributions, feedback, and criticism are welcome.

## Ways to Contribute

### Report Bugs

If you find bugs:
- Check if it's already reported in [issues](https://codeberg.org/jailop/tzutrader/issues)
- Provide a minimal reproducible example
- Include your compiler version and OS
- Describe expected vs actual behavior

### Share Feedback

Since this is an experimental project, architectural feedback is valuable:
- What patterns work well?
- What's confusing or difficult to use?
- Where does the abstraction leak?
- What would you change?

Be honest. Criticism is welcome and helpful.

### Submit Code

If you want to contribute code:
- Start with small changes
- Follow existing code style
- Add tests for new functionality
- Update documentation

## Development Setup

### Clone and Build

```bash
git clone https://codeberg.org/jailop/tzutrader
cd tzutrader
mkdir build && cd build
cmake ..
cmake --build .
```

### Run Tests

```bash
cd build
./test_indicators
./test_strategies
# Or run all tests
ctest
```

### Build Documentation

```bash
make -f Makefile.docs all
```

Requires:
- `mkdocs` for user documentation
- `doxygen` for API reference

## Project Structure

```
tzutrader/
├── include/tzu/          # Header files
│   ├── defs.h           # Core data structures
│   ├── indicators.h     # Indicator implementations
│   ├── strategies.h     # Strategy implementations
│   ├── portfolio.h      # Portfolio management
│   ├── runner.h         # Backtest orchestration
│   └── streamers.h      # Data input
├── src/                 # Implementation files (if any)
├── tests/               # Test suite
│   ├── data/           # Test data
│   └── *.cpp           # Test files
├── examples/           # Example programs
├── docs_src/          # Documentation source
└── docs/              # Generated documentation
```

## Code Style

**General principles:**
- Keep it simple
- Prefer composition over inheritance
- Use templates for flexibility without runtime cost
- Comment non-obvious logic, not obvious code
- Prefer `const` and `noexcept` where appropriate

**Naming:**
- Classes: `PascalCase`
- Functions/methods: `snake_case`
- Variables: `snake_case`
- Constants: `UPPER_SNAKE_CASE`
- Template parameters: `PascalCase`

**Example:**
```cpp
class MyIndicator: public Indicator<MyIndicator, double, double> {
private:
    double internal_state;
    
public:
    double get() const noexcept;
    double update(double value);
};
```

## Adding New Indicators

1. Create class inheriting from `Indicator<Derived, InputType, OutputType>`
2. Implement `get()` const noexcept method
3. Implement `update(InputType)` method
4. Use circular buffers for rolling windows
5. Return `std::nan("")` when insufficient data
6. Add test cases
7. Document usage and limitations

**Template:**
```cpp
class NewIndicator: public Indicator<NewIndicator, double, double> {
private:
    // Minimal state
    std::vector<double> buffer;
    size_t window;
    
public:
    NewIndicator(size_t window) : window(window) {
        buffer.reserve(window);
    }
    
    double get() const noexcept {
        // Return current value or NaN
        return buffer.size() < window ? std::nan("") : compute();
    }
    
    double update(double value) {
        // Update state
        buffer.push_back(value);
        if (buffer.size() > window) {
            buffer.erase(buffer.begin());
        }
        return get();
    }
};
```

## Adding New Strategies

1. Inherit from `Strategy<Derived, InputType>`
2. Implement `update(const InputType&) -> Signal`
3. Track `last_side` to avoid signal spam
4. Check for NaN values from indicators
5. Make parameters configurable via constructor
6. Add test with known outcomes
7. Document strategy logic and use cases

**Template:**
```cpp
class NewStrategy: public Strategy<NewStrategy, Ohlcv> {
private:
    Indicator1 ind1;
    Indicator2 ind2;
    Side last_side;
    
public:
    NewStrategy(/* parameters */)
        : ind1(params), ind2(params), last_side(Side::NONE) {}
    
    Signal update(const Ohlcv& data) {
        double val1 = ind1.update(data.close);
        double val2 = ind2.update(data.close);
        
        Signal signal = {data.timestamp, Side::NONE, data.close};
        
        if (std::isnan(val1) || std::isnan(val2)) {
            return signal;
        }
        
        // Strategy logic here
        if (buy_condition && last_side != Side::BUY) {
            signal.side = Side::BUY;
            last_side = Side::BUY;
        } else if (sell_condition && last_side != Side::SELL) {
            signal.side = Side::SELL;
            last_side = Side::SELL;
        }
        
        return signal;
    }
};
```

## Adding Tests

Tests live in `tests/` directory. Use a simple testing framework or plain assertions.

**Example test:**
```cpp
#include <cassert>
#include <cmath>
#include "tzu.h"

void test_new_indicator() {
    tzu::NewIndicator ind(5);
    
    // Test insufficient data
    assert(std::isnan(ind.update(1.0)));
    assert(std::isnan(ind.update(2.0)));
    
    // Test with enough data
    for (int i = 0; i < 5; i++) {
        ind.update(i);
    }
    double result = ind.get();
    assert(!std::isnan(result));
    // Check expected value
}

int main() {
    test_new_indicator();
    return 0;
}
```

## Documentation

When adding features:
- Update relevant documentation pages
- Add code examples
- Explain limitations and trade-offs
- Keep an honest tone

Documentation lives in `docs_src/`:
- `getting-started.md`: Introductory content
- `indicators.md`: Indicator documentation
- `strategies.md`: Strategy documentation
- `portfolios.md`: Portfolio management
- `architecture.md`: Design details

## Pull Request Process

1. **Fork the repository** on Codeberg
2. **Create a feature branch**: `git checkout -b feature/my-feature`
3. **Make your changes** with clear commits
4. **Test your changes** locally
5. **Update documentation** if needed
6. **Submit a pull request** with:
   - Description of changes
   - Rationale for the change
   - Any breaking changes noted

**PR guidelines:**
- Keep changes focused (one feature/fix per PR)
- Write clear commit messages
- Ensure tests pass
- Update documentation

## Communication

- **Issues**: Use for bugs, feature requests, questions
- **Pull Requests**: Use for code contributions
- **Email**: Contact maintainers for private discussions

## What Gets Accepted

Since this is experimental, the bar for contributions varies:

**Likely accepted:**
- Bug fixes
- New indicators with tests
- New strategies with tests
- Documentation improvements
- Test coverage improvements
- Performance optimizations (with benchmarks)

**Needs discussion:**
- Architectural changes
- New dependencies
- Breaking API changes
- Major feature additions

**Unlikely accepted:**
- Large refactors without clear benefit
- Features that break composability
- Overly complex additions
- Changes without tests

## Design Philosophy

Keep these principles in mind:

1. **Simplicity over features**: Small, focused tools
2. **Composability**: Components mix and match
3. **Streaming**: Process data incrementally
4. **No magic**: Clear, understandable code
5. **Educational**: Easy to learn from

If a contribution aligns with these principles, it's more likely to be accepted.

## Code Review

Expect code reviews to focus on:
- Correctness
- Clarity
- Performance implications
- API design
- Test coverage

Feedback is meant to improve code quality, not personal criticism. Reviews may be thorough—that's because the maintainers care about the project.

## Recognition

Contributors are recognized in:
- Commit history
- CHANGELOG.txt
- Repository contributors page

Significant contributions may be noted in documentation.

## License

By contributing, you agree that your contributions will be licensed under the same license as the project. Check the LICENSE file in the repository.

## Getting Started as a Contributor

If you want to contribute but don't know where to start:

1. **Read the code**: Start with `include/tzu/` headers
2. **Run examples**: Understand how components work together
3. **Try the tests**: See what's currently tested
4. **Look at issues**: Find something labeled "good first issue"
5. **Ask questions**: File an issue if something is unclear

The best way to start is small: fix a typo, improve a comment, add a test case. Build familiarity before tackling larger changes.

## Experimental Nature

Remember: tzutrader is experimental. The API may change, architectural decisions may be revisited, and features may be removed. This is intentional.

If you contribute, understand that your code might be refactored or even removed as the project evolves. That's not a rejection of your work—it's part of the exploration process.

## Final Notes

Contributions are appreciated, but there's no obligation. If you use tzutrader and find value in it, that's contribution enough.

If you do contribute code, be patient. This is a side project, and review/merge may take time. Quality over speed.

Thank you for your interest in improving tzutrader.
