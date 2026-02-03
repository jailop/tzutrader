# TzuTrader Development Roadmap

Year: 2026

**Zero-Allocation Core**

- Stack-Based Allocation: Move all core memory requirements to the
  stack. Utilize comptime definitions to pre-calculate buffer sizes for
  order books and signal arrays.
- Heap Elimination: Audit the current codebase to remove dynamic
  allocations during the hot loop. This ensures deterministic
  performance and eliminates garbage collection pauses.

**Static Polymorphism via Concepts**

- Deprecate OOP: Remove inheritance and runtime dispatch.
- Nim Concepts Implementation: Implement concepts to define behavior for
  trading entities. This allows for "compile-time interfaces" that
  maintain high performance without the overhead of virtual method
  tables (vtables).

**Dynamic Strategy JIT**

- YAML Compilation: Implement a JIT compiler for YAML-defined strategy
  templates.
- Runtime Flexibility: Allow users to modify strategies via YAML without
  a full project recompilation, while ensuring the generated machine
  code remains optimized for the CPU.

**Expanded Data Universe**

- Alternative Data Support: Extend the engine beyond standard OHLCV
  (Open, High, Low, Close, Volume) data.
- Data Types: Integrate support for data like:
    - Level 2 Quote Data: Full order book depth and market by price.
    - Contracts and open interest for derivatives.
    - Fundamental Data: Financial statements, earnings reports, etc.
    - Macroeconomic Indicators: Interest rates, employment data, GDP
      figures.
    - Sentiment & Metadata: Alternative inputs like news feeds or social
      signals.

**Standardized Connectivity Interface**

- Provider/Processor Abstraction: Define a strict, unified interface to
  decouple the engine from specific brokers or data vendors.
- Data Provider Interface: A standard concept for streaming real-time
  market data.
- Order Processor Interface: A standard concept for order routing,
  execution, and state management (e.g., filled, cancelled, rejected).
