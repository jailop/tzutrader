# TzuTrader Development Roadmap

Year: 2026

**User Experience**

- Include examples and templates for common strategies to help user
  onboarding.
- Improve the documentation to be more consistent and comprehensive.

Memory Management

- Move key core memory requirements to the stack. Utilize comptime
  definitions to pre-calculate buffer sizes
- Remove dynamic allocations during the hot loop.

**Introduce Concepts**

- Deprecate OOP: Remove inheritance and runtime dispatch.
- Implement concepts to define behavior on indicators and strategies

**YAML templates**

- Implement run time compilation to support YAML-defined strategy
  templates.

**Expanded Data Interfaces**

- Alternative Data Support: Extend the engine beyond standard OHLCV
  data.
- Define a unified interface to decouple the engine from third party
  data sources.
