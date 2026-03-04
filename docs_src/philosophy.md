# Design Philosophy

## Why tzutrader Exists

Most backtesting libraries fall into two camps: either they're huge frameworks trying to do everything, or they're simple scripts that get rewritten for each project. tzutrader explores a middle path—composable building blocks you can understand and extend.

This is an experiment in architecture. The goal isn't to build the most feature-complete backtesting platform. It's to explore patterns for composable, streaming financial data processing in C++.

## Core Principles

### 1. Composability

Components should mix and match like LEGO blocks. Any indicator works with any strategy. Any strategy works with any portfolio. This modularity lets you:

- Test different combinations quickly
- Replace one component without rewriting everything
- Build complex behavior from simple pieces
- Understand each part in isolation

**Example:**

```cpp
// These all work together
SMA sma(20);
RSI rsi(14);
SMACrossover strategy(10, 30);
BasicPortfolio portfolio(100000, 0.001, 0.1, 0.2);

// Easy to swap components
EMA ema(20);  // Drop-in replacement for SMA
MACDStrat different_strategy(12, 26, 9);  // Different strategy, same interface
```

This is harder to achieve than it sounds. It requires careful interface design and resisting the urge to couple components together.

### 2. Streaming Over Vectorization

Financial data arrives sequentially in real trading. Backtests should too. Processing data point-by-point:

- Prevents lookahead bias (can't peek at future data)
- Uses constant memory regardless of dataset size
- Mimics how live trading systems actually work
- Forces you to think about state management

**Why this matters:**

Vectorized libraries (pandas, numpy) are fast and convenient for analysis. But they make it easy to accidentally use future data:

```python
# Easy to accidentally introduce lookahead bias
df['signal'] = (df['close'].shift(-1) > df['close'])  # Using tomorrow's price!
```

With streaming, you physically can't access data that hasn't arrived yet:

```cpp
// Only current data is available
Signal update(const Ohlcv& data) {
    double ma = sma.update(data.close);  // Can only use current and past data
    // No way to peek ahead
}
```

This constraint is a feature, not a limitation.

### 3. Simplicity and Focus

Small is beautiful. The library does one thing: backtest single-asset strategies on historical data. It doesn't:

- Fetch data from APIs
- Provide a GUI
- Include 100+ built-in strategies
- Offer parameter optimization
- Connect to live brokers

This narrow focus means:

- Less code to understand and maintain
- Fewer dependencies to manage
- Clearer mental model
- Room to experiment without breaking things

You can add these features yourself if needed. The library provides building blocks, not a complete platform.

### 4. No Magic

All behavior should be understandable by reading the code. No hidden state, no implicit behavior, no "framework magic."

**What you see is what you get:**

```cpp
class SMA {
    std::vector<double> buffer;  // Visible state
    size_t pos;
    double sum;
    
    double update(double value) {
        // Clear logic, no hidden behavior
        if (len < window) {
            len++;
        } else {
            sum -= buffer[pos];
        }
        sum += value;
        buffer[pos] = value;
        pos = (pos + 1) % window;
        return sum / window;
    }
};
```

You can trace exactly what happens on each update. No surprises.

### 5. Performance Through Simplicity

Fast code doesn't need to be complex. Simple algorithms with good data structures often outperform "clever" code.

**Design choices for performance:**

- Circular buffers for rolling windows (O(1) updates)
- Templates for zero-cost abstraction
- Minimal dynamic allocation in hot paths
- Streaming to avoid loading entire datasets

But performance isn't the primary goal—clarity is. Fast code that's unmaintainable isn't useful.

## Unix Philosophy Influence

> Write programs that do one thing and do it well. Write programs to work together.
> — Doug McIlroy

The Unix philosophy shapes tzutrader's design:

### Small, Focused Tools

Each component does one thing:

- Indicators calculate values
- Strategies generate signals
- Portfolios manage positions
- Runners orchestrate the process

Like Unix commands (`grep`, `sort`, `cut`), you combine them to create complex behavior.

### Text Streams as Universal Interface

Unix programs communicate through text streams. tzutrader uses standard interfaces:

```bash
# Unix pipeline
cat data.csv | grep "2024" | cut -d',' -f5 | awk '{sum+=$1} END {print sum}'

# tzutrader pipeline
cat data.csv | ./my_backtest | tr ' ' '\n' | column -t -s ':'
```

CSV in, metrics out. Simple, composable, scriptable.

### Sharp Tools

Each component should be a "sharp tool"—simple interface, powerful when composed:

```cpp
// Sharp tools
SMA sma(20);
EMA ema(20);
RSI rsi(14);

// Composed into something more powerful
class MyStrategy {
    SMA sma;
    RSI rsi;
    // Use both together
};
```

### Mechanism, Not Policy

The library provides mechanisms (indicators, signal generation, position tracking) but doesn't enforce policies (which strategy to use, how to size positions).

You decide the policies. The library just provides the tools.

## Who This Is For

### Target Users

**Primary audience:**

- Intermediate to advanced programmers comfortable with C++
- Traders who want systematic strategy testing
- Students learning about algorithmic trading
- Developers interested in financial software architecture

**This is NOT for:**

- Complete programming beginners (C++ is hard)
- People wanting plug-and-play solutions (requires coding)
- Those expecting guaranteed profits (no such thing)
- Users wanting extensive hand-holding (minimal docs, you read code)

### Why C++?

C++ is harder than Python. So why use it?

**Learning value:**

- Forces you to think about memory and state
- No hiding behind framework magic
- Closer to how production systems work
- Understanding performance implications

**Performance:**

- 10-100x faster than Python for compute-heavy tasks
- Matters when testing thousands of parameter combinations
- Low latency when processing large datasets

**Production relevance:**

- Most serious trading systems use C++ (or C, Java, Rust)
- Skills transfer to professional environment
- Understanding systems-level concerns

**Trade-offs:**

- Steeper learning curve than Python
- More verbose code
- Harder to prototype quickly
- Less forgiving of mistakes

If you're learning backtesting, Python is easier. If you're learning systems programming or want production-relevant skills, C++ is valuable.

### Prerequisites

To use tzutrader effectively, you should understand:

**C++ fundamentals:**

- Classes and templates
- Standard library containers
- Memory management basics
- Build systems (CMake)

**Trading basics:**

- What indicators measure
- How signals translate to trades
- Risk management concepts
- Why backtesting is hard

**Unix/command-line:**

- Basic shell commands
- Pipes and redirection
- Text processing tools

If you're missing any of these, tzutrader will be frustrating. That's okay—it's not for everyone.

## What This Means in Practice

### You Will Write Code

This isn't a GUI application where you click buttons. You write C++ code to define strategies:

```cpp
class MyStrategy: public tzu::Strategy<MyStrategy, tzu::Ohlcv> {
    tzu::SMA fast;
    tzu::SMA slow;
    
public:
    MyStrategy() : fast(10), slow(30) {}
    
    tzu::Signal update(const tzu::Ohlcv& data) {
        // Your logic here
    }
};
```

If you're not comfortable writing and compiling C++, this isn't the right tool.

### You Will Read Code

Documentation is minimal by design. To understand how things work, read the headers in `include/tzu/`. They're commented and relatively short.

If you expect comprehensive documentation explaining every detail, you'll be disappointed. The code IS the documentation.

### You Will Experiment

This is experimental software. You'll encounter rough edges. You might need to fix bugs yourself. You'll definitely need to extend it for your needs.

If you want stable, well-supported software, use a mature library. This is for people who want to understand and modify their tools.

### You Will Think About Design

The architecture is intentionally visible. You see how components connect, where state lives, how data flows. This is educational but requires engagement.

If you just want to run backtests without understanding the internals, other tools are better suited.

## Non-Goals

Just as important as what tzutrader is—here's what it's not trying to be:

**Not a complete trading platform:** No data feeds, no broker connections, no live trading support.

**Not beginner-friendly:** Assumes C++ proficiency and trading knowledge.

**Not feature-complete:** Minimal built-in strategies and indicators. You build what you need.

**Not production-ready:** Experimental, APIs can change, bugs exist.

**Not optimized to death:** Performance is good, not obsessive. Clarity over speed.

**Not a framework:** Provides libraries, not a framework you inherit from.

**Not trying to be Python:** If you want Python ergonomics, use Python. This is C++.

## Why This Matters

These design principles aren't arbitrary. They serve specific goals:

**For learning:** Small, understandable components teach better than massive frameworks.

**For experimentation:** Easy to modify and extend when the architecture is simple.

**For correctness:** Streaming prevents lookahead bias; composability enables testing in isolation.

**For longevity:** Simple code with few dependencies ages better than complex systems.

This is an opinionated approach. It won't suit everyone. That's fine—use what works for you.

## Evolution

Design philosophy guides decisions but isn't dogma. As we learn what works, things will change:

- Components might be refactored
- Interfaces might be simplified
- New patterns might emerge
- Bad ideas will be abandoned

The principles provide direction, not constraints. If violating a principle makes the library genuinely better, we'll violate it.

This is an experiment. Experiments mean learning, and learning means changing.

## Contributing to the Philosophy

If you use tzutrader, your feedback shapes its evolution:

- What works well?
- What's confusing?
- Where do the principles help?
- Where do they hurt?

File issues, start discussions, share your experience. Philosophy emerges from practice, not theory.

The goal is finding patterns that make backtesting code clear, composable, and correct. If you discover better patterns, share them.
