## Generic Strategy Framework for tzutrader
##
## This module provides a generic approach to strategies using Nim's generic types
## and procedures. This is simpler and more compatible than explicit concepts.
##
## **Design Philosophy:**
## - Strategies implement a specific interface (generic constraints)
## - Type information is preserved through generics
## - onData is a generic method that can process any data type
## - Zero runtime overhead - everything is resolved at compile time
## - More idiomatic Nim - uses static dispatch preferred by the language
##
## **Generic onData Pattern:**
## Strategies implement a generic onData method that handles different data types:
## ```nim
## proc onData*[T](s: var MyStrat, data: T): Signal =
##   when T is OHLCV:
##     # Process OHLCV bar
##   elif T is Quote:
##     # Process Quote (future)
##   else:
##     {.error: "Unsupported data type"}
## ```
##
## This allows future extension without modifying the core framework.

import std/[tables, math]
import ../core
from ../data import Quote
from ../datastreamers/types import DataKind, DataProvider

export core, Quote, DataKind, DataProvider

# ============================================================================
# Core Types
# ============================================================================

type
  DataFrequency* = enum
    ## Data frequency/timeframe requirements
    dfRealtime   ## Real-time tick data
    dfMinute     ## Minute bars (1m, 5m, etc.)
    dfHourly     ## Hourly bars
    dfDaily      ## Daily bars
    dfWeekly     ## Weekly bars

  DataRequirement* = object
    ## Declares a data type requirement for a strategy
    dataKind*: DataKind             ## Type of data needed (OHLCV, Quote, etc.)
    providers*: seq[DataProvider]   ## Preferred providers (in order of preference)
    required*: bool                 ## Is this data required or optional?
    frequency*: DataFrequency       ## Desired frequency
    metadata*: Table[string, string]  ## Provider-specific configuration

  PositionSizingType* = enum
    ## How the strategy calculates position sizes
    pstDefault,   ## Use backtester default (95% of cash)
    pstFixed,     ## Fixed number of shares
    pstPercent    ## Percentage of portfolio equity

# ============================================================================
# Generic Strategy Interface (implicit via generic constraints)
# ============================================================================

## Strategies must implement:
## - name: string field containing strategy name
## - symbol: string field for the trading symbol
## - onData[T](data: T): Signal - generic method that processes any data type
## - reset(): void - reset strategy state
## - getPositionSizing(): (PositionSizingType, float) - sizing configuration
##
## The framework uses generic procedures and compile-time type matching
## (via `when` statements) to ensure type safety without explicit concepts.

# ============================================================================
# Generic Strategy Processors (Compile-time Polymorphism)
# ============================================================================

proc processBar*[S](strategy: S, bar: OHLCV): Signal =
  ## Process a single OHLCV bar through a strategy
  ##
  ## This generic function preserves the concrete type S through the generic
  ## type parameter, enabling proper compile-time dispatch.
  ##
  ## Args:
  ##   strategy: Strategy instance (concrete type preserved)
  ##   bar: OHLCV bar to process
  ##
  ## Returns:
  ##   Signal with trading recommendation
  
  strategy.onData(bar)

proc processQuote*[S](strategy: S, quote: Quote): Signal =
  ## Process a Quote through a strategy
  ##
  ## Strategies that don't support quotes should raise a compile error.
  ##
  ## Args:
  ##   strategy: Strategy instance (concrete type preserved)
  ##   quote: Quote data to process
  ##
  ## Returns:
  ##   Signal with trading recommendation
  
  strategy.onData(quote)

proc resetStrategy*[S](strategy: var S) =
  ## Reset strategy state
  ##
  ## Args:
  ##   strategy: Strategy instance (concrete type preserved, must be mutable)
  
  strategy.reset()

proc getStrategyName*[S](strategy: S): string =
  ## Get strategy name
  ##
  ## Args:
  ##   strategy: Strategy instance (concrete type preserved)
  ##
  ## Returns:
  ##   Strategy name as string
  
  strategy.name

proc getStrategySymbol*[S](strategy: S): string =
  ## Get strategy symbol
  ##
  ## Args:
  ##   strategy: Strategy instance (concrete type preserved)
  ##
  ## Returns:
  ##   Trading symbol as string
  
  strategy.symbol

proc getSizingConfig*[S](strategy: S): tuple[sizingType: PositionSizingType, value: float] =
  ## Get position sizing configuration
  ##
  ## Args:
  ##   strategy: Strategy instance (concrete type preserved)
  ##
  ## Returns:
  ##   Tuple of (PositionSizingType, sizing value)
  
  strategy.getPositionSizing()

# ============================================================================
# Generic Backtester Type
# ============================================================================

type
  GenericBacktester*[S] = object
    ## Generic backtester that works with any strategy type
    ##
    ## By using a generic type parameter S, we preserve the concrete strategy type
    ## throughout the backtest, enabling proper compile-time dispatch.
    ##
    ## This is more efficient than using Strategy references because:
    ## - No virtual method table lookups
    ## - Compiler can inline all strategy calls
    ## - Better optimization opportunities
    ## - Type errors caught at compile-time
    strategy*: S
    symbol*: string
    verbose*: bool

proc newGenericBacktester*[S](strategy: S, symbol: string = "", verbose: bool = false): GenericBacktester[S] =
  ## Create a generic backtester for a specific strategy type
  ##
  ## Args:
  ##   strategy: Strategy instance (concrete type preserved)
  ##   symbol: Trading symbol (optional)
  ##   verbose: Enable verbose logging
  ##
  ## Returns:
  ##   GenericBacktester with preserved strategy type
  
  GenericBacktester[S](
    strategy: strategy,
    symbol: symbol,
    verbose: verbose
  )

# ============================================================================
# Type-Erased Runtime Polymorphism (Optional)
# ============================================================================

type
  StrategyBox* = object
    ## Type-erased container for strategies
    ##
    ## This enables runtime polymorphism when needed (e.g., heterogeneous
    ## collections of different strategy types).
    ##
    ## Supports multiple data types through proc fields:
    ## - onDataOHLCVImpl: For OHLCV bar data
    ## - onDataQuoteImpl: For Quote data (future use)
    ##
    ## Trade-off: Small runtime cost for flexibility
    ## When: Use only when you need to store different strategy types together
    name*: string
    symbol*: string
    onDataOHLCVImpl*: proc(bar: OHLCV): Signal
    onDataQuoteImpl*: proc(quote: Quote): Signal
    resetImpl*: proc(): void
    sizingImpl*: proc(): tuple[sizingType: PositionSizingType, value: float]

proc newStrategyBox*[S](strategy: S): StrategyBox =
  ## Create a type-erased box for any strategy
  ##
  ## The box captures closures for each data type that the strategy supports.
  ## When calling processBox*, the generic onData method is instantiated
  ## with the appropriate type parameter.
  ##
  ## Args:
  ##   strategy: Concrete strategy instance
  ##
  ## Returns:
  ##   StrategyBox with runtime dispatch capability
  ##
  ## Note: This captures the strategy by reference through closures.
  ##       Only use this when you need runtime polymorphism.
  
  # Create closures that capture the strategy
  # These instantiate the generic onData with specific types
  let onDataOHLCVProc = proc(bar: OHLCV): Signal = processBar(strategy, bar)
  let onDataQuoteProc = proc(quote: Quote): Signal = processQuote(strategy, quote)
  let resetProc = proc() = resetStrategy(strategy)
  let sizingProc = proc(): tuple[sizingType: PositionSizingType, value: float] = getSizingConfig(strategy)

  StrategyBox(
    name: getStrategyName(strategy),
    symbol: getStrategySymbol(strategy),
    onDataOHLCVImpl: onDataOHLCVProc,
    onDataQuoteImpl: onDataQuoteProc,
    resetImpl: resetProc,
    sizingImpl: sizingProc
  )

proc processBox*(box: StrategyBox, bar: OHLCV): Signal =
  ## Process OHLCV bar through boxed strategy
  ##
  ## Calls the strategy's generic onData method with OHLCV type.
  box.onDataOHLCVImpl(bar)

proc processBoxQuote*(box: StrategyBox, quote: Quote): Signal =
  ## Process Quote through boxed strategy
  ##
  ## Calls the strategy's generic onData method with Quote type.
  box.onDataQuoteImpl(quote)

proc resetBox*(box: StrategyBox) =
  ## Reset boxed strategy
  box.resetImpl()

proc getSizingBox*(box: StrategyBox): tuple[sizingType: PositionSizingType, value: float] =
  ## Get sizing config from boxed strategy
  box.sizingImpl()

# ============================================================================
# Helper Conversions
# ============================================================================

proc newDataRequirement*(
  dataKind: DataKind,
  providers: seq[DataProvider] = @[],
  required: bool = true,
  frequency: DataFrequency = dfDaily,
  metadata: Table[string, string] = initTable[string, string]()
): DataRequirement =
  ## Create a DataRequirement specification
  DataRequirement(
    dataKind: dataKind,
    providers: providers,
    required: required,
    frequency: frequency,
    metadata: metadata
  )

# ============================================================================
# String Representations
# ============================================================================

proc `$`*(freq: DataFrequency): string =
  ## String representation of DataFrequency
  case freq
  of dfRealtime: "realtime"
  of dfMinute: "minute"
  of dfHourly: "hourly"
  of dfDaily: "daily"
  of dfWeekly: "weekly"

proc `$`*(req: DataRequirement): string =
  ## String representation of DataRequirement
  result = "DataRequirement(kind=" & $req.dataKind & 
           ", required=" & $req.required &
           ", freq=" & $req.frequency
  if req.providers.len > 0:
    result &= ", providers=["
    for i, p in req.providers:
      if i > 0: result &= ", "
      result &= $p
    result &= "]"
  result &= ")"
